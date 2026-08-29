const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const admin = require("firebase-admin");
const { Resend } = require("resend");
const { PKPass } = require("passkit-generator");
const path = require("path");
const fs = require("fs");

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
      confirmationTitle: '🎫 Registrazione Confermata',
      confirmationSubtitle: 'Il tuo posto è stato riservato',
      greeting: 'Ciao <strong>{{firstName}}</strong>,',
      confirmationBody: 'La tua registrazione per <strong style="color: #1A1A2E;">{{eventTitle}}</strong> è stata confermata. Ecco i tuoi dettagli:',
      dateLabel: '📅 Data',
      timeLabel: '🕐 Ora',
      locationLabel: '📍 Luogo',
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
      // Organizer notification
      orgNotificationSubject: '🔔 Nuova Iscrizione - {{eventTitle}}',
      orgNotificationTitle: 'Nuova Iscrizione: {{eventTitle}}',
      orgNotificationName: 'Nome',
      orgNotificationEmail: 'Email',
      orgNotificationRegisteredAt: 'Registrato il',
      orgNotificationViewEvent: 'Visualizza Evento',
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
      confirmationTitle: '🎫 Registration Confirmed',
      confirmationSubtitle: 'Your spot has been reserved',
      greeting: 'Hi <strong>{{firstName}}</strong>,',
      confirmationBody: 'Your registration for <strong style="color: #1A1A2E;">{{eventTitle}}</strong> has been confirmed. Here are your details:',
      dateLabel: '📅 Date',
      timeLabel: '🕐 Time',
      locationLabel: '📍 Venue',
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
      // Organizer notification
      orgNotificationSubject: '🔔 New Registration - {{eventTitle}}',
      orgNotificationTitle: 'New Registration: {{eventTitle}}',
      orgNotificationName: 'Name',
      orgNotificationEmail: 'Email',
      orgNotificationRegisteredAt: 'Registered on',
      orgNotificationViewEvent: 'View Event',
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

    const classId = `${GOOGLE_WALLET_ISSUER_ID}.ticketto_demo`;
    const objectId = `${GOOGLE_WALLET_ISSUER_ID}.ticket_${attendeeIdSafe}`;

    const eventTitle = eventData.title || "Evento Ticketto";
    const issuerName = orgData?.name || "Ticketto";
    const attendeeFullName = `${attendee.firstName || ""} ${attendee.lastName || ""}`.trim() || attendee.email || "Partecipante";
    const primaryColor = eventData.primaryColor && /^#[0-9A-Fa-f]{6}$/.test(eventData.primaryColor)
      ? eventData.primaryColor
      : "#6366F1";

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

