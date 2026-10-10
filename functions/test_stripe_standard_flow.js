/**
 * Automated Test Suite for Stripe Standard Flow & Direct Charges (Ticketto)
 * 
 * Covers all 9 required verification scenarios:
 * 1. Account creation for new organizer (controller properties)
 * 2. Onboarding & Dashboard link generation
 * 3. Checkout Session creation for €20 ticket (direct charge, no platform fee/transfer)
 * 4. Webhook checkout.session.completed & idempotency check
 * 5. Callable refundTicket execution ({ stripeAccount } & status update)
 * 6. Webhook charge.refunded handling (organizer Stripe dashboard refund)
 * 7. Incomplete account check (charges_enabled = false rejection)
 * 8. Group paid registration with pending_registrations
 * 9. Platform subscriptions integrity (checkout & stripeWebhook isolation)
 */

const assert = require("assert");

// Colors for terminal output
const green = (s) => `\x1b[32m${s}\x1b[0m`;
const red = (s) => `\x1b[31m${s}\x1b[0m`;
const cyan = (s) => `\x1b[36m${s}\x1b[0m`;
const bold = (s) => `\x1b[1m${s}\x1b[0m`;

console.log(bold("\n══════════════════════════════════════════════════════════"));
console.log(bold("  Ticketto - Stripe Standard Flow Automated Test Suite    "));
console.log(bold("══════════════════════════════════════════════════════════\n"));

// ─── In-Memory Mock Firestore ─────────────────────────────────
class MockFirestore {
  constructor() {
    this.data = {}; // collection -> docId -> data
  }

  collection(collName) {
    if (!this.data[collName]) this.data[collName] = {};
    const coll = this.data[collName];
    const self = this;

    return {
      doc(id) {
        const docId = id || `mock_id_${Math.random().toString(36).substring(7)}`;
        return {
          id: docId,
          async get() {
            const docData = coll[docId];
            return {
              id: docId,
              exists: !!docData,
              ref: self.collection(collName).doc(docId),
              data: () => (docData ? JSON.parse(JSON.stringify(docData)) : undefined),
            };
          },
          async set(data) {
            coll[docId] = JSON.parse(JSON.stringify(data));
          },
          async update(updates) {
            if (!coll[docId]) coll[docId] = {};
            for (const [k, v] of Object.entries(updates)) {
              if (v && v._isIncrement) {
                coll[docId][k] = (coll[docId][k] || 0) + v.val;
              } else if (v && v._isDelete) {
                delete coll[docId][k];
              } else {
                coll[docId][k] = v;
              }
            }
          },
          async delete() {
            delete coll[docId];
          },
          collection(subCollName) {
            return self.collection(`${collName}/${docId}/${subCollName}`);
          },
        };
      },
      where(field, op, val) {
        return {
          where(f2, op2, v2) {
            return this;
          },
          limit(n) {
            return this;
          },
          async get() {
            const results = [];
            for (const [id, docData] of Object.entries(coll)) {
              if (op === "==" && docData[field] === val) {
                results.push({
                  id,
                  exists: true,
                  data: () => JSON.parse(JSON.stringify(docData)),
                  ref: self.collection(collName).doc(id),
                });
              }
            }
            return {
              empty: results.length === 0,
              size: results.length,
              docs: results,
            };
          },
        };
      },
      async get() {
        const results = Object.entries(coll).map(([id, docData]) => ({
          id,
          exists: true,
          data: () => JSON.parse(JSON.stringify(docData)),
          ref: self.collection(collName).doc(id),
        }));
        return {
          empty: results.length === 0,
          size: results.length,
          docs: results,
        };
      },
    };
  }

  batch() {
    return {
      delete(ref) {
        ref.delete();
      },
      async commit() {},
    };
  }
}

// FieldValue mocks
const mockFieldValue = {
  serverTimestamp: () => new Date().toISOString(),
  increment: (n) => ({ _isIncrement: true, val: n }),
  delete: () => ({ _isDelete: true }),
};

