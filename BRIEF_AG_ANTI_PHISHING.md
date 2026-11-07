# Prompt per AG — Arginare lo spam/phishing su Ticketto

**Contesto (5 nov 2026).** Due account hanno usato Ticketto per preparare una truffa telefonica
("Your Amazon purchase invoice #3182… call +1 805 284-3248"). Pattern identico tutte e due le volte:

1. signup email+password con dominio usa-e-getta (`litedl.com`, `aiqseo.com`), email **mai verificata**;
2. org + evento creati in meno di 2 minuti dal signup, titolo/descrizione = testo della truffa;
3. evento pubblicato; un terzo account (`mildredfost.e.r4.1489@gmail.com`) ha fatto il test completo:
   evento "Test1" + iscrizione di un indirizzo esterno → **Ticketto ha mandato la mail di conferma**.

Il vettore vero NON è la pagina pubblica (SPA, meta generici, non indicizza il testo): è la
**mail di conferma iscrizione**. Chiunque, senza login, può creare un documento `attendees` per
qualunque `eventId` (regole Firestore) e `onAttendeeCreated` spedisce da `event@ticketto.it` una mail
con il titolo dell'evento nell'oggetto. Con uno script il truffatore manda migliaia di mail di phishing
firmate dal nostro dominio → reputazione del dominio su Resend bruciata e Ticketto in blocklist.
Inoltre `resendAttendeeConfirmation` è un endpoint HTTP **senza auth**: basta un `attendeeId`.

Punti nel codice (repo `eventflow`):
- `firestore.rules` → `match /attendees` (create pubblico senza controllo su evento/status), `match /events`, `match /organizations`
- `functions/index.js:635` `onAttendeeCreated`, `:943` `resendAttendeeConfirmation`
- `lib/features/auth/presentation/providers/auth_providers.dart` (signup: nessun `sendEmailVerification`)
- `lib/features/registration/presentation/screens/public_registration_screen.dart:388` (controllo `published` solo lato client)

Dati: 160 account, 121 Google (già verificati), 39 email+password **tutti non verificati**, tra cui
clienti veri (`info@deveromedicalspa.com`, `depaola.davide@icloud.com`, `marketing@thespa-bergamo.it`).
Quindi: niente blocchi retroattivi secchi, serve grandfathering (punto 4).

---

## Livello 1 — Server, da fare SUBITO (poche righe, nessun impatto sui clienti)

### 1.1 `onAttendeeCreated`: non mandare mail se l'evento non è legittimo
Prima di `resend.emails.send`:
```js
// a) evento deve essere pubblicato e l'org non bloccata
if (eventData.status !== 'published' || orgData?.blocked === true) {
  await event.data.ref.update({ emailSent: false, emailError: 'blocked: event not published or org blocked' });
  return;
}
// b) filtro contenuti sul testo dell'evento (titolo+descrizione+location+nome org)
const text = [eventData.title, eventData.description, eventData.location, orgData?.name].join(' ');
if (looksLikeScam(text)) {
  await db.collection('organizations').doc(attendee.orgId).set({ blocked: true, blockedReason: 'auto:scam-filter', blockedAt: FieldValue.serverTimestamp() }, { merge: true });
  await event.data.ref.update({ emailSent: false, emailError: 'blocked: scam filter' });
  await notifyAdmin('SCAM FILTER', { orgId: attendee.orgId, eventId: attendee.eventId, title: eventData.title });
  return;
}
```
`looksLikeScam(text)`: true se matcha un numero di telefono internazionale (`\+?\d[\d\s().-]{8,}\d`) **insieme** a una
parola della lista `invoice|refund|purchase|paypal|amazon|apple|usd|\$|cancellation|call|support|helpdesk|mcafee|norton|geek squad`,
oppure se titolo o nome org contengono una email o un URL. Tienilo in una costante facilmente aggiornabile.

