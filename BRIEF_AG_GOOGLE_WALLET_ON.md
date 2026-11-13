# BRIEF PER AG — Riattivare Google Wallet (approvato da Google il 10/11)

Repo: `/srv/data/progetti/Flutter/eventflow` (branch main). Progetto Firebase: `eventflow-3541b`.

## Contesto
- Il 10/11/2026 Google Wallet Support (case 05763474, legato a 05580142) ha scritto a f.gabelli@revan.it: "We have approved your Google Wallet API request in the Google Pay & Wallet Console".
  - Issuer: `3388000000023089767`
  - Merchant: `BCR2DN5T23V3RLS3`
  - Classe: `3388000000023089767.ticketto`
- Nel codice Google Wallet è **spento**: `functions/index.js` ~1233-1243, blocco commentato "Temporarily disabled pending Google Wallet publishing approval". `generateGoogleWalletLink` (~342-480) firma un JWT `savetowallet` con il SA `eventflow-3541b@appspot.gserviceaccount.com` tramite IAM Credentials. Il pulsante IT/EN è a ~49 e ~129.
- Da ricordare (esperienza del 7/11): la function gen2 gira come SA compute `289853352690-compute@…`, che ha Token Creator sul SA appspot. Il token del metadata server ha solo lo scope cloud-platform: per la firma va bene (signJwt via IAM), per chiamare la Wallet API REST no.

## Cosa fare
1. **Prima di toccare il codice**, verifica nella console Google Pay & Wallet (o via API con il metodo che ha funzionato il 7/11, generateAccessToken con scope `wallet_object.issuer`) che:
   - l'accesso dell'issuer sia passato a **pubblicazione (publishing access)**;
   - la classe `3388000000023089767.ticketto` sia `APPROVED`. Se risulta ancora `UNDER_REVIEW` o `DRAFT`, scrivimi lo stato esatto e fermati.
2. Togli il commento dal blocco a ~1233-1243, mantenendo il gating **Pro/Business** (`isPaidPlan`) e l'errore non bloccante. Aggiorna il commento ("enabled after Google approval 2026-11-10").
3. Controlla che `buildConfirmationEmail` mostri il pulsante "Aggiungi a Google Wallet" solo quando c'è `googleWalletUrl`, accanto al pass Apple. Il layout non deve rompersi insieme al nuovo pulsante "Aggiungi al calendario".
4. L'oggetto di test `3388000000023089767.review_sample_001` può restare. Il trigger `admin_tasks` deve essere già stato rimosso: se c'è ancora, toglilo.

## Deploy
Solo `firebase deploy --only functions:onAttendeeCreated --project eventflow-3541b` (mai senza `--project`).
⚠️ Prima del deploy verifica che `functions/certs/` (Apple Wallet) sia presente sul server, altrimenti il pkpass si rompe di nuovo come dal 7/11 al 13/11.
Commit: `feat: re-enable Google Wallet pass after Google approval`.

## Test prima di dire "fatto" (dati veri, non mockup)
1. Iscrizione di test a un evento di un'org **Pro**, con un indirizzo Gmail aperto su un **telefono Android**. L'email deve contenere sia "Aggiungi a Google Wallet" sia il pkpass Apple. Toccando il pulsante, il pass si salva in Google Wallet **senza** la scritta "Test only"/"Solo test". Il QR nel pass deve essere lo stesso dell'email e deve passare il check-in con l'app Ticketto.
2. Iscrizione su un'org **Free**: nessun pulsante Google Wallet.
3. Sull'attendee Pro risulta `googleWalletUrl` valorizzato.
4. Consegna: commit, id dell'evento e dell'attendee di test, id dell'email Resend, e uno screenshot **vero** del pass in Google Wallet (foto dal telefono, non mockup).
