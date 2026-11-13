const { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const functions = require("firebase-functions/v1");

const admin = require("firebase-admin");
const { Resend } = require("resend");
const { PKPass } = require("passkit-generator");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

// ─── Environment Variables ───────────────────────────────────
// These are loaded from functions/.env file
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const EMAIL_FROM = process.env.EMAIL_FROM || 'Ticketto <event@ticketto.it>';

// ─── i18n Localization ──────────────────────────────────────
const SUPPORTED_LANGUAGES = ['it', 'en'];

const i18nStrings = {
  it: {
    email: {
      // Confirmation email
      confirmationSubject: '🎫 Registrazione Confermata – {{eventTitle}}',
      confirmationTitle: 'Registrazione Confermata',
      confirmationSubtitle: 'Il tuo posto è stato riservato',
      greeting: 'Ciao <strong>{{firstName}}</strong>,',
      confirmationBody: 'La tua iscrizione è confermata. Qui trovi le informazioni dell\'evento e il tuo invito per <strong style="color: #101410;">{{eventTitle}}</strong>:',
      addToCalendarButton: 'Aggiungi al calendario',
      calendarIcsHint: 'o apri l\'allegato evento.ics',
      calendarQrNote: 'Il tuo QR di ingresso è nell\'email di conferma',
      calendarMeetingLabel: 'Link riunione',
      dateLabel: '📅 Data',
      timeLabel: '🕐 Ora',
      locationLabel: '📍 Luogo',
      openInMapsLabel: 'Apri in Maps',
      onlineEventLabel: '🌐 Evento Online',
      joinStreamLabel: 'Partecipa allo Streaming',
      timeSlotLabel: '⏰ Fascia oraria',
      priceLabel: '💰 Prezzo',
      qrTitle: 'Il tuo QR Code per l\'ingresso',
      qrHint: 'Mostra questo QR code all\'ingresso per il check-in',
      appleWalletHint: '🍎 Il file <strong>biglietto.pkpass</strong> è allegato a questa email — aprilo per aggiungerlo a Apple Wallet',
      googleWalletButton: '🤖 Aggiungi a Google Wallet',
      sentBy: 'Inviato da <strong>{{orgName}}</strong>',
      // Reminder email
      reminderSubject: '📅 Promemoria: {{eventTitle}} si avvicina!',
      reminderTitle: '📅 Promemoria Evento',
      reminderSubtitle: 'Non dimenticare, ci vediamo presto!',
      reminderBody: 'Ti ricordiamo che l\'evento <strong style="color: #1A1A2E;">{{eventTitle}}</strong> si avvicina. Ecco i dettagli:',
      reminderNote: 'Ricorda di portare con te il QR code ricevuto nella mail di conferma per un check-in rapido all\'ingresso.',
      // Thank you email
      thankYouSubject: '🙏 Grazie per aver partecipato a {{eventTitle}}!',
      thankYouTitle: '🙏 Grazie!',
      thankYouSubtitle: 'La tua partecipazione è stata preziosa',
      thankYouBody: 'Grazie per aver partecipato a <strong style="color: #1A1A2E;">{{eventTitle}}</strong> del {{formattedDate}}. Speriamo che l\'esperienza sia stata di tuo gradimento!',
      feedbackTitle: '💬 Lascia un feedback',
      feedbackBody: 'Il tuo parere ci aiuta a migliorare i prossimi eventi',
      feedbackButton: 'Lascia il tuo feedback →',
      // HTML title tags
      confirmationPageTitle: 'Conferma Registrazione',
      reminderPageTitle: 'Promemoria Evento',
      thankYouPageTitle: 'Grazie per aver partecipato',
      // Attachment
      passFilename: 'biglietto.pkpass',
      icsFilename: 'evento.ics',
      // Organizer notification
      orgNotificationSubject: '🔔 Nuova Iscrizione - {{eventTitle}}',
      orgNotificationTitle: 'Nuova Iscrizione: {{eventTitle}}',
      orgNotificationName: 'Nome',
      orgNotificationEmail: 'Email',
      orgNotificationRegisteredAt: 'Registrato il',
      orgNotificationViewEvent: 'Visualizza Evento',
      // Team invitation
      teamInviteSubject: '👋 Sei parte del team di {{orgName}} su Ticketto',
      teamInviteTitle: 'Invito nel Team',
      teamInviteSubtitle: 'Sei parte di {{orgName}}',
      teamInviteBody: '<strong style="color: #101410;">{{orgName}}</strong> ti ha aggiunto al team su Ticketto come <strong style="color: #0E6B52;">{{roleLabel}}</strong>. Accedi con questa email per iniziare subito a collaborare.',
      teamInviteButton: 'Accedi a Ticketto',
      checkinAppTitle: 'App Ticketto Check-in',
      checkinAppDesc: 'Come membro dello Staff, puoi scaricare l\'app mobile per scansionare i biglietti e gestire gli ingressi agli eventi:',
    },
    wallet: {
      passDescription: 'Biglietto per {{eventTitle}}',
      eventLabel: 'EVENTO',
      dateLabel: 'DATA',
      timeLabel: 'ORA',
      locationLabel: 'LUOGO',
      attendeeLabel: 'PARTECIPANTE',
      emailLabel: 'Email',
      organizerLabel: 'Organizzatore',
      infoLabel: 'Info',
      infoText: 'Mostra questo pass all\'ingresso per il check-in.\n\nPowered by Ticketto — ticketto.it',
    },
    stripe: {
      ticketProduct: '🎫 {{eventTitle}}',
      ticketDescriptionSingle: 'Biglietto per {{eventTitle}}',
      ticketDescriptionMultiple: '{{quantity}} biglietti per {{eventTitle}}',
    },
  },
  en: {
    email: {
      // Confirmation email
      confirmationSubject: '🎫 Registration Confirmed – {{eventTitle}}',
      confirmationTitle: 'Registration Confirmed',
      confirmationSubtitle: 'Your spot has been reserved',
      greeting: 'Hi <strong>{{firstName}}</strong>,',
      confirmationBody: 'Your registration is confirmed. Here are the event details and your invitation for <strong style="color: #101410;">{{eventTitle}}</strong>:',
      addToCalendarButton: 'Add to calendar',
      calendarIcsHint: 'or open the attached event.ics',
      calendarQrNote: 'Your entry QR code is in the confirmation email',
      calendarMeetingLabel: 'Meeting link',
      dateLabel: '📅 Date',
      timeLabel: '🕐 Time',
      locationLabel: '📍 Venue',
      openInMapsLabel: 'Open in Maps',
      onlineEventLabel: '🌐 Online Event',
      joinStreamLabel: 'Join the Stream',
      timeSlotLabel: '⏰ Time slot',
      priceLabel: '💰 Price',
      qrTitle: 'Your QR Code for entry',
      qrHint: 'Show this QR code at the entrance for check-in',
      appleWalletHint: '🍎 The <strong>ticket.pkpass</strong> file is attached to this email — open it to add it to Apple Wallet',
      googleWalletButton: '🤖 Add to Google Wallet',
      sentBy: 'Sent by <strong>{{orgName}}</strong>',
      // Reminder email
      reminderSubject: '📅 Reminder: {{eventTitle}} is coming up!',
      reminderTitle: '📅 Event Reminder',
      reminderSubtitle: 'Don\'t forget, see you soon!',
      reminderBody: 'Just a reminder that <strong style="color: #1A1A2E;">{{eventTitle}}</strong> is coming up. Here are the details:',
      reminderNote: 'Remember to bring the QR code you received in the confirmation email for a quick check-in at the entrance.',
      // Thank you email
      thankYouSubject: '🙏 Thanks for attending {{eventTitle}}!',
      thankYouTitle: '🙏 Thank you!',
      thankYouSubtitle: 'Your attendance meant a lot to us',
      thankYouBody: 'Thank you for attending <strong style="color: #1A1A2E;">{{eventTitle}}</strong> on {{formattedDate}}. We hope you enjoyed the experience!',
      feedbackTitle: '💬 Leave feedback',
      feedbackBody: 'Your feedback helps us improve future events',
      feedbackButton: 'Leave your feedback →',
      // HTML title tags
      confirmationPageTitle: 'Registration Confirmation',
      reminderPageTitle: 'Event Reminder',
      thankYouPageTitle: 'Thanks for attending',
      // Attachment
      passFilename: 'ticket.pkpass',
      icsFilename: 'event.ics',
      // Organizer notification
      orgNotificationSubject: '🔔 New Registration - {{eventTitle}}',
      orgNotificationTitle: 'New Registration: {{eventTitle}}',
      orgNotificationName: 'Name',
      orgNotificationEmail: 'Email',
      orgNotificationRegisteredAt: 'Registered on',
      orgNotificationViewEvent: 'View Event',
      // Team invitation
      teamInviteSubject: '👋 You have been added to the {{orgName}} team on Ticketto',
      teamInviteTitle: 'Team Invitation',
      teamInviteSubtitle: 'You are part of {{orgName}}',
      teamInviteBody: '<strong style="color: #101410;">{{orgName}}</strong> added you to their team on Ticketto as <strong style="color: #0E6B52;">{{roleLabel}}</strong>. Sign in with this email to get started.',
      teamInviteButton: 'Sign in to Ticketto',
      checkinAppTitle: 'Ticketto Check-in App',
      checkinAppDesc: 'As a Staff member, you can download the mobile app to scan tickets and manage check-ins at events:',
    },
    wallet: {
      passDescription: 'Ticket for {{eventTitle}}',
      eventLabel: 'EVENT',
      dateLabel: 'DATE',
      timeLabel: 'TIME',
      locationLabel: 'VENUE',
      attendeeLabel: 'ATTENDEE',
      emailLabel: 'Email',
      organizerLabel: 'Organizer',
      infoLabel: 'Info',
      infoText: 'Show this pass at the entrance for check-in.\n\nPowered by Ticketto — ticketto.it',
    },
    stripe: {
      ticketProduct: '🎫 {{eventTitle}}',
      ticketDescriptionSingle: 'Ticket for {{eventTitle}}',
      ticketDescriptionMultiple: '{{quantity}} tickets for {{eventTitle}}',
    },
  },
};

/**
 * Resolve a localized string with variable interpolation.
 * @param {string} lang - Language code ('it', 'en')
 * @param {string} section - Section key ('email', 'wallet', 'stripe')
 * @param {string} key - String key within the section
 * @param {Object} vars - Variables to interpolate (e.g. { eventTitle: "..." })
 * @returns {string} Resolved string
 */
function t(lang, section, key, vars = {}) {
  const safeLang = SUPPORTED_LANGUAGES.includes(lang) ? lang : 'en';
  const str = i18nStrings[safeLang]?.[section]?.[key]
    || i18nStrings['en']?.[section]?.[key]
    || `[${section}.${key}]`;
  return str.replace(/\{\{(\w+)\}\}/g, (_, v) => vars[v] !== undefined ? vars[v] : `{{${v}}}`);
}

/**
 * Get the locale string for date formatting based on language.
 * @param {string} lang - Language code
 * @returns {string} Locale string (e.g. 'it-IT', 'en-US')
 */
function getDateLocale(lang) {
  return lang === 'it' ? 'it-IT' : 'en-US';
}

/**
 * Resolve event language with fallback.
 * @param {Object} eventData - Firestore event document data
 * @returns {string} Resolved language code
 */
function getEventLang(eventData) {
  const lang = eventData?.language || 'it';
  return SUPPORTED_LANGUAGES.includes(lang) ? lang : 'en';
}

/**
 * Resolve Google Maps URL for an event with fallback to encoded address.
 * @param {Object} eventData - Firestore event document data
 * @returns {string|null} Resolved Google Maps URL or null
 */
function getEventMapUrl(eventData) {
  if (!eventData || eventData.isOnline) return null;
  if (typeof eventData.mapUrl === 'string' && eventData.mapUrl.trim() !== '') {
    return eventData.mapUrl.trim();
  }
  if (typeof eventData.lat === 'number' && typeof eventData.lng === 'number' && !isNaN(eventData.lat) && !isNaN(eventData.lng)) {
    return `https://www.google.com/maps/search/?api=1&query=${eventData.lat},${eventData.lng}`;
  }
  if (typeof eventData.location === 'string' && eventData.location.trim() !== '') {
    return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(eventData.location.trim())}`;
  }
  return null;
}

// ─── Apple Wallet Pass Generator ─────────────────────────────
const PASS_CERTS_DIR = path.join(__dirname, "certs");
const PASS_MODEL_DIR = path.join(PASS_CERTS_DIR, "ticketto.pass");

async function generateApplePass(attendee, eventData, orgData, attendeeDocId, lang = 'it') {
  try {
    if (!attendee.qrCode) {
      console.warn("⚠️ Apple Wallet skipped: qrCode is empty");
      return null;
    }

    const eventDate = eventData.date?.toDate
      ? eventData.date.toDate()
      : new Date(eventData.date);

    const locale = getDateLocale(lang);
    const formattedDate = eventDate.toLocaleDateString(locale, {
      weekday: "long", year: "numeric", month: "long", day: "numeric", timeZone: "Europe/Rome",
    });
    const formattedTime = eventDate.toLocaleTimeString(locale, {
      hour: "2-digit", minute: "2-digit", timeZone: "Europe/Rome",
    });

    const pass = await PKPass.from({
      model: PASS_MODEL_DIR,
      certificates: {
        wwdr: fs.readFileSync(path.join(PASS_CERTS_DIR, "wwdr.pem")),
        signerCert: fs.readFileSync(path.join(PASS_CERTS_DIR, "pass_cert.pem")),
        signerKey: fs.readFileSync(path.join(PASS_CERTS_DIR, "pass_key.pem")),
      },
    }, {
      serialNumber: attendee.qrCode,
      description: t(lang, 'wallet', 'passDescription', { eventTitle: eventData.title }),
      organizationName: orgData?.name || "Ticketto",
      relevantDate: eventDate.toISOString(),
    });

    // Set pass type (required in passkit-generator v3 before accessing fields)
    pass.type = "eventTicket";

    // Set barcode
    pass.setBarcodes({
      message: attendee.qrCode,
      format: "PKBarcodeFormatQR",
      messageEncoding: "iso-8859-1",
    });

    // Primary: event name
    pass.primaryFields.push({
      key: "event",
      label: t(lang, 'wallet', 'eventLabel'),
      value: eventData.title,
    });

    // Secondary: date + time
    pass.secondaryFields.push(
      { key: "date", label: t(lang, 'wallet', 'dateLabel'), value: formattedDate },
      { key: "time", label: t(lang, 'wallet', 'timeLabel'), value: formattedTime }
    );

    // Auxiliary: location + attendee name
    if (eventData.location) {
      pass.auxiliaryFields.push({
        key: "location", label: t(lang, 'wallet', 'locationLabel'), value: eventData.location,
      });
    }
    pass.auxiliaryFields.push({
      key: "name", label: t(lang, 'wallet', 'attendeeLabel'),
      value: `${attendee.firstName} ${attendee.lastName}`,
    });

    // Back fields
    const passMapUrl = getEventMapUrl(eventData);
    if (passMapUrl) {
      pass.backFields.push({
        key: "map",
        label: t(lang, 'wallet', 'locationLabel'),
        value: eventData.location ? `${eventData.location}\n${passMapUrl}` : passMapUrl,
      });
    }
    pass.backFields.push(
      { key: "email", label: t(lang, 'wallet', 'emailLabel'), value: attendee.email },
      { key: "org", label: t(lang, 'wallet', 'organizerLabel'), value: orgData?.name || "—" },
      { key: "info", label: t(lang, 'wallet', 'infoLabel'), value: t(lang, 'wallet', 'infoText') }
    );

    // Generate buffer — return it directly for email attachment
    const pkpassBuffer = pass.getAsBuffer();
    console.log(`🎫 Apple Wallet pass generated (${pkpassBuffer.length} bytes)`);
    return pkpassBuffer;
  } catch (error) {
    console.error("❌ Error generating Apple Wallet pass:", error);
    return null;
  }
}

// ─── Google Wallet Pass Generator ────────────────────────────
const GOOGLE_WALLET_ISSUER_ID = "3388000000023089767";
const WALLET_SERVICE_ACCOUNT = "eventflow-3541b@appspot.gserviceaccount.com";

async function generateGoogleWalletLink(attendee, eventData, orgData, attendeeDocId, lang = 'it') {
  try {
    if (!attendee.qrCode) {
      console.warn("⚠️ Google Wallet skipped: qrCode is empty");
      return null;
    }

    const { GoogleAuth } = require("google-auth-library");

    let eventDate = null;
    if (eventData.date?.toDate) {
      eventDate = eventData.date.toDate();
    } else if (eventData.date) {
      const parsed = new Date(eventData.date);
      if (!isNaN(parsed.getTime())) eventDate = parsed;
    }

    const eventIdSafe = (eventData.id || attendee.eventId || "event").replace(/[^a-zA-Z0-9_.-]/g, "_");
    const attendeeIdSafe = (attendeeDocId || attendee.id || attendee.qrCode || "ticket").replace(/[^a-zA-Z0-9_.-]/g, "_");

    const classId = `${GOOGLE_WALLET_ISSUER_ID}.ticketto`;
    const objectId = `${GOOGLE_WALLET_ISSUER_ID}.ticket_${attendeeIdSafe}`;

    const eventTitle = eventData.title || "Evento Ticketto";
    const issuerName = orgData?.name || "Ticketto";
    const attendeeFullName = `${attendee.firstName || ""} ${attendee.lastName || ""}`.trim() || attendee.email || "Partecipante";
    const primaryColor = eventData.primaryColor && /^#[0-9A-Fa-f]{6}$/.test(eventData.primaryColor)
      ? eventData.primaryColor
      : "#0E6B52";

    const locale = getDateLocale(lang);
    let formattedDateTime = "";
    if (eventDate) {
      const dateStr = eventDate.toLocaleDateString(locale, {
        weekday: "short", year: "numeric", month: "short", day: "numeric", timeZone: "Europe/Rome",
      });
      const timeStr = eventDate.toLocaleTimeString(locale, {
        hour: "2-digit", minute: "2-digit", timeZone: "Europe/Rome",
      });
      formattedDateTime = `${dateStr} ${timeStr}`;
    }

    const textModules = [];
    if (formattedDateTime) {
      textModules.push({
        header: t(lang, "wallet", "dateLabel") || "DATA",
        body: formattedDateTime,
      });
    }
    if (eventData.location) {
      textModules.push({
        header: t(lang, "wallet", "locationLabel") || "LUOGO",
        body: eventData.location,
      });
    }
    textModules.push({
      header: t(lang, "wallet", "emailLabel") || "Email",
      body: attendee.email || "—",
    });
    if (orgData?.name) {
      textModules.push({
        header: t(lang, "wallet", "organizerLabel") || "Organizzatore",
        body: orgData.name,
      });
    }

    const genericObject = {
      id: objectId,
      classId: classId,
      logo: {
        sourceUri: {
          uri: "https://ticketto.it/icons/Icon-512.png",
        },
        contentDescription: {
          defaultValue: { language: lang, value: "Ticketto Logo" },
        },
      },
      cardTitle: {
        defaultValue: { language: lang, value: eventTitle },
      },
      subheader: {
        defaultValue: { language: lang, value: issuerName },
      },
      header: {
        defaultValue: { language: lang, value: attendeeFullName },
      },
      barcode: {
        type: "QR_CODE",
        value: attendee.qrCode,
        alternateText: attendee.qrCode,
      },
      hexBackgroundColor: primaryColor,
      textModulesData: textModules,
    };

    // Build the JWT claims for Google Wallet Generic Pass
    const claims = {
      iss: WALLET_SERVICE_ACCOUNT,
      aud: "google",
      typ: "savetowallet",
      payload: {
        genericObjects: [genericObject],
      },
    };

    // Sign JWT using IAM Credentials API
    // Requires "Service Account Token Creator" role on the service account
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
    const client = await auth.getClient();

    const now = Math.floor(Date.now() / 1000);
    // IAM Credentials API restricts exp to at most 12 hours (43200 seconds) after iat
    const expTime = now + 43200;

    const jwtPayload = {
      ...claims,
      iat: now,
      exp: expTime,
    };

    const response = await client.request({
      url: `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${WALLET_SERVICE_ACCOUNT}:signJwt`,
      method: "POST",
      data: {
        payload: JSON.stringify(jwtPayload),
      },
    });

    const signedJwt = response.data.signedJwt;
    const saveUrl = `https://pay.google.com/gp/v/save/${signedJwt}`;

    console.log(`🎫 Google Wallet link generated for ${attendee.email}`);
    return saveUrl;
  } catch (error) {
    console.error("❌ Error generating Google Wallet link:", error);
    return null;
  }
}

// ─── Calendar Helpers (Google Calendar URL & RFC 5545 .ics) ──
function parseRomeDateTime(year, month, day, hour = 0, minute = 0, second = 0) {
  const getOffsetAt = (utcMs) => {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Europe/Rome",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23",
    }).formatToParts(new Date(utcMs));
    const map = {};
    for (const p of parts) map[p.type] = p.value;
    const romeAsUtc = Date.UTC(
      Number(map.year),
      Number(map.month) - 1,
      Number(map.day),
      Number(map.hour),
      Number(map.minute),
      Number(map.second)
    );
    return romeAsUtc - utcMs;
  };
  const utcGuess = Date.UTC(year, month - 1, day, hour, minute, second);
  const offset1 = getOffsetAt(utcGuess);
  const adjusted1 = utcGuess - offset1;
  const offset2 = getOffsetAt(adjusted1);
  return new Date(utcGuess - offset2);
}

function toUtcDateFromEventField(val) {
  if (!val) return null;
  if (typeof val.toDate === "function") {
    const d = val.toDate();
    return isNaN(d.getTime()) ? null : d;
  }
  if (val instanceof Date) {
    return isNaN(val.getTime()) ? null : val;
  }
  if (typeof val === "number") {
    const d = new Date(val);
    return isNaN(d.getTime()) ? null : d;
  }
  if (typeof val === "string") {
    const s = val.trim();
    if (!s) return null;
    if (/(?:Z|[+-]\d{2}:?\d{2})$/i.test(s)) {
      const d = new Date(s);
      return isNaN(d.getTime()) ? null : d;
    }
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?/);
    if (m) {
      return parseRomeDateTime(
        Number(m[1]),
        Number(m[2]),
        Number(m[3]),
        Number(m[4] || 0),
        Number(m[5] || 0),
        Number(m[6] || 0)
      );
    }
    const fallback = new Date(s);
    return isNaN(fallback.getTime()) ? null : fallback;
  }
  return null;
}