### 1.2 Rate limit sulle mail di conferma per org (piano Free)
Contatore `organizations/{orgId}/counters/emails` con finestra oraria/giornaliera, stesso meccanismo di
`checkAiRateLimit`. Soglie proposte: Free 60/ora e 200/giorno; Pro/Business 600/ora e 3000/giorno.
Oltre soglia: `emailSent:false`, `emailError:'rate-limited'`, un solo avviso admin. (Devero ha fatto 91 iscritti
in un mese, Davide 106 in tre settimane: nessun cliente vero si avvicina.)

### 1.3 `resendAttendeeConfirmation`: richiedere auth
Accettare solo `Authorization: Bearer <idToken>`, verificare con `admin.auth().verifyIdToken`, controllare che
l'utente sia staff dell'org dell'attendee. Il client Flutter deve mandare il token (come già fa per gli `onCall`).
Alternativa più pulita: trasformarla in `onCall`.

### 1.4 Regole Firestore (deploy solo regole, `firebase deploy --only firestore:rules --project eventflow-3541b`)
```
match /attendees/{attendeeId} {
  allow create: if (isAuth() && isOrgStaff(request.resource.data.orgId))
    || (
      request.resource.data.keys().hasAll(['eventId','orgId','firstName','lastName','email','qrCode','status'])
      && request.resource.data.firstName is string && request.resource.data.firstName.size() <= 80
      && request.resource.data.lastName  is string && request.resource.data.lastName.size()  <= 80
      && request.resource.data.email is string && request.resource.data.email.size() <= 254
      && request.resource.data.email.matches('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$')
      && exists(/databases/$(database)/documents/events/$(request.resource.data.eventId))
      && get(/databases/$(database)/documents/events/$(request.resource.data.eventId)).data.status == 'published'
      && get(/databases/$(database)/documents/events/$(request.resource.data.eventId)).data.orgId == request.resource.data.orgId
    );
}
match /events/{eventId} {
  allow create: if isAuth() && isOrgAdmin(request.resource.data.orgId) && canPublish(request.resource.data);
  allow update: if isAuth() && isOrgStaff(resource.data.orgId) && canPublish(request.resource.data);
}
match /organizations/{orgId} {
  allow create: if isAuth() && request.auth.token.email_verified == true && !isDisposable(request.auth.token.email);
}
// helper: si può pubblicare solo con email verificata (o org con grandfathering) e org non bloccata
function canPublish(data) {
  return data.status != 'published'
    || (
      (request.auth.token.email_verified == true
        || get(/databases/$(database)/documents/organizations/$(data.orgId)).data.trusted == true)
      && get(/databases/$(database)/documents/organizations/$(data.orgId)).data.blocked != true
    );
}
function isDisposable(email) {
  return email.lower().matches('.*@(litedl\\.com|aiqseo\\.com|mailinator\\.com|guerrillamail\\.com|10minutemail\\.com|tempmail\\.com|yopmail\\.com|sharklasers\\.com|trashmail\\.com|temp-mail\\.org|dispostable\\.com|getnada\\.com|mohmal\\.com|emailondeck\\.com)$');
}
```
Nota: `get()` in regole costa letture; sono 2 per iscrizione, accettabile.

## Livello 2 — Signup (Flutter + Auth)

### 2.1 Verifica email obbligatoria per pubblicare
- Dopo `createUserWithEmailAndPassword` → `user.sendEmailVerification()` e banner persistente
  "Verifica l'email per pubblicare eventi" con pulsante "Reinvia".
- Il pulsante **Pubblica** resta disabilitato finché `user.emailVerified` è false (ricarica con `user.reload()`);
  il server lo impone comunque (regola `canPublish`).
- Login Google/Apple: già verificati, nessun attrito (121 utenti su 160).

### 2.2 Grandfathering degli account esistenti
Script one-shot: `trusted: true` su tutte le org che hanno almeno un evento con `attendeesCount >= 1` o un
abbonamento attivo, o create prima del 1° ottobre 2026. In particolare: DEVERO SPA, Depaola.davide, The Spa,
Polilogoi, Bitle, TEST, Apple Review Organization. Nessun cliente vero deve accorgersi del cambio.

