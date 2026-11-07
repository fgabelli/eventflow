/**
 * One-shot setup script for Google Wallet Generic Class & Sample Object (for publishing review).
 *
 * Usage:
 *   node functions/setup_google_wallet.mjs
 *
 * Authenticates as `eventflow-3541b@appspot.gserviceaccount.com` with scope
 * `https://www.googleapis.com/auth/wallet_object.issuer` via IAM Credentials API
 * (or GOOGLE_APPLICATION_CREDENTIALS if provided).
 */
import fs from 'fs';

const ISSUER_ID = '3388000000023089767';
const CLASS_ID = `${ISSUER_ID}.ticketto`;
const SAMPLE_OBJECT_ID = `${ISSUER_ID}.review_sample_001`;
const SERVICE_ACCOUNT = 'eventflow-3541b@appspot.gserviceaccount.com';
const WALLET_SCOPE = 'https://www.googleapis.com/auth/wallet_object.issuer';
const BASE_URL = 'https://walletobjects.googleapis.com/walletobjects/v1';

async function getWalletAccessToken() {
  // 1. If GOOGLE_APPLICATION_CREDENTIALS is set, use GoogleAuth directly
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const { GoogleAuth } = await import('google-auth-library');
    const auth = new GoogleAuth({ scopes: [WALLET_SCOPE] });
    const client = await auth.getClient();
    const tokenRes = await client.getAccessToken();
    if (tokenRes?.token) return tokenRes.token;
  }

  // 2. Otherwise impersonate SERVICE_ACCOUNT using Firebase CLI OAuth token
  const cfgPath = `${process.env.HOME}/.config/configstore/firebase-tools.json`;
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const userToken = cfg.tokens?.access_token;
  if (!userToken) {
    throw new Error('No Firebase CLI access_token found and GOOGLE_APPLICATION_CREDENTIALS not set.');
  }

  const iamUrl = `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${SERVICE_ACCOUNT}:generateAccessToken`;
  const res = await fetch(iamUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${userToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      scope: [WALLET_SCOPE],
      lifetime: '3600s',
    }),
  });

  if (!res.ok) {
    throw new Error(`IAM generateAccessToken failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return data.accessToken;
}

async function upsertResource(token, collectionPath, resourceId, payload) {
  const postRes = await fetch(`${BASE_URL}/${collectionPath}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (postRes.ok) {
    const created = await postRes.json();
    console.log(`✅ Created ${collectionPath}/${resourceId}`);
    return created;
  }

  if (postRes.status === 409) {
    console.log(`ℹ️ ${collectionPath}/${resourceId} already exists (409). Updating via PUT...`);
    const putRes = await fetch(`${BASE_URL}/${collectionPath}/${encodeURIComponent(resourceId)}`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    if (!putRes.ok) {
      throw new Error(`PUT ${collectionPath}/${resourceId} failed (${putRes.status}): ${await putRes.text()}`);
    }
    const updated = await putRes.json();
    console.log(`✅ Updated ${collectionPath}/${resourceId}`);
    return updated;
  }

  throw new Error(`POST ${collectionPath} failed (${postRes.status}): ${await postRes.text()}`);
}

async function main() {
  console.log(`🔑 Obtaining access token for ${SERVICE_ACCOUNT} (scope: ${WALLET_SCOPE})...`);
  const token = await getWalletAccessToken();
  console.log('✅ Access token acquired.');

  // 1a. Create/Update Generic Class with reviewStatus: UNDER_REVIEW
  const classPayload = {
    id: CLASS_ID,
    reviewStatus: 'UNDER_REVIEW',
    multipleDevicesAndHoldersAllowedStatus: 'MULTIPLE_HOLDERS',
  };
  await upsertResource(token, 'genericClass', CLASS_ID, classPayload);

  // 1b. Create/Update sample Generic Object with realistic data
  const objectPayload = {
    id: SAMPLE_OBJECT_ID,
    classId: CLASS_ID,
    state: 'ACTIVE',
    cardTitle: {
      defaultValue: { language: 'it', value: 'AREL & Friends | Aperitivo a Milano' },
    },
    subheader: {
      defaultValue: { language: 'it', value: 'AREL' },
    },
    header: {
      defaultValue: { language: 'it', value: 'Mario Rossi' },
    },
    logo: {
      sourceUri: { uri: 'https://ticketto.it/icons/Icon-512.png' },
      contentDescription: { defaultValue: { language: 'it', value: 'Ticketto' } },
    },
    barcode: {
      type: 'QR_CODE',
      value: 'TKT-REVIEW-SAMPLE-001',
      alternateText: 'TKT-REVIEW-SAMPLE-001',
    },
    hexBackgroundColor: '#0E6B52',
    textModulesData: [
      { header: 'DATA', body: 'mar 10 nov 2026 18:30', id: 'date' },
      { header: 'LUOGO', body: 'Piccolo Café, Via Rovello 2, Milano', id: 'loc' },
    ],
  };
  await upsertResource(token, 'genericObject', SAMPLE_OBJECT_ID, objectPayload);

  // 1c. Verify class & object list via GET
  console.log('\n🔍 Verifying genericClass...');
  const classGetRes = await fetch(`${BASE_URL}/genericClass/${encodeURIComponent(CLASS_ID)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const classData = await classGetRes.json();
  console.log(`   Class ID: ${classData.id} | reviewStatus: ${classData.reviewStatus}`);

  console.log('\n🔍 Verifying genericObject list for class...');
  const listRes = await fetch(`${BASE_URL}/genericObject?classId=${encodeURIComponent(CLASS_ID)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const listData = await listRes.json();
  const resources = listData.resources || [];
  console.log(`   Found ${resources.length} object(s) in class ${CLASS_ID}:`);
  for (const obj of resources) {
    console.log(`   - ${obj.id} (state: ${obj.state}, header: ${obj.header?.defaultValue?.value})`);
  }
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
