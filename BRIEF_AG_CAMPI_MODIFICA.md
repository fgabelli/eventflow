# BRIEF PER AG — Campi personalizzati modificabili dopo il salvataggio

Repo: `/srv/data/progetti/Flutter/eventflow` (branch main). Progetto Firebase: `eventflow-3541b`.
Richiesta di una cliente in prova Pro (org AREL): deve sistemare il modulo di un evento già creato.

## Il problema (verificato su origin/main)
- I campi personalizzati del modulo di iscrizione si possono aggiungere o togliere **solo** quando si crea l'evento:
  - `lib/features/events/presentation/screens/events_screen.dart` ~righe 1454-1517 e 1911;
  - oppure dall'AI creator, `ai_event_creator_dialog.dart` ~636-677.
- La schermata di modifica `event_detail_screen.dart` (salvataggio ~righe 190-230) **non mostra e non salva** `customFields`. Oggi li legge solo per l'export CSV (~508) e per duplicare l'evento (~607).
- Le risposte degli iscritti sono salvate in `attendee.customData[field.id]` (`public_registration_screen.dart` ~165, 1203). Il modello è `CustomField` in `lib/core/models.dart` ~539.

## Cosa fare
1. Nella schermata di modifica evento aggiungi la stessa sezione "Campi personalizzati" della creazione. Possibilmente **estrai un widget condiviso** dalla dialog di creazione invece di copiarlo. La sezione deve permettere di:
   - aggiungere un campo (stessi tipi della creazione, checkbox inclusa, e flag "Obbligatorio");
   - modificare etichetta, tipo, opzioni e "Obbligatorio" di un campo esistente;
   - eliminare un campo;
   - cambiare l'ordine dei campi, se è semplice (drag o frecce). Non è indispensabile.
2. Il salvataggio deve scrivere `customFields` sull'evento.
3. **L'`id` dei campi esistenti non si cambia mai.** Così le risposte già raccolte restano collegate anche se cambia l'etichetta. Un campo nuovo prende un id nuovo.
4. Se l'evento ha già iscritti:
   - prima di **eliminare** un campo, mostra un avviso: "Le risposte già raccolte per questo campo non saranno più visibili nell'elenco e nell'export". Non cancellare `customData` dagli iscritti;
   - prima di **cambiare il tipo** di un campo, mostra un avviso simile.
5. Il gating resta quello attuale: i campi personalizzati sono Pro e Business, con badge PRO sul Free, come nella creazione.
6. IT/EN nelle stringhe nuove (`app_localizations.dart`).

## Deploy
Web **solo** con `./deploy_landing.sh --deploy`. Mai `firebase deploy` diretto sull'hosting. Commit in stile `feat: ...`.

## Test prima di dire "fatto" (con l'app vera, non mockup)
1. Crea un evento di test senza campi. Poi da Modifica aggiungi una checkbox obbligatoria e salva. La pagina pubblica `/register/<id>` deve mostrarla e bloccare l'iscrizione se non è spuntata.
2. Iscriviti, poi cambia l'etichetta del campo. Nell'elenco iscritti e nell'export CSV la risposta deve restare collegata.
3. Elimina un campo: compare l'avviso e la pagina pubblica non lo mostra più.
4. Consegna: commit, e l'id dell'evento di test. Io verifico via REST che `customFields` venga salvato.