// ─── Email Template ──────────────────────────────────────────
function buildConfirmationEmail(attendee, event, org, timeSlot, walletPassUrl, googleWalletUrl, lang = 'it') {
  const locale = getDateLocale(lang);
  const eventDate = event.date?.toDate
    ? event.date.toDate()
    : new Date(event.date);
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
  if (event.isOnline && event.meetingUrl) {
    locationHtml = `<tr>
        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'onlineEventLabel')}</td>
        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #6366F1;">
          <a href="${event.meetingUrl}" style="color: #6366F1; text-decoration: none;">${t(lang, 'email', 'joinStreamLabel')}</a>
        </td>
      </tr>`;
  } else if (event.location) {
    locationHtml = `<tr>
        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'locationLabel')}</td>
        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">${event.location}</td>
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
            <td style="background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 50%, #A78BFA 100%); padding: 40px 32px; text-align: center;">
              <h1 style="color: #FFFFFF; margin: 0 0 8px 0; font-size: 26px; font-weight: 700; letter-spacing: -0.5px;">${t(lang, 'email', 'confirmationTitle')}</h1>
              <p style="color: rgba(255,255,255,0.85); margin: 0; font-size: 15px;">${t(lang, 'email', 'confirmationSubtitle')}</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 32px 32px 16px 32px;">
              <p style="margin: 0; font-size: 16px; color: #374151;">
                ${t(lang, 'email', 'greeting', { firstName: attendee.firstName })}
              </p>
              <p style="margin: 8px 0 0 0; font-size: 15px; color: #6B7280; line-height: 1.6;">
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

          <!-- QR Code -->
          <tr>
            <td style="padding: 24px 32px; text-align: center;">
              <p style="margin: 0 0 16px 0; font-size: 14px; font-weight: 600; color: #374151;">${t(lang, 'email', 'qrTitle')}</p>
              <div style="display: inline-block; background: #FFFFFF; border: 2px solid #E5E7EB; border-radius: 16px; padding: 20px;">
                <img src="${qrCodeUrl}" alt="QR Code" width="200" height="200" style="display: block;" />
              </div>
              <p style="margin: 12px 0 0 0; font-size: 12px; color: #9CA3AF;">${t(lang, 'email', 'qrHint')}</p>
            </td>
          </tr>

          <!-- Wallet Buttons -->
          ${(walletPassUrl || googleWalletUrl) ? `
          <tr>
            <td style="padding: 0 32px 24px 32px; text-align: center;">
              ${walletPassUrl ? `<p style="margin: 0 0 8px 0; font-size: 13px; color: #6B7280;">${t(lang, 'email', 'appleWalletHint')}</p>` : ""}
              ${googleWalletUrl ? `<a href="${googleWalletUrl}" style="display: inline-block; background-color: #4285F4; color: #FFFFFF; text-decoration: none; padding: 12px 24px; border-radius: 12px; font-size: 14px; font-weight: 600; margin: 4px;">
                ${t(lang, 'email', 'googleWalletButton')}
              </a>` : ""}
            </td>
          </tr>
          ` : ""}

          <!-- Attendee Info -->
          <tr>
            <td style="padding: 0 32px 24px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #EEF2FF; border-radius: 12px;">
                <tr>
                  <td style="padding: 16px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="font-size: 13px; color: #6366F1;">👤 ${attendee.firstName} ${attendee.lastName}</td>
                        <td style="font-size: 13px; color: #6366F1; text-align: right;">✉️ ${attendee.email}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 20px 32px 32px 32px; text-align: center; border-top: 1px solid #E5E7EB;">
              <p style="margin: 0; font-size: 12px; color: #9CA3AF;">
                ${t(lang, 'email', 'sentBy', { orgName: org?.name || "Ticketto" })}
              </p>
              <p style="margin: 4px 0 0 0; font-size: 11px; color: #D1D5DB;">
                Powered by Ticketto
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

      // Fetch org data
      let orgData = null;
      if (attendee.orgId) {
        const orgDoc = await db.collection("organizations").doc(attendee.orgId).get();
        if (orgDoc.exists) orgData = orgDoc.data();
      }

      // Wallet passes are only generated for Pro/Business plans
      const orgPlan = orgData?.plan || "free";
      const isPaidPlan = orgPlan !== "free";

      // Plan limit warning (telemetry only, does not block)
      const planLimit = PLAN_ATTENDEE_LIMITS[orgPlan] || 50;
      if (planLimit > 0 && currentCount > planLimit) {
        console.warn(`⚠️ PLAN LIMIT EXCEEDED: org=${attendee.orgId} plan=${orgPlan} limit=${planLimit} current=${currentCount} event=${attendee.eventId}`);
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

      // Generate Google Wallet link (Pro/Business only)
      let googleWalletUrl = null;
      if (isPaidPlan) {
        try {
          googleWalletUrl = await generateGoogleWalletLink(attendee, eventData, orgData, event.data.id, lang);
        } catch (walletErr) {
          console.warn("⚠️ Google Wallet link generation failed (non-blocking):", walletErr.message);
        }
      }

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

      // Attach Apple Wallet pass directly to email (paid plans only)
      if (applePassBuffer) {
        emailPayload.attachments = [{
          filename: t(lang, 'email', 'passFilename'),
          content: applePassBuffer.toString("base64"),
          content_type: "application/vnd.apple.pkpass",
        }];
      }

      const { data, error } = await resend.emails.send(emailPayload);

      if (error) {
        throw new Error(JSON.stringify(error));
      }

      console.log(`✅ Email sent to ${attendee.email} for "${eventData.title}" | Resend ID: ${data.id} | Plan: ${orgPlan}`);

      // Notify organizer on new registration (paid plans only)
      if (eventData.notifyOrganizerOnNewRegistration && isPaidPlan && orgData?.email) {
        try {
          // Detect organizer language preference
          let orgLang = "it";
          try {
            const userQuery = await db.collection("users").where("email", "==", orgData.email).limit(1).get();
            if (!userQuery.empty) {
              orgLang = userQuery.docs[0].data().uiLanguage || "it";
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
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
              <h2 style="color: #2b5cff;">${t(orgLang, 'email', 'orgNotificationTitle', { eventTitle: eventData.title })}</h2>
              <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-top: 20px;">
                <p style="margin: 0 0 10px 0;"><strong>${t(orgLang, 'email', 'orgNotificationName')}:</strong> ${attendee.firstName} ${attendee.lastName}</p>
                <p style="margin: 0 0 10px 0;"><strong>${t(orgLang, 'email', 'orgNotificationEmail')}:</strong> <a href="mailto:${attendee.email}">${attendee.email}</a></p>
                <p style="margin: 0;"><strong>${t(orgLang, 'email', 'orgNotificationRegisteredAt')}:</strong> ${registeredAtStr}</p>
              </div>
              <div style="margin-top: 30px; text-align: center;">
                <a href="https://ticketto.it/events/${event.data.id}" style="background-color: #2b5cff; color: white; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: bold; display: inline-block;">${t(orgLang, 'email', 'orgNotificationViewEvent')}</a>
              </div>
            </div>
          `;
          
          await resend.emails.send({
            from: EMAIL_FROM,
            to: [orgData.email],
            subject: t(orgLang, 'email', 'orgNotificationSubject', { eventTitle: eventData.title }),
            html: orgHtml,
          });
          console.log(`🔔 Notified organizer ${orgData.email} of new registration in language: ${orgLang}`);
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
          <div style="font-family: sans-serif; padding: 40px; text-align: center; background: linear-gradient(135deg, #6366F1, #8B5CF6); border-radius: 16px; margin: 20px;">
            <h1 style="color: white; margin: 0 0 12px 0;">🎫 Configurazione OK!</h1>
            <p style="color: rgba(255,255,255,0.85); margin: 0;">Le email di Ticketto funzionano correttamente.</p>
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

// ═══════════════════════════════════════════════════════════════
// ─── STRIPE SUBSCRIPTION MANAGEMENT ──────────────────────────
// ═══════════════════════════════════════════════════════════════

const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

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
        customer_email: sessionData.email,
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

          // ─── Ticket Payment (Stripe Connect) ───
          if (paymentType === "ticket_payment") {
            const eventId = session.metadata.event_id;
            const orgId = session.metadata.org_id;
            const slotId = session.metadata.slot_id || null;
            const pendingRegId = session.metadata.pending_registration_id;
            const { v4: uuidv4 } = require("uuid");

            // ─── Group registration (from pending_registrations) ───
            if (pendingRegId) {
              const pendingDoc = await db.collection("pending_registrations").doc(pendingRegId).get();
              if (pendingDoc.exists) {
                const pending = pendingDoc.data();
                const allAttendees = [pending.primaryAttendee, ...(pending.extraAttendees || [])];
                const perPersonAmount = session.amount_total / allAttendees.length / 100;

                for (const att of allAttendees) {
                  if (!att.email) continue;
                  const email = att.email.toLowerCase();
                  const docId = `${eventId}_${Math.abs(hashCode(email))}`;
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
                    paymentStatus: "paid",
                    paymentId: session.payment_intent,
                    paymentAmount: perPersonAmount,
                    registeredAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                }

                // Cleanup pending registration
                await db.collection("pending_registrations").doc(pendingRegId).delete();
                console.log(`🎫 Group ticket payment completed: event=${eventId} count=${allAttendees.length}`);
              }
              break;
            }

            // ─── Single registration (legacy / no pending) ───
            const attendeeData = JSON.parse(session.metadata.attendee_data || "{}");

            if (eventId && attendeeData.email) {
              const email = attendeeData.email.toLowerCase();
              const docId = `${eventId}_${Math.abs(hashCode(email))}`;
              const qrCode = uuidv4();

              // Create attendee
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
                paymentStatus: "paid",
                paymentId: session.payment_intent,
                paymentAmount: session.amount_total / 100,
                registeredAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              console.log(`🎫 Ticket payment completed: event=${eventId} attendee=${email}`);
            }
            break;
          }

          // ─── Subscription Payment ───
          const orgId = session.metadata?.orgId;
          const plan = session.metadata?.plan;

          if (orgId && plan) {
            await db.collection("organizations").doc(orgId).update({
              plan: plan,
              stripeCustomerId: session.customer,
              stripeSubscriptionId: session.subscription,
              subscriptionStatus: "active",
              subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Save subscription details
            await db.collection("subscriptions").doc(orgId).set({
              orgId: orgId,
              plan: plan,
              stripeCustomerId: session.customer,
              stripeSubscriptionId: session.subscription,
              status: "active",
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`✅ Subscription activated: org=${orgId} plan=${plan}`);
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
// ─── STRIPE CONNECT (Ticket Payments) ────────────────────────
// ═══════════════════════════════════════════════════════════════

const PLATFORM_FEE_PERCENT = 5; // 5% platform commission

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

// ─── Create Stripe Connect Express Account ──────────────────
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
      if (orgDoc.exists && orgDoc.data().stripeConnectAccountId) {
        const accountLink = await stripe.accountLinks.create({
          account: orgDoc.data().stripeConnectAccountId,
          refresh_url: `https://ticketto.it/settings?stripe=refresh`,
          return_url: `https://ticketto.it/settings?stripe=success`,
          type: "account_onboarding",
        });
        res.json({ url: accountLink.url, accountId: orgDoc.data().stripeConnectAccountId });
        return;
      }

      // Create Express account
      const account = await stripe.accounts.create({
        type: "express",
        email: email || undefined,
        business_profile: {
          name: orgName || undefined,
          product_description: "Event ticket sales via Ticketto",
        },
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        metadata: { orgId: orgId },
      });

      // Save account ID to organization
      await db.collection("organizations").doc(orgId).update({
        stripeConnectAccountId: account.id,
        stripeConnectStatus: "pending",
      });

      // Create onboarding link
      const accountLink = await stripe.accountLinks.create({
        account: account.id,
        refresh_url: `https://ticketto.it/settings?stripe=refresh`,
        return_url: `https://ticketto.it/settings?stripe=success`,
        type: "account_onboarding",
      });

      console.log(`🔗 Connect account created: org=${orgId} account=${account.id}`);
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
      const accountId = orgDoc.data()?.stripeConnectAccountId;

      if (!accountId) {
        res.status(400).json({ error: "No Stripe Connect account found" });
        return;
      }

      if (type === "dashboard") {
        const loginLink = await stripe.accounts.createLoginLink(accountId);
        res.json({ url: loginLink.url });
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
      res.status(500).json({ error: error.message });
    }
  }
);

// ─── Create Ticket Payment Checkout Session ─────────────────
exports.createTicketCheckout = onRequest(
  { cors: true },
  async (req, res) => {
    const {
      eventId, orgId, eventTitle, price,
      firstName, lastName, email, phone,
      slotId, customData,
      quantity, extraAttendees,
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

      if (!connectedAccountId) {
        res.status(400).json({ error: "Organizer has not connected Stripe" });
        return;
      }

      // ─── Plan check: Free plan cannot sell tickets ───
      const orgPlan = orgData?.plan || "free";
      if (orgPlan === "free") {
        res.status(403).json({ error: "Gli eventi a pagamento richiedono un piano Pro o Business." });
        return;
      }

      // Check account status
      const account = await stripe.accounts.retrieve(connectedAccountId);
      if (!account.charges_enabled) {
        res.status(400).json({ error: "Organizer Stripe account is not yet active" });
        return;
      }

      // Get event language for Stripe descriptions
      const eventDoc = await db.collection("events").doc(eventId).get();
      const lang = eventDoc.exists ? getEventLang(eventDoc.data()) : 'it';

      const ticketQuantity = Math.min(Math.max(parseInt(quantity) || 1, 1), 10);
      const amountCents = Math.round(price * 100);
      const totalAmountCents = amountCents * ticketQuantity;
      const platformFee = Math.round(totalAmountCents * PLATFORM_FEE_PERCENT / 100);

      // For group registrations, save pending data to Firestore
      // (Stripe metadata has 500 char limit per value)
      let pendingRegId = null;
      if (ticketQuantity > 1 && extraAttendees && extraAttendees.length > 0) {
        const pendingRef = db.collection("pending_registrations").doc();
        pendingRegId = pendingRef.id;
        await pendingRef.set({
          eventId,
          orgId,
          slotId: slotId || null,
          customData: customData || {},
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

      const session = await stripe.checkout.sessions.create({
        mode: "payment",
        payment_method_types: ["card"],
        line_items: [
          {
            price_data: {
              currency: "eur",
              unit_amount: amountCents,
              product_data: {
                name: t(lang, 'stripe', 'ticketProduct', { eventTitle: eventTitle || "Event Ticket" }),
                description: ticketQuantity > 1
                  ? t(lang, 'stripe', 'ticketDescriptionMultiple', { quantity: ticketQuantity, eventTitle })
                  : t(lang, 'stripe', 'ticketDescriptionSingle', { eventTitle }),
              },
            },
            quantity: ticketQuantity,
          },
        ],
        payment_intent_data: {
          application_fee_amount: platformFee,
          transfer_data: {
            destination: connectedAccountId,
          },
        },
        customer_email: email,
        success_url: `https://ticketto.it/register/${eventId}?payment=success&session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `https://ticketto.it/register/${eventId}?payment=cancelled`,
        metadata: {
          payment_type: "ticket_payment",
          event_id: eventId,
          org_id: orgId,
          slot_id: slotId || "",
          quantity: String(ticketQuantity),
          pending_registration_id: pendingRegId || "",
          attendee_data: pendingRegId ? "{}" : JSON.stringify({
            firstName, lastName, email, phone,
            customData: customData || {},
          }),
        },
      });

      console.log(`💳 Ticket checkout: event=${eventId} qty=${ticketQuantity} amount=€${(totalAmountCents / 100).toFixed(2)} fee=€${(platformFee / 100).toFixed(2)}`);
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

    try {
      // ─── 1. REMINDER EMAILS (Pro + Business) ────────────────────
      const reminderEvents = await db.collection("events")
        .where("reminderEnabled", "==", true)
        .where("reminderSentAt", "==", null)
        .where("status", "==", "published")
        .get();

      for (const eventDoc of reminderEvents.docs) {
        const eventData = eventDoc.data();
        const lang = getEventLang(eventData);
        const eventDate = eventData.date?.toDate ? eventData.date.toDate() : new Date(eventData.date);
        const daysBefore = eventData.reminderDaysBefore || 1;
        const reminderDate = new Date(eventDate);
        reminderDate.setDate(reminderDate.getDate() - daysBefore);

        // Check if it's time to send (reminder date has passed but event hasn't)
        if (now >= reminderDate && now < eventDate) {
          // Check org plan
          const orgDoc = await db.collection("organizations").doc(eventData.orgId).get();
          const orgPlan = orgDoc.exists ? (orgDoc.data().plan || "free") : "free";
          if (orgPlan === "free") continue;

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
              await resend.emails.send(payload);
              remindersSent++;
            } catch (emailErr) {
              console.error(`❌ Reminder email failed for ${att.email}:`, emailErr.message);
            }
          }

          await eventDoc.ref.update({ reminderSentAt: admin.firestore.FieldValue.serverTimestamp() });
          console.log(`✅ Reminder sent for "${eventData.title}" to ${attendees.size} attendees`);
        }
      }

      // ─── 2. POST-EVENT THANK YOU (Business only) ────────────────
      const completedEvents = await db.collection("events")
        .where("postEventEmailEnabled", "==", true)
        .where("postEventSentAt", "==", null)
        .where("status", "==", "completed")
        .get();

      for (const eventDoc of completedEvents.docs) {
        const eventData = eventDoc.data();
        const lang = getEventLang(eventData);

        // Check org plan (Business only)
        const orgDoc = await db.collection("organizations").doc(eventData.orgId).get();
        const orgPlan = orgDoc.exists ? (orgDoc.data().plan || "free") : "free";
        if (orgPlan !== "business") continue;

        const orgData = orgDoc.exists ? orgDoc.data() : null;

        // Get all attendees who checked in
        const attendees = await db.collection("attendees")
          .where("eventId", "==", eventDoc.id)
          .where("checkInStatus", "==", "checkedIn")
          .get();

        if (attendees.empty) {
          await eventDoc.ref.update({ postEventSentAt: admin.firestore.FieldValue.serverTimestamp() });
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
            await resend.emails.send(payload);
            thankYouSent++;
          } catch (emailErr) {
            console.error(`❌ Thank you email failed for ${att.email}:`, emailErr.message);
          }
        }

        await eventDoc.ref.update({ postEventSentAt: admin.firestore.FieldValue.serverTimestamp() });
        console.log(`✅ Thank you sent for "${eventData.title}" to ${attendees.size} attendees`);
      }

      console.log(`📬 Scheduled emails done: ${remindersSent} reminders, ${thankYouSent} thank you emails`);
    } catch (error) {
      console.error("❌ Scheduled emails processing error:", error);
    }
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

  const locationHtml = event.location
    ? `<tr>
        <td style="padding: 8px 0; color: #6B7280; font-size: 14px;">${t(lang, 'email', 'locationLabel')}</td>
        <td style="padding: 8px 0; text-align: right; font-weight: 600; font-size: 14px; color: #1A1A2E;">${event.location}</td>
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
                ${t(lang, 'email', 'greeting', { firstName: attendee.firstName })}
              </p>
              <p style="margin: 8px 0 0 0; font-size: 15px; color: #6B7280; line-height: 1.6;">
                ${t(lang, 'email', 'reminderBody', { eventTitle: event.title })}
              </p>
            </td>
          </tr>

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
                ${t(lang, 'email', 'sentBy', { orgName: org?.name || "Ticketto" })}
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
                ${t(lang, 'email', 'greeting', { firstName: attendee.firstName })}
              </p>
              <p style="margin: 8px 0 0 0; font-size: 15px; color: #6B7280; line-height: 1.6;">
                ${t(lang, 'email', 'thankYouBody', { eventTitle: event.title, formattedDate: formattedDate })}
              </p>
            </td>
          </tr>

          <!-- Feedback CTA -->
          <tr>
            <td style="padding: 8px 32px 32px 32px; text-align: center;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F0FDF4; border-radius: 12px; border: 1px solid #BBF7D0;">
                <tr>
                  <td style="padding: 24px;">
                    <p style="margin: 0 0 4px 0; font-size: 16px; font-weight: 600; color: #374151;">${t(lang, 'email', 'feedbackTitle')}</p>
                    <p style="margin: 0 0 16px 0; font-size: 14px; color: #6B7280;">${t(lang, 'email', 'feedbackBody')}</p>
                    <a href="${feedbackUrl}" style="display: inline-block; background: linear-gradient(135deg, #10B981, #059669); color: #FFFFFF; padding: 12px 32px; border-radius: 8px; font-size: 14px; font-weight: 600; text-decoration: none;">${t(lang, 'email', 'feedbackButton')}</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 20px 32px 32px 32px; text-align: center; border-top: 1px solid #E5E7EB;">
              <p style="margin: 0; font-size: 12px; color: #9CA3AF;">
                ${t(lang, 'email', 'sentBy', { orgName: org?.name || "Ticketto" })}
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
    '<div style="background:linear-gradient(135deg,#6366F1,#8B5CF6); padding:28px 32px;">',
    '<span style="color:#fff; font-size:20px; font-weight:700;">🎫 Ticketto</span>',
    '</div>',
    '<div style="padding:32px;">',
    '<p style="font-size:16px; color:#1A1A2E; margin:0 0 16px;">Ciao <strong>' + n + '</strong>,</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 16px;">hai creato il tuo account Ticketto ma non hai ancora lanciato il tuo primo evento.</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 24px;">Ci vogliono davvero <strong>2 minuti</strong>: dai un nome, scegli i posti, e ottieni un link da condividere. Le iscrizioni arrivano da sole — niente chat infinite, niente fogli Excel da aggiornare a mano.</p>',
    '<div style="text-align:center; margin:0 0 28px;">',
    '<a href="' + REACTIVATION_CTA_URL + '" style="display:inline-block; background:#6366F1; color:#fff; text-decoration:none; font-weight:600; font-size:16px; padding:14px 32px; border-radius:10px;">Crea il tuo evento →</a>',
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
    '<div style="background:linear-gradient(135deg,#6366F1,#8B5CF6); padding:28px 32px;">',
    '<span style="color:#fff; font-size:20px; font-weight:700;">🎫 Ticketto</span>',
    '</div>',
    '<div style="padding:32px;">',
    '<p style="font-size:16px; color:#1A1A2E; margin:0 0 16px;">Salve,</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 16px;">vi scrivo perché organizzate ' + ev + ' su invito, e so quanto sia scomodo gestire la lista all’ingresso: chi c’è, chi manca, e a fine serata ricostruire chi è venuto davvero.</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 24px;">Ho creato <strong>Ticketto</strong>, uno strumento semplice per chiudere il cerchio: mandate gli inviti con un link, all’ingresso fate il check-in dal telefono in un secondo, e vi resta la lista dei presenti — pronta da riversare nel vostro CRM per il follow-up.</p>',
    '<div style="text-align:center; margin:0 0 28px;">',
    '<a href="https://ticketto.it" style="display:inline-block; background:#6366F1; color:#fff; text-decoration:none; font-weight:600; font-size:16px; padding:14px 32px; border-radius:10px;">Scopri Ticketto →</a>',
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
