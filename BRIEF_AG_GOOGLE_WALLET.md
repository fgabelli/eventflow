# Prompt per AG — Sbloccare Google Wallet (accesso in pubblicazione)

**Stato verificato il 2026-11-07** (console Google Pay & Wallet, Merchant BCR2DN5T23V3RLS3, Issuer ID `3388000000023089767`):
- Profilo attività: completato ✅. Richiesta "accesso con diritti di pubblicazione": **In revisione dal 29/8/2026**, ferma.
- Ticket assistenza **[05580142]**: il 31/8 Google (Praneetha, Google Wallet API Support) ha risposto a sviluppo@revan.it / f.gabelli@revan.it:
  > "Upon reviewing your details, we cannot find the pass in the event class. I request you to create at least one pass to proceed further."
  **Nessuno ha mai risposto.** È per questo che è tutto fermo: Google aspetta noi, non il contrario.
- Utenti console: sviluppo@revan.it (admin), fabio.gabelli@bitle.it (admin), `eventflow-3541b@appspot.gserviceaccount.com` (Sviluppatore) ✅ → il service account può chiamare l'API.
- Codice (`functions/index.js:283-427`, `generateGoogleWalletLink`): JWT `savetowallet` con **`genericObjects`** su classe `3388000000023089767.ticketto_demo`, firmato via IAM `signJwt`. Funziona (5 attendee hanno già `googleWalletUrl`, giugno e 29/8). Disattivato con commento a riga ~711 dal commit `dba1859`.

**Perché Google "non trova il pass":** con il flusso JWT `savetowallet` l'oggetto viene creato **solo quando un utente tocca "Aggiungi a Google Wallet"**. Nessuno dei 5 link è stato salvato (o lo è stato da account non tester), quindi nella classe non c'è alcun oggetto e il revisore non ha nulla da guardare. Inoltre la classe `ticketto_demo` potrebbe non esistere affatto lato API (nel JWT non mandiamo `genericClasses`, quindi non viene creata al volo): la tab "Gestisci" della console non mostra nessuna classe.

## Cosa fare (ordine)

### 1. Creare classe e almeno un oggetto **via REST API** (non via JWT)
Script one-shot in `functions/` (es. `setup_google_wallet.mjs`), eseguito con il service account `eventflow-3541b@appspot.gserviceaccount.com` (chiave JSON locale **oppure** `gcloud auth print-access-token --impersonate-service-account=...` con scope `https://www.googleapis.com/auth/wallet_object.issuer`). Non committare chiavi.

```js
// 1a. classe generica "ticketto" (nome definitivo, non "demo")
PUT/POST https://walletobjects.googleapis.com/walletobjects/v1/genericClass
{
  "id": "3388000000023089767.ticketto",
  "classTemplateInfo": { ... opzionale ... },
  "reviewStatus": "UNDER_REVIEW",          // ⬅ necessario per la revisione
  "multipleDevicesAndHoldersAllowedStatus": "MULTIPLE_HOLDERS"
}
// 1b. almeno un oggetto reale nella classe (usa i dati di un evento vero, es. AREL 10/11 o Halloween di Davide)
POST https://walletobjects.googleapis.com/walletobjects/v1/genericObject
{
  "id": "3388000000023089767.review_sample_001",
  "classId": "3388000000023089767.ticketto",
  "state": "ACTIVE",
  "cardTitle": {"defaultValue":{"language":"it","value":"AREL & Friends | Aperitivo a Milano"}},
  "subheader": {"defaultValue":{"language":"it","value":"AREL"}},
  "header": {"defaultValue":{"language":"it","value":"Mario Rossi"}},
  "logo": {"sourceUri":{"uri":"https://ticketto.it/icons/Icon-512.png"}, "contentDescription":{"defaultValue":{"language":"it","value":"Ticketto"}}},
  "barcode": {"type":"QR_CODE","value":"TKT-REVIEW-SAMPLE-001","alternateText":"TKT-REVIEW-SAMPLE-001"},
  "hexBackgroundColor": "#0E6B52",
  "textModulesData": [{"header":"DATA","body":"mar 10 nov 2026 18:30","id":"date"},{"header":"LUOGO","body":"Piccolo Café, Via Rovello 2, Milano","id":"loc"}]
}
// 1c. verifica
GET .../genericClass/3388000000023089767.ticketto
GET .../genericObject?classId=3388000000023089767.ticketto   → deve elencare review_sample_001
```
Se preferisci mantenere l'id `ticketto_demo`, va bene, ma rinominarlo in `ticketto` evita che il revisore legga "demo" e pensi a un test. In quel caso aggiorna `classId` in `generateGoogleWalletLink`.

### 2. Aggiungere account tester (console → API Google Wallet → Gestisci → "Account di test" / Test accounts)
Inserire fabio.gabelli@bitle.it, f.gabelli@gmail.com, sviluppo@revan.it. Finché l'issuer è in demo, solo questi possono salvare il pass. Poi **salvare davvero un pass** da uno di questi account (apri un `googleWalletUrl` esistente o rigenerane uno): così nella classe compare anche un oggetto "vero" salvato da un utente.

### 3. Rispondere al ticket Google (lo manda Fabio da f.gabelli@revan.it, rispondendo alla mail del 31/8 di google-wallet-passes-support@google.com, oggetto "Re: [05580142] Google Wallet API Support Request from Merchant ID: BCR2DN5T23V3RLS3")
Testo pronto (inglese, come il ticket):

> Hello Praneetha,
>
> apologies for the late reply. We have now created the pass class and a sample pass object under Issuer ID 3388000000023089767 so you can review them:
>
> - Class ID: 3388000000023089767.ticketto (Generic pass, reviewStatus UNDER_REVIEW)
> - Object ID: 3388000000023089767.review_sample_001 (state ACTIVE)
>
> Ticketto (ticketto.it) is an event registration and check-in platform used by Italian organizers; the pass is the attendee's ticket with a QR code scanned at the entrance. The pass is generated server-side by our Cloud Function and offered to attendees in the confirmation email via a "Save to Google Wallet" link (JWT, genericObjects).
>
> Could you please proceed with the publishing access review for this issuer? Let us know if you need anything else (screenshots, a test pass link, etc.).
>
> Thank you,
> Fabio Gabelli — Bitle srls / Ticketto

### 4. Dopo l'approvazione (mail di Google "publishing access granted")
- In `onAttendeeCreated` (riga ~711) e in `resendAttendeeConfirmation` riattivare la generazione: togliere il commento, tenere il try/catch non bloccante.
- Rimettere il pulsante "Aggiungi a Google Wallet" nel template email (`googleWalletButton` già tradotto IT/EN).
- Allineare il `classId` nel codice alla classe approvata.
- Test end-to-end: iscrizione a un evento Pro → mail con due pulsanti → salvataggio da un account **non** tester su Android.
- Avvisare Claude per riattivare "Google Wallet" nel copy del sito (`/prezzi/`, feature list), oggi da togliere perché promette una cosa spenta.

## Test di accettazione
- `genericObject.list?classId=…` restituisce ≥ 1 oggetto.
- Console → Gestisci mostra la classe con stato "In revisione".
- Un account tester salva il pass su un telefono Android e lo vede in Google Wallet.
- Ticket 05580142 ha la nostra risposta.
