# BRIEF PER AG — Inviti del team: il collegamento non esiste (URGENTE)

Repo: `/srv/data/progetti/Flutter/eventflow` (branch main). Progetto Firebase: `eventflow-3541b`.
Urgenza: una cliente in prova Pro (org AREL, id `WCDQdPMBJgoUSvQealRx`) sta per invitare il suo staff per fare il check-in.

## Il problema (verificato nel codice di origin/main)

1. `lib/features/settings/presentation/screens/team_screen.dart` ~riga 309: "Invita membro" crea `organizations/{orgId}/members/{idCasuale}` con `userId: ''` e il commento `// Will be linked when user accepts`. **Il collegamento non è mai stato scritto.** Nessuna email d'invito parte.
2. `firestore.rules` righe 16-30: il ruolo si legge da `members/{request.auth.uid}`. Il doc dell'invitato ha un id casuale, quindi le regole non lo riconoscono.
3. `users/{uid}.organizationIds` dell'invitato non viene mai aggiornato. L'unico punto che lo scrive è `createOrganization` in `auth_providers.dart:252`. Risultato:
   - web: `app_router.dart:72-80` manda l'invitato su `/create-org`;
   - app check-in `ticketto_checkin`: `login_screen.dart:34-46` lo disconnette perché `organizationIds` è vuoto.
4. `currentRoleProvider` (`auth_providers.dart:44-62`) cerca `where('userId', isEqualTo: uid)`, che con `userId: ''` non trova mai nulla.

**Effetto:** un membro invitato (Staff, Admin o Visualizzatore) non riesce a entrare né sul web né nell'app check-in.

## Cosa fare (lato server, così NON serve una nuova versione dell'app check-in)

### A. Cloud Function `linkPendingInvites(email, uid)`, condivisa tra i punti B, C e D
Va scritta con Admin SDK in `functions/index.js`.
- Usa `collectionGroup('members')` con `where('email', '==', emailLowercase)` e `where('userId', '==', '')`. Crea l'indice se serve, in `firestore.indexes.json`.
- Per ogni invito trovato, in una batch:
  - crea `organizations/{orgId}/members/{uid}` con `{orgId, userId: uid, email, displayName, role, joinedAt}`, tenendo il `role` dell'invito;
  - cancella il doc invito con l'id casuale;
  - fa `users/{uid}` set merge con `organizationIds: arrayUnion(orgId)`. Se `activeOrgId` è vuoto, imposta anche quello.
- Le email vanno salvate e confrontate sempre in **minuscolo**. Correggi anche `team_screen.dart`, che oggi salva l'email così come viene scritta.

### B. Trigger alla registrazione di un nuovo utente
Usa Auth `onCreate` (gen1 `functions.auth.user().onCreate`, oppure `beforeUserCreated` se preferisci). Deve chiamare `linkPendingInvites(user.email, user.uid)`.
⚠️ Controlla come il client crea `users/{uid}` al primo accesso. Se usa `set()` senza merge, può sovrascrivere `organizationIds` scritto dal trigger. In quel caso il client deve usare merge, oppure aggiungere un `arrayUnion` sicuro. Le stesse condizioni valgono per il login Google, Apple ed email/password.

### C. Trigger alla creazione dell'invito
`onDocumentCreated('organizations/{orgId}/members/{memberId}')`: se `userId == ''`, prova `admin.auth().getUserByEmail(email)`. Se l'utente esiste già, collega subito con A.

### D. Callable `claimPendingInvites`, come rete di sicurezza
Prende l'email dal token verificato (`request.auth.token.email`), **mai dal client**, e chiama A. Va chiamata dalla web app subito dopo il login, **prima** del redirect a `/create-org`. Serve per gli utenti che esistevano già e per gli inviti creati prima di questo fix. Gli inviti pendenti oggi presenti nel DB devono collegarsi così.

### E. Email d'invito all'invitato
Usa Resend da `event@ticketto.it`, con lo stesso stile delle email transazionali attuali (brand lime/ink/verde). Parte dal trigger C.
- Testo: "[Nome org] ti ha aggiunto al team su Ticketto come [ruolo]. Accedi con questa email."
- Bottone "Accedi" che porta a https://ticketto.it (login).
- Per il ruolo Staff, aggiungi i link all'app check-in:
  - App Store: https://apps.apple.com/it/app/ticketto/id6759349436
  - Google Play: https://play.google.com/store/apps/details?id=com.ticketto.app
- Versione IT/EN come le altre email.

### F. Schermata Team
- Un invito non ancora accettato deve mostrare il badge "In attesa".
- Deve esserci la possibilità di annullare l'invito.
- Bisogna impedire il doppio invito alla stessa email.

### G. App check-in (solo da verificare, NON fare una nuova build ora)
`events_screen.dart:39-48` usa `organizationIds.first`. Se lo staff appartiene anche a una sua organizzazione, l'app potrebbe aprire quella sbagliata. Segnalalo e proponi la correzione (usare `activeOrgId` o una scelta dell'org) per la prossima versione. Non serve buildare adesso.

## Vincoli
- Non toccare le regole Firestore se non serve. Il ruolo resta su `members/{uid}`, che dopo il fix sarà il doc corretto.
- I deploy si fanno così:
  - Functions **solo** con `firebase deploy --only functions:<nomi>,firestore:indexes --project eventflow-3541b` (mai senza `--project`);
  - web **solo** con `./deploy_landing.sh --deploy`, mai `firebase deploy` diretto sull'hosting.
- Commit in stile conventional (`fix: ...`).

## Test da fare prima di dire "fatto" (con prove reali, non mockup)
1. Org di test: invita come Staff un'email che **non** ha ancora un account. L'email d'invito deve arrivare. Poi registrati con quell'email:
   - sul web non deve comparire `/create-org`, si entra nell'org con il ruolo Staff;
   - nell'app check-in il login va a buon fine, gli eventi dell'org si vedono e il check-in di un partecipante funziona.
2. Ripeti il test con un'email che ha **già** un account Ticketto (con una sua org). Il collegamento deve avvenire senza perdere la sua org.
3. Un utente Visualizzatore **non** deve poter fare il check-in (le regole lo negano).
4. Consegna: elenco dei commit, nomi delle function deployate, path Firestore dei doc `members/{uid}` creati nel test. Io li verifico via REST.