function resolveEventDateRange(event, timeSlot) {
  const baseStart = toUtcDateFromEventField(event?.date) || new Date();

  if (timeSlot && typeof timeSlot.startTime === "string" && typeof timeSlot.endTime === "string") {
    const sm = timeSlot.startTime.trim().match(/^(\d{1,2}):(\d{2})$/);
    const em = timeSlot.endTime.trim().match(/^(\d{1,2}):(\d{2})$/);
    if (sm && em) {
      const parts = new Intl.DateTimeFormat("en-CA", {
        timeZone: "Europe/Rome",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
      }).formatToParts(baseStart);
      const map = {};
      for (const p of parts) map[p.type] = p.value;
      const year = Number(map.year);
      const month = Number(map.month);
      const day = Number(map.day);

      const start = parseRomeDateTime(year, month, day, Number(sm[1]), Number(sm[2]), 0);
      let end = parseRomeDateTime(year, month, day, Number(em[1]), Number(em[2]), 0);
      if (end.getTime() <= start.getTime()) {
        end = parseRomeDateTime(year, month, day + 1, Number(em[1]), Number(em[2]), 0);
      }
      return { start, end };
    }
  }

  const parsedEnd = toUtcDateFromEventField(event?.endDate);
  const end = (parsedEnd && parsedEnd.getTime() > baseStart.getTime())
    ? parsedEnd
    : new Date(baseStart.getTime() + 2 * 60 * 60 * 1000);

  return { start: baseStart, end };
}

function formatUtcCalendarTimestamp(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return (
    String(date.getUTCFullYear()) +
    pad(date.getUTCMonth() + 1) +
    pad(date.getUTCDate()) +
    "T" +
    pad(date.getUTCHours()) +
    pad(date.getUTCMinutes()) +
    pad(date.getUTCSeconds()) +
    "Z"
  );
}

function getCalendarLocation(event) {
  if (!event) return "";
  if (event.isOnline) {
    return typeof event.meetingUrl === "string" ? event.meetingUrl.trim() : "";
  }
  return typeof event.location === "string" ? event.location.trim() : "";
}

function buildCalendarDescription(event, lang = "it") {
  const parts = [];
  const rawDesc = typeof event?.description === "string" ? event.description.trim() : "";
  if (rawDesc) {
    let shortDesc = rawDesc.replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\n{3,}/g, "\n\n");
    if (shortDesc.length > 300) {
      shortDesc = shortDesc.slice(0, 297).trimEnd() + "...";
    }
    parts.push(shortDesc);
  }
  if (event?.isOnline && typeof event.meetingUrl === "string" && event.meetingUrl.trim()) {
    parts.push(`${t(lang, "email", "calendarMeetingLabel")}: ${event.meetingUrl.trim()}`);
  }
  parts.push(t(lang, "email", "calendarQrNote"));
  return parts.join("\n\n");
}

function buildGoogleCalendarUrl(event, timeSlot, lang = "it") {
  const { start, end } = resolveEventDateRange(event, timeSlot);
  const startUtc = formatUtcCalendarTimestamp(start);
  const endUtc = formatUtcCalendarTimestamp(end);
  const title = (event?.title || "Evento").trim();
  const details = buildCalendarDescription(event, lang);
  const location = getCalendarLocation(event);

  return (
    "https://calendar.google.com/calendar/render?action=TEMPLATE" +
    `&text=${encodeURIComponent(title)}` +
    `&dates=${startUtc}/${endUtc}` +
    `&details=${encodeURIComponent(details)}` +
    `&location=${encodeURIComponent(location)}`
  );
}

function escapeIcsText(value) {
  return String(value ?? "")
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\r\n|\r|\n/g, "\\n");
}

function foldIcsLine(line) {
  if (Buffer.byteLength(line, "utf8") <= 75 && line.length <= 75) {
    return line;
  }
  const chunks = [];
  let current = "";
  let currentBytes = 0;
  for (const ch of line) {
    const chBytes = Buffer.byteLength(ch, "utf8");
    if (currentBytes + chBytes > 75 || current.length + ch.length > 75) {
      chunks.push(current);
      current = " " + ch;
      currentBytes = 1 + chBytes;
    } else {
      current += ch;
      currentBytes += chBytes;
    }
  }
  if (current) chunks.push(current);
  return chunks.join("\r\n");
}

function generateEventIcs(attendee, event, timeSlot, attendeeDocId, lang = "it") {
  const { start, end } = resolveEventDateRange(event, timeSlot);
  const dtStamp = formatUtcCalendarTimestamp(new Date());
  const dtStart = formatUtcCalendarTimestamp(start);
  const dtEnd = formatUtcCalendarTimestamp(end);
  const uidBase = String(attendeeDocId || attendee?.id || attendee?.qrCode || crypto.randomUUID()).trim();
  const resolvedEventId = String(event?.id || attendee?.eventId || "").trim();
  const eventUrl = resolvedEventId ? `https://ticketto.it/register/${encodeURIComponent(resolvedEventId)}` : "https://ticketto.it";
  const summary = (event?.title || "Evento").trim();
  const description = buildCalendarDescription(event, lang);
  const location = getCalendarLocation(event);

  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Ticketto//Eventflow//IT",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "BEGIN:VEVENT",
    `UID:${uidBase}@ticketto.it`,
    `DTSTAMP:${dtStamp}`,
    `DTSTART:${dtStart}`,
    `DTEND:${dtEnd}`,
    `SUMMARY:${escapeIcsText(summary)}`,
    `DESCRIPTION:${escapeIcsText(description)}`,
    `LOCATION:${escapeIcsText(location)}`,
    `URL:${eventUrl}`,
    "STATUS:CONFIRMED",
    "BEGIN:VALARM",
    "TRIGGER:-PT1H",
    "ACTION:DISPLAY",
    `DESCRIPTION:${escapeIcsText(summary)}`,
    "END:VALARM",
    "END:VEVENT",
    "END:VCALENDAR",
  ];

  return lines.map(foldIcsLine).join("\r\n") + "\r\n";
}

// ─── Email Template ──────────────────────────────────────────
function buildConfirmationEmail(attendee, event, org, timeSlot, walletPassUrl, googleWalletUrl, lang = 'it') {
  const locale = getDateLocale(lang);
  const eventDate = toUtcDateFromEventField(event.date) || new Date();
  const googleCalendarUrl = buildGoogleCalendarUrl(event, timeSlot, lang);
  const formattedDate = eventDate.toLocaleDateString(locale, {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "Europe/Rome",
  });
  const formattedTime = eventDate.toLocaleTimeString(locale, {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Rome",
  });

  const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(attendee.qrCode)}`;

  const timeSlotHtml = timeSlot
    ? `<tr>
        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'timeSlotLabel')}</td>
        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">${timeSlot.label} (${timeSlot.startTime} – ${timeSlot.endTime})</td>
      </tr>`
    : "";

  let locationHtml = "";
  const mapUrl = getEventMapUrl(event);
  if (event.isOnline && event.meetingUrl) {
    locationHtml = `<tr>
        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'onlineEventLabel')}</td>
        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #0E6B52;">
          <a href="${event.meetingUrl}" style="color: #0E6B52; text-decoration: none;">${t(lang, 'email', 'joinStreamLabel')}</a>
        </td>
      </tr>`;
  } else if (event.location || mapUrl) {
    locationHtml = `<tr>
        <td style="padding: 8px 0; color: #6B7280; font-size: 14px; vertical-align: top;">${t(lang, 'email', 'locationLabel')}</td>
        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">
          ${event.location ? `<div>${mapUrl ? `<a href="${mapUrl}" target="_blank" rel="noopener" style="color: #1A1A2E; text-decoration: none;">${event.location}</a>` : event.location}</div>` : ""}
          ${mapUrl ? `<div style="margin-top: 4px;"><a href="${mapUrl}" target="_blank" rel="noopener" style="color: #0E6B52; text-decoration: underline; font-weight: 600; font-size: 13px;">📍 ${t(lang, 'email', 'openInMapsLabel')}</a></div>` : ""}
        </td>
      </tr>`;
  }

  const priceHtml = event.isPaid
    ? `<tr>
        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'priceLabel')}</td>
        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">€${Number(event.price).toFixed(2)}</td>
      </tr>`
    : "";

  return `<!DOCTYPE html>
<html lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${t(lang, 'email', 'confirmationPageTitle')}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F3F4F6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F3F4F6; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.06);">
          
          <!-- Header -->
          <tr>
            <td style="background-color: #0E6B52; padding: 36px 32px; text-align: center;">
              <div style="margin-bottom: 20px;">
                <img src="https://ticketto.it/images/ticketto_logo_dark.png" alt="Ticketto" height="28" style="height: 28px; display: inline-block; border: 0;" />
              </div>
              <h1 style="color: #FFFFFF; margin: 0 0 8px 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">${t(lang, 'email', 'confirmationTitle')}</h1>
              <p style="color: rgba(255,255,255,0.9); margin: 0; font-size: 15px;">${t(lang, 'email', 'confirmationSubtitle')}</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 32px 32px 16px 32px;">
              <p style="margin: 0; font-size: 16px; color: #101410;">
                ${t(lang, 'email', 'greeting', { firstName: attendee.firstName })}
              </p>
              <p style="margin: 8px 0 0 0; font-size: 15px; color: #4B5563; line-height: 1.6;">
                ${t(lang, 'email', 'confirmationBody', { eventTitle: event.title })}
              </p>
            </td>
          </tr>

          <!-- Event Details -->
          <tr>
            <td style="padding: 0 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F9FAFB; border-radius: 12px; border: 1px solid #E5E7EB;">
                <tr>
                  <td style="padding: 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'dateLabel')}</td>
                        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">${formattedDate}</td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'timeLabel')}</td>
                        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">${formattedTime}</td>
                      </tr>
                      ${locationHtml}
                      ${timeSlotHtml}
                      ${priceHtml}
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Add to Calendar CTA -->
          <tr>
            <td style="padding: 20px 32px 8px 32px; text-align: center;">
              <a href="${googleCalendarUrl.replace(/&/g, '&amp;')}" target="_blank" rel="noopener" style="display: inline-block; background-color: #9AD530; color: #101410; text-decoration: none; font-weight: 700; font-size: 15px; padding: 14px 32px; border-radius: 10px; letter-spacing: -0.2px;">
                ${t(lang, 'email', 'addToCalendarButton')}
              </a>
              <p style="margin: 10px 0 0 0; font-size: 12px; color: #6B7280;">
                ${t(lang, 'email', 'calendarIcsHint')}
              </p>
            </td>
          </tr>

          <!-- QR Code -->
          <tr>
            <td style="padding: 20px 32px 24px 32px; text-align: center;">
              <p style="margin: 0 0 16px 0; font-size: 14px; font-weight: 600; color: #101410;">${t(lang, 'email', 'qrTitle')}</p>
              <div style="display: inline-block; background: #FFFFFF; border: 2px solid #E5E7EB; border-radius: 16px; padding: 20px;">
                <img src="${qrCodeUrl}" alt="QR Code" width="200" height="200" style="display: block;" />
              </div>
              <p style="margin: 12px 0 0 0; font-size: 12px; color: #6B7280;">${t(lang, 'email', 'qrHint')}</p>
            </td>
          </tr>

          <!-- Wallet Hints -->
          ${walletPassUrl ? `
          <tr>
            <td style="padding: 0 32px 24px 32px; text-align: center;">
              <p style="margin: 0; font-size: 13px; color: #6B7280;">${t(lang, 'email', 'appleWalletHint')}</p>
            </td>
          </tr>
          ` : ""}

          <!-- Attendee Info -->
          <tr>
            <td style="padding: 0 32px 24px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #E8F2EC; border-radius: 12px;">
                <tr>
                  <td style="padding: 16px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="font-size: 13px; color: #0E6B52; font-weight: 500;">👤 ${attendee.firstName} ${attendee.lastName}</td>
                        <td style="font-size: 13px; color: #0E6B52; font-weight: 500; text-align: right;">✉️ ${attendee.email}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 32px 32px 32px; text-align: center; border-top: 1px solid #E5E7EB; background-color: #FAFAFA;">
              <p style="margin: 0 0 10px 0; font-size: 12px; color: #6B7280;">
                ${t(lang, 'email', 'sentBy', { orgName: org?.name || "Ticketto" })}
              </p>
              <div style="margin: 6px 0 4px 0;">
                <img src="https://ticketto.it/images/ticketto_logo.png" alt="Ticketto" height="18" style="height: 18px; vertical-align: middle; border: 0; display: inline-block;" />
              </div>
              <p style="margin: 4px 0 0 0; font-size: 12px; color: #0E6B52; font-weight: 600;">
                L'invito diventa presenza.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// ─── Helper: email dell'organizzatore (per Reply-To) ─────────
// Le email ai partecipanti partono da event@ticketto.it: senza Reply-To, chi
// risponde (es. "non posso venire") scrive a una casella che nessuno presidia
// e l'organizzatore non lo sa mai. NB: organizations.email è quasi sempre null,
// quindi il fallback vero è il proprietario in users.organizationIds.
async function getOrganizerEmail(orgId, orgData) {
  try {
    if (orgData?.email) return orgData.email;
    if (!orgId) return null;
    const owners = await db.collection("users")
      .where("organizationIds", "array-contains", orgId)
      .get();
    if (owners.empty) return null;
    // il più vecchio = chi ha creato l'organizzazione
    const sorted = owners.docs
      .map((d) => d.data())
      .filter((u) => u.email)
      .sort((a, b) => (a.createdAt?.toMillis?.() || 0) - (b.createdAt?.toMillis?.() || 0));
    return sorted[0]?.email || null;
  } catch (err) {
    console.warn("⚠️ getOrganizerEmail failed (non-blocking):", err.message);
    return null;
  }
}

// ─── Anti-Phishing & Rate Limit Helpers ──────────────────────
const ADMIN_ALERT_EMAIL = "f.gabelli@gmail.com";
const ADMIN_ALLOWED_EMAILS = new Set([
  "f.gabelli@gmail.com",
  "fabio.gabelli@bitle.it",
  "sviluppo@revan.it",
]);

const SCAM_KEYWORDS_REGEX = /\b(invoice|refund|purchase|paypal|amazon|apple|usd|cancellation|call|support|helpdesk|mcafee|norton|geek\s*squad)\b|\$/i;
const SCAM_PHONE_REGEX = /\+?\d[\d\s().-]{8,}\d/;
const EMAIL_OR_URL_REGEX = /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|https?:\/\/\S+|www\.\S+)/i;

const EMAIL_RATE_LIMITS = {
  free: { maxPerHour: 60, maxPerDay: 200 },
  paid: { maxPerHour: 600, maxPerDay: 3000 },
};

function looksLikeScam(text, title = "", orgName = "") {
  const combined = String(text || "");
  if (SCAM_PHONE_REGEX.test(combined) && SCAM_KEYWORDS_REGEX.test(combined)) {
    return true;
  }
  if (EMAIL_OR_URL_REGEX.test(String(title || "")) || EMAIL_OR_URL_REGEX.test(String(orgName || ""))) {
    return true;
  }
  return false;
}

async function notifyAdmin(subjectPrefix, details) {
  try {
    if (!RESEND_API_KEY) return;
    const resend = new Resend(RESEND_API_KEY);
    const rows = Object.entries(details || {})
      .map(([k, v]) => `<tr><td style="padding:6px 12px;font-weight:bold;border-bottom:1px solid #eee;">${k}</td><td style="padding:6px 12px;border-bottom:1px solid #eee;">${String(v ?? "")}</td></tr>`)
      .join("");
    await resend.emails.send({
      from: EMAIL_FROM,
      to: [ADMIN_ALERT_EMAIL],
      subject: `🚨 [Ticketto Security] ${subjectPrefix}`,
      html: `<div style="font-family:sans-serif;max-width:600px;margin:20px auto;padding:20px;border:1px solid #e5e7eb;border-radius:12px;">
        <h2 style="margin-top:0;color:#b91c1c;">🚨 ${subjectPrefix}</h2>
        <table style="width:100%;border-collapse:collapse;font-size:14px;">${rows}</table>
      </div>`,
    });
  } catch (err) {
    console.error("⚠️ notifyAdmin failed:", err.message);
  }
}

/**
 * Rate limit check & counter increment for confirmation emails per organization.
 * Uses `organizations/{orgId}/counters/emails` with hourly and daily windows.
 */