### 2.3 Lista domini usa-e-getta
Client: rifiuta al signup i domini della lista (messaggio: "Usa un'email aziendale o personale reale").
Server: la stessa lista nelle regole (sopra). Fonte lista: `disposable-email-domains` su GitHub, prendi i top 500.

## Livello 3 — Protezione anti-script

### 3.1 Firebase App Check (reCAPTCHA v3 / Enterprise) su web
`firebase_app_check` con `ReCaptchaV3Provider` in `main.dart`; attivare enforcement su Firestore e Functions dalla
console. Blocca le scritture dirette da script (il vettore delle iscrizioni di massa) senza captcha visibile.
Prima in modalità "monitor" 1 settimana, poi enforce.

## Livello 4 — Moderazione e kill switch

### 4.1 Campo `blocked` sull'org
- regole: org bloccata → nessuna create/update su events e attendees;
- `public_registration_screen`: se org `blocked` → mostra "Evento non disponibile";
- funzione admin `blockOrganization` (onCall, solo UID di Fabio/sviluppo) che setta `blocked:true`,
  porta gli eventi a `draft` e disabilita l'utente in Auth (`admin.auth().updateUser(uid,{disabled:true})`).

### 4.2 Avviso al primo evento pubblicato
Trigger `onDocumentUpdated('events/{id}')`: quando `status` passa a `published` per un'org Free creata da meno di
7 giorni → mail a `f.gabelli@gmail.com` con titolo, nome org, email utente, minuti dal signup, e due link
"OK" / "BLOCCA" (il secondo chiama `blockOrganization`). Costo zero, dà a Fabio il controllo umano.

### 4.3 Pagina pubblica
Aggiungere `<meta name="robots" content="noindex">` dinamico per eventi di org Free non `trusted`
(oggi il rischio SEO è basso perché la pagina è una SPA con meta generici, ma meglio chiudere).

---

## Ordine consigliato e stima
1. Livello 1 (1.1, 1.2, 1.3, 1.4) + 2.2 grandfathering → **mezza giornata**, chiude il vettore email oggi.
2. Livello 2.1 + 2.3 → 1 giornata (UI + test signup).
3. Livello 4.1 + 4.2 → mezza giornata.
4. Livello 3 App Check → mezza giornata + 1 settimana di monitor.

## Test di accettazione
- Iscrizione via script (curl REST Firestore, non autenticata) a un evento `draft` → **negata** dalle regole.
- Iscrizione a evento `published` con titolo "Your invoice … call +1 …" → documento creato ma **nessuna mail**, org `blocked:true`, avviso admin.
- `resendAttendeeConfirmation?attendeeId=…` senza token → 401.
- Nuovo signup email+password → mail di verifica ricevuta; Pubblica disabilitato finché non verificato; dopo verifica pubblica.
- Signup con `x@mailinator.com` → rifiutato.
- Davide (Google) e Devero (password, `trusted:true`) pubblicano e iscrivono senza alcun cambiamento.
- 70 iscrizioni in un'ora su org Free → la 61ª non manda mail, log `rate-limited`.

## Pulizia già individuata (la fa Claude/Fabio, non serve codice)
- Eventi da cancellare: `HqAv9WgS1IYlj9lcZiGb` (draft, 20/10), `Xjaa3tRmwkKfXCrlMppa` (published, 29/10)
- Org da cancellare: `L0TwfGj4CNE2vFJqj8eI`, `JwMdcxTIlJCyBjcvIlxT`
- Auth da disabilitare: `eltxku01196@aiqseo.com` (uid `wax2Ka0PA8ffNhRbI4IP0QsELLY2`); `xpwluh94785@litedl.com` già disabilitato
- Da tenere d'occhio: `mildredfost.e.r4.1489@gmail.com` (evento "Test1" + iscritto esterno), `rajichan827@gmail.com`, `corpus.au@gmail.com`
