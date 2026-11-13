# BRIEF PER AG — Email di conferma: sezione Wallet che parli di Apple E Google

Repo: `/srv/data/progetti/Flutter/eventflow` (branch main). Progetto Firebase: `eventflow-3541b`.
Segue il brief BRIEF_AG_GOOGLE_WALLET_ON (commit `adcd9cd`, test Android riuscito il 13/11).

## Problema
Nell'email di conferma (Pro/Business), sotto il QR, c'è il pulsante "🤖 Aggiungi a Google Wallet" e sotto una frase che parla solo di Apple: "🍎 Il file biglietto.pkpass è allegato a questa email — aprilo per aggiungerlo a Apple Wallet" (`functions/index.js` stringhe ~48-49 IT e ~128-129 EN, blocco HTML ~851-861). Chi legge ha l'impressione che il biglietto sia "solo Apple Wallet".

## Cosa fare
1. Sopra il blocco Wallet aggiungi un titoletto: **"Salva il biglietto nel tuo Wallet"** (EN: "Save your ticket to your Wallet"), stesso stile degli altri titoletti dell'email.
2. Due righe, una per telefono, nello stesso stile:
   - **Android:** il pulsante "Aggiungi a Google Wallet" (togli l'emoji 🤖; meglio un testo pulito, oppure il badge ufficiale "Add to Google Wallet" se è semplice e rispetta le linee guida Google).
   - **iPhone:** "Su iPhone apri l'allegato **biglietto.pkpass** per aggiungerlo ad Apple Wallet" (EN: "On iPhone, open the attached **ticket.pkpass** to add it to Apple Wallet"). Togli l'emoji 🍎.
   Correggi anche l'italiano: "ad Apple Wallet", non "a Apple Wallet".
3. Se c'è solo uno dei due (es. Google fallisce, o manca il pkpass), mostra solo la riga presente; se mancano entrambi, niente titoletto.
4. Vale per `onAttendeeCreated` e `resendAttendeeConfirmation` (stesso builder). Il pulsante "Aggiungi al calendario" e il QR non si toccano.
5. Controlla in tutto `functions/index.js` e nell'app Flutter (`lib/`) se ci sono altri testi visibili all'utente che dicono solo "Apple Wallet": se sì, correggili in "Apple Wallet e Google Wallet" (o "Wallet") e scrivimi quali.

## Deploy
Solo `firebase deploy --only functions:onAttendeeCreated,functions:resendAttendeeConfirmation --project eventflow-3541b` (mai senza `--project`). Prima del deploy verifica che `functions/certs/` ci sia. Se tocchi `lib/`, web **solo** con `./deploy_landing.sh --deploy`.
Commit: `fix: confirmation email wallet section mentions both Apple and Google Wallet`.

## Test prima di dire "fatto" (dati veri)
1. Nuova iscrizione di test sull'evento Pro `USBrawg0RX64ChLk6huq` (org TEST) con f.gabelli@gmail.com: l'email mostra il titoletto, il pulsante Google e la riga iPhone; il pulsante Google funziona ancora.
2. Stessa cosa in inglese (evento con lingua EN, o cambia temporaneamente la lingua dell'evento di test).
3. Iscrizione su org Free: nessun blocco Wallet.
4. Consegna: commit, id attendee e id email Resend, screenshot vero dell'email da Gmail.