async function checkAndIncrementEmailRateLimit(orgId, isPaidPlan) {
  if (!orgId) return { allowed: true };
  const limits = isPaidPlan ? EMAIL_RATE_LIMITS.paid : EMAIL_RATE_LIMITS.free;
  const now = new Date();
  const iso = now.toISOString();
  const hourKey = iso.slice(0, 13); // YYYY-MM-DDTHH
  const dayKey = iso.slice(0, 10);  // YYYY-MM-DD

  const counterRef = db.collection("organizations").doc(orgId).collection("counters").doc("emails");

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const data = snap.exists ? snap.data() : {};

    const hourCount = data.hourKey === hourKey ? (data.hourCount || 0) : 0;
    const hourAlerted = data.hourKey === hourKey ? Boolean(data.hourAlerted) : false;
    const dayCount = data.dayKey === dayKey ? (data.dayCount || 0) : 0;
    const dayAlerted = data.dayKey === dayKey ? Boolean(data.dayAlerted) : false;

    if (hourCount >= limits.maxPerHour) {
      if (!hourAlerted) {
        tx.set(counterRef, {
          hourKey, hourCount, hourAlerted: true,
          dayKey, dayCount, dayAlerted,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      return {
        allowed: false,
        shouldAlert: !hourAlerted,
        reason: `Hourly limit exceeded (${hourCount}/${limits.maxPerHour})`,
      };
    }

    if (dayCount >= limits.maxPerDay) {
      if (!dayAlerted) {
        tx.set(counterRef, {
          hourKey, hourCount, hourAlerted,
          dayKey, dayCount, dayAlerted: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      return {
        allowed: false,
        shouldAlert: !dayAlerted,
        reason: `Daily limit exceeded (${dayCount}/${limits.maxPerDay})`,
      };
    }

    tx.set(counterRef, {
      hourKey,
      hourCount: hourCount + 1,
      hourAlerted,
      dayKey,
      dayCount: dayCount + 1,
      dayAlerted,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { allowed: true };
  });
}

function signModerationAction(orgId, action) {
  const secret = RESEND_API_KEY || "ticketto-moderation-secret-2026";
  return crypto.createHmac("sha256", secret).update(`${orgId}:${action}`).digest("hex");
}

async function performBlockOrganization(orgId, reason = "admin:manual") {
  if (!orgId) throw new Error("Missing orgId");

  await db.collection("organizations").doc(orgId).set({
    blocked: true,
    blockedReason: reason,
    blockedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await db.collection("organizations").doc(orgId).collection("public").doc("profile").set({
    blocked: true,
  }, { merge: true });

  // Move all published events of this org to draft
  const eventsSnap = await db.collection("events").where("orgId", "==", orgId).get();
  let draftedEvents = 0;
  for (const evDoc of eventsSnap.docs) {
    if (evDoc.data().status === "published") {
      await evDoc.ref.update({ status: "draft" });
      draftedEvents++;
    }
  }

  // Find and disable associated users in Firebase Auth
  const uids = new Set();
  const membersSnap = await db.collection("organizations").doc(orgId).collection("members").get();
  membersSnap.docs.forEach((d) => {
    uids.add(d.id);
    if (d.data().userId) uids.add(d.data().userId);
  });
  const usersSnap = await db.collection("users").where("organizationIds", "array-contains", orgId).get();
  usersSnap.docs.forEach((d) => uids.add(d.id));

  let disabledUsers = 0;
  for (const uid of uids) {
    try {
      const userRecord = await admin.auth().getUser(uid);
      if (userRecord.email && ADMIN_ALLOWED_EMAILS.has(userRecord.email.toLowerCase())) {
        continue;
      }
      await admin.auth().updateUser(uid, { disabled: true });
      disabledUsers++;
    } catch (uErr) {
      console.warn(`⚠️ Could not disable user ${uid}:`, uErr.message);
    }
  }

  console.log(`🛑 Blocked org=${orgId} reason=${reason} draftedEvents=${draftedEvents} disabledUsers=${disabledUsers}`);
  return { orgId, draftedEvents, disabledUsers };
}

// ─── Trigger: New Attendee Created ───────────────────────────
exports.onAttendeeCreated = onDocumentCreated(
  {
    document: "attendees/{attendeeId}",
  },
  async (event) => {
    const attendee = event.data?.data();
    if (!attendee) return;

    try {
      // Fetch event data
      const eventDoc = await db.collection("events").doc(attendee.eventId).get();
      if (!eventDoc.exists) {
        console.error("Event not found:", attendee.eventId);
        return;
      }
      const eventData = eventDoc.data();
      const lang = getEventLang(eventData);

      // Fetch org data
      let orgData = null;
      if (attendee.orgId) {
        const orgDoc = await db.collection("organizations").doc(attendee.orgId).get();
        if (orgDoc.exists) orgData = orgDoc.data();
      }

      // ─── Anti-Phishing 1.1a: Event must be published and org not blocked ───
      if (eventData.status !== "published" || orgData?.blocked === true) {
        console.warn(`🛑 Blocked confirmation email: event=${attendee.eventId} status=${eventData.status} orgBlocked=${orgData?.blocked}`);
        await event.data.ref.update({
          emailSent: false,
          emailError: "blocked: event not published or org blocked",
        });
        return;
      }

      // ─── Anti-Phishing 1.1b: Content scam filter on event + org text ───
      const combinedText = [eventData.title, eventData.description, eventData.location, orgData?.name].join(" ");
      if (looksLikeScam(combinedText, eventData.title, orgData?.name)) {
        console.warn(`🚨 SCAM FILTER triggered for org=${attendee.orgId} event=${attendee.eventId} title="${eventData.title}"`);
        if (attendee.orgId) {
          await db.collection("organizations").doc(attendee.orgId).set({
            blocked: true,
            blockedReason: "auto:scam-filter",
            blockedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          await db.collection("organizations").doc(attendee.orgId).collection("public").doc("profile").set({
            blocked: true,
          }, { merge: true });
        }
        await event.data.ref.update({
          emailSent: false,
          emailError: "blocked: scam filter",
        });
        await notifyAdmin("SCAM FILTER", {
          orgId: attendee.orgId,
          orgName: orgData?.name || "",
          eventId: attendee.eventId,
          title: eventData.title || "",
          attendeeEmail: attendee.email || "",
        });
        return;
      }

      // ─── Server-side: Increment attendeesCount & update timeSlot booking ───
      const eventUpdateData = {
        attendeesCount: admin.firestore.FieldValue.increment(1),
      };

      // If attendee booked a time slot, increment its bookedCount
      if (attendee.timeSlotId && eventData.timeSlots) {
        const slotIndex = eventData.timeSlots.findIndex((s) => s.id === attendee.timeSlotId);
        if (slotIndex >= 0) {
          const updatedSlots = [...eventData.timeSlots];
          updatedSlots[slotIndex] = {
            ...updatedSlots[slotIndex],
            bookedCount: (updatedSlots[slotIndex].bookedCount || 0) + 1,
          };
          eventUpdateData.timeSlots = updatedSlots;
        }
      }

      await db.collection("events").doc(attendee.eventId).update(eventUpdateData);
      console.log(`📊 attendeesCount incremented for "${eventData.title}"`);

      // ─── Plan limit telemetry ───
      const currentCount = (eventData.attendeesCount || 0) + 1;
      const PLAN_ATTENDEE_LIMITS = { free: 50, pro: 500, business: -1 };

      // Wallet passes are only generated for Pro/Business plans
      const orgPlan = orgData?.plan || "free";
      const isPaidPlan = orgPlan !== "free";

      // Plan limit warning (telemetry only, does not block)
      const planLimit = PLAN_ATTENDEE_LIMITS[orgPlan] || 50;
      if (planLimit > 0 && currentCount > planLimit) {
        console.warn(`⚠️ PLAN LIMIT EXCEEDED: org=${attendee.orgId} plan=${orgPlan} limit=${planLimit} current=${currentCount} event=${attendee.eventId}`);
      }

      // ─── Anti-Phishing 1.2: Per-org email rate limit ───
      const emailRate = await checkAndIncrementEmailRateLimit(attendee.orgId, isPaidPlan);
      if (!emailRate.allowed) {
        console.warn(`⚠️ Email rate-limited: org=${attendee.orgId} plan=${orgPlan} reason=${emailRate.reason}`);
        await event.data.ref.update({
          emailSent: false,
          emailError: "rate-limited",
        });
        if (emailRate.shouldAlert) {
          await notifyAdmin("EMAIL RATE LIMIT", {
            orgId: attendee.orgId,
            orgName: orgData?.name || "",
            plan: orgPlan,
            eventId: attendee.eventId,
            title: eventData.title || "",
            reason: emailRate.reason,
          });
        }
        return;
      }

      // Find time slot if applicable
      let timeSlot = null;
      if (attendee.timeSlotId && eventData.timeSlots) {
        timeSlot = eventData.timeSlots.find((s) => s.id === attendee.timeSlotId);
      }

      // Generate Apple Wallet pass (Pro/Business only)
      let applePassBuffer = null;
      if (isPaidPlan) {
        try {
          applePassBuffer = await generateApplePass(attendee, eventData, orgData, event.data.id, lang);
        } catch (walletErr) {
          console.warn("⚠️ Apple Wallet pass generation failed (non-blocking):", walletErr.message);
        }
      }

      // Generate Google Wallet link (Pro/Business only - Temporarily disabled pending Google Wallet publishing approval)
      let googleWalletUrl = null;
      /*
      if (isPaidPlan) {
        try {
          googleWalletUrl = await generateGoogleWalletLink(attendee, eventData, orgData, event.data.id, lang);
        } catch (walletErr) {
          console.warn("⚠️ Google Wallet link generation failed (non-blocking):", walletErr.message);
        }
      }
      */

      // Build email (with wallet info only for paid plans)
      const hasApplePass = applePassBuffer !== null;
      const html = buildConfirmationEmail(attendee, eventData, orgData, timeSlot, hasApplePass, googleWalletUrl, lang);

      // Send via Resend (always — confirmation email is core functionality)
      const resend = new Resend(RESEND_API_KEY);
      const emailPayload = {
        from: EMAIL_FROM,
        to: [attendee.email],
        subject: t(lang, 'email', 'confirmationSubject', { eventTitle: eventData.title }),
        html: html,
      };

      // Reply-To → organizzatore: se il partecipante risponde (disdetta, domande)
      // la mail arriva a chi organizza, non nel vuoto. Mai bloccante.
      const organizerEmail = await getOrganizerEmail(attendee.orgId, orgData);
      if (organizerEmail) {
        emailPayload.reply_to = [organizerEmail];
      } else {
        console.warn(`⚠️ Nessuna email organizzatore per org=${attendee.orgId}: invio senza Reply-To`);
      }

      // Attach .ics calendar invite (all plans, including Free) + Apple Wallet pass (paid plans only)
      const attachments = [];
      try {
        const icsContent = generateEventIcs(attendee, { ...eventData, id: eventDoc.id }, timeSlot, event.data.id, lang);
        attachments.push({
          filename: t(lang, 'email', 'icsFilename'),
          content: Buffer.from(icsContent, "utf8").toString("base64"),
          contentType: "text/calendar; method=PUBLISH",
        });
      } catch (icsErr) {
        console.warn("⚠️ ICS calendar generation failed (non-blocking):", icsErr.message);
      }

      if (applePassBuffer) {
        attachments.push({
          filename: t(lang, 'email', 'passFilename'),
          content: applePassBuffer.toString("base64"),
          contentType: "application/vnd.apple.pkpass",
        });
      }

      if (attachments.length > 0) {
        emailPayload.attachments = attachments;
      }

      const { data, error } = await resend.emails.send(emailPayload);

      if (error) {
        throw new Error(JSON.stringify(error));
      }

      console.log(`✅ Email sent to ${attendee.email} for "${eventData.title}" | Resend ID: ${data.id} | Plan: ${orgPlan}`);

      // Notify organizer on new registration (paid plans only)
      const targetOrganizerEmail = organizerEmail || orgData?.email;
      if (eventData.notifyOrganizerOnNewRegistration && isPaidPlan && targetOrganizerEmail) {
        try {
          // Detect organizer language preference
          let orgLang = lang || "it";
          try {
            const userQuery = await db.collection("users").where("email", "==", targetOrganizerEmail).limit(1).get();
            if (!userQuery.empty) {
              orgLang = userQuery.docs[0].data().uiLanguage || orgLang;
            }
          } catch (langErr) {
            console.warn("⚠️ Failed to fetch organizer uiLanguage:", langErr);
          }

          const registeredAtStr = new Date().toLocaleString(orgLang === 'it' ? 'it-IT' : 'en-US', {
            timeZone: 'Europe/Rome',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
          });

          const orgHtml = `
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #101410;">
              <h2 style="color: #0E6B52;">${t(orgLang, 'email', 'orgNotificationTitle', { eventTitle: eventData.title })}</h2>
              <div style="background-color: #F4F6F2; padding: 20px; border-radius: 12px; margin-top: 20px;">
                <p style="margin: 0 0 10px 0;"><strong>${t(orgLang, 'email', 'orgNotificationName')}:</strong> ${attendee.firstName} ${attendee.lastName}</p>
                <p style="margin: 0 0 10px 0;"><strong>${t(orgLang, 'email', 'orgNotificationEmail')}:</strong> <a href="mailto:${attendee.email}" style="color: #0E6B52;">${attendee.email}</a></p>
                <p style="margin: 0;"><strong>${t(orgLang, 'email', 'orgNotificationRegisteredAt')}:</strong> ${registeredAtStr}</p>
              </div>
              <div style="margin-top: 30px; text-align: center;">
                <a href="https://ticketto.it/events/${attendee.eventId}" style="background-color: #9AD530; color: #101410; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: 700; display: inline-block;">${t(orgLang, 'email', 'orgNotificationViewEvent')}</a>
              </div>
            </div>
          `;
          
          await resend.emails.send({
            from: EMAIL_FROM,
            to: [targetOrganizerEmail],
            subject: t(orgLang, 'email', 'orgNotificationSubject', { eventTitle: eventData.title }),
            html: orgHtml,
          });
          console.log(`🔔 Notified organizer ${targetOrganizerEmail} of new registration in language: ${orgLang}`);
        } catch (orgErr) {
          console.error("⚠️ Failed to notify organizer:", orgErr);
        }
      }

      // Mark email as sent + wallet URLs
      const updateData = {
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        emailId: data.id,
      };
      if (applePassBuffer) updateData.hasApplePass = true;
      if (googleWalletUrl) updateData.googleWalletUrl = googleWalletUrl;
      await event.data.ref.update(updateData);
    } catch (error) {
      console.error("❌ Error sending email:", error);
      await event.data.ref.update({
        emailSent: false,
        emailError: error.message,
      });
    }
  }
);

// ─── Trigger: Attendee Deleted ───────────────────────────────
exports.onAttendeeDeleted = onDocumentDeleted(
  {
    document: "attendees/{attendeeId}",
  },
  async (event) => {
    const attendee = event.data?.data();
    if (!attendee || !attendee.eventId) return;

    try {
      const eventRef = db.collection("events").doc(attendee.eventId);
      const eventDoc = await eventRef.get();

      if (!eventDoc.exists) {
        console.log(`⚠️ Event ${attendee.eventId} not found for deleted attendee`);
        return;
      }

      const eventData = eventDoc.data();
      const updateData = {
        attendeesCount: admin.firestore.FieldValue.increment(-1),
      };

      // Decrement timeSlot bookedCount if applicable
      if (attendee.timeSlotId && eventData.timeSlots) {
        const slotIndex = eventData.timeSlots.findIndex((s) => s.id === attendee.timeSlotId);
        if (slotIndex >= 0) {
          const updatedSlots = [...eventData.timeSlots];
          updatedSlots[slotIndex] = {
            ...updatedSlots[slotIndex],
            bookedCount: Math.max(0, (updatedSlots[slotIndex].bookedCount || 1) - 1),
          };
          updateData.timeSlots = updatedSlots;
        }
      }

      await eventRef.update(updateData);
      console.log(`📊 attendeesCount decremented for "${eventData.title}" (deleted: ${attendee.email})`);
    } catch (error) {
      console.error("❌ Error on attendee delete:", error);
    }
  }
);

// ─── Trigger: Event Deleted ──────────────────────────────────
exports.onEventDeleted = onDocumentDeleted(
  {
    document: "events/{eventId}",
  },
  async (event) => {
    const eventId = event.params.eventId;
    if (!eventId) return;

    try {
      const attendeesSnap = await db.collection("attendees").where("eventId", "==", eventId).get();
      if (attendeesSnap.empty) return;

      const batch = db.batch();
      attendeesSnap.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log(`🗑️ Cleaned up ${attendeesSnap.size} attendees for deleted event ${eventId}`);
    } catch (error) {
      console.error(`❌ Error cleaning up attendees for deleted event ${eventId}:`, error);
    }
  }
);

// ─── HTTP: Test Email ────────────────────────────────────────
exports.testEmail = onRequest(
  {
    cors: true,
  },
  async (req, res) => {
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      res.status(401).json({ error: "Unauthorized: missing Bearer token" });
      return;
    }
    try {
      await admin.auth().verifyIdToken(authHeader.slice("Bearer ".length).trim());
    } catch (_) {
      res.status(401).json({ error: "Unauthorized: invalid token" });
      return;
    }

    const { to } = req.query;
    if (!to) {
      res.status(400).json({ error: "Missing 'to' query parameter" });
      return;
    }

    try {
      const resend = new Resend(RESEND_API_KEY);
      const { data, error } = await resend.emails.send({
        from: EMAIL_FROM,
        to: [to],
        subject: "🎫 Ticketto – Test Email",
        html: `
          <div style="font-family: sans-serif; padding: 40px; text-align: center; background-color: #0E6B52; border-radius: 16px; margin: 20px;">
            <div style="margin-bottom: 16px;">
              <img src="https://ticketto.it/images/ticketto_logo_dark.png" alt="Ticketto" height="28" style="height: 28px; display: inline-block; border: 0;" />
            </div>
            <h1 style="color: white; margin: 0 0 12px 0;">Configurazione OK!</h1>
            <p style="color: rgba(255,255,255,0.9); margin: 0;">Le email di Ticketto funzionano correttamente.</p>
          </div>
        `,
      });

      if (error) {
        res.status(500).json({ success: false, error });
        return;
      }

      res.json({ success: true, message: `Test email sent to ${to}`, id: data.id });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  }
);

// ─── HTTP: Resend Attendee Confirmation ──────────────────────────
exports.resendAttendeeConfirmation = onRequest(
  {
    cors: true,
  },
  async (req, res) => {
    // 1. Require Authorization: Bearer <idToken>
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      res.status(401).json({ error: "Unauthorized: missing Bearer token" });
      return;
    }

    let decodedToken;
    try {
      const idToken = authHeader.slice("Bearer ".length).trim();
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (authErr) {
      res.status(401).json({ error: "Unauthorized: invalid token" });
      return;
    }

    const attendeeId = req.query.attendeeId || req.body?.attendeeId;
    if (!attendeeId) {
      res.status(400).json({ error: "Missing attendeeId parameter" });
      return;
    }

    try {
      const attendeeDoc = await db.collection("attendees").doc(attendeeId).get();
      if (!attendeeDoc.exists) {
        res.status(404).json({ error: "Attendee not found" });
        return;
      }
      const attendee = attendeeDoc.data();

      // Fetch event data
      const eventDoc = await db.collection("events").doc(attendee.eventId).get();
      if (!eventDoc.exists) {
        res.status(404).json({ error: "Event not found" });
        return;
      }
      const eventData = eventDoc.data();
      const lang = getEventLang(eventData);

      // Fetch org data
      const orgId = attendee.orgId || eventData.orgId;
      let orgData = null;
      if (orgId) {
        const orgDoc = await db.collection("organizations").doc(orgId).get();
        if (orgDoc.exists) orgData = orgDoc.data();
      }

      // 2. Verify user is staff of the attendee's organization (or global admin)
      const uid = decodedToken.uid;
      const isGlobalAdmin = decodedToken.email && ADMIN_ALLOWED_EMAILS.has(decodedToken.email.toLowerCase());
      let isOrgStaffMember = false;
      if (orgId && !isGlobalAdmin) {
        const memberDoc = await db.collection("organizations").doc(orgId).collection("members").doc(uid).get();
        if (memberDoc.exists && ["owner", "admin", "staff"].includes(memberDoc.data()?.role)) {
          isOrgStaffMember = true;
        } else if (orgData?.ownerId === uid) {
          isOrgStaffMember = true;
        }
      }
      if (!isGlobalAdmin && !isOrgStaffMember) {
        res.status(403).json({ error: "Forbidden: user is not staff of this organization" });
        return;
      }

      // 3. Anti-phishing & rate limit checks
      if (eventData.status !== "published" || orgData?.blocked === true) {
        res.status(403).json({ error: "Blocked: event not published or organization is blocked" });
        return;
      }
      const combinedText = [eventData.title, eventData.description, eventData.location, orgData?.name].join(" ");
      if (looksLikeScam(combinedText, eventData.title, orgData?.name)) {
        res.status(403).json({ error: "Blocked by scam filter" });
        return;
      }

      const orgPlan = orgData?.plan || "free";
      const isPaidPlan = orgPlan !== "free";

      const emailRate = await checkAndIncrementEmailRateLimit(orgId, isPaidPlan);
      if (!emailRate.allowed) {
        res.status(429).json({ error: "rate-limited", reason: emailRate.reason });
        return;
      }

      // Find time slot if applicable
      let timeSlot = null;
      if (attendee.timeSlotId && eventData.timeSlots) {
        timeSlot = eventData.timeSlots.find((s) => s.id === attendee.timeSlotId);
      }

      // Generate Apple Wallet pass (Pro/Business only)
      let applePassBuffer = null;
      if (isPaidPlan) {
        try {
          applePassBuffer = await generateApplePass(attendee, eventData, orgData, attendeeId, lang);
        } catch (walletErr) {
          console.warn("⚠️ Apple Wallet pass generation failed (non-blocking):", walletErr.message);
        }
      }

      const hasApplePass = applePassBuffer !== null;
      const html = buildConfirmationEmail(attendee, eventData, orgData, timeSlot, hasApplePass, null, lang);

      const resend = new Resend(RESEND_API_KEY);
      const emailPayload = {
        from: EMAIL_FROM,
        to: [attendee.email],
        subject: t(lang, 'email', 'confirmationSubject', { eventTitle: eventData.title }),
        html: html,
      };

      const organizerEmail = await getOrganizerEmail(orgId, orgData);
      if (organizerEmail) {
        emailPayload.reply_to = [organizerEmail];
      }

      const resendAttachments = [];
      try {
        const icsContent = generateEventIcs(attendee, { ...eventData, id: eventDoc.id }, timeSlot, attendeeId, lang);
        resendAttachments.push({
          filename: t(lang, 'email', 'icsFilename'),
          content: Buffer.from(icsContent, "utf8").toString("base64"),
          contentType: "text/calendar; method=PUBLISH",
        });
      } catch (icsErr) {
        console.warn("⚠️ ICS calendar generation failed on resend (non-blocking):", icsErr.message);
      }

      if (applePassBuffer) {
        resendAttachments.push({
          filename: t(lang, 'email', 'passFilename'),
          content: applePassBuffer.toString("base64"),
          contentType: "application/vnd.apple.pkpass",
        });
      }

      if (resendAttachments.length > 0) {
        emailPayload.attachments = resendAttachments;
      }

      const { data, error } = await resend.emails.send(emailPayload);
      if (error) {
        throw new Error(JSON.stringify(error));
      }

      const updateData = {
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        emailId: data.id,
        emailError: admin.firestore.FieldValue.delete(),
      };
      if (applePassBuffer) updateData.hasApplePass = true;
      await db.collection("attendees").doc(attendeeId).update(updateData);

      console.log(`✅ Confirmation email resent to ${attendee.email} for "${eventData.title}" | Resend ID: ${data.id}`);
      res.json({ success: true, message: `Email sent to ${attendee.email}`, id: data.id });
    } catch (error) {
      console.error("Error resending confirmation:", error);
      res.status(500).json({ success: false, error: error.message });
    }
  }
);

// ─── Admin Moderation & Kill Switch (Livello 4) ──────────────
exports.blockOrganization = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const callerEmail = (request.auth.token.email || "").toLowerCase();
    let isAllowed = ADMIN_ALLOWED_EMAILS.has(callerEmail);
    if (!isAllowed) {
      const userDoc = await db.collection("users").doc(request.auth.uid).get();
      if (userDoc.exists && userDoc.data()?.role === "admin") {
        isAllowed = true;
      }
    }
    if (!isAllowed) {
      throw new HttpsError("permission-denied", "Admin privileges required");
    }

    const { orgId, reason } = request.data || {};
    if (!orgId) {
      throw new HttpsError("invalid-argument", "orgId is required");
    }

    const result = await performBlockOrganization(orgId, reason || `admin:${callerEmail || request.auth.uid}`);
    return { success: true, ...result };
  }
);

exports.adminModerateOrg = onRequest(
  { cors: true },
  async (req, res) => {
    const { orgId, action, sig } = req.query;
    if (!orgId || !action || !sig || !["block", "trust"].includes(action)) {
      res.status(400).send("Invalid moderation parameters");
      return;
    }
    const expectedSig = signModerationAction(orgId, action);
    if (sig !== expectedSig) {
      res.status(403).send("Invalid signature");
      return;
    }

    try {
      if (action === "block") {
        const result = await performBlockOrganization(orgId, "admin:email-kill-switch");
        res.status(200).send(`<!DOCTYPE html><html><body style="font-family:sans-serif;padding:40px;text-align:center;">
          <h1 style="color:#b91c1c;">🛑 Organizzazione Bloccata</h1>
          <p>Org ID: <code>${orgId}</code></p>
          <p>Eventi riportati in bozza: <strong>${result.draftedEvents}</strong> | Utenti disabilitati: <strong>${result.disabledUsers}</strong></p>
        </body></html>`);
      } else {
        await db.collection("organizations").doc(orgId).set({
          trusted: true,
          blocked: false,
          moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        await db.collection("organizations").doc(orgId).collection("public").doc("profile").set({
          trusted: true,
          blocked: false,
        }, { merge: true });
        res.status(200).send(`<!DOCTYPE html><html><body style="font-family:sans-serif;padding:40px;text-align:center;">
          <h1 style="color:#0E6B52;">✅ Organizzazione Approvata (Trusted)</h1>
          <p>Org ID: <code>${orgId}</code> è ora contrassegnata come <code>trusted: true</code>.</p>
        </body></html>`);
      }
    } catch (err) {
      console.error("❌ adminModerateOrg error:", err);
      res.status(500).send(`Error: ${err.message}`);
    }
  }
);

async function checkFirstPublishedEventAlert(eventId, eventData) {
  try {
    if (!eventData || eventData.status !== "published" || !eventData.orgId) return;
    const orgId = eventData.orgId;
    const orgRef = db.collection("organizations").doc(orgId);
    const orgDoc = await orgRef.get();
    if (!orgDoc.exists) return;
    const orgData = orgDoc.data() || {};

    const plan = orgData.plan || "free";
    if (plan !== "free" || orgData.trusted === true || orgData.firstPublishNotified === true) {
      return;
    }

    let orgCreatedMs = 0;
    if (orgData.createdAt?.toMillis) {
      orgCreatedMs = orgData.createdAt.toMillis();
    } else if (orgData.createdAt) {
      orgCreatedMs = new Date(orgData.createdAt).getTime() || 0;
    }
    const nowMs = Date.now();
    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    if (orgCreatedMs > 0 && (nowMs - orgCreatedMs) > sevenDaysMs) {
      return;
    }

    await orgRef.set({ firstPublishNotified: true }, { merge: true });

    const organizerEmail = await getOrganizerEmail(orgId, orgData);
    const minutesSinceSignup = orgCreatedMs > 0 ? Math.max(0, Math.round((nowMs - orgCreatedMs) / 60000)) : "N/A";
    const baseFuncUrl = "https://us-central1-eventflow-3541b.cloudfunctions.net/adminModerateOrg";
    const okUrl = `${baseFuncUrl}?orgId=${encodeURIComponent(orgId)}&action=trust&sig=${signModerationAction(orgId, "trust")}`;
    const blockUrl = `${baseFuncUrl}?orgId=${encodeURIComponent(orgId)}&action=block&sig=${signModerationAction(orgId, "block")}`;

    if (!RESEND_API_KEY) return;
    const resend = new Resend(RESEND_API_KEY);
    await resend.emails.send({
      from: EMAIL_FROM,
      to: [ADMIN_ALERT_EMAIL],
      subject: `👀 [Ticketto] Primo evento pubblicato (Free <7gg): "${eventData.title}"`,
      html: `<div style="font-family:sans-serif;max-width:600px;margin:20px auto;padding:24px;border:1px solid #e5e7eb;border-radius:12px;">
        <h2 style="margin-top:0;color:#0E6B52;">Nuovo evento pubblicato da org Free recente</h2>
        <p><strong>Titolo evento:</strong> ${eventData.title || "—"}</p>
        <p><strong>Descrizione:</strong> ${eventData.description || "—"}</p>
        <p><strong>Luogo:</strong> ${eventData.location || "—"}</p>
        <p><strong>Organizzazione:</strong> ${orgData.name || "—"} (<code>${orgId}</code>)</p>
        <p><strong>Email utente:</strong> ${organizerEmail || "—"}</p>
        <p><strong>Minuti dalla creazione org:</strong> ${minutesSinceSignup}</p>
        <p><strong>Pagina pubblica:</strong> <a href="https://ticketto.it/register/${eventId}">https://ticketto.it/register/${eventId}</a></p>
        <div style="margin-top:24px;">
          <a href="${okUrl}" style="display:inline-block;background:#0E6B52;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold;margin-right:12px;">✅ OK (Approva Org)</a>
          <a href="${blockUrl}" style="display:inline-block;background:#b91c1c;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold;">🛑 BLOCCA ORG</a>
        </div>
      </div>`,
    });
    console.log(`📧 Sent first-published alert for org=${orgId} event=${eventId}`);
  } catch (err) {
    console.warn("⚠️ checkFirstPublishedEventAlert failed:", err.message);
  }
}

exports.onEventCreatedModeration = onDocumentCreated(
  { document: "events/{eventId}" },
  async (event) => {
    const data = event.data?.data();
    if (data?.status === "published") {
      await checkFirstPublishedEventAlert(event.params.eventId, data);
    }
  }
);

exports.onEventUpdatedModeration = onDocumentUpdated(
  { document: "events/{eventId}" },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (before?.status !== "published" && after?.status === "published") {
      await checkFirstPublishedEventAlert(event.params.eventId, after);
    }
  }
);

// ═══════════════════════════════════════════════════════════════
// ─── STRIPE SUBSCRIPTION MANAGEMENT ──────────────────────────
// ═══════════════════════════════════════════════════════════════

const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
const STRIPE_CONNECT_WEBHOOK_SECRET = process.env.STRIPE_CONNECT_WEBHOOK_SECRET || process.env.STRIPE_WEBHOOK_SECRET;
const STRIPE_CLIENT_ID = process.env.STRIPE_CLIENT_ID;

// ─── Create Stripe Checkout Session ──────────────────────────
// Triggered when a document is created in stripe_checkout_sessions
exports.createCheckoutSession = onDocumentCreated(
  {
    document: "stripe_checkout_sessions/{sessionId}",
  },
  async (event) => {
    const sessionData = event.data?.data();
    if (!sessionData) return;

    try {
      const stripe = require("stripe")(STRIPE_SECRET_KEY);

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        payment_method_types: ["card"],
        ...(sessionData.customerId
          ? { customer: sessionData.customerId, customer_update: { name: "auto", address: "auto" } }
          : { customer_email: sessionData.email }),
        billing_address_collection: "required",
        tax_id_collection: { enabled: true },
        custom_fields: [
          {
            key: "sdi_pec",
            label: { type: "custom", custom: "Codice destinatario SDI o PEC (solo aziende)" },
            type: "text",
            optional: true,
          },
          {
            key: "codice_fiscale",
            label: { type: "custom", custom: "Codice fiscale (per le società spesso uguale alla P.IVA)" },
            type: "text",
            optional: false,
          },
        ],
        line_items: [
          {
            price: sessionData.priceId,
            quantity: 1,
          },
        ],
        success_url: sessionData.successUrl,
        cancel_url: sessionData.cancelUrl,
        metadata: {
          orgId: sessionData.orgId,
          userId: sessionData.userId,
          plan: sessionData.plan,
        },
        subscription_data: {
          metadata: {
            orgId: sessionData.orgId,
            plan: sessionData.plan,
          },
        },
      });

      // Write the checkout URL back to Firestore
      await event.data.ref.update({
        url: session.url,
        sessionId: session.id,
        status: "created",
      });

      console.log(`✅ Checkout session created for org ${sessionData.orgId}: ${session.id}`);
    } catch (error) {
      console.error("❌ Error creating checkout session:", error);
      await event.data.ref.update({
        error: error.message,
        status: "error",
      });
    }
  }
);

// ─── HTTP: Create Subscription Checkout Session ───────────────
// Direct HTTPS endpoint returning the checkout URL immediately
exports.createSubscriptionCheckout = onRequest(
  {
    cors: true,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const { orgId, userId, email, customerId, priceId, plan, billingCycle, successUrl, cancelUrl } = req.body || {};

    if (!orgId || !priceId || !plan) {
      res.status(400).json({ error: "Missing required fields (orgId, priceId, plan)" });
      return;
    }

    try {
      const stripe = require("stripe")(STRIPE_SECRET_KEY);

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        payment_method_types: ["card"],
        ...(customerId
          ? { customer: customerId, customer_update: { name: "auto", address: "auto" } }
          : { customer_email: email }),
        billing_address_collection: "required",
        tax_id_collection: { enabled: true },
        custom_fields: [
          {
            key: "sdi_pec",
            label: { type: "custom", custom: "Codice destinatario SDI o PEC (solo aziende)" },
            type: "text",
            optional: true,
          },
          {
            key: "codice_fiscale",
            label: { type: "custom", custom: "Codice fiscale (per le società spesso uguale alla P.IVA)" },
            type: "text",
            optional: false,
          },
        ],
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        success_url: successUrl || "https://ticketto.it/settings?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancelUrl || "https://ticketto.it/subscription",
        metadata: {
          orgId: orgId,
          userId: userId || "",
          plan: plan,
          billingCycle: billingCycle || "monthly",
        },
        subscription_data: {
          metadata: {
            orgId: orgId,
            plan: plan,
            billingCycle: billingCycle || "monthly",
          },
        },
      });

      console.log(`✅ Direct checkout session created for org ${orgId}: ${session.id}`);
      res.json({ url: session.url, sessionId: session.id });
    } catch (error) {
      console.error("❌ Error creating direct checkout session:", error);
      res.status(500).json({ error: error.message });
    }
  }
);

// ─── Stripe Webhook Handler ─────────────────────────────────
exports.stripeWebhook = onRequest(
  {
    cors: false,
  },
  async (req, res) => {
    const stripe = require("stripe")(STRIPE_SECRET_KEY);

    let stripeEvent;
    try {
      const sig = req.headers["stripe-signature"];
      stripeEvent = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        STRIPE_WEBHOOK_SECRET
      );
    } catch (err) {
      console.error("⚠️ Webhook signature verification failed:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    console.log(`📩 Stripe event: ${stripeEvent.type}`);

    try {
      switch (stripeEvent.type) {
        // ─── Checkout completed → Activate subscription ───
        case "checkout.session.completed": {
          const session = stripeEvent.data.object;
          const paymentType = session.metadata?.payment_type;

          // ─── Ticket Payment (Handled by stripeConnectWebhook) ───
          if (paymentType === "ticket_payment") {
            console.log("ℹ️ Ticket payment event received on platform webhook, ignored (handled by stripeConnectWebhook).");
            break;
          }

          // ─── Subscription Payment ───
          const orgId = session.metadata?.orgId;
          const plan = session.metadata?.plan;

          if (orgId && plan) {
            // Extract custom fields (sdi_pec, codice_fiscale)
            const customFields = Array.isArray(session.custom_fields) ? session.custom_fields : [];
            const sdiPecField = customFields.find((f) => f.key === "sdi_pec");
            const sdiPec = sdiPecField?.text?.value || null;

            const cfField = customFields.find((f) => f.key === "codice_fiscale");
            const codiceFiscale = cfField?.text?.value || null;

            // Extract tax ID (Partita IVA)
            const taxIds = session.customer_details?.tax_ids || [];
            const vatId = taxIds.length > 0 && taxIds[0]?.value ? taxIds[0].value : null;

            // Extract address
            let address = null;
            if (session.customer_details?.address) {
              const a = session.customer_details.address;
              address = {
                city: a.city || null,
                country: a.country || null,
                line1: a.line1 || null,
                line2: a.line2 || null,
                postal_code: a.postal_code || null,
                state: a.state || null,
              };
            }

            const fiscalInfo = {
              name: session.customer_details?.name || null,
              address: address,
              vatId: vatId,
              sdiOrPec: sdiPec,
              codiceFiscale: codiceFiscale,
              isBusiness: Boolean(vatId),
            };

            await db.collection("organizations").doc(orgId).update({
              plan: plan,
              stripeCustomerId: session.customer,
              stripeSubscriptionId: session.subscription,
              subscriptionStatus: "active",
              subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
              fiscalInfo: fiscalInfo,
            });

            // Save subscription details
            await db.collection("subscriptions").doc(orgId).set({
              orgId: orgId,
              plan: plan,
              stripeCustomerId: session.customer,
              stripeSubscriptionId: session.subscription,
              status: "active",
              fiscalInfo: fiscalInfo,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Update Stripe customer metadata for electronic billing
            if (session.customer) {
              try {
                await stripe.customers.update(session.customer, {
                  metadata: {
                    sdi_pec: sdiPec || "",
                    codice_fiscale: codiceFiscale || "",
                  },
                });
                console.log(`📋 Updated Stripe customer ${session.customer} metadata with fiscal info`);
              } catch (customerUpdateErr) {
                console.error("⚠️ Failed to update customer metadata:", customerUpdateErr);
              }
            }

            console.log(`✅ Subscription activated with fiscal info: org=${orgId} plan=${plan}`);
          }
          break;
        }

        // ─── Subscription updated (plan change, renewal) ───
        case "customer.subscription.updated": {
          const subscription = stripeEvent.data.object;
          const orgId = subscription.metadata?.orgId;
          const plan = subscription.metadata?.plan;

          if (orgId) {
            const updateData = {
              subscriptionStatus: subscription.status,
              subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            // Update plan if changed
            if (plan) updateData.plan = plan;

            // Handle cancellation at period end
            if (subscription.cancel_at_period_end) {
              updateData.subscriptionCancelAt = new Date(subscription.current_period_end * 1000);
            }

            await db.collection("organizations").doc(orgId).update(updateData);
            await db.collection("subscriptions").doc(orgId).update({
              ...updateData,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`🔄 Subscription updated: org=${orgId} status=${subscription.status}`);
          }
          break;
        }

        // ─── Subscription deleted/canceled ───
        case "customer.subscription.deleted": {
          const subscription = stripeEvent.data.object;
          const orgId = subscription.metadata?.orgId;

          if (orgId) {
            // Downgrade to free
            await db.collection("organizations").doc(orgId).update({
              plan: "free",
              subscriptionStatus: "canceled",
              subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            await db.collection("subscriptions").doc(orgId).update({
              plan: "free",
              status: "canceled",
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`❌ Subscription canceled: org=${orgId} → downgraded to free`);
          }
          break;
        }

        // ─── Payment failed ───
        case "invoice.payment_failed": {
          const invoice = stripeEvent.data.object;
          const subscriptionId = invoice.subscription;

          if (subscriptionId) {
            // Find org by subscription ID
            const orgs = await db
              .collection("organizations")
              .where("stripeSubscriptionId", "==", subscriptionId)
              .get();

            for (const orgDoc of orgs.docs) {
              await orgDoc.ref.update({
                subscriptionStatus: "past_due",
                subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              console.log(`⚠️ Payment failed for org=${orgDoc.id}`);
            }
          }
          break;
        }
        // ─── Connect account updated ───
        case "account.updated": {
          const account = stripeEvent.data.object;
          const orgId = account.metadata?.orgId;

          if (orgId && account.charges_enabled) {
            await db.collection("organizations").doc(orgId).update({
              stripeConnectStatus: "active",
            });
            console.log(`✅ Connect account active: org=${orgId} account=${account.id}`);
          }
          break;
        }

        default:
          console.log(`Unhandled event type: ${stripeEvent.type}`);
      }
    } catch (error) {
      console.error(`❌ Error processing webhook ${stripeEvent.type}:`, error);
    }

    res.json({ received: true });
  }
);

// ─── Create Stripe Customer Portal Session ──────────────────
exports.createPortalSession = onRequest(
  {
    cors: true,
  },
  async (req, res) => {
    const { customerId, returnUrl } = req.query;

    if (!customerId) {
      res.status(400).json({ error: "Missing customerId" });
      return;
    }

    try {
      const stripe = require("stripe")(STRIPE_SECRET_KEY);

      const session = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: returnUrl || "https://ticketto.it/settings",
      });

      res.json({ url: session.url });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);

// ═══════════════════════════════════════════════════════════════
// ─── STRIPE CONNECT (Ticket Payments & Standard Accounts) ────
// ═══════════════════════════════════════════════════════════════

// Helper: Java-style hashCode for deterministic doc IDs
function hashCode(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return hash;
}

// ─── Stripe Connect Webhook (Events on Connected Accounts) ─────
exports.stripeConnectWebhook = onRequest(
  {
    cors: false,
  },
  async (req, res) => {
    const stripe = require("stripe")(STRIPE_SECRET_KEY);

    let stripeEvent;
    try {
      const sig = req.headers["stripe-signature"];
      stripeEvent = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        STRIPE_CONNECT_WEBHOOK_SECRET
      );
    } catch (err) {
      console.error("⚠️ Connect Webhook signature verification failed:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    const connectedAccountId = stripeEvent.account;
    console.log(`📩 Stripe Connect event: ${stripeEvent.type} (account: ${connectedAccountId || 'n/a'})`);

    try {
      switch (stripeEvent.type) {
        // ─── Checkout completed on connected account → Confirm ticket registration ───
        case "checkout.session.completed": {
          const session = stripeEvent.data.object;
          const paymentType = session.metadata?.payment_type;

          if (paymentType === "ticket_payment") {
            const eventId = session.metadata.event_id;
            const orgId = session.metadata.org_id;
            const slotId = session.metadata.slot_id || null;
            const pendingRegId = session.metadata.pending_registration_id;
            const paymentIntentId = session.payment_intent;
            const { v4: uuidv4 } = require("uuid");

            // Idempotency check: don't process the same payment twice
            if (paymentIntentId) {
              const existingSnap = await db.collection("attendees")
                .where("paymentId", "==", paymentIntentId)
                .limit(1)
                .get();

              if (!existingSnap.empty) {
                console.log(`ℹ️ Ticket payment already processed for paymentIntent: ${paymentIntentId}, skipping.`);
                res.json({ received: true });
                return;
              }
            }

            // ─── Group registration (from pending_registrations) ───
            if (pendingRegId) {
              const pendingDoc = await db.collection("pending_registrations").doc(pendingRegId).get();
              if (pendingDoc.exists) {
                const pending = pendingDoc.data();
                const allAttendees = [pending.primaryAttendee, ...(pending.extraAttendees || [])];
                const perPersonAmount = session.amount_total / allAttendees.length / 100;
                const mConsentShown = pending.marketingConsentShown !== undefined ? Boolean(pending.marketingConsentShown) : true;
                const mConsent = mConsentShown ? Boolean(pending.marketingConsent) : false;
                const pConsent = pending.photoConsent !== undefined && pending.photoConsent !== null ? Boolean(pending.photoConsent) : null;
                const nowTimestamp = admin.firestore.FieldValue.serverTimestamp();

                for (const att of allAttendees) {
                  if (!att.email) continue;
                  const email = att.email.toLowerCase();
                  const docId = db.collection("attendees").doc().id;
                  const qrCode = uuidv4();

                  await db.collection("attendees").doc(docId).set({
                    eventId: eventId,
                    orgId: orgId,
                    firstName: att.firstName || "",
                    lastName: att.lastName || "",
                    email: email,
                    phone: att.phone || null,
                    category: "Standard",
                    status: "confirmed",
                    checkInStatus: "notCheckedIn",
                    checkInTime: null,
                    qrCode: qrCode,
                    timeSlotId: pending.slotId || null,
                    customData: pending.customData || {},
                    privacyAccepted: true,
                    privacyAcceptedAt: nowTimestamp,
                    marketingConsent: mConsent,
                    marketingConsentShown: mConsentShown,
                    marketingConsentAt: mConsent ? nowTimestamp : null,
                    photoConsent: pConsent,
                    photoConsentAt: pConsent !== null && pConsent ? nowTimestamp : null,
                    paymentStatus: "paid",
                    paymentId: paymentIntentId,
                    paymentAmount: perPersonAmount,
                    stripeAccount: connectedAccountId,
                    registeredAt: nowTimestamp,
                  });
                }

                // Cleanup pending registration
                await db.collection("pending_registrations").doc(pendingRegId).delete();
                console.log(`🎫 Group ticket payment completed: event=${eventId} count=${allAttendees.length}`);
              }
              break;
            }

            // ─── Single registration (attendee_data in metadata) ───
            const attendeeData = JSON.parse(session.metadata.attendee_data || "{}");

            if (eventId && attendeeData.email) {
              const email = attendeeData.email.toLowerCase();
              const docId = db.collection("attendees").doc().id;
              const qrCode = uuidv4();
              const mConsentShownRaw = session.metadata.marketing_consent_shown;
              const mConsentShown = mConsentShownRaw !== undefined ? mConsentShownRaw === "true" : true;
              const mConsent = mConsentShown && session.metadata.marketing_consent === "true";
              const pConsentRaw = session.metadata.photo_consent;
              const pConsent = pConsentRaw === "true" ? true : (pConsentRaw === "false" ? false : null);
              const nowTimestamp = admin.firestore.FieldValue.serverTimestamp();

              await db.collection("attendees").doc(docId).set({
                eventId: eventId,
                orgId: orgId,
                firstName: attendeeData.firstName || "",
                lastName: attendeeData.lastName || "",
                email: email,
                phone: attendeeData.phone || null,
                category: "Standard",
                status: "confirmed",
                checkInStatus: "notCheckedIn",
                checkInTime: null,
                qrCode: qrCode,
                timeSlotId: slotId,
                customData: attendeeData.customData || {},
                privacyAccepted: true,
                privacyAcceptedAt: nowTimestamp,
                marketingConsent: mConsent,
                marketingConsentShown: mConsentShown,
                marketingConsentAt: mConsent ? nowTimestamp : null,
                photoConsent: pConsent,
                photoConsentAt: pConsent !== null && pConsent ? nowTimestamp : null,
                paymentStatus: "paid",
                paymentId: paymentIntentId,
                paymentAmount: session.amount_total / 100,
                stripeAccount: connectedAccountId,
                registeredAt: nowTimestamp,
              });

              console.log(`🎫 Ticket payment completed: event=${eventId} attendee=${email} account=${connectedAccountId}`);
            }
          }
          break;
        }

        // ─── Charge refunded on connected account (e.g. from organizer Stripe dashboard) ───
        case "charge.refunded": {
          const charge = stripeEvent.data.object;
          const paymentIntentId = charge.payment_intent;

          if (paymentIntentId) {
            const attendeesSnap = await db.collection("attendees")
              .where("paymentId", "==", paymentIntentId)
              .get();

            for (const attendeeDoc of attendeesSnap.docs) {
              const attendee = attendeeDoc.data();
              if (attendee.status !== "refunded") {
                await attendeeDoc.ref.update({
                  status: "refunded",
                  paymentStatus: "refunded",
                  refundedAt: admin.firestore.FieldValue.serverTimestamp(),
                  refundSource: "stripe_dashboard",
                });

                // Decrement event attendees count & time slot
                const eventUpdate = {
                  attendeesCount: admin.firestore.FieldValue.increment(-1),
                };
                if (attendee.timeSlotId) {
                  const eventDoc = await db.collection("events").doc(attendee.eventId).get();
                  if (eventDoc.exists) {
                    const eventData = eventDoc.data();
                    if (eventData.timeSlots) {
                      const slotIdx = eventData.timeSlots.findIndex((s) => s.id === attendee.timeSlotId);
                      if (slotIdx >= 0) {
                        const updatedSlots = [...eventData.timeSlots];
                        updatedSlots[slotIdx] = {
                          ...updatedSlots[slotIdx],
                          bookedCount: Math.max(0, (updatedSlots[slotIdx].bookedCount || 1) - 1),
                        };
                        eventUpdate.timeSlots = updatedSlots;
                      }
                    }
                  }
                }
                await db.collection("events").doc(attendee.eventId).update(eventUpdate);

                // Send refund confirmation email
                const eventDoc = await db.collection("events").doc(attendee.eventId).get();
                const orgDoc = await db.collection("organizations").doc(attendee.orgId).get();
                if (eventDoc.exists) {
                  await sendRefundEmail({
                    attendee,
                    eventData: eventDoc.data(),
                    orgData: orgDoc.exists ? orgDoc.data() : null,
                    amount: attendee.paymentAmount,
                  });
                }

                console.log(`↩️ Attendee marked as refunded from Stripe dashboard: ${attendee.email}`);
              }
            }
          }
          break;
        }

        // ─── Account updated (onboarding / capabilities change) ───
        case "account.updated": {
          const account = stripeEvent.data.object;
          const rawOrgId = account.metadata?.orgId || null;
          let orgRef = null;

          if (rawOrgId) {
            const orgDoc = await db.collection("organizations").doc(rawOrgId).get();
            if (orgDoc.exists) {
              orgRef = orgDoc.ref;
            }
          }

          if (!orgRef) {
            const orgSnap = await db.collection("organizations")
              .where("stripeConnectAccountId", "==", account.id)
              .limit(1)
              .get();
            if (!orgSnap.empty) {
              orgRef = orgSnap.docs[0].ref;
            }
          }

          if (!orgRef) {
            console.warn(`⚠️ Organization not found for Stripe Connect account: ${account.id}, metadata.orgId: ${rawOrgId}. Event ignored.`);
            res.status(200).json({ received: true, ignored: true });
            return;
          }

          const isChargesEnabled = Boolean(account.charges_enabled);
          const isPayoutsEnabled = Boolean(account.payouts_enabled);
          const status = isChargesEnabled ? "active" : (account.details_submitted ? "pending_verification" : "pending");

          await orgRef.update({
            stripeConnectStatus: status,
            stripeChargesEnabled: isChargesEnabled,
            stripePayoutsEnabled: isPayoutsEnabled,
            paymentMode: "standard",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`🏢 Org Stripe Connect updated: org=${orgRef.id} account=${account.id} status=${status} charges_enabled=${isChargesEnabled}`);
          break;
        }

        default:
          console.log(`ℹ️ Unhandled Connect event type: ${stripeEvent.type}`);
      }

      res.json({ received: true });
    } catch (err) {
      console.error("❌ Error processing Connect webhook event:", err);
      res.status(500).send(`Webhook Handler Error: ${err.message}`);
    }
  }
);

// ─── Helper: Send Refund Confirmation Email ──────────────────
async function sendRefundEmail({ attendee, eventData, orgData, amount }) {
  try {
    const lang = getEventLang(eventData);
    const resend = new Resend(RESEND_API_KEY);
    const organizerEmail = await getOrganizerEmail(attendee.orgId, orgData);

    const isIt = lang === "it";
    const subject = isIt
      ? `↩️ Rimborso Confermato – ${eventData.title}`
      : `↩️ Refund Confirmed – ${eventData.title}`;

    const formattedAmount = amount ? `€ ${Number(amount).toFixed(2)}` : "";

    const html = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 32px 24px; color: #1A1A2E;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #0E6B52; font-size: 24px; margin-bottom: 8px;">
            ${isIt ? "Rimborso Confermato" : "Refund Confirmed"}
          </h1>
          <p style="color: #6B7280; font-size: 14px; margin: 0;">
            ${eventData.title}
          </p>
        </div>
        <div style="background-color: #F9FAFB; border-radius: 12px; padding: 24px; margin-bottom: 24px; border: 1px solid #E5E7EB;">
          <p style="font-size: 15px; margin-top: 0;">
            ${isIt ? `Ciao <strong>${attendee.firstName || ""}</strong>,` : `Hello <strong>${attendee.firstName || ""}</strong>,`}
          </p>
          <p style="font-size: 14px; line-height: 1.6; color: #374151;">
            ${isIt
              ? `Ti confermiamo che il rimborso per il tuo biglietto per <strong>${eventData.title}</strong> è stato elaborato con successo${formattedAmount ? ` per un importo di <strong>${formattedAmount}</strong>` : ""}.`
              : `We confirm that your refund for <strong>${eventData.title}</strong> has been successfully processed${formattedAmount ? ` for <strong>${formattedAmount}</strong>` : ""}.`}
          </p>
          <p style="font-size: 13px; color: #6B7280; line-height: 1.5;">
            ${isIt
              ? "L'accredito avverrà automaticamente sul metodo di pagamento originale entro 5-10 giorni lavorativi, in base ai tempi del tuo istituto bancario."
              : "The credit will automatically appear on your original payment method within 5-10 business days, depending on your bank."}
          </p>
        </div>
        <div style="text-align: center; font-size: 12px; color: #9CA3AF;">
          <p style="margin: 0;">Ticketto – ${orgData?.name || "L'Organizzatore"}</p>
        </div>
      </div>
    `;

    const emailPayload = {
      from: EMAIL_FROM,
      to: [attendee.email],
      subject,
      html,
    };
    if (organizerEmail) {
      emailPayload.reply_to = [organizerEmail];
    }

    await resend.emails.send(emailPayload);
    console.log(`📧 Refund email sent to ${attendee.email}`);
  } catch (err) {
    console.warn("⚠️ Error sending refund email (non-blocking):", err.message);
  }
}

// ─── Callable: Refund Ticket ─────────────────────────────────
exports.refundTicket = onCall(
  { cors: true },
  async (request) => {
    // 1. Verify authentication
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "È necessario essere autenticati per emettere un rimborso.");
    }
    const uid = request.auth.uid;
    const { eventId, attendeeId, paymentIntentId } = request.data || {};

    if (!attendeeId && !paymentIntentId) {
      throw new HttpsError("invalid-argument", "Specificare attendeeId o paymentIntentId.");
    }

    // 2. Fetch attendee
    let attendeeDoc = null;
    if (attendeeId) {
      attendeeDoc = await db.collection("attendees").doc(attendeeId).get();
    } else {
      const snap = await db.collection("attendees")
        .where("paymentId", "==", paymentIntentId)
        .limit(1)
        .get();
      if (!snap.empty) attendeeDoc = snap.docs[0];
    }

    if (!attendeeDoc || !attendeeDoc.exists) {
      throw new HttpsError("not-found", "Partecipante non trovato.");
    }

    const attendee = attendeeDoc.data();
    const actualEventId = eventId || attendee.eventId;

    // 3. Fetch event & org
    const eventDoc = await db.collection("events").doc(actualEventId).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Evento non trovato.");
    }
    const eventData = eventDoc.data();
    const orgId = attendee.orgId || eventData.orgId;

    // 4. Verify permission (global admin OR org owner/admin)
    const userDoc = await db.collection("users").doc(uid).get();
    const isGlobalAdmin = userDoc.exists && userDoc.data().role === "admin";

    const orgDoc = await db.collection("organizations").doc(orgId).get();
    const orgData = orgDoc.exists ? orgDoc.data() : {};
    const isOrgOwner = orgData.ownerId === uid;

    let isOrgAdmin = false;
    if (!isGlobalAdmin && !isOrgOwner) {
      const memberDoc = await db.collection("organizations").doc(orgId).collection("members").doc(uid).get();
      if (memberDoc.exists && ["owner", "admin"].includes(memberDoc.data().role)) {
        isOrgAdmin = true;
      }
    }

    if (!isGlobalAdmin && !isOrgOwner && !isOrgAdmin) {
      throw new HttpsError("permission-denied", "Non hai i permessi per rimborsare i biglietti di questa organizzazione.");
    }

    // 5. Check if already refunded
    if (attendee.status === "refunded") {
      throw new HttpsError("already-exists", "Questo biglietto è già stato rimborsato.");
    }

    const connectedAccountId = orgData.stripeConnectAccountId;
    if (!connectedAccountId) {
      throw new HttpsError("failed-precondition", "L'organizzazione non ha un account Stripe Connect configurato.");
    }

    const actualPaymentIntentId = attendee.paymentId || paymentIntentId;
    if (!actualPaymentIntentId) {
      throw new HttpsError("failed-precondition", "Nessun pagamento associato a questo partecipante.");
    }

    // 6. Execute refund on connected account
    const stripe = require("stripe")(STRIPE_SECRET_KEY);
    let refund;
    try {
      refund = await stripe.refunds.create(
        {
          payment_intent: actualPaymentIntentId,
        },
        {
          stripeAccount: connectedAccountId,
        }
      );
    } catch (stripeErr) {
      console.error("❌ Stripe refund error:", stripeErr);
      throw new HttpsError("internal", `Errore Stripe durante il rimborso: ${stripeErr.message}`);
    }

    // 7. Update attendee record
    await attendeeDoc.ref.update({
      status: "refunded",
      paymentStatus: "refunded",
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      refundId: refund.id,
      refundSource: "ticketto_dashboard",
    });

    // 8. Decrement event count & time slot
    const eventUpdate = {
      attendeesCount: admin.firestore.FieldValue.increment(-1),
    };
    if (attendee.timeSlotId && eventData.timeSlots) {
      const slotIdx = eventData.timeSlots.findIndex((s) => s.id === attendee.timeSlotId);
      if (slotIdx >= 0) {
        const updatedSlots = [...eventData.timeSlots];
        updatedSlots[slotIdx] = {
          ...updatedSlots[slotIdx],
          bookedCount: Math.max(0, (updatedSlots[slotIdx].bookedCount || 1) - 1),
        };
        eventUpdate.timeSlots = updatedSlots;
      }
    }
    await db.collection("events").doc(actualEventId).update(eventUpdate);

    // 9. Send refund confirmation email
    await sendRefundEmail({
      attendee,
      eventData,
      orgData,
      amount: attendee.paymentAmount,
    });

    console.log(`✅ Refund successful: attendee=${attendee.email} event=${actualEventId} refundId=${refund.id}`);
    return { success: true, refundId: refund.id };
  }
);

// ─── Create Stripe Connect Standard Account ─────────────────
exports.createConnectAccount = onRequest(
  { cors: true },
  async (req, res) => {
    const { orgId, email, orgName } = req.body || req.query;

    if (!orgId) {
      res.status(400).json({ error: "Missing orgId" });
      return;
    }

    try {
      const stripe = require("stripe")(STRIPE_SECRET_KEY);

      // Check if org already has a connect account
      const orgDoc = await db.collection("organizations").doc(orgId).get();
      if (!orgDoc.exists) {
        res.status(404).json({ error: "Organizzazione non trovata" });
        return;
      }
      const orgData = orgDoc.data() || {};
      const existingAccountId = orgData.stripeConnectAccountId;
      const paymentMode = orgData.paymentMode;

      if (existingAccountId) {
        // Reuse it ONLY if paymentMode === "standard" AND account exists on current Stripe account
        if (paymentMode === "standard") {
          try {
            const existingAccount = await stripe.accounts.retrieve(existingAccountId);
            if (existingAccount && !existingAccount.deleted) {
              const accountLink = await stripe.accountLinks.create({
                account: existingAccountId,
                refresh_url: `https://ticketto.it/settings?stripe=refresh`,
                return_url: `https://ticketto.it/settings?stripe=success`,
                type: "account_onboarding",
              });
              res.json({ url: accountLink.url, accountId: existingAccountId });
              return;
            }
          } catch (retrieveErr) {
            console.warn(`⚠️ Existing account ${existingAccountId} invalid on current Stripe account (${retrieveErr.message}). Marking legacy and recreating.`);
          }
        } else {
          console.log(`ℹ️ Existing account ${existingAccountId} has paymentMode="${paymentMode}". Treating as legacy and migrating to standard.`);
        }

        // Otherwise (error "not connected / does not exist", or paymentMode !== "standard"), consider ID obsolete:
        // Save the old ID in stripeConnectAccountIdLegacy and proceed to create a new Standard account.
        await db.collection("organizations").doc(orgId).set({
          stripeConnectAccountIdLegacy: existingAccountId,
          stripeConnectAccountId: admin.firestore.FieldValue.delete(),
          stripeConnectStatus: "pending",
        }, { merge: true });
      }

      // Create Standard account with controller properties
      const account = await stripe.accounts.create({
        controller: {
          stripe_dashboard: { type: "full" },
          fees: { payer: "account" },
          losses: { payments: "stripe" },
          requirement_collection: "stripe",
        },
        email: email || undefined,
        business_profile: {
          name: orgName || undefined,
          product_description: "Event ticket sales via Ticketto",
        },
        metadata: { orgId: orgId },
      });

      // Save account ID and paymentMode to organization
      await db.collection("organizations").doc(orgId).set({
        stripeConnectAccountId: account.id,
        stripeConnectStatus: "pending",
        paymentMode: "standard",
      }, { merge: true });

      // Create onboarding link
      const accountLink = await stripe.accountLinks.create({
        account: account.id,
        refresh_url: `https://ticketto.it/settings?stripe=refresh`,
        return_url: `https://ticketto.it/settings?stripe=success`,
        type: "account_onboarding",
      });

      console.log(`🔗 Standard Connect account created: org=${orgId} account=${account.id}`);
      res.json({ url: accountLink.url, accountId: account.id });
    } catch (error) {
      console.error("❌ Error creating Connect account:", error);
      res.status(500).json({ error: error.message });
    }
  }
);

// ─── Create Connect Account Link (re-onboarding or dashboard) ───
exports.createConnectAccountLink = onRequest(
  { cors: true },
  async (req, res) => {
    const { orgId, type } = req.query; // type: 'onboarding' or 'dashboard'

    if (!orgId) {
      res.status(400).json({ error: "Missing orgId" });
      return;
    }

    try {
      const stripe = require("stripe")(STRIPE_SECRET_KEY);

      const orgDoc = await db.collection("organizations").doc(orgId).get();
      const orgData = orgDoc.data();
      const accountId = orgData?.stripeConnectAccountId;
      const paymentMode = orgData?.paymentMode;

      if (!accountId || paymentMode !== "standard") {
        res.status(400).json({ error: "Ricollega il tuo account Stripe dalle Impostazioni" });
        return;
      }

      // Verify that account exists on current Stripe account
      try {
        const account = await stripe.accounts.retrieve(accountId);
        if (!account || account.deleted) {
          throw new Error("Account not found or deleted");
        }
      } catch (err) {
        console.warn(`⚠️ Account ${accountId} not retrievable on current Stripe account:`, err.message);
        res.status(400).json({ error: "Ricollega il tuo account Stripe dalle Impostazioni" });
        return;
      }

      if (type === "dashboard") {
        // Standard accounts use the full Stripe Dashboard directly
        res.json({ url: "https://dashboard.stripe.com" });
        return;
      } else {
        const accountLink = await stripe.accountLinks.create({
          account: accountId,
          refresh_url: `https://ticketto.it/settings?stripe=refresh`,
          return_url: `https://ticketto.it/settings?stripe=success`,
          type: "account_onboarding",
        });
        res.json({ url: accountLink.url });
      }
    } catch (error) {
      console.error("❌ Error creating account link:", error);
      res.status(500).json({ error: error.message });
    }
  }
);

// ─── Stripe Connect OAuth Callback ──────────────────────────
exports.stripeConnectOAuthCallback = onRequest(
  { cors: true },
  async (req, res) => {
    const { code, state: orgId, error, error_description } = req.query;

    if (error) {
      console.error("❌ Stripe OAuth error:", error, error_description);
      res.redirect(`https://ticketto.it/settings?stripe=error&message=${encodeURIComponent(error_description || error)}`);
      return;
    }

    if (!code || !orgId) {
      res.status(400).send("Missing code or state (orgId)");
      return;
    }

    try {
      const stripe = require("stripe")(STRIPE_SECRET_KEY);
      const response = await stripe.oauth.token({
        grant_type: "authorization_code",
        code: code,
      });

      const connectedAccountId = response.stripe_user_id;

      await db.collection("organizations").doc(orgId).update({
        stripeConnectAccountId: connectedAccountId,
        stripeConnectStatus: "active",
        paymentMode: "standard",
        stripeChargesEnabled: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`🔗 Connect account connected via OAuth: org=${orgId} account=${connectedAccountId}`);
      res.redirect("https://ticketto.it/settings?stripe=connected");
    } catch (err) {
      console.error("❌ Error exchanging OAuth code:", err);
      res.redirect(`https://ticketto.it/settings?stripe=error&message=${encodeURIComponent(err.message)}`);
    }
  }
);

// ─── Helper: Create Ticket Checkout Session (Direct Charge) ──
/**
 * Creates a Stripe Checkout Session for ticket sales based on the organization's payment mode.
 * Standard mode: Direct charge executed on the organizer's connected Stripe account.
 * Extensible for future payment modes (e.g. Express managed mode with platform fee).
 */
async function createTicketCheckoutSession({
  stripe,
  orgData,
  connectedAccountId,
  ticketParams,
  lang,
}) {
  const paymentMode = orgData?.paymentMode || "standard";

  if (paymentMode === "standard") {
    // Direct Charge executed directly on connected Standard account
    return await stripe.checkout.sessions.create(
      {
        mode: "payment",
        payment_method_types: ["card"],
        line_items: [
          {
            price_data: {
              currency: "eur",
              unit_amount: ticketParams.amountCents,
              product_data: {
                name: ticketParams.productName,
                description: ticketParams.productDescription,
              },
            },
            quantity: ticketParams.quantity,
          },
        ],
        customer_email: ticketParams.email,
        success_url: ticketParams.successUrl,
        cancel_url: ticketParams.cancelUrl,
        metadata: ticketParams.metadata,
      },
      {
        stripeAccount: connectedAccountId,
      }
    );
  }

  throw new Error(`Unsupported payment mode: ${paymentMode}`);
}

// ─── Create Ticket Payment Checkout Session ─────────────────
exports.createTicketCheckout = onRequest(
  { cors: true },
  async (req, res) => {
    const {
      eventId, orgId, eventTitle, price,
      firstName, lastName, email, phone,
      slotId, customData,
      quantity, extraAttendees,
      marketingConsent, marketingConsentShown, photoConsent,
    } = req.body || {};

    if (!eventId || !orgId || !email || !price) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }

    try {
      const stripe = require("stripe")(STRIPE_SECRET_KEY);

      // Get organizer's connected account
      const orgDoc = await db.collection("organizations").doc(orgId).get();
      const orgData = orgDoc.data();
      const connectedAccountId = orgData?.stripeConnectAccountId;
      const paymentMode = orgData?.paymentMode;

      if (!connectedAccountId || paymentMode !== "standard") {
        res.status(400).json({ error: "Ricollega il tuo account Stripe dalle Impostazioni", code: "stripe_not_configured" });
        return;
      }

      // ─── Plan check: Free plan cannot sell tickets ───
      const orgPlan = orgData?.plan || "free";
      if (orgPlan === "free") {
        res.status(403).json({ error: "Gli eventi a pagamento richiedono un piano Pro o Business." });
        return;
      }

      // Check account status: charges_enabled must be true on current Stripe account
      let account;
      try {
        account = await stripe.accounts.retrieve(connectedAccountId);
        if (!account || account.deleted) {
          throw new Error("Account not found or deleted");
        }
      } catch (retrieveErr) {
        console.warn(`⚠️ Account ${connectedAccountId} not retrievable on current Stripe account (${retrieveErr.message}).`);
        res.status(400).json({ error: "Ricollega il tuo account Stripe dalle Impostazioni", code: "stripe_not_configured" });
        return;
      }

      if (!account.charges_enabled) {
        res.status(400).json({
          error: "Completa la configurazione del tuo account Stripe per vendere biglietti",
          code: "stripe_not_configured",
        });
        return;
      }

      // Get event language & consent settings
      const eventDoc = await db.collection("events").doc(eventId).get();
      const eventData = eventDoc.exists ? eventDoc.data() : {};
      const lang = eventDoc.exists ? getEventLang(eventData) : "it";
      const eventShowMarketing = eventData.showMarketingConsent !== false;
      const eventShowPhoto = !eventData.isOnline && eventData.showPhotoConsent !== false;
      const mConsentShown = eventShowMarketing && (marketingConsentShown !== undefined ? Boolean(marketingConsentShown) : true);
      const mConsent = mConsentShown ? Boolean(marketingConsent) : false;
      const pConsent = eventShowPhoto && photoConsent !== undefined && photoConsent !== null ? Boolean(photoConsent) : null;

      const ticketQuantity = Math.min(Math.max(parseInt(quantity) || 1, 1), 10);
      const amountCents = Math.round(price * 100);
      const totalAmountCents = amountCents * ticketQuantity;

      // For group registrations, save pending data to Firestore
      let pendingRegId = null;
      if (ticketQuantity > 1 && extraAttendees && extraAttendees.length > 0) {
        const pendingRef = db.collection("pending_registrations").doc();
        pendingRegId = pendingRef.id;
        await pendingRef.set({
          eventId,
          orgId,
          slotId: slotId || null,
          customData: customData || {},
          marketingConsent: mConsent,
          marketingConsentShown: mConsentShown,
          photoConsent: pConsent,
          primaryAttendee: { firstName, lastName, email: email.toLowerCase(), phone: phone || null },
          extraAttendees: extraAttendees.map((a) => ({
            firstName: a.firstName || "",
            lastName: a.lastName || "",
            email: (a.email || "").toLowerCase(),
            phone: a.phone || null,
          })),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      const session = await createTicketCheckoutSession({
        stripe,
        orgData,
        connectedAccountId,
        ticketParams: {
          amountCents,
          quantity: ticketQuantity,
          productName: t(lang, "stripe", "ticketProduct", { eventTitle: eventTitle || "Event Ticket" }),
          productDescription: ticketQuantity > 1
            ? t(lang, "stripe", "ticketDescriptionMultiple", { quantity: ticketQuantity, eventTitle })
            : t(lang, "stripe", "ticketDescriptionSingle", { eventTitle }),
          email,
          successUrl: `https://ticketto.it/register/${eventId}?payment=success&session_id={CHECKOUT_SESSION_ID}`,
          cancelUrl: `https://ticketto.it/register/${eventId}?payment=cancelled`,
          metadata: {
            payment_type: "ticket_payment",
            event_id: eventId,
            org_id: orgId,
            slot_id: slotId || "",
            quantity: String(ticketQuantity),
            pending_registration_id: pendingRegId || "",
            marketing_consent: mConsent ? "true" : "false",
            marketing_consent_shown: mConsentShown ? "true" : "false",
            photo_consent: pConsent !== null ? String(pConsent) : "",
            attendee_data: pendingRegId ? "{}" : JSON.stringify({
              firstName, lastName, email, phone,
              customData: customData || {},
            }),
          },
        },
        lang,
      });

      console.log(`💳 Ticket checkout: event=${eventId} qty=${ticketQuantity} amount=€${(totalAmountCents / 100).toFixed(2)} (direct charge on ${connectedAccountId})`);
      res.json({ url: session.url, sessionId: session.id });
    } catch (error) {
      console.error("❌ Error creating ticket checkout:", error);
      res.status(500).json({ error: error.message });
    }
  }
);

// ═══════════════════════════════════════════════════════════════
// ─── AI EVENT CREATOR (Vertex AI) ────────────────────────────
// ═══════════════════════════════════════════════════════════════

const AI_PLAN_LIMITS = {
  free: 0,
  pro: 5,       // monthly limit
  business: -1, // unlimited monthly
};

// ─── Rate Limiting & Daily Caps (anti-abuse) ─────────────────
const AI_RATE_LIMITS = {
  maxPerHour: 20,   // per org, any plan
  maxPerDay: 100,   // per org, any plan (even Business)
};

/**
 * Server-side rate limit check for AI features.
 * Prevents abuse even on unlimited plans.
 * Returns { allowed: boolean, reason?: string }
 */
async function checkAiRateLimit(orgId) {
  const now = new Date();

  // Hourly check
  const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
  const hourlySnap = await db.collection("ai_usage")
    .where("orgId", "==", orgId)
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(oneHourAgo))
    .count().get();
  const hourlyCount = hourlySnap.data().count || 0;

  if (hourlyCount >= AI_RATE_LIMITS.maxPerHour) {
    return {
      allowed: false,
      reason: `Rate limit: max ${AI_RATE_LIMITS.maxPerHour} AI requests per hour. Try again later.`,
    };
  }

  // Daily check
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const dailySnap = await db.collection("ai_usage")
    .where("orgId", "==", orgId)
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(todayStart))
    .count().get();
  const dailyCount = dailySnap.data().count || 0;

  if (dailyCount >= AI_RATE_LIMITS.maxPerDay) {
    return {
      allowed: false,
      reason: `Daily limit: max ${AI_RATE_LIMITS.maxPerDay} AI requests per day. Try again tomorrow.`,
    };
  }

  return { allowed: true };
}

exports.generateEventWithAI = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    // 1. Authentication check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { orgId, prompt } = request.data;
    if (!orgId || !prompt) {
      throw new HttpsError("invalid-argument", "orgId and prompt are required");
    }

    // 2. Verify org membership and get plan
    const orgDoc = await db.collection("organizations").doc(orgId).get();
    if (!orgDoc.exists) {
      throw new HttpsError("not-found", "Organization not found");
    }
    const orgData = orgDoc.data();
    const plan = orgData.plan || "free";

    // 3. Check AI access for plan
    const maxUsages = AI_PLAN_LIMITS[plan];
    if (maxUsages === 0) {
      throw new HttpsError(
        "permission-denied",
        "AI features are not available on the Free plan. Upgrade to Pro to unlock AI."
      );
    }

    // 4a. Rate limit check (anti-abuse, all plans)
    const rateCheck = await checkAiRateLimit(orgId);
    if (!rateCheck.allowed) {
      throw new HttpsError("resource-exhausted", rateCheck.reason);
    }

    // 4b. Check monthly usage limits (server-side, not bypassable)
    if (maxUsages !== -1) {
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

      const usageSnap = await db
        .collection("ai_usage")
        .where("orgId", "==", orgId)
        .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(monthStart))
        .count()
        .get();

      const currentUsage = usageSnap.data().count || 0;
      if (currentUsage >= maxUsages) {
        throw new HttpsError(
          "resource-exhausted",
          `Monthly AI usage limit reached (${maxUsages}/${maxUsages}). Upgrade to Business for unlimited AI.`
        );
      }
    }

    // 5. Call Vertex AI (Gemini 2.0 Flash)
    try {
      const { VertexAI } = require("@google-cloud/vertexai");

      const vertexAI = new VertexAI({
        project: "eventflow-3541b",
        location: "europe-west1",
      });

      const model = vertexAI.getGenerativeModel({
        model: "gemini-2.0-flash-001",
        generationConfig: {
          temperature: 0.7,
          topP: 0.95,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      });

      const systemPrompt = `You are an expert event planner assistant for Ticketto, an event management platform.
Given the user's description, generate a complete event configuration in JSON format.

RULES:
- Always respond in the SAME LANGUAGE as the user's input
- Title should be catchy and professional
- Description should be 2-3 sentences, engaging and informative
- Suggest relevant custom fields based on the event type (max 3)
- Suggest time slots ONLY if the event naturally needs them (e.g., workshops, tours, timed entries)
- Categories should reflect attendee types for this event
- Be smart about maxAttendees based on event type
- If the user mentions a price, set isPaid=true and include the price
- Custom field types can be: "text", "select", "number", "checkbox", "email", "phone"

RESPOND ONLY WITH THIS JSON STRUCTURE:
{
  "title": "Event Title",
  "description": "Engaging event description...",
  "location": "Venue or null",
  "maxAttendees": 50,
  "isPaid": false,
  "price": null,
  "categories": ["Standard"],
  "customFields": [
    {
      "label": "Field Label",
      "type": "text",
      "required": true,
      "placeholder": "hint text",
      "options": null
    }
  ],
  "timeSlots": [
    {
      "label": "Slot Name",
      "startTime": "09:00",
      "endTime": "10:00",
      "maxCapacity": 20
    }
  ]
}`;

      const result = await model.generateContent({
        contents: [
          { role: "user", parts: [{ text: systemPrompt }] },
          { role: "model", parts: [{ text: "Capito! Sono pronto a generare eventi. Inviami la tua descrizione." }] },
          { role: "user", parts: [{ text: prompt }] },
        ],
      });

      const responseText = result.response.candidates[0].content.parts[0].text;
      const eventData = JSON.parse(responseText);

      // 6. Record usage in Firestore
      await db.collection("ai_usage").add({
        orgId: orgId,
        userId: request.auth.uid,
        feature: "event_creator",
        prompt: prompt.substring(0, 200), // Store first 200 chars for analytics
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✨ AI event generated for org=${orgId} plan=${plan} title="${eventData.title}"`);

      return { success: true, event: eventData };
    } catch (error) {
      console.error("❌ AI generation error:", error);
      throw new HttpsError("internal", "AI generation failed. Please try again.");
    }
  }
);

// ─── Get AI Usage Stats ─────────────────────────────────────
exports.getAiUsageStats = onCall(
  { region: "europe-west1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { orgId } = request.data;
    if (!orgId) {
      throw new HttpsError("invalid-argument", "orgId is required");
    }

    const orgDoc = await db.collection("organizations").doc(orgId).get();
    if (!orgDoc.exists) {
      throw new HttpsError("not-found", "Organization not found");
    }

    const plan = orgDoc.data().plan || "free";
    const maxUsages = AI_PLAN_LIMITS[plan];

    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const usageSnap = await db
      .collection("ai_usage")
      .where("orgId", "==", orgId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(monthStart))
      .count()
      .get();

    const currentUsage = usageSnap.data().count || 0;

    return {
      plan,
      maxUsages,
      currentUsage,
      remaining: maxUsages === -1 ? -1 : Math.max(0, maxUsages - currentUsage),
    };
  }
);

// ─── Smart Email Composer (Vertex AI) ───────────────────────
exports.generateEmailWithAI = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { orgId, eventId, emailType, customInstructions } = request.data;
    if (!orgId || !eventId || !emailType) {
      throw new HttpsError("invalid-argument", "orgId, eventId, and emailType are required");
    }

    // Check plan
    const orgDoc = await db.collection("organizations").doc(orgId).get();
    if (!orgDoc.exists) throw new HttpsError("not-found", "Organization not found");
    const plan = orgDoc.data().plan || "free";
    const maxUsages = AI_PLAN_LIMITS[plan];

    if (maxUsages === 0) {
      throw new HttpsError("permission-denied", "AI features are not available on the Free plan.");
    }

    // Rate limit check (anti-abuse)
    const rateCheck = await checkAiRateLimit(orgId);
    if (!rateCheck.allowed) {
      throw new HttpsError("resource-exhausted", rateCheck.reason);
    }

    // Check monthly usage
    if (maxUsages !== -1) {
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const usageSnap = await db.collection("ai_usage")
        .where("orgId", "==", orgId)
        .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(monthStart))
        .count().get();
      if ((usageSnap.data().count || 0) >= maxUsages) {
        throw new HttpsError("resource-exhausted", "Monthly AI usage limit reached.");
      }
    }

    // Fetch event data
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found");
    const eventData = eventDoc.data();

    // Fetch attendee count
    const attendeesSnap = await db.collection("attendees")
      .where("eventId", "==", eventId).count().get();
    const attendeeCount = attendeesSnap.data().count || 0;

    const eventDate = eventData.date && eventData.date.toDate ? eventData.date.toDate() : new Date();
    const formattedDate = eventDate.toLocaleDateString("it-IT", { weekday: "long", day: "numeric", month: "long", year: "numeric", timeZone: "Europe/Rome" });
    const formattedTime = eventDate.toLocaleTimeString("it-IT", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Rome" });

    try {
      const { VertexAI } = require("@google-cloud/vertexai");
      const vertexAI = new VertexAI({ project: "eventflow-3541b", location: "europe-west1" });
      const model = vertexAI.getGenerativeModel({
        model: "gemini-2.0-flash-001",
        generationConfig: { temperature: 0.7, maxOutputTokens: 1500, responseMimeType: "application/json" },
      });

      const emailTypeLabels = {
        reminder: "Reminder pre-evento (da inviare 1-2 giorni prima)",
        followup: "Follow-up post-evento (ringraziamento e feedback)",
        change: "Comunicazione di cambiamento (orario, location, dettagli)",
        custom: "Email personalizzata: " + (customInstructions || "comunicazione generica"),
      };

      const prompt = `You are a professional event communication specialist for "${orgDoc.data().name || "Ticketto"}".
Generate an email for the following event and type.

EVENT DETAILS:
- Title: ${eventData.title}
- Date: ${formattedDate} at ${formattedTime}
- Location: ${eventData.location || "Not specified"}
- Registered attendees: ${attendeeCount}
- Max capacity: ${eventData.maxAttendees}
- Description: ${eventData.description || "None"}
${eventData.isPaid ? "- Price: EUR " + eventData.price : "- Free event"}

EMAIL TYPE: ${emailTypeLabels[emailType] || emailType}
${customInstructions ? "CUSTOM INSTRUCTIONS: " + customInstructions : ""}

RULES:
- Write in Italian
- Use a professional but warm tone
- Keep it concise (max 150 words)
- Include a clear call-to-action
- Use the event name and details naturally
- Do NOT include HTML tags, just plain text
- Adapt tone to event type (formal for conferences, casual for parties)

RESPOND WITH THIS JSON:
{
  "subject": "Email subject line",
  "body": "Email body text with line breaks",
  "tone": "formal or casual or friendly"
}`;

      const result = await model.generateContent({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
      });

      const responseText = result.response.candidates[0].content.parts[0].text;
      const emailData = JSON.parse(responseText);

      // Record usage
      await db.collection("ai_usage").add({
        orgId: orgId,
        userId: request.auth.uid,
        feature: "email_composer",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("AI email generated for org=" + orgId + " event=" + eventId + " type=" + emailType);
      return { success: true, email: emailData };
    } catch (error) {
      console.error("AI email error:", error);
      throw new HttpsError("internal", "AI email generation failed.");
    }
  }
);

// ─── Event Insights Summary (Vertex AI - Business only) ─────
exports.generateEventInsights = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 90,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { orgId, eventId } = request.data;
    if (!orgId || !eventId) {
      throw new HttpsError("invalid-argument", "orgId and eventId are required");
    }

    // Business plan only
    const orgDoc = await db.collection("organizations").doc(orgId).get();
    if (!orgDoc.exists) throw new HttpsError("not-found", "Organization not found");
    const plan = orgDoc.data().plan || "free";

    if (plan !== "business") {
      throw new HttpsError(
        "permission-denied",
        "Event Insights are available exclusively on the Business plan."
      );
    }

    // Rate limit check (anti-abuse)
    const rateCheck = await checkAiRateLimit(orgId);
    if (!rateCheck.allowed) {
      throw new HttpsError("resource-exhausted", rateCheck.reason);
    }

    // Fetch event
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found");
    const eventData = eventDoc.data();

    // Fetch all attendees
    const attendeesSnap = await db.collection("attendees")
      .where("eventId", "==", eventId).get();

    const attendees = attendeesSnap.docs.map(function (d) { return d.data(); });
    const totalRegistered = attendees.length;
    const confirmed = attendees.filter(function (a) { return a.status === "confirmed"; }).length;
    const checkedIn = attendees.filter(function (a) { return a.checkInStatus === "checkedIn"; }).length;
    const noShows = confirmed - checkedIn;
    const checkInRate = totalRegistered > 0 ? Math.round((checkedIn / totalRegistered) * 100) : 0;
    const capacityRate = eventData.maxAttendees > 0 ? Math.round((totalRegistered / eventData.maxAttendees) * 100) : 0;

    // Revenue data
    const totalRevenue = attendees
      .filter(function (a) { return a.paymentAmount; })
      .reduce(function (sum, a) { return sum + (a.paymentAmount || 0); }, 0);

    // Registration timeline
    const registrationDates = attendees
      .map(function (a) { return a.registeredAt && a.registeredAt.toDate ? a.registeredAt.toDate() : null; })
      .filter(function (d) { return d !== null; })
      .sort(function (a, b) { return a - b; });

    const eventDate = eventData.date && eventData.date.toDate ? eventData.date.toDate() : new Date();

    // Days before event for each registration
    var registrationDistribution = {};
    registrationDates.forEach(function (regDate) {
      var daysBefore = Math.ceil((eventDate - regDate) / (1000 * 60 * 60 * 24));
      var bucket = daysBefore <= 0 ? "day-of" : daysBefore <= 1 ? "1-day" : daysBefore <= 3 ? "2-3-days" : daysBefore <= 7 ? "4-7-days" : "7+-days";
      registrationDistribution[bucket] = (registrationDistribution[bucket] || 0) + 1;
    });

    // Time slot analysis
    var slotAnalysis = "";
    if (eventData.hasTimeSlots && eventData.timeSlots && eventData.timeSlots.length > 0) {
      var slotStats = eventData.timeSlots.map(function (s) {
        return {
          label: s.label,
          booked: s.bookedCount || 0,
          max: s.maxCapacity,
          fillRate: s.maxCapacity > 0 ? Math.round(((s.bookedCount || 0) / s.maxCapacity) * 100) : 0,
        };
      });
      slotAnalysis = "Time slots: " + JSON.stringify(slotStats);
    }

    // Check-in times analysis
    var checkInTimes = attendees
      .filter(function (a) { return a.checkInTime && a.checkInTime.toDate; })
      .map(function (a) { return a.checkInTime.toDate(); });

    var checkInTimeline = "";
    if (checkInTimes.length > 0) {
      var earliest = new Date(Math.min.apply(null, checkInTimes));
      var latest = new Date(Math.max.apply(null, checkInTimes));
      checkInTimeline = "Check-in window: " + earliest.toLocaleTimeString("it-IT", { timeZone: "Europe/Rome" }) + " - " + latest.toLocaleTimeString("it-IT", { timeZone: "Europe/Rome" });
    }

    var noShowRate = totalRegistered > 0 ? Math.round((noShows / totalRegistered) * 100) : 0;

    try {
      const { VertexAI } = require("@google-cloud/vertexai");
      var vertexAI = new VertexAI({ project: "eventflow-3541b", location: "europe-west1" });
      var model = vertexAI.getGenerativeModel({
        model: "gemini-2.0-flash-001",
        generationConfig: { temperature: 0.6, maxOutputTokens: 2000, responseMimeType: "application/json" },
      });

      var formattedEventDate = eventDate.toLocaleDateString("it-IT", { weekday: "long", day: "numeric", month: "long", year: "numeric", timeZone: "Europe/Rome" });

      var prompt = 'You are a data analyst for event management. Analyze the following event data and generate actionable insights.\n\n' +
        'EVENT: "' + eventData.title + '"\n' +
        'Date: ' + formattedEventDate + '\n' +
        'Location: ' + (eventData.location || "Not specified") + '\n' +
        (eventData.isPaid ? 'Paid event: EUR ' + eventData.price + '\n' : 'Free event\n') +
        '\nMETRICS:\n' +
        '- Total registered: ' + totalRegistered + ' / ' + eventData.maxAttendees + ' max (' + capacityRate + '% capacity)\n' +
        '- Confirmed: ' + confirmed + '\n' +
        '- Checked in: ' + checkedIn + ' (' + checkInRate + '% check-in rate)\n' +
        '- No-shows: ' + noShows + '\n' +
        (eventData.isPaid ? '- Total revenue: EUR ' + totalRevenue.toFixed(2) + '\n' : '') +
        '\nREGISTRATION DISTRIBUTION (days before event):\n' +
        JSON.stringify(registrationDistribution) + '\n' +
        (slotAnalysis ? '\n' + slotAnalysis + '\n' : '') +
        (checkInTimeline ? '\n' + checkInTimeline + '\n' : '') +
        '\nRULES:\n' +
        '- Write in Italian\n' +
        '- Be specific with numbers and percentages\n' +
        '- Provide 3-5 key insights\n' +
        '- Each insight should have a title, description, and recommendation\n' +
        '- Include a predicted no-show rate for future similar events\n' +
        '- If check-in rate is low, suggest strategies\n' +
        '- If capacity is low, suggest promotion strategies\n' +
        '- Be encouraging but honest\n' +
        '\nRESPOND WITH THIS JSON:\n' +
        '{\n' +
        '  "summary": "One paragraph executive summary of the event performance",\n' +
        '  "overallScore": 85,\n' +
        '  "insights": [\n' +
        '    {\n' +
        '      "icon": "emoji",\n' +
        '      "title": "Insight title",\n' +
        '      "description": "What the data shows",\n' +
        '      "recommendation": "What to do about it",\n' +
        '      "sentiment": "positive or neutral or negative"\n' +
        '    }\n' +
        '  ],\n' +
        '  "predictedNoShowRate": 15,\n' +
        '  "bestRegistrationWindow": "Description of when most registrations happened",\n' +
        '  "keyMetrics": {\n' +
        '    "capacityRate": ' + capacityRate + ',\n' +
        '    "checkInRate": ' + checkInRate + ',\n' +
        '    "noShowRate": ' + noShowRate + '\n' +
        '  }\n' +
        '}';

      var result = await model.generateContent({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
      });

      var responseText = result.response.candidates[0].content.parts[0].text;
      var insights = JSON.parse(responseText);

      // Record usage
      await db.collection("ai_usage").add({
        orgId: orgId,
        userId: request.auth.uid,
        feature: "event_insights",
        eventId: eventId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("AI insights generated for org=" + orgId + " event=" + eventId);
      return { success: true, insights: insights };
    } catch (error) {
      console.error("AI insights error:", error);
      throw new HttpsError("internal", "AI insights generation failed.");
    }
  }
);

// ═══════════════════════════════════════════════════════════════
// ─── SCHEDULED EMAILS (REMINDER + POST-EVENT) ────────────────
// ═══════════════════════════════════════════════════════════════

function escapeScheduledEmailHtml(str) {
  if (str === null || str === undefined) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function buildScheduledEmailCustomMessageHtml(rawMessage, accentColor = "#0E6B52") {
  if (typeof rawMessage !== "string") return "";
  const trimmed = rawMessage.trim().slice(0, 1000);
  if (!trimmed) return "";
  const escapedWithBreaks = escapeScheduledEmailHtml(trimmed).replace(/\r\n|\r|\n/g, "<br>");
  return `
          <!-- Custom Message -->
          <tr>
            <td style="padding: 0 32px 16px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F9FAFB; border-radius: 12px; border: 1px solid #E5E7EB; border-left: 4px solid ${accentColor};">
                <tr>
                  <td style="padding: 16px 20px; font-size: 15px; color: #1F2937; line-height: 1.6; word-break: break-word;">
                    ${escapedWithBreaks}
                  </td>
                </tr>
              </table>
            </td>
          </tr>`;
}

async function verifyOrgOwnerOrAdmin(orgId, uid) {
  if (!orgId || !uid) return false;
  const directDoc = await db.collection("organizations").doc(orgId).collection("members").doc(uid).get();
  if (directDoc.exists) {
    const role = directDoc.data()?.role;
    return role === "owner" || role === "admin";
  }
  const snap = await db.collection("organizations").doc(orgId).collection("members")
    .where("userId", "==", uid)
    .limit(1)
    .get();
  if (!snap.empty) {
    const role = snap.docs[0].data()?.role;
    return role === "owner" || role === "admin";
  }
  return false;
}

function normalizeScheduledEmailType(type) {
  if (type === "reminder") return "reminder";
  if (type === "thankYou" || type === "thank_you" || type === "postEvent") return "thankYou";
  return null;
}

// Runs every hour
exports.processScheduledEmails = onSchedule(
  {
    schedule: "every 1 hours",
    region: "europe-west1",
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async () => {
    const now = new Date();
    console.log(`⏰ Processing scheduled emails at ${now.toISOString()}`);

    let remindersSent = 0;
    let thankYouSent = 0;
    let thankYouSkippedStale = 0;

    try {
      // ─── 1. REMINDER EMAILS (Pro + Business) ────────────────────
      const reminderEvents = await db.collection("events")
        .where("reminderEnabled", "==", true)
        .where("status", "==", "published")
        .get();

      for (const eventDoc of reminderEvents.docs) {
        const eventData = eventDoc.data();
        if (eventData.reminderSentAt) continue;

        const lang = getEventLang(eventData);
        const eventDate = eventData.date?.toDate ? eventData.date.toDate() : new Date(eventData.date);
        if (!eventDate || isNaN(eventDate.getTime())) continue;

        const daysBefore = eventData.reminderDaysBefore || 1;
        const reminderDate = new Date(eventDate);
        reminderDate.setDate(reminderDate.getDate() - daysBefore);

        // Check if it's time to send (reminder date has passed but event hasn't)
        if (now >= reminderDate && now < eventDate) {
          // Check org plan (Pro + Business)
          const orgDoc = await db.collection("organizations").doc(eventData.orgId).get();
          const orgPlan = orgDoc.exists ? (orgDoc.data().plan || "free") : "free";
          if (orgPlan !== "pro" && orgPlan !== "business") continue;

          const orgData = orgDoc.exists ? orgDoc.data() : null;

          // Get all confirmed attendees
          const attendees = await db.collection("attendees")
            .where("eventId", "==", eventDoc.id)
            .where("status", "==", "confirmed")
            .get();

          if (attendees.empty) {
            await eventDoc.ref.update({ reminderSentAt: admin.firestore.FieldValue.serverTimestamp() });
            continue;
          }

          const resend = new Resend(RESEND_API_KEY);
          const organizerEmail = await getOrganizerEmail(eventData.orgId, orgData);

          for (const attDoc of attendees.docs) {
            const att = attDoc.data();
            try {
              const html = buildReminderEmail(att, eventData, orgData, lang);
              const payload = {
                from: EMAIL_FROM,
                to: [att.email],
                subject: t(lang, 'email', 'reminderSubject', { eventTitle: eventData.title }),
                html: html,
              };
              if (organizerEmail) payload.reply_to = [organizerEmail];
              const { data: sendData, error: sendErr } = await resend.emails.send(payload);
              if (sendErr) {
                console.error(`❌ Reminder email failed for ${att.email}:`, sendErr);
              } else {
                remindersSent++;
                console.log(`✉️ Reminder email sent to ${att.email} (event=${eventDoc.id}, resendId=${sendData?.id})`);
              }
            } catch (emailErr) {
              console.error(`❌ Reminder email failed for ${att.email}:`, emailErr.message);
            }
          }

          await eventDoc.ref.update({ reminderSentAt: admin.firestore.FieldValue.serverTimestamp() });
          console.log(`✅ Reminder sent for "${eventData.title}" (${eventDoc.id}) to ${attendees.size} attendees`);
        }
      }

      // ─── 2. POST-EVENT THANK YOU (Pro + Business, automatic) ────
      const TWELVE_HOURS_MS = 12 * 60 * 60 * 1000;
      const THREE_DAYS_MS = 3 * 24 * 60 * 60 * 1000;

      const postEventCandidates = await db.collection("events")
        .where("postEventEmailEnabled", "==", true)
        .get();

      for (const eventDoc of postEventCandidates.docs) {
        const eventData = eventDoc.data();
        if (eventData.postEventSentAt) continue;

        // Only published or completed events (never draft or canceled)
        if (eventData.status !== "published" && eventData.status !== "completed") continue;

        const startDate = eventData.date?.toDate ? eventData.date.toDate() : new Date(eventData.date);
        if (!startDate || isNaN(startDate.getTime())) continue;

        const rawEndDate = eventData.endDate
          ? (eventData.endDate?.toDate ? eventData.endDate.toDate() : new Date(eventData.endDate))
          : null;
        const effectiveEndDate = (rawEndDate && !isNaN(rawEndDate.getTime()))
          ? rawEndDate
          : new Date(startDate.getTime() + 3 * 60 * 60 * 1000);

        const elapsedMs = now.getTime() - effectiveEndDate.getTime();

        // Must be at least 12 hours after event end
        if (elapsedMs < TWELVE_HOURS_MS) continue;

        // Guard against retroactive sends: if event ended more than 3 days ago,
        // mark postEventSentAt without sending anything.
        if (elapsedMs > THREE_DAYS_MS) {
          await eventDoc.ref.update({ postEventSentAt: admin.firestore.FieldValue.serverTimestamp() });
          thankYouSkippedStale++;
          console.log(`⏭️ Marked stale event "${eventData.title}" (${eventDoc.id}, ended ${effectiveEndDate.toISOString()}) with postEventSentAt without sending`);
          continue;
        }

        // Check org plan (Pro + Business)
        const orgDoc = await db.collection("organizations").doc(eventData.orgId).get();
        const orgPlan = orgDoc.exists ? (orgDoc.data().plan || "free") : "free";
        if (orgPlan !== "pro" && orgPlan !== "business") continue;

        const orgData = orgDoc.exists ? orgDoc.data() : null;
        const lang = getEventLang(eventData);

        // Get all attendees who checked in
        const attendees = await db.collection("attendees")
          .where("eventId", "==", eventDoc.id)
          .where("checkInStatus", "==", "checkedIn")
          .get();

        if (attendees.empty) {
          await eventDoc.ref.update({ postEventSentAt: admin.firestore.FieldValue.serverTimestamp() });
          console.log(`ℹ️ No checked-in attendees for "${eventData.title}" (${eventDoc.id}), marked postEventSentAt`);
          continue;
        }

        const resend = new Resend(RESEND_API_KEY);
        const feedbackUrl = `https://ticketto.it/feedback/${eventDoc.id}`;
        const organizerEmail = await getOrganizerEmail(eventData.orgId, orgData);

        for (const attDoc of attendees.docs) {
          const att = attDoc.data();
          try {
            const html = buildThankYouEmail(att, eventData, orgData, feedbackUrl, lang);
            const payload = {
              from: EMAIL_FROM,
              to: [att.email],
              subject: t(lang, 'email', 'thankYouSubject', { eventTitle: eventData.title }),
              html: html,
            };
            if (organizerEmail) payload.reply_to = [organizerEmail];
            const { data: sendData, error: sendErr } = await resend.emails.send(payload);
            if (sendErr) {
              console.error(`❌ Thank you email failed for ${att.email}:`, sendErr);
            } else {
              thankYouSent++;
              console.log(`✉️ Thank you email sent to ${att.email} (event=${eventDoc.id}, resendId=${sendData?.id})`);
            }
          } catch (emailErr) {
            console.error(`❌ Thank you email failed for ${att.email}:`, emailErr.message);
          }
        }

        await eventDoc.ref.update({ postEventSentAt: admin.firestore.FieldValue.serverTimestamp() });
        console.log(`✅ Thank you sent for "${eventData.title}" (${eventDoc.id}) to ${attendees.size} attendees`);
      }

      console.log(`📬 Scheduled emails done: ${remindersSent} reminders, ${thankYouSent} thank you emails (${thankYouSkippedStale} stale skipped)`);
    } catch (error) {
      console.error("❌ Scheduled emails processing error:", error);
    }
  }
);

// ─── Preview Scheduled Email (Owner/Admin only, no send) ─────
exports.previewScheduledEmail = onCall(
  { region: "europe-west1", cors: true },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { eventId, type, customMessage } = request.data || {};
    const normalizedType = normalizeScheduledEmailType(type);
    if (!eventId || typeof eventId !== "string" || !normalizedType) {
      throw new HttpsError("invalid-argument", "Valid eventId and type ('reminder' or 'thankYou') are required.");
    }

    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }

    const eventData = eventDoc.data();
    const isAllowed = await verifyOrgOwnerOrAdmin(eventData.orgId, request.auth.uid);
    if (!isAllowed) {
      throw new HttpsError("permission-denied", "Only organization owners and admins can preview scheduled emails.");
    }

    const orgDoc = await db.collection("organizations").doc(eventData.orgId).get();
    const orgData = orgDoc.exists ? orgDoc.data() : null;

    const effectiveEvent = { ...eventData };
    if (typeof customMessage === "string") {
      if (normalizedType === "reminder") {
        effectiveEvent.reminderCustomMessage = customMessage.slice(0, 1000);
      } else {
        effectiveEvent.thankYouCustomMessage = customMessage.slice(0, 1000);
      }
    }

    const lang = getEventLang(effectiveEvent);
    const fakeAttendee = lang === "it"
      ? { firstName: "Mario", lastName: "Rossi", email: "mario.rossi@example.com" }
      : { firstName: "Alex", lastName: "Smith", email: "alex.smith@example.com" };

    let subject;
    let html;
    if (normalizedType === "reminder") {
      subject = t(lang, "email", "reminderSubject", { eventTitle: effectiveEvent.title });
      html = buildReminderEmail(fakeAttendee, effectiveEvent, orgData, lang);
    } else {
      const feedbackUrl = `https://ticketto.it/feedback/${eventDoc.id}`;
      subject = t(lang, "email", "thankYouSubject", { eventTitle: effectiveEvent.title });
      html = buildThankYouEmail(fakeAttendee, effectiveEvent, orgData, feedbackUrl, lang);
    }

    return {
      subject,
      html,
      lang,
      type: normalizedType,
    };
  }
);

// ─── Send Test Scheduled Email to Logged-in User ─────────────
exports.sendTestScheduledEmail = onCall(
  { region: "europe-west1", cors: true },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { eventId, type, customMessage } = request.data || {};
    const normalizedType = normalizeScheduledEmailType(type);
    if (!eventId || typeof eventId !== "string" || !normalizedType) {
      throw new HttpsError("invalid-argument", "Valid eventId and type ('reminder' or 'thankYou') are required.");
    }

    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }

    const eventData = eventDoc.data();
    const isAllowed = await verifyOrgOwnerOrAdmin(eventData.orgId, request.auth.uid);
    if (!isAllowed) {
      throw new HttpsError("permission-denied", "Only organization owners and admins can send test scheduled emails.");
    }

    const orgDoc = await db.collection("organizations").doc(eventData.orgId).get();
    const orgData = orgDoc.exists ? orgDoc.data() : null;
    const orgPlan = orgData?.plan || "free";
    if (orgPlan !== "pro" && orgPlan !== "business") {
      throw new HttpsError("permission-denied", "Scheduled emails are available from the Pro plan.");
    }

    let recipientEmail = request.auth.token?.email;
    let recipientName = request.auth.token?.name || "";
    if (!recipientEmail) {
      const userRec = await admin.auth().getUser(request.auth.uid);
      recipientEmail = userRec.email;
      recipientName = userRec.displayName || "";
    }
    if (!recipientEmail) {
      throw new HttpsError("failed-precondition", "Authenticated user does not have an email address.");
    }

    // Rate limit: max 5 test emails per rolling hour per user
    const rateRef = db.collection("rate_limits").doc(`scheduled_email_test_${request.auth.uid}`);
    const nowMs = Date.now();
    const windowMs = 60 * 60 * 1000;
    const maxPerHour = 5;

    await db.runTransaction(async (tx) => {
      const rateSnap = await tx.get(rateRef);
      const prev = rateSnap.exists && Array.isArray(rateSnap.data().timestamps)
        ? rateSnap.data().timestamps
        : [];
      const recent = prev.filter((ts) => typeof ts === "number" && nowMs - ts < windowMs);
      if (recent.length >= maxPerHour) {
        throw new HttpsError("resource-exhausted", "Hourly limit of test emails reached. Please try again later.");
      }
      recent.push(nowMs);
      tx.set(rateRef, {
        userId: request.auth.uid,
        timestamps: recent,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const effectiveEvent = { ...eventData };
    if (typeof customMessage === "string") {
      if (normalizedType === "reminder") {
        effectiveEvent.reminderCustomMessage = customMessage.slice(0, 1000);
      } else {
        effectiveEvent.thankYouCustomMessage = customMessage.slice(0, 1000);
      }
    }

    const lang = getEventLang(effectiveEvent);
    const firstName = (recipientName.trim().split(/\s+/)[0]) || (lang === "it" ? "Mario" : "Alex");
    const testAttendee = { firstName, lastName: "", email: recipientEmail };
    const prefix = lang === "it" ? "[PROVA] " : "[TEST] ";

    let subject;
    let html;
    if (normalizedType === "reminder") {
      subject = prefix + t(lang, "email", "reminderSubject", { eventTitle: effectiveEvent.title });
      html = buildReminderEmail(testAttendee, effectiveEvent, orgData, lang);
    } else {
      const feedbackUrl = `https://ticketto.it/feedback/${eventDoc.id}`;
      subject = prefix + t(lang, "email", "thankYouSubject", { eventTitle: effectiveEvent.title });
      html = buildThankYouEmail(testAttendee, effectiveEvent, orgData, feedbackUrl, lang);
    }

    const resend = new Resend(RESEND_API_KEY);
    const organizerEmail = await getOrganizerEmail(eventData.orgId, orgData);
    const payload = {
      from: EMAIL_FROM,
      to: [recipientEmail],
      subject,
      html,
    };
    if (organizerEmail) payload.reply_to = [organizerEmail];

    const { data: sendData, error: sendErr } = await resend.emails.send(payload);
    if (sendErr) {
      console.error("❌ Failed to send test scheduled email:", sendErr);
      throw new HttpsError("internal", "Failed to send test email.");
    }

    console.log(`✉️ Sent test ${normalizedType} email to ${recipientEmail} (event=${eventId}, resendId=${sendData?.id})`);
    return {
      success: true,
      to: recipientEmail,
      id: sendData?.id || null,
    };
  }
);

// ─── Reminder Email Template ─────────────────────────────────
function buildReminderEmail(attendee, event, org, lang = 'it') {
  const locale = getDateLocale(lang);
  const eventDate = event.date?.toDate ? event.date.toDate() : new Date(event.date);
  const formattedDate = eventDate.toLocaleDateString(locale, {
    weekday: "long", year: "numeric", month: "long", day: "numeric", timeZone: "Europe/Rome",
  });
  const formattedTime = eventDate.toLocaleTimeString(locale, {
    hour: "2-digit", minute: "2-digit", timeZone: "Europe/Rome",
  });

  const safeFirstName = escapeScheduledEmailHtml(attendee.firstName || "");
  const safeTitle = escapeScheduledEmailHtml(event.title || "");
  const safeLocation = event.location ? escapeScheduledEmailHtml(event.location) : "";
  const safeOrgName = escapeScheduledEmailHtml(org?.name || "Ticketto");
  const customMessageHtml = buildScheduledEmailCustomMessageHtml(event.reminderCustomMessage, "#F59E0B");

  const reminderMapUrl = getEventMapUrl(event);
  const safeMapUrl = reminderMapUrl ? escapeScheduledEmailHtml(reminderMapUrl) : "";
  const locationHtml = (safeLocation || safeMapUrl)
    ? `<tr>
        <td style="padding: 8px 0; color: #6B7280; font-size: 14px; vertical-align: top;">${t(lang, 'email', 'locationLabel')}</td>
        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">
          ${safeLocation ? `<div>${safeMapUrl ? `<a href="${safeMapUrl}" target="_blank" rel="noopener" style="color: #1A1A2E; text-decoration: none;">${safeLocation}</a>` : safeLocation}</div>` : ""}
          ${safeMapUrl ? `<div style="margin-top: 4px;"><a href="${safeMapUrl}" target="_blank" rel="noopener" style="color: #0E6B52; text-decoration: underline; font-weight: 600; font-size: 13px;">📍 ${t(lang, 'email', 'openInMapsLabel')}</a></div>` : ""}
        </td>
      </tr>`
    : "";

  return `<!DOCTYPE html>
<html lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${t(lang, 'email', 'reminderPageTitle')}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F3F4F6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F3F4F6; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.06);">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #F59E0B 0%, #EF6C00 100%); padding: 40px 32px; text-align: center;">
              <h1 style="color: #FFFFFF; margin: 0 0 8px 0; font-size: 26px; font-weight: 700; letter-spacing: -0.5px;">${t(lang, 'email', 'reminderTitle')}</h1>
              <p style="color: rgba(255,255,255,0.85); margin: 0; font-size: 15px;">${t(lang, 'email', 'reminderSubtitle')}</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 32px 32px 16px 32px;">
              <p style="margin: 0; font-size: 16px; color: #374151;">
                ${t(lang, 'email', 'greeting', { firstName: safeFirstName })}
              </p>
              <p style="margin: 8px 0 0 0; font-size: 15px; color: #6B7280; line-height: 1.6;">
                ${t(lang, 'email', 'reminderBody', { eventTitle: safeTitle })}
              </p>
            </td>
          </tr>
${customMessageHtml}
          <!-- Event Details -->
          <tr>
            <td style="padding: 0 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #FFFBEB; border-radius: 12px; border: 1px solid #FDE68A;">
                <tr>
                  <td style="padding: 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'dateLabel')}</td>
                        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">${formattedDate}</td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'timeLabel')}</td>
                        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">${formattedTime}</td>
                      </tr>
                      ${locationHtml}
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Note -->
          <tr>
            <td style="padding: 24px 32px; text-align: center;">
              <p style="margin: 0; font-size: 14px; color: #6B7280; line-height: 1.6;">${t(lang, 'email', 'reminderNote')}</p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 20px 32px 32px 32px; text-align: center; border-top: 1px solid #E5E7EB;">
              <p style="margin: 0; font-size: 12px; color: #9CA3AF;">
                ${t(lang, 'email', 'sentBy', { orgName: safeOrgName })}
              </p>
              <p style="margin: 4px 0 0 0; font-size: 11px; color: #D1D5DB;">Powered by Ticketto</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// ─── Thank You Email Template ────────────────────────────────
function buildThankYouEmail(attendee, event, org, feedbackUrl, lang = 'it') {
  const locale = getDateLocale(lang);
  const eventDate = event.date?.toDate ? event.date.toDate() : new Date(event.date);
  const formattedDate = eventDate.toLocaleDateString(locale, {
    weekday: "long", year: "numeric", month: "long", day: "numeric", timeZone: "Europe/Rome",
  });

  const safeFirstName = escapeScheduledEmailHtml(attendee.firstName || "");
  const safeTitle = escapeScheduledEmailHtml(event.title || "");
  const safeOrgName = escapeScheduledEmailHtml(org?.name || "Ticketto");
  const safeFeedbackUrl = escapeScheduledEmailHtml(feedbackUrl || "");
  const customMessageHtml = buildScheduledEmailCustomMessageHtml(event.thankYouCustomMessage, "#10B981");

  return `<!DOCTYPE html>
<html lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${t(lang, 'email', 'thankYouPageTitle')}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F3F4F6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F3F4F6; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.06);">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #10B981 0%, #059669 100%); padding: 40px 32px; text-align: center;">
              <h1 style="color: #FFFFFF; margin: 0 0 8px 0; font-size: 26px; font-weight: 700; letter-spacing: -0.5px;">${t(lang, 'email', 'thankYouTitle')}</h1>
              <p style="color: rgba(255,255,255,0.85); margin: 0; font-size: 15px;">${t(lang, 'email', 'thankYouSubtitle')}</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 32px 32px 16px 32px;">
              <p style="margin: 0; font-size: 16px; color: #374151;">
                ${t(lang, 'email', 'greeting', { firstName: safeFirstName })}
              </p>
              <p style="margin: 8px 0 0 0; font-size: 15px; color: #6B7280; line-height: 1.6;">
                ${t(lang, 'email', 'thankYouBody', { eventTitle: safeTitle, formattedDate: formattedDate })}
              </p>
            </td>
          </tr>
${customMessageHtml}
          <!-- Feedback CTA -->
          <tr>
            <td style="padding: 8px 32px 32px 32px; text-align: center;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F0FDF4; border-radius: 12px; border: 1px solid #BBF7D0;">
                <tr>
                  <td style="padding: 24px;">
                    <p style="margin: 0 0 4px 0; font-size: 16px; font-weight: 600; color: #374151;">${t(lang, 'email', 'feedbackTitle')}</p>
                    <p style="margin: 0 0 16px 0; font-size: 14px; color: #6B7280;">${t(lang, 'email', 'feedbackBody')}</p>
                    <a href="${safeFeedbackUrl}" style="display: inline-block; background: linear-gradient(135deg, #10B981, #059669); color: #FFFFFF; padding: 12px 32px; border-radius: 8px; font-size: 14px; font-weight: 600; text-decoration: none;">${t(lang, 'email', 'feedbackButton')}</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 20px 32px 32px 32px; text-align: center; border-top: 1px solid #E5E7EB;">
              <p style="margin: 0; font-size: 12px; color: #9CA3AF;">
                ${t(lang, 'email', 'sentBy', { orgName: safeOrgName })}
              </p>
              <p style="margin: 4px 0 0 0; font-size: 11px; color: #D1D5DB;">Powered by Ticketto</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}




// ═══════════════════════════════════════════════════════════════
// ─── REACTIVATION CAMPAIGN (org dormienti) — marketing, temporaneo
// Aggiunto 2026-07-06. Endpoint protetto da token. Rimuovibile.
// ═══════════════════════════════════════════════════════════════
const REACTIVATION_TOKEN = "rz7Qn2reactivTicketto2026";
const REACTIVATION_SUBJECT = "Il tuo primo evento su Ticketto è a 2 minuti";
const REACTIVATION_CTA_URL = "https://ticketto.it/events";

function reactivationEmailHtml(name) {
  const n = (name && String(name).trim()) ? String(name).trim().split(" ")[0] : "ciao";
  return [
    '<div style="font-family: -apple-system, Segoe UI, Roboto, sans-serif; background:#F4F4F8; padding:24px;">',
    '<div style="max-width:520px; margin:0 auto; background:#ffffff; border-radius:16px; overflow:hidden; border:1px solid #ECECF3;">',
    '<div style="background-color:#0E6B52; padding:28px 32px;">',
    '<img src="https://ticketto.it/images/ticketto_logo_dark.png" alt="Ticketto" height="28" style="height:28px; display:block; border:0;" />',
    '</div>',
    '<div style="padding:32px;">',
    '<p style="font-size:16px; color:#1A1A2E; margin:0 0 16px;">Ciao <strong>' + n + '</strong>,</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 16px;">hai creato il tuo account Ticketto ma non hai ancora lanciato il tuo primo evento.</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 24px;">Ci vogliono davvero <strong>2 minuti</strong>: dai un nome, scegli i posti, e ottieni un link da condividere. Le iscrizioni arrivano da sole — niente chat infinite, niente fogli Excel da aggiornare a mano.</p>',
    '<div style="text-align:center; margin:0 0 28px;">',
    '<a href="' + REACTIVATION_CTA_URL + '" style="display:inline-block; background-color:#9AD530; color:#101410; text-decoration:none; font-weight:700; font-size:16px; padding:14px 32px; border-radius:10px;">Crea il tuo evento →</a>',
    '</div>',
    '<p style="font-size:15px; color:#333; margin:0 0 8px;">Qualche idea per partire:</p>',
    '<ul style="font-size:15px; line-height:1.8; color:#333; margin:0 0 8px; padding-left:20px;">',
    '<li>🚌 una gita o un viaggio di gruppo</li>',
    '<li>🎓 un Family Day o un doposcuola</li>',
    '<li>📚 un book club</li>',
    '<li>🎉 una festa o un compleanno</li>',
    '</ul>',
    '<p style="font-size:16px; color:#333; margin:24px 0 0;">A presto,<br>Fabio — Ticketto</p>',
    '</div>',
    '<div style="padding:20px 32px; border-top:1px solid #ECECF3; background:#FAFAFC;">',
    '<p style="font-size:12px; color:#9A9AAE; margin:0; line-height:1.5;">Ricevi questa email perché hai un account su Ticketto. Se non vuoi più riceverle, <a href="mailto:event@ticketto.it?subject=unsubscribe" style="color:#9A9AAE;">clicca qui per disiscriverti</a>.</p>',
    '</div>',
    '</div>',
    '</div>',
  ].join("");
}

exports.sendReactivationCampaign = onRequest({ cors: true }, async (req, res) => {
  const token = req.query.token;
  const mode = req.query.mode; // "test" | "count" | "all"
  const to = req.query.to;
  if (token !== REACTIVATION_TOKEN) { res.status(403).json({ error: "forbidden" }); return; }

  const resend = new Resend(RESEND_API_KEY);
  const headers = { "List-Unsubscribe": "<mailto:event@ticketto.it?subject=unsubscribe>" };

  try {
    if (mode === "test") {
      if (!to) { res.status(400).json({ error: "missing 'to'" }); return; }
      const { data, error } = await resend.emails.send({
        from: EMAIL_FROM, to: [to], subject: REACTIVATION_SUBJECT,
        html: reactivationEmailHtml("Fabio"), headers,
      });
      res.json({ ok: !error, mode: "test", to, id: data && data.id, error });
      return;
    }

    if (mode === "count" || mode === "all") {
      const orgsSnap = await db.collection("organizations").get();
      const now = Date.now();
      const r = { orgsTotal: orgsSnap.size, dormant: 0, skippedInternal: 0, skippedFresh: 0, noEmail: 0, alreadySent: 0, eligible: 0, sent: 0, errors: 0 };
      for (const orgDoc of orgsSnap.docs) {
        const org = orgDoc.data() || {};
        const orgId = orgDoc.id;
        const name = org.name || "";
        const evSnap = await db.collection("events").where("orgId", "==", orgId).limit(1).get();
        if (!evSnap.empty) continue;
        r.dormant++;
        if (/revan|test|apple|prova|demo/i.test(name)) { r.skippedInternal++; continue; }
        let createdMs = 0;
        if (org.createdAt && typeof org.createdAt.toMillis === "function") createdMs = org.createdAt.toMillis();
        else if (org.createdAt) createdMs = Date.parse(org.createdAt) || 0;
        if (createdMs && (now - createdMs) < 7 * 86400000) { r.skippedFresh++; continue; }
        let email = null, displayName = name;
        const userSnap = await db.collection("users").where("organizationIds", "array-contains", orgId).limit(1).get();
        if (!userSnap.empty) { const u = userSnap.docs[0].data(); email = u.email; displayName = u.displayName || name; }
        if (!email && org.email) email = org.email;
        if (!email || !String(email).includes("@")) { r.noEmail++; continue; }
        const logRef = db.collection("reactivation_log").doc(orgId);
        const logDoc = await logRef.get();
        if (logDoc.exists) { r.alreadySent++; continue; }
        r.eligible++;
        if (mode === "count") continue;
        try {
          const { data, error } = await resend.emails.send({
            from: EMAIL_FROM, to: [email], subject: REACTIVATION_SUBJECT,
            html: reactivationEmailHtml(displayName), headers,
          });
          if (error) { r.errors++; }
          else {
            r.sent++;
            await logRef.set({ orgId, email, displayName: displayName || null, sentAt: admin.firestore.FieldValue.serverTimestamp(), resendId: (data && data.id) || null, campaign: "reactivation-2026-07" });
          }
        } catch (e) { r.errors++; }
      }
      res.json({ ok: true, mode, result: r });
      return;
    }

    res.status(400).json({ error: "mode must be test | count | all" });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ===== OUTREACH "EVENTI SU INVITO" (B2B) — aggiunto 2026-07-25 =====
const OUTREACH_TOKEN = "iz8Wp4inviteTicketto2026";
const OUTREACH_SUBJECT = "Chi è venuto davvero al vostro ultimo evento su invito?";
const OUTREACH_RECIPIENTS = [
  {
    "name": "Marchetti Eventi",
    "email": "info@marchettieventi.it",
    "evento": "convention aziendali"
  },
  {
    "name": "Ad Mirabilia",
    "email": "welcome@admirabilia.it",
    "evento": "convegni"
  },
  {
    "name": "Eventi di Roma",
    "email": "info@eventidiroma.it",
    "evento": "eventi corporate"
  },
  {
    "name": "NoSilence Eventi",
    "email": "info@nosilence.it",
    "evento": "eventi corporate"
  },
  {
    "name": "Capitaleventi",
    "email": "info@capitaleventi.it",
    "evento": "eventi aziendali e team building"
  },
  {
    "name": "ToGet4U",
    "email": "info@toget4u.com",
    "evento": "eventi corporate"
  },
  {
    "name": "Elastica - Live e Comunicazione",
    "email": "info@elastica.eu",
    "evento": "convention aziendali"
  },
  {
    "name": "G2Pro",
    "email": "info@g2pro.it",
    "evento": "eventi aziendali"
  },
  {
    "name": "Effe Erre Congressi",
    "email": "info@frcongressi.it",
    "evento": "convegni"
  },
  {
    "name": "Studioverde",
    "email": "info@studioverde.it",
    "evento": "eventi aziendali e lanci di prodotto"
  },
  {
    "name": "WAO – We Are Open",
    "email": "hello@waospaces.it",
    "evento": "aperitivi musicali"
  },
  {
    "name": "LVenture Group – The Hub",
    "email": "info@lventuregroup.com",
    "evento": "oltre 300 eventi l'anno sull'innovazione digitale"
  },
  {
    "name": "Nana Bianca",
    "email": "start@nanabianca.it",
    "evento": "demo day dei programmi di accelerazione"
  },
  {
    "name": "Impact Hub Firenze",
    "email": "florence@impacthub.net",
    "evento": "fuckup Nights Firenze"
  },
  {
    "name": "Galleria Raffaella Cortese",
    "email": "galleria@raffaellacortese.com",
    "evento": "vernissage e opening di mostre personali/collettive con collezionisti"
  },
  {
    "name": "Galleria Lia Rumma",
    "email": "info@liarumma.it",
    "evento": "inaugurazioni di mostre di artisti internazionali con inviti a collezi"
  },
  {
    "name": "Galleria d'Arte Marchetti",
    "email": "info@artemarchetti.it",
    "evento": "vernissage e inaugurazioni di mostre in Via Margutta con inviti a clie"
  },
  {
    "name": "Galleria la Nuvola",
    "email": "info@gallerialanuvola.it",
    "evento": "inaugurazioni e vernissage di mostre di arte contemporanea in Via Marg"
  },
  {
    "name": "Luce Gallery",
    "email": "info@lucegallery.com",
    "evento": "opening di mostre di artisti emergenti/internazionali su invito"
  },
  {
    "name": "Gagliardi e Domke Contemporary",
    "email": "info@gagliardiedomke.com",
    "evento": "vernissage e inaugurazioni di mostre di arte contemporanea su invito"
  },
  {
    "name": "LABS Gallery",
    "email": "info@labsgallery.it",
    "evento": "vernissage serali di mostre su invito"
  },
  {
    "name": "Studio Trisorio",
    "email": "info@studiotrisorio.com",
    "evento": "inaugurazioni di mostre di arte contemporanea su invito"
  },
  {
    "name": "Marignana Arte",
    "email": "info@marignanaarte.it",
    "evento": "vernissage e opening di mostre su invito"
  },
  {
    "name": "Galleria Continua",
    "email": "sangimignano@galleriacontinua.com",
    "evento": "grandi inaugurazioni di mostre di artisti internazionali con inviti a"
  },
  {
    "name": "Sa.Mo.Car (Samocar S.p.A.)",
    "email": "info@samocar.it",
    "evento": "eventi Maserati/Ferrari su invito: lanci nuovo modello"
  },
  {
    "name": "Bonaldi - Gruppo Eurocar Italia",
    "email": "vendite.volkswagen@bonaldi.it",
    "evento": "anteprime nuovi modelli e serate clienti per Audi"
  },
  {
    "name": "Minotti Firenze by Belvedere",
    "email": "info@minottifirenze.com",
    "evento": "presentazioni collezione annuale e serate 'Spotlight on Art & Design'"
  },
  {
    "name": "LuisaViaRoma",
    "email": "store@luisaviaroma.com",
    "evento": "eventi moda di alto livello"
  },
  {
    "name": "Cassina Store Milano",
    "email": "showroom@cassina.it",
    "evento": "presentazioni collezione e appuntamenti privati in showroom"
  },
  {
    "name": "BYmyCAR Milano (BMW / MINI)",
    "email": "sales.bmw.zavattini@bymycar.it",
    "evento": "inaugurazioni e anteprime nuovi modelli con clienti"
  },
  {
    "name": "Ineco Auto",
    "email": "verona@inecoauto.it",
    "evento": "'Eventi Ineco' dedicati agli appassionati Ferrari: anteprime e serate"
  },
  {
    "name": "Selezione Auto (Mercedes-Benz Napoli)",
    "email": "reception@selezioneauto.it",
    "evento": "anteprime nuovi modelli Mercedes-Benz e serate clienti in showroom"
  },
  {
    "name": "Rossocorsa Torino",
    "email": "servizioclienti@rossocorsa.it",
    "evento": "anteprime Ferrari/Maserati e serate esclusive per clienti"
  },
  {
    "name": "Gruppo Giovani Imprenditori - Confindustria Emilia Area Centro",
    "email": "info@confindustriaemilia.it",
    "evento": "cene networking"
  },
  {
    "name": "Rotary Club di Milano",
    "email": "segreteria@rotarymilano.it",
    "evento": "riunioni conviviali settimanali su invito"
  },
  {
    "name": "Bologna Business School (BBS)",
    "email": "info@bbs.unibo.it",
    "evento": "open Day master"
  },
  {
    "name": "Generazione Vincente Academy (GEVI Academy)",
    "email": "info@geviacademy.it",
    "evento": "corsi e workshop professionali"
  },
  {
    "name": "Camera di Commercio di Firenze",
    "email": "info@fi.camcom.it",
    "evento": "convegni"
  },
  {
    "name": "ELIS (ELIS Academy / ICT Academy)",
    "email": "promozione@elis.org",
    "evento": "sessioni di presentazione dei percorsi formativi"
  },
  {
    "name": "Gruppo Giovani Imprenditori - Confindustria Canavese",
    "email": "ggi@confindustriacanavese.it",
    "evento": "incontri su cultura d'impresa"
  },
  {
    "name": "Lions Clubs - Distretto 108 Ia1 (Torino)",
    "email": "distretto@lions108ia1.it",
    "evento": "serate conviviali"
  },
  {
    "name": "Rotary Club Gorizia",
    "email": "rotaryclubgorizia@gmail.com",
    "evento": "conviviali settimanali e serate/eventi service del club su invito con"
  },
  {
    "name": "CUOA Business School (Fondazione CUOA)",
    "email": "info@cuoa.it",
    "evento": "open day master/MBA"
  },
  {
    "name": "Nilufar (E. Mangione)",
    "email": "e.mangione@nilufar.com",
    "evento": "mostre e presentazioni di design da collezione"
  },
  {
    "name": "Nilufar (management)",
    "email": "management@nilufar.com",
    "evento": "mostre e presentazioni di design da collezione"
  }
];

function outreachEmailHtml(evento) {
  const ev = (evento && String(evento).trim()) ? String(evento).trim() : "eventi su invito";
  return [
    '<div style="font-family: -apple-system, Segoe UI, Roboto, sans-serif; background:#F4F4F8; padding:24px;">',
    '<div style="max-width:520px; margin:0 auto; background:#ffffff; border-radius:16px; overflow:hidden; border:1px solid #ECECF3;">',
    '<div style="background-color:#0E6B52; padding:28px 32px;">',
    '<img src="https://ticketto.it/images/ticketto_logo_dark.png" alt="Ticketto" height="28" style="height:28px; display:block; border:0;" />',
    '</div>',
    '<div style="padding:32px;">',
    '<p style="font-size:16px; color:#1A1A2E; margin:0 0 16px;">Salve,</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 16px;">vi scrivo perché organizzate ' + ev + ' su invito, e so quanto sia scomodo gestire la lista all’ingresso: chi c’è, chi manca, e a fine serata ricostruire chi è venuto davvero.</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 24px;">Ho creato <strong>Ticketto</strong>, uno strumento semplice per chiudere il cerchio: mandate gli inviti con un link, all’ingresso fate il check-in dal telefono in un secondo, e vi resta la lista dei presenti — pronta da riversare nel vostro CRM per il follow-up.</p>',
    '<div style="text-align:center; margin:0 0 28px;">',
    '<a href="https://ticketto.it" style="display:inline-block; background-color:#9AD530; color:#101410; text-decoration:none; font-weight:700; font-size:16px; padding:14px 32px; border-radius:10px;">Scopri Ticketto →</a>',
    '</div>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 8px;">Se vi fa piacere, ve lo configuro io su un vostro prossimo evento, senza alcun impegno, così lo vedete sul campo.</p>',
    '<p style="font-size:16px; color:#333; margin:24px 0 0;">Un saluto,<br>Fabio — Ticketto</p>',
    '</div>',
    '<div style="padding:20px 32px; border-top:1px solid #ECECF3; background:#FAFAFC;">',
    '<p style="font-size:12px; color:#9A9AAE; margin:0; line-height:1.5;">Ricevete questa email perché organizzate eventi ed è pubblicamente disponibile un vostro contatto. Se non volete più riceverne, <a href="mailto:event@ticketto.it?subject=unsubscribe" style="color:#9A9AAE;">cliccate qui per disiscrivervi</a>.</p>',
    '</div>',
    '</div>',
    '</div>',
  ].join("");
}

exports.sendInviteOutreach = onRequest({ cors: true }, async (req, res) => {
  const token = req.query.token;
  const mode = req.query.mode; // "test" | "count" | "all"
  const to = req.query.to;
  if (token !== OUTREACH_TOKEN) { res.status(403).json({ error: "forbidden" }); return; }

  const resend = new Resend(RESEND_API_KEY);
  const headers = { "List-Unsubscribe": "<mailto:event@ticketto.it?subject=unsubscribe>" };

  try {
    if (mode === "test") {
      if (!to) { res.status(400).json({ error: "missing to" }); return; }
      const { data, error } = await resend.emails.send({
        from: EMAIL_FROM, to: [to], subject: OUTREACH_SUBJECT,
        html: outreachEmailHtml("convention aziendali"), headers,
      });
      res.json({ ok: !error, mode: "test", to, id: data && data.id, error });
      return;
    }

    if (mode === "count" || mode === "all") {
      const r = { total: OUTREACH_RECIPIENTS.length, alreadySent: 0, sent: 0, errors: 0, eligible: 0 };
      for (const p of OUTREACH_RECIPIENTS) {
        if (!p.email || !String(p.email).includes("@")) continue;
        const key = String(p.email).toLowerCase().replace(/[^a-z0-9]/g, "_");
        const logRef = db.collection("invite_outreach_log").doc(key);
        const logDoc = await logRef.get();
        if (logDoc.exists) { r.alreadySent++; continue; }
        r.eligible++;
        if (mode === "count") continue;
        try {
          const { data, error } = await resend.emails.send({
            from: EMAIL_FROM, to: [p.email], subject: OUTREACH_SUBJECT,
            html: outreachEmailHtml(p.evento), headers,
          });
          if (error) { r.errors++; }
          else {
            r.sent++;
            await logRef.set({ email: p.email, name: p.name || null, sentAt: admin.firestore.FieldValue.serverTimestamp(), resendId: (data && data.id) || null, campaign: "invite-outreach-2026-07" });
          }
        } catch (e) { r.errors++; }
      }
      res.json({ ok: true, mode, result: r });
      return;
    }

    res.status(400).json({ error: "mode must be test | count | all" });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── Team Invitation Email Template ──────────────────────────
function buildTeamInviteEmail({ orgName, role, recipientEmail, lang = "it" }) {
  const roleLabels = {
    it: {
      owner: "Proprietario",
      admin: "Amministratore",
      staff: "Staff Check-in",
      viewer: "Visualizzatore",
    },
    en: {
      owner: "Owner",
      admin: "Admin",
      staff: "Check-in Staff",
      viewer: "Viewer",
    },
  };

  const safeLang = SUPPORTED_LANGUAGES.includes(lang) ? lang : "it";
  const roleLabel = (roleLabels[safeLang] && roleLabels[safeLang][role]) || role;
  const isStaff = role === "staff";

  const staffAppSection = isStaff
    ? `
          <!-- Staff App Download Section -->
          <tr>
            <td style="padding: 0 32px 28px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F9FAFB; border-radius: 14px; border: 1px solid #E5E7EB;">
                <tr>
                  <td style="padding: 24px 20px; text-align: center;">
                    <div style="font-size: 28px; margin-bottom: 8px;">📱</div>
                    <h3 style="margin: 0 0 6px 0; font-size: 16px; font-weight: 700; color: #101410;">
                      ${t(safeLang, "email", "checkinAppTitle")}
                    </h3>
                    <p style="margin: 0 0 16px 0; font-size: 13px; color: #4B5563; line-height: 1.5; max-width: 440px; display: inline-block;">
                      ${t(safeLang, "email", "checkinAppDesc")}
                    </p>
                    <div>
                      <a href="https://apps.apple.com/it/app/ticketto/id6759349436" target="_blank" rel="noopener" style="display: inline-block; background-color: #101410; color: #FFFFFF; text-decoration: none; font-size: 13px; font-weight: 600; padding: 10px 18px; border-radius: 8px; margin: 4px 6px;">
                        🍏 App Store
                      </a>
                      <a href="https://play.google.com/store/apps/details?id=com.ticketto.app" target="_blank" rel="noopener" style="display: inline-block; background-color: #101410; color: #FFFFFF; text-decoration: none; font-size: 13px; font-weight: 600; padding: 10px 18px; border-radius: 8px; margin: 4px 6px;">
                        🤖 Google Play
                      </a>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
    `
    : "";

  return `<!DOCTYPE html>
<html lang="${safeLang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${t(safeLang, "email", "teamInviteTitle")}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F3F4F6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F3F4F6; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.06);">
          
          <!-- Header -->
          <tr>
            <td style="background-color: #0E6B52; padding: 36px 32px; text-align: center;">
              <div style="margin-bottom: 20px;">
                <img src="https://ticketto.it/images/ticketto_logo_dark.png" alt="Ticketto" height="28" style="height: 28px; display: inline-block; border: 0;" />
              </div>
              <h1 style="color: #FFFFFF; margin: 0 0 8px 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">
                ${t(safeLang, "email", "teamInviteTitle")}
              </h1>
              <p style="color: rgba(255,255,255,0.9); margin: 0; font-size: 15px;">
                ${t(safeLang, "email", "teamInviteSubtitle", { orgName })}
              </p>
            </td>
          </tr>

          <!-- Body Message -->
          <tr>
            <td style="padding: 32px 32px 20px 32px;">
              <p style="margin: 0; font-size: 16px; color: #101410; line-height: 1.6;">
                ${t(safeLang, "email", "teamInviteBody", { orgName, roleLabel })}
              </p>
            </td>
          </tr>

          <!-- Invite Info Box -->
          <tr>
            <td style="padding: 0 32px 24px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #E8F2EC; border-radius: 12px; border: 1px solid rgba(14, 107, 82, 0.15);">
                <tr>
                  <td style="padding: 18px 22px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 4px 0; color: #0E6B52; font-size: 13px; font-weight: 500;">🏢 ${safeLang === "it" ? "Organizzazione" : "Organization"}</td>
                        <td style="padding: 4px 0; text-align: right; font-weight: 700; font-size: 14px; color: #101410;">${orgName}</td>
                      </tr>
                      <tr>
                        <td style="padding: 4px 0; color: #0E6B52; font-size: 13px; font-weight: 500;">🛡️ ${safeLang === "it" ? "Ruolo assegnato" : "Assigned Role"}</td>
                        <td style="padding: 4px 0; text-align: right; font-weight: 700; font-size: 14px; color: #101410;">${roleLabel}</td>
                      </tr>
                      <tr>
                        <td style="padding: 4px 0; color: #0E6B52; font-size: 13px; font-weight: 500;">✉️ ${safeLang === "it" ? "Email invito" : "Invite Email"}</td>
                        <td style="padding: 4px 0; text-align: right; font-weight: 600; font-size: 13px; color: #4B5563;">${recipientEmail}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Login CTA Button -->
          <tr>
            <td style="padding: 8px 32px 32px 32px; text-align: center;">
              <a href="https://ticketto.it/login" style="display: inline-block; background-color: #9AD530; color: #101410; text-decoration: none; font-weight: 700; font-size: 15px; padding: 14px 36px; border-radius: 10px; letter-spacing: -0.2px;">
                ${t(safeLang, "email", "teamInviteButton")} →
              </a>
            </td>
          </tr>

          ${staffAppSection}

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 32px 32px 32px; text-align: center; border-top: 1px solid #E5E7EB; background-color: #FAFAFA;">
              <p style="margin: 0 0 10px 0; font-size: 12px; color: #6B7280;">
                ${t(safeLang, "email", "sentBy", { orgName })}
              </p>
              <div style="margin: 6px 0 4px 0;">
                <img src="https://ticketto.it/images/ticketto_logo.png" alt="Ticketto" height="18" style="height: 18px; vertical-align: middle; border: 0; display: inline-block;" />
              </div>
              <p style="margin: 4px 0 0 0; font-size: 12px; color: #0E6B52; font-weight: 600;">
                L'invito diventa presenza.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// ─── Shared Helper: Link Pending Invites ─────────────────────
/**
 * Links any pending invitations for the given email to the specified user UID.
 * Updates organizations/{orgId}/members/{uid}, removes the pending invite doc,
 * and updates users/{uid} with organizationIds and activeOrgId.
 *
 * @param {string} email
 * @param {string} uid
 * @returns {Promise<{linkedCount: number, orgIds: string[]}>}
 */
async function linkPendingInvites(email, uid) {
  const emailLower = (email || "").toLowerCase().trim();
  if (!emailLower || !uid) {
    return { linkedCount: 0, orgIds: [] };
  }

  // Query pending invites where email matches and userId is empty string
  const pendingSnap = await db.collectionGroup("members")
    .where("email", "==", emailLower)
    .where("userId", "==", "")
    .get();

  if (pendingSnap.empty) {
    return { linkedCount: 0, orgIds: [] };
  }

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};
  let activeOrgId = userData.activeOrgId;

  let authUser = null;
  try {
    authUser = await admin.auth().getUser(uid);
  } catch (_) {}
  const userDisplayName = (authUser && authUser.displayName) || userData.displayName || null;

  const orgIdsToLink = [];
  const batch = db.batch();

  for (const doc of pendingSnap.docs) {
    const inviteData = doc.data();
    const orgId = inviteData.orgId || doc.ref.parent.parent.id;
    if (!orgId) continue;

    if (!orgIdsToLink.includes(orgId)) {
      orgIdsToLink.push(orgId);
    }

    // 1. Create or update organizations/{orgId}/members/{uid}
    const memberRef = db.collection("organizations").doc(orgId).collection("members").doc(uid);
    batch.set(memberRef, {
      orgId: orgId,
      userId: uid,
      email: emailLower,
      displayName: inviteData.displayName || userDisplayName || null,
      role: inviteData.role || "staff",
      joinedAt: inviteData.joinedAt || admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // 2. Delete the pending invite doc with random ID
    if (doc.id !== uid) {
      batch.delete(doc.ref);
    }
  }

  if (orgIdsToLink.length > 0) {
    // 3. Update users/{uid} with organizationIds and activeOrgId
    const userUpdates = {
      organizationIds: admin.firestore.FieldValue.arrayUnion(...orgIdsToLink),
    };
    if (!activeOrgId) {
      activeOrgId = orgIdsToLink[0];
      userUpdates.activeOrgId = activeOrgId;
    }
    if (!userData.email && emailLower) {
      userUpdates.email = emailLower;
    }
    if (!userData.displayName && userDisplayName) {
      userUpdates.displayName = userDisplayName;
    }
    batch.set(userRef, userUpdates, { merge: true });
  }

  await batch.commit();
  console.log(`🔗 Successfully linked ${orgIdsToLink.length} invites for ${emailLower} (uid=${uid}): orgIds=${orgIdsToLink.join(", ")}`);
  return { linkedCount: orgIdsToLink.length, orgIds: orgIdsToLink };
}

// ─── Trigger: User Registration (Auth onCreate) ───────────────
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  const email = user.email;
  const uid = user.uid;
  if (!email || !uid) return;

  console.log(`👤 New user registered: ${email} (uid=${uid}), checking for pending invites...`);
  try {
    const result = await linkPendingInvites(email, uid);
    if (result.linkedCount > 0) {
      console.log(`🎉 Linked ${result.linkedCount} pending invites for new user ${email}`);
    }
  } catch (err) {
    console.error(`❌ Error linking pending invites for new user ${email}:`, err);
  }
});

// ─── Trigger: Team Member Created (onDocumentCreated) ─────────
exports.onTeamMemberCreated = onDocumentCreated(
  {
    document: "organizations/{orgId}/members/{memberId}",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    if (!data) return;

    // Only process pending invites (where userId is empty string)
    if (data.userId !== "") {
      return;
    }

    const email = (data.email || "").toLowerCase().trim();
    if (!email) {
      console.warn("⚠️ Pending invite without email in", snap.ref.path);
      return;
    }

    const orgId = event.params.orgId;
    const role = data.role || "staff";

    // 1. If user already exists in Firebase Auth, link immediately!
    let existingUser = null;
    try {
      existingUser = await admin.auth().getUserByEmail(email);
    } catch (err) {
      if (err.code !== "auth/user-not-found") {
        console.error("Error looking up user by email:", err);
      }
    }

    if (existingUser && existingUser.uid) {
      console.log(`👤 User already exists for ${email} (uid=${existingUser.uid}), linking immediately...`);
      try {
        await linkPendingInvites(email, existingUser.uid);
      } catch (linkErr) {
        console.error("Error linking pending invites on member creation:", linkErr);
      }
    }

    // 2. Send invitation email via Resend
    try {
      const orgSnap = await db.collection("organizations").doc(orgId).get();
      const orgData = orgSnap.exists ? orgSnap.data() : null;
      const orgName = (orgData && orgData.name) || "Ticketto";
      const lang = orgData?.defaultLanguage || "it";

      const html = buildTeamInviteEmail({
        orgName,
        role,
        recipientEmail: email,
        lang,
      });

      const resend = new Resend(RESEND_API_KEY);
      const emailPayload = {
        from: EMAIL_FROM,
        to: [email],
        subject: t(lang, "email", "teamInviteSubject", { orgName }),
        html: html,
      };

      const organizerEmail = await getOrganizerEmail(orgId, orgData);
      if (organizerEmail) {
        emailPayload.reply_to = [organizerEmail];
      }

      const { data: resendData, error: resendError } = await resend.emails.send(emailPayload);
      if (resendError) {
        console.error(`❌ Errore invio email invito a ${email}:`, resendError);
      } else {
        console.log(`✉️ Email invito inviata con successo a ${email} (resendId=${resendData?.id})`);
      }
    } catch (emailErr) {
      console.error("❌ Exception during team invite email sending:", emailErr);
    }
  }
);

// ─── Callable: Claim Pending Invites ─────────────────────────
exports.claimPendingInvites = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const email = (request.auth.token.email || "").toLowerCase().trim();
  if (!email) {
    return { linkedCount: 0, orgIds: [] };
  }

  const result = await linkPendingInvites(email, request.auth.uid);
  return { success: true, ...result };
});