// ─── Mock Stripe SDK ───────────────────────────────────────────
class MockStripe {
  constructor(secretKey) {
    this.secretKey = secretKey;
    this.lastCalls = {
      accountsCreate: null,
      accountLinksCreate: null,
      checkoutSessionsCreate: null,
      refundsCreate: null,
    };

    this.accounts = {
      create: async (params) => {
        this.lastCalls.accountsCreate = params;
        return { id: "acct_test_standard_123" };
      },
      retrieve: async (accountId) => {
        if (accountId === "acct_legacy_invalid") {
          throw new Error("No such account: " + accountId);
        }
        if (accountId === "acct_incomplete") {
          return { id: accountId, charges_enabled: false };
        }
        return { id: accountId, charges_enabled: true };
      },
    };

    this.customers = {
      update: async (customerId, params) => {
        return { id: customerId, ...params };
      },
    };

    this.accountLinks = {
      create: async (params) => {
        this.lastCalls.accountLinksCreate = params;
        return { url: "https://connect.stripe.com/setup/s/test_link_123" };
      },
    };

    this.checkout = {
      sessions: {
        create: async (params, options) => {
          this.lastCalls.checkoutSessionsCreate = { params, options };
          return {
            id: "cs_test_session_123",
            url: "https://checkout.stripe.com/c/pay/cs_test_session_123",
          };
        },
      },
    };

    this.refunds = {
      create: async (params, options) => {
        this.lastCalls.refundsCreate = { params, options };
        return {
          id: "re_test_refund_123",
          status: "succeeded",
        };
      },
    };

    this.webhooks = {
      constructEvent: (payload, sig, secret) => {
        // Return parsed JSON payload as event
        if (Buffer.isBuffer(payload)) {
          return JSON.parse(payload.toString("utf8"));
        }
        if (typeof payload === "string") {
          return JSON.parse(payload);
        }
        return payload;
      },
    };

    this.oauth = {
      token: async (params) => {
        return { stripe_user_id: "acct_oauth_connected_456" };
      },
    };
  }
}

// ─── Test Harness Setup ────────────────────────────────────────
const mockDb = new MockFirestore();
const mockStripeInstance = new MockStripe("sk_test_mock");

// Intercept module dependencies
const Module = require("module");
const originalRequire = Module.prototype.require;

Module.prototype.require = function (id) {
  if (id === "stripe") {
    return () => mockStripeInstance;
  }
  if (id === "firebase-admin") {
    return {
      initializeApp: () => {},
      firestore: Object.assign(() => mockDb, {
        FieldValue: mockFieldValue,
      }),
      storage: () => ({}),
    };
  }
  if (id === "resend") {
    return {
      Resend: class {
        constructor() {
          this.emails = {
            send: async () => ({ data: { id: "resend_test_123" } }),
          };
        }
      },
    };
  }
  return originalRequire.apply(this, arguments);
};

// Set required env vars for tests
process.env.STRIPE_SECRET_KEY = "sk_test_mock";
process.env.STRIPE_CONNECT_WEBHOOK_SECRET = "whsec_test_connect";
process.env.STRIPE_WEBHOOK_SECRET = "whsec_test_platform";

// Load Cloud Functions
const funcs = require("./index.js");

const { EventEmitter } = require("events");

// Mock HTTP req / res helpers
class MockResponse extends EventEmitter {
  constructor() {
    super();
    this.statusCode = 200;
    this.headers = {};
    this.data = null;
    this.redirectUrl = null;
  }
  setHeader(k, v) {
    this.headers[k.toLowerCase()] = v;
    return this;
  }
  getHeader(k) {
    return this.headers[k.toLowerCase()];
  }
  status(code) {
    this.statusCode = code;
    return this;
  }
  json(payload) {
    this.data = payload;
    this.emit("finish");
    return this;
  }
  send(payload) {
    this.data = payload;
    this.emit("finish");
    return this;
  }
  redirect(url) {
    this.redirectUrl = url;
    this.emit("finish");
    return this;
  }
  end() {
    this.emit("finish");
    return this;
  }
}

