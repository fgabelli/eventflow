# BRIEF PER AG — Email di conferma: "Aggiungi al calendario" al posto di "Visualizza il tuo invito"

Repo: `/srv/data/progetti/Flutter/eventflow` (branch main). Progetto Firebase: `eventflow-3541b`.
Segnalazione di una cliente in prova Pro (org AREL): il pulsante "Visualizza il tuo invito" non funziona, e chiede "Aggiungi al calendario".

## Situazione attuale (verificata su origin/main)
- Il pulsante "Visualizza il tuo invito" è `<a href="#ticketto-invite">` (`functions/index.js` ~576). Punta al QR nella stessa email (`<td id="ticketto-invite">` ~584). Le etichette sono a ~33 (IT) e ~101 (EN). Gmail e la maggior parte dei client ignorano le ancore, quindi il pulsante non fa niente.
- Nessun "Aggiungi al calendario": nessun .ics e nessun link a Google Calendar. L'unico allegato è il pkpass Apple Wallet (Pro+, ~1009-1016).

## Cosa fare (in `onAttendeeCreated` e nel builder dell'email di conferma)
1. **Togli** il pulsante "Visualizza il tuo invito" (IT/EN). Il QR resta dov'è.
2. Al suo posto metti il pulsante **"Aggiungi al calendario"** (EN: "Add to calendar"), che apre Google Calendar:
   `https://calendar.google.com/calendar/render?action=TEMPLATE&text=…&dates=YYYYMMDDTHHMMSSZ/YYYYMMDDTHHMMSSZ&details=…&location=…`
   - date in UTC (`Z`), calcolate correttamente dall'orario Europe/Rome;
   - fine = data di fine evento se esiste, altrimenti inizio + 2 ore;
   - `details` = una breve descrizione + "Il tuo QR di ingresso è nell'email di conferma";
   - `location` = indirizzo; per gli eventi online, il `meetingUrl`.
   Tutto URL-encoded.
3. Sotto il pulsante un link testuale più piccolo: **"Apple / Outlook (.ics)"**.
4. **Allega un file `.ics`** (`evento.ics`, `text/calendar; method=PUBLISH`) all'email di conferma, su **tutti i piani** (Free incluso):
   - `VEVENT` con `UID` stabile (`<attendeeId>@ticketto.it`), `DTSTAMP`, `DTSTART` e `DTEND` in UTC, `SUMMARY`, `LOCATION`, `DESCRIPTION`, `URL` della pagina evento;
   - un `VALARM` 1 ora prima;
   - escaping RFC 5545 (virgole, punto e virgola, a capo) e righe spezzate a 75 caratteri.
   Gmail, Apple Mail e Outlook mostrano già "Aggiungi al calendario" quando c'è l'allegato .ics. Il link testuale del punto 3 può puntare a una URL pubblica che restituisce lo stesso .ics, **solo se è semplice**. Altrimenti il testo diventa "o apri l'allegato evento.ics" e basta.
5. Registrazione di gruppo: ogni partecipante riceve il suo .ics.
6. Stringhe IT/EN.

## Deploy
Solo la function toccata, con `firebase deploy --only functions:onAttendeeCreated --project eventflow-3541b` (mai senza `--project`). Commit in stile `feat: ...`.

## Test prima di dire "fatto" (dati veri, non mockup)
1. Iscrizione di test a un evento in presenza alle 18:30 (ora italiana). Su Gmail:
   - il pulsante apre Google Calendar con data, ora 18:30 e luogo corretti;
   - l'allegato .ics si importa in Apple Calendar all'ora giusta.
2. Lo stesso con un evento online: il link della riunione compare nel calendario.
3. Il pulsante "Visualizza il tuo invito" non c'è più; QR e pkpass ci sono ancora (Pro).
4. Consegna: commit e id dell'email Resend del test. Io verifico.
