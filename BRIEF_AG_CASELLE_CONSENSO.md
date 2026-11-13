# BRIEF PER AG — Caselle "comunicazioni" e "foto/video" disattivabili per evento

Repo: `/srv/data/progetti/Flutter/eventflow` (branch main). Progetto Firebase: `eventflow-3541b`.
Richiesta di una cliente in prova Pro (org AREL). Ha la sua informativa privacy, già inserita come campo checkbox obbligatorio, e vuole togliere le due caselle facoltative di Ticketto, perché coprono cose già presenti nella loro informativa.

## Situazione attuale (verificata su origin/main)
Nel modulo pubblico (`lib/features/registration/presentation/screens/public_registration_screen.dart` ~righe 991-1180):
- la casella Privacy + Termini di Ticketto è obbligatoria. **RESTA SEMPRE, non va toccata**;
- la casella **comunicazioni** (`marketingConsent`) è facoltativa e sempre visibile (~1088);
- la casella **foto/video** (`photoConsent`) è facoltativa e visibile per ogni evento non online (`!event.isOnline`, ~1128).

Il modello `EventModel` (`lib/core/models.dart` ~280-311) non ha impostazioni per queste due caselle.
I consensi si salvano su `attendee.marketingConsent/At` e `photoConsent/At`, sia nel flusso gratuito sia in quello Stripe (`functions/index.js` ~2009-2085, ~2664-2767).

## Cosa fare
1. Su `EventModel` aggiungi due campi, con fromMap, toMap e copyWith:
   - `showMarketingConsent` (bool, **default true**);
   - `showPhotoConsent` (bool, **default true**).
   Gli eventi esistenti senza questi campi devono comportarsi esattamente come oggi.
2. Nella **creazione** e nella **modifica** evento aggiungi due interruttori nella sezione del modulo di iscrizione:
   - "Mostra casella consenso comunicazioni dell'organizzatore";
   - "Mostra casella consenso foto/video" (visibile solo per eventi in presenza).
   Con un testo d'aiuto: "Spegnila se la tua informativa privacy copre già questo consenso."
3. Nella pagina pubblica mostra ciascuna casella solo se il relativo interruttore è acceso. Per foto/video vale anche la condizione attuale `!event.isOnline`.
4. Quando una casella è nascosta, salva il consenso come **assente**, non come rifiutato:
   - `photoConsent: null`;
   - `marketingConsent: false` va bene, ma **aggiungi** `marketingConsentShown: false` sull'attendee, così nell'export si distingue "non chiesto" da "rifiutato".
   Controlla il flusso gratuito, quello Stripe (metadata della sessione) e quello di gruppo.
5. Export CSV ed elenco iscritti: se la casella era nascosta, la colonna resta vuota o "non richiesto", non "No".
6. Nessun gating di piano: gli interruttori valgono per tutti i piani.
7. IT/EN nelle stringhe nuove.

## Deploy
Web **solo** con `./deploy_landing.sh --deploy`. Se tocchi `functions/index.js`, deploya solo le function modificate con `firebase deploy --only functions:<nomi> --project eventflow-3541b` (mai senza `--project`). Commit in stile `feat: ...`.

## Test prima di dire "fatto" (con l'app vera, non mockup)
1. Evento di test in presenza con entrambi gli interruttori spenti. La pagina `/register/<id>` mostra solo Privacy+Termini di Ticketto e gli eventuali campi personalizzati.
2. Iscrizione gratuita su quell'evento. Sull'attendee: `photoConsent` null e `marketingConsentShown` false.
3. Un evento esistente non toccato mostra ancora entrambe le caselle, come oggi.
4. Consegna: commit, function deployate se ce ne sono, id dell'evento di test. Io verifico via REST.