class MockRequest extends EventEmitter {
  constructor({ body = {}, query = {}, headers = {}, rawBody = null }) {
    super();
    this.body = body;
    this.query = query;
    this.headers = headers;
    this.rawBody = rawBody !== null ? Buffer.from(rawBody) : Buffer.from(JSON.stringify(body));
    this.method = "POST";
  }
}

function createMockReqRes(options = {}) {
  const res = new MockResponse();
  const req = new MockRequest(options);
  return { req, res };
}

// ─── TEST SUITE EXECUTION ─────────────────────────────────────
let passedCount = 0;
let failedCount = 0;

async function runTest(testNumber, testName, testFn) {
  try {
    process.stdout.write(cyan(`Test ${testNumber}: ${testName}... `));
    await testFn();
    console.log(green("PASSED ✓"));
    passedCount++;
  } catch (err) {
    console.log(red("FAILED ✗"));
    console.error(err);
    failedCount++;
  }
}

async function runAllTests() {
  // Setup baseline mock data
  await mockDb.collection("organizations").doc("org_standard_1").set({
    name: "Org Standard Test",
    ownerId: "user_owner_1",
    plan: "pro",
  });

  await mockDb.collection("events").doc("evt_paid_1").set({
    title: "Concerto Live 2026",
    orgId: "org_standard_1",
    attendeesCount: 5,
    language: "it",
  });

  // ─── 1. Account Creation (Standard Controller Properties & Legacy Replacement) ───
  await runTest(
    1,
    "Organizer account creation with Stripe Standard controller properties and legacy replacement",
    async () => {
      // 1a. Test legacy account replacement (like Bitle and TEST orgs)
      await mockDb.collection("organizations").doc("org_legacy_bitle").set({
        name: "Bitle Legacy Org",
        plan: "pro",
        stripeConnectAccountId: "acct_legacy_invalid", // exists in DB from old stripe account
        stripeConnectStatus: "pending",
        paymentMode: null, // old mode was null
      });

      const { req: reqLegacy, res: resLegacy } = createMockReqRes({
        body: { orgId: "org_legacy_bitle", email: "info@bitle.it", orgName: "Bitle Legacy Org" },
      });

      await funcs.createConnectAccount(reqLegacy, resLegacy);
      assert.strictEqual(resLegacy.statusCode, 200);

      const bitleDoc = await mockDb.collection("organizations").doc("org_legacy_bitle").get();
      assert.strictEqual(bitleDoc.data().stripeConnectAccountIdLegacy, "acct_legacy_invalid");
      assert.strictEqual(bitleDoc.data().stripeConnectAccountId, "acct_test_standard_123");
      assert.strictEqual(bitleDoc.data().paymentMode, "standard");
      assert.strictEqual(bitleDoc.data().stripeConnectStatus, "pending");

      // 1b. Fresh org creation
      const { req, res } = createMockReqRes({
        body: { orgId: "org_standard_1", email: "organizer@ticketto.it", orgName: "Org Standard Test" },
      });

      await funcs.createConnectAccount(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.data.accountId, "acct_test_standard_123");

      const params = mockStripeInstance.lastCalls.accountsCreate;
      assert.ok(params, "stripe.accounts.create must have been called");
      assert.strictEqual(params.controller?.stripe_dashboard?.type, "full");
      assert.strictEqual(params.controller?.fees?.payer, "account");
      assert.strictEqual(params.controller?.losses?.payments, "stripe");
      assert.strictEqual(params.controller?.requirement_collection, "stripe");

      // Verify Firestore saved paymentMode = standard
      const orgDoc = await mockDb.collection("organizations").doc("org_standard_1").get();
      assert.strictEqual(orgDoc.data().paymentMode, "standard");
      assert.strictEqual(orgDoc.data().stripeConnectAccountId, "acct_test_standard_123");
    }
  );

  // ─── 2. Onboarding / Dashboard Link Generation ───────────────
  await runTest(
    2,
    "Account link generation (type=dashboard returns stripe.com, type=onboarding returns setup URL)",
    async () => {
      // Test type: 'dashboard'
      const { req: reqDash, res: resDash } = createMockReqRes({
        query: { orgId: "org_standard_1", type: "dashboard" },
      });
      await funcs.createConnectAccountLink(reqDash, resDash);
      assert.strictEqual(resDash.statusCode, 200);
      assert.strictEqual(resDash.data.url, "https://dashboard.stripe.com");

      // Test type: 'onboarding'
      const { req: reqOnb, res: resOnb } = createMockReqRes({
        query: { orgId: "org_standard_1", type: "onboarding" },
      });
      await funcs.createConnectAccountLink(reqOnb, resOnb);
      assert.strictEqual(resOnb.statusCode, 200);
      assert.strictEqual(resOnb.data.url, "https://connect.stripe.com/setup/s/test_link_123");
      assert.strictEqual(mockStripeInstance.lastCalls.accountLinksCreate.type, "account_onboarding");
    }
  );

  // ─── 3. Checkout Session Creation for €20 Ticket ─────────────
  await runTest(
    3,
    "Ticket checkout session creation (€20 direct charge with { stripeAccount })",
    async () => {
      const { req, res } = createMockReqRes({
        body: {
          eventId: "evt_paid_1",
          orgId: "org_standard_1",
          eventTitle: "Concerto Live 2026",
          price: 20,
          quantity: 1,
          firstName: "Mario",
          lastName: "Rossi",
          email: "mario.rossi@example.com",
        },
      });

      await funcs.createTicketCheckout(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.data.sessionId, "cs_test_session_123");

      const call = mockStripeInstance.lastCalls.checkoutSessionsCreate;
      assert.ok(call, "checkout.sessions.create must be called");

      // 1. Direct charge header options:
      assert.strictEqual(call.options?.stripeAccount, "acct_test_standard_123");

      // 2. Exact amount: 2000 cents (€20.00)
      const lineItem = call.params.line_items[0];
      assert.strictEqual(lineItem.price_data.unit_amount, 2000);
      assert.strictEqual(lineItem.price_data.currency, "eur");

      // 3. ZERO platform deductions or transfer_data
      assert.strictEqual(call.params.payment_intent_data?.application_fee_amount, undefined);
      assert.strictEqual(call.params.payment_intent_data?.transfer_data, undefined);
      assert.strictEqual(call.params.application_fee_amount, undefined);
    }
  );

  // ─── 4. Webhook checkout.session.completed & Idempotency ─────
  await runTest(
    4,
    "Connect webhook checkout.session.completed creation and idempotency check",
    async () => {
      const eventPayload = {
        type: "checkout.session.completed",
        account: "acct_test_standard_123",
        data: {
          object: {
            payment_intent: "pi_direct_123",
            amount_total: 2000,
            metadata: {
              payment_type: "ticket_payment",
              event_id: "evt_paid_1",
              org_id: "org_standard_1",
              marketing_consent: "true",
              attendee_data: JSON.stringify({
                firstName: "Mario",
                lastName: "Rossi",
                email: "mario.rossi@example.com",
              }),
            },
          },
        },
      };

      const { req: req1, res: res1 } = createMockReqRes({
        rawBody: JSON.stringify(eventPayload),
        headers: { "stripe-signature": "test_sig" },
      });

      await funcs.stripeConnectWebhook(req1, res1);
      assert.strictEqual(res1.statusCode, 200);

      // Verify attendee created in mock Firestore
      const attendeeSnap = await mockDb.collection("attendees").where("paymentId", "==", "pi_direct_123").get();
      assert.strictEqual(attendeeSnap.size, 1);
      const att = attendeeSnap.docs[0].data();
      assert.strictEqual(att.paymentStatus, "paid");
      assert.strictEqual(att.paymentAmount, 20);
      assert.strictEqual(att.status, "confirmed");
      assert.strictEqual(att.stripeAccount, "acct_test_standard_123");

      // Test idempotency: send exact same webhook a second time
      const { req: req2, res: res2 } = createMockReqRes({
        rawBody: JSON.stringify(eventPayload),
        headers: { "stripe-signature": "test_sig" },
      });

      await funcs.stripeConnectWebhook(req2, res2);
      assert.strictEqual(res2.statusCode, 200);

      // Ensure attendee count is STILL 1
      const attendeeSnap2 = await mockDb.collection("attendees").where("paymentId", "==", "pi_direct_123").get();
      assert.strictEqual(attendeeSnap2.size, 1, "Duplicate payment must be ignored");
    }
  );

  // ─── 5. Callable refundTicket Execution ───────────────────────
  await runTest(
    5,
    "Callable refundTicket executes stripe.refunds.create on connected account and decrements attendee count",
    async () => {
      // Find the attendee created in Test 4
      const attendeeSnap = await mockDb.collection("attendees").where("paymentId", "==", "pi_direct_123").get();
      const attendeeId = attendeeSnap.docs[0].id;

      // Initial event count is 5
      const callerAuth = { auth: { uid: "user_owner_1" }, data: { attendeeId } };

      const result = await funcs.refundTicket.run(callerAuth);
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.refundId, "re_test_refund_123");

      // Verify Stripe refund call was executed with { stripeAccount: connectedAccountId }
      const refundCall = mockStripeInstance.lastCalls.refundsCreate;
      assert.ok(refundCall, "stripe.refunds.create must be called");
      assert.strictEqual(refundCall.options?.stripeAccount, "acct_test_standard_123");
      assert.strictEqual(refundCall.params?.payment_intent, "pi_direct_123");

      // Verify attendee status updated to refunded
      const updatedAttDoc = await mockDb.collection("attendees").doc(attendeeId).get();
      assert.strictEqual(updatedAttDoc.data().status, "refunded");
      assert.strictEqual(updatedAttDoc.data().paymentStatus, "refunded");
      assert.strictEqual(updatedAttDoc.data().refundSource, "ticketto_dashboard");

      // Verify event attendee count decremented
      const evtDoc = await mockDb.collection("events").doc("evt_paid_1").get();
      assert.strictEqual(evtDoc.data().attendeesCount, 4);
    }
  );

  // ─── 6. Webhook charge.refunded from Organizer Dashboard ────
  await runTest(
    6,
    "Connect webhook charge.refunded updates attendee status and decrements count",
    async () => {
      // Create a paid attendee to be refunded via Stripe dashboard
      const attRef = mockDb.collection("attendees").doc("att_dashboard_refund");
      await attRef.set({
        eventId: "evt_paid_1",
        orgId: "org_standard_1",
        firstName: "Giulia",
        email: "giulia@example.com",
        status: "confirmed",
        paymentStatus: "paid",
        paymentId: "pi_dashboard_refund_456",
      });

      const refundEventPayload = {
        type: "charge.refunded",
        account: "acct_test_standard_123",
        data: {
          object: {
            payment_intent: "pi_dashboard_refund_456",
          },
        },
      };

      const { req, res } = createMockReqRes({
        rawBody: JSON.stringify(refundEventPayload),
        headers: { "stripe-signature": "test_sig" },
      });

      await funcs.stripeConnectWebhook(req, res);
      assert.strictEqual(res.statusCode, 200);

      // Verify attendee updated to refunded
      const updated = await attRef.get();
      assert.strictEqual(updated.data().status, "refunded");
      assert.strictEqual(updated.data().paymentStatus, "refunded");
      assert.strictEqual(updated.data().refundSource, "stripe_dashboard");

      // Event count decremented from 4 to 3
      const evtDoc = await mockDb.collection("events").doc("evt_paid_1").get();
      assert.strictEqual(evtDoc.data().attendeesCount, 3);
    }
  );

  // ─── 7. Incomplete & Legacy Account Rejections ─────────────
  await runTest(
    7,
    "createTicketCheckout rejects charges_enabled=false and legacy/invalid accounts",
    async () => {
      // 7a. Account with charges_enabled = false
      await mockDb.collection("organizations").doc("org_incomplete").set({
        name: "Incomplete Org",
        plan: "pro",
        paymentMode: "standard",
        stripeConnectAccountId: "acct_incomplete",
      });

      const { req, res } = createMockReqRes({
        body: {
          eventId: "evt_paid_1",
          orgId: "org_incomplete",
          price: 15,
          email: "buyer@example.com",
        },
      });

      await funcs.createTicketCheckout(req, res);

      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(
        res.data.error,
        "Completa la configurazione del tuo account Stripe per vendere biglietti"
      );

      // 7b. Organization with legacy/unretrievable account or paymentMode != standard
      await mockDb.collection("organizations").doc("org_legacy_checkout").set({
        name: "Legacy Org",
        plan: "pro",
        paymentMode: null,
        stripeConnectAccountId: "acct_legacy_invalid",
      });

      const { req: lReq, res: lRes } = createMockReqRes({
        body: {
          eventId: "evt_paid_1",
          orgId: "org_legacy_checkout",
          price: 15,
          email: "buyer@example.com",
        },
      });

      await funcs.createTicketCheckout(lReq, lRes);
      assert.strictEqual(lRes.statusCode, 400);
      assert.strictEqual(
        lRes.data.error,
        "Ricollega il tuo account Stripe dalle Impostazioni"
      );

      // 7c. createConnectAccountLink with legacy/unretrievable account
      const { req: linkReq, res: linkRes } = createMockReqRes({
        query: { orgId: "org_legacy_checkout", type: "onboarding" },
      });
      await funcs.createConnectAccountLink(linkReq, linkRes);
      assert.strictEqual(linkRes.statusCode, 400);
      assert.strictEqual(
        linkRes.data.error,
        "Ricollega il tuo account Stripe dalle Impostazioni"
      );
    }
  );

  // ─── 8. Group Paid Registration via pending_registrations ───
  await runTest(
    8,
    "Group paid registration creates pending_registration and webhook unpacks all attendees",
    async () => {
      const { req, res } = createMockReqRes({
        body: {
          eventId: "evt_paid_1",
          orgId: "org_standard_1",
          eventTitle: "Concerto Live 2026",
          price: 25,
          quantity: 2,
          firstName: "Luca",
          lastName: "Bianchi",
          email: "luca.bianchi@example.com",
          extraAttendees: [
            { firstName: "Elena", lastName: "Neri", email: "elena.neri@example.com" },
          ],
        },
      });

      await funcs.createTicketCheckout(req, res);
      assert.strictEqual(res.statusCode, 200);

      // Verify pending_registration was created
      const pendingSnap = await mockDb.collection("pending_registrations").get();
      assert.strictEqual(pendingSnap.size, 1);
      const pendingId = pendingSnap.docs[0].id;

      // Simulate webhook completion with pending_registration_id
      const groupWebhookPayload = {
        type: "checkout.session.completed",
        account: "acct_test_standard_123",
        data: {
          object: {
            payment_intent: "pi_group_789",
            amount_total: 5000, // €50 total for 2 attendees
            metadata: {
              payment_type: "ticket_payment",
              event_id: "evt_paid_1",
              org_id: "org_standard_1",
              pending_registration_id: pendingId,
            },
          },
        },
      };

      const { req: gReq, res: gRes } = createMockReqRes({
        rawBody: JSON.stringify(groupWebhookPayload),
        headers: { "stripe-signature": "test_sig" },
      });

      await funcs.stripeConnectWebhook(gReq, gRes);
      assert.strictEqual(gRes.statusCode, 200);

      // Verify both attendees are created with paid status & equal split €25
      const attLucaSnap = await mockDb.collection("attendees").where("email", "==", "luca.bianchi@example.com").get();
      assert.strictEqual(attLucaSnap.size, 1);
      assert.strictEqual(attLucaSnap.docs[0].data().paymentAmount, 25);
      assert.strictEqual(attLucaSnap.docs[0].data().paymentStatus, "paid");

      const attElenaSnap = await mockDb.collection("attendees").where("email", "==", "elena.neri@example.com").get();
      assert.strictEqual(attElenaSnap.size, 1);
      assert.strictEqual(attElenaSnap.docs[0].data().paymentAmount, 25);
      assert.strictEqual(attElenaSnap.docs[0].data().paymentStatus, "paid");

      // Verify pending_registration is cleaned up
      const checkPending = await mockDb.collection("pending_registrations").doc(pendingId).get();
      assert.strictEqual(checkPending.exists, false, "pending_registration must be deleted after fulfillment");
    }
  );

  // ─── 9. Platform Subscriptions Integrity ─────────────────────
  await runTest(
    9,
    "Platform subscriptions checkout and stripeWebhook isolate ticket payments and activate plans",
    async () => {
      await mockDb.collection("organizations").doc("org_sub_test").set({
        name: "Subscription Org",
        plan: "free",
      });

      // 1. Ticket payment sent to platform webhook must be ignored
      const ticketOnPlatformPayload = {
        type: "checkout.session.completed",
        data: {
          object: {
            metadata: { payment_type: "ticket_payment" },
          },
        },
      };
      const { req: tReq, res: tRes } = createMockReqRes({
        rawBody: JSON.stringify(ticketOnPlatformPayload),
        headers: { "stripe-signature": "test_sig" },
      });

      await funcs.stripeWebhook(tReq, tRes);
      assert.strictEqual(tRes.statusCode, 200);

      // 2. Subscription payment activates organization plan
      const subPayload = {
        type: "checkout.session.completed",
        data: {
          object: {
            customer: "cus_sub_123",
            subscription: "sub_sub_456",
            metadata: {
              orgId: "org_sub_test",
              plan: "business",
            },
          },
        },
      };
      const { req: sReq, res: sRes } = createMockReqRes({
        rawBody: JSON.stringify(subPayload),
        headers: { "stripe-signature": "test_sig" },
      });

      await funcs.stripeWebhook(sReq, sRes);
      assert.strictEqual(sRes.statusCode, 200);

      const subOrg = await mockDb.collection("organizations").doc("org_sub_test").get();
      assert.strictEqual(subOrg.data().plan, "business");
      assert.strictEqual(subOrg.data().stripeCustomerId, "cus_sub_123");
      assert.strictEqual(subOrg.data().stripeSubscriptionId, "sub_sub_456");
    }
  );

  // ─── Final Summary ──────────────────────────────────────────
  console.log(bold("\n══════════════════════════════════════════════════════════"));
  if (failedCount === 0) {
    console.log(green(bold(`  ALL ${passedCount} TESTS PASSED SUCCESSFULLY! ✓`)));
  } else {
    console.log(red(bold(`  ${failedCount} TESTS FAILED, ${passedCount} PASSED.`)));
  }
  console.log(bold("══════════════════════════════════════════════════════════\n"));

  process.exit(failedCount === 0 ? 0 : 1);
}

runAllTests().catch((err) => {
  console.error("Unhandled test runner error:", err);
  process.exit(1);
});
