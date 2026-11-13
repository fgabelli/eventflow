# BRIEF PER AG — Email di promemoria e ringraziamento: messaggio personale + ringraziamento sul Pro e automatico

Repo: `/srv/data/progetti/Flutter/eventflow` (branch main). Progetto Firebase: `eventflow-3541b`.
Richiesta di una cliente in prova Pro (org AREL): vuole vedere e personalizzare le email automatiche.

## Situazione attuale (verificata su origin/main)
- `processScheduledEmails` (`functions/index.js` ~3354-3482) gira ogni ora.
- **Promemoria:** parte se `reminderEnabled` è attivo, l'evento è pubblicato e si è a `reminderDaysBefore` giorni dall'evento (1, 3 o 7). Va solo ai confermati. Pro e Business (il Free è saltato, ~3388).
- **Ringraziamento** (~3430-3470) ha tre limiti:
  - parte solo se `status == "completed"`, e nessuno lo imposta in automatico: l'organizzatore deve segnare l'evento come concluso a mano (`event_detail_screen.dart` ~893, `events_screen.dart` ~473);
  - solo per il **Business** (`if (orgPlan !== "business") continue;`);
  - va solo a chi ha fatto check-in. Contiene il link a `https://ticketto.it/feedback/{eventId}`.
- Template fissi: `buildReminderEmail` ~3493 e `buildThankYouEmail` ~3596. Nessun testo personalizzabile e nessuna anteprima.
- UI: sezione "Email automatiche" in `event_detail_screen.dart` ~2261-2330, con interruttori e menu 1/3/7 giorni. **Non ha gating**: un Free può accendere il promemoria e non parte niente, senza nessun avviso.

## Cosa fare

### 1. Ringraziamento anche sul Pro, e automatico
- Il ringraziamento deve partire per i piani **Pro e Business**.
- Deve partire in automatico, senza `status == completed`. Condizioni:
  - `postEventEmailEnabled == true`;
  - `postEventSentAt` vuoto;
  - fine evento (usa la data di fine se esiste, altrimenti data inizio + 3 ore) passata da almeno **12 ore**;
  - `status` pubblicato o completato, mai bozza o annullato.
  Se segnare l'evento come "concluso" a mano resta possibile, va bene lo stesso, ma non deve più essere obbligatorio.
- Attenzione alla query Firestore: con `where("postEventSentAt","==",null)` serve che il campo esista come null. Verifica che gli eventi esistenti lo abbiano, oppure filtra in memoria. Crea gli indici se servono (`firestore.indexes.json`).
- Destinatari: invariati, solo chi ha fatto check-in.
- **Nessun invio retroattivo**: gli eventi già passati da più di 3 giorni al momento del deploy vanno marcati con `postEventSentAt` senza inviare niente. Fallo come guardia nella query, non con uno script a parte.

### 2. Messaggio personale + anteprima
- Su `EventModel` aggiungi `reminderCustomMessage` e `thankYouCustomMessage` (stringhe opzionali, max 1000 caratteri, testo semplice).
- Nella sezione "Email automatiche" (modifica evento, e anche creazione se c'è la sezione) aggiungi per ciascuna email una casella "Messaggio personale (facoltativo)".
- Nelle email il messaggio va in un riquadro dopo il saluto, prima dei dettagli dell'evento. Testo **escapato** (niente HTML iniettabile), a capo convertiti in `<br>`.
- Bottone **"Anteprima"** per ciascuna email: mostra l'HTML vero generato dagli stessi builder. Fai una callable `previewScheduledEmail({eventId, type})` riservata ai membri owner/admin dell'org, con dati di un partecipante finto. Nessun invio.
- Bottone **"Invia una prova a me"**, se è semplice: manda l'email all'utente loggato, con un limite di qualche invio all'ora.

### 3. Gating chiaro nella UI
- Sul Free gli interruttori sono disabilitati, con badge PRO e il testo "Disponibile dal piano Pro".
- Sotto l'interruttore del ringraziamento scrivi quando parte: "Parte da sola il giorno dopo l'evento, a chi ha fatto check-in."

### 4. Stringhe IT/EN.

## Deploy
- Functions: solo quelle toccate, con `firebase deploy --only functions:processScheduledEmails,previewScheduledEmail[,…],firestore:indexes --project eventflow-3541b` (mai senza `--project`).
- Web **solo** con `./deploy_landing.sh --deploy`.
- Commit in stile `feat: ...`.

## Test prima di dire "fatto" (dati veri, non mockup)
1. Org Pro di test, evento finito da più di 12 ore, un partecipante con check-in, ringraziamento acceso. Entro un'ora deve arrivare l'email con il messaggio personale, e sull'evento deve risultare `postEventSentAt`.
2. Lo stesso test su un'org Free: niente invio, e nella UI l'interruttore è disabilitato.
3. Un evento vecchio (più di 3 giorni) con l'interruttore acceso **non** deve inviare niente dopo il deploy.
4. L'anteprima mostra il messaggio personale. Un `<script>` scritto nel messaggio appare come testo.
5. Consegna: commit, function deployate, id dell'evento di test, id dell'email Resend. Io verifico.
