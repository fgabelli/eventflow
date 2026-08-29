# Brief i18n per Antigravity — Ticketto multilingua (IT + EN)

> Preparato per l'esecuzione da parte di Antigravity (AG) sul progetto Flutter `eventflow` + Cloud Functions.
> Obiettivo: rendere Ticketto multilingua **end-to-end**, coerente con il nuovo sito di marketing inglese (in costruzione, dominio separato gestito a parte).
> Lingue v1: **Italiano + Inglese**. Architettura predisposta per aggiungerne altre (ES/FR/DE) in futuro.

## 1. Le tre superfici da localizzare (NON solo la UI Flutter)

Rendere "l'app" multilingua significa localizzare **tutta la catena**, non solo la UI dell'organizzatore. Il pezzo che conta per i ricavi è quello rivolto al partecipante.

| # | Superficie | Tecnologia | Lingua determinata da |
|---|---|---|---|
| A | UI app organizzatore (eventflow) | Flutter | locale dispositivo/browser + override in impostazioni |
| B | Pagina pubblica di registrazione (vista dal partecipante) | Flutter web / template | **lingua dell'evento** |
| C | Email transazionali + Apple/Google Wallet pass | Cloud Functions | **lingua dell'evento** |

Se si localizza solo A e si lasciano B e C in italiano, un cliente estero si blocca al momento dell'iscrizione/conferma → l'internazionalizzazione è monca.

## 2. Modello di lingua (DECISIONE PRODOTTO, già presa da Fabio)

- **`Event.language`**: ogni evento ha un campo lingua (`it` | `en`).
  - **Default automatico**: alla creazione, preimpostato sulla lingua corrente della UI dell'organizzatore (locale attivo).
  - **Override libero**: l'organizzatore può cambiarlo. Un org italiano può creare un evento in inglese e viceversa. Selettore lingua nella schermata di creazione/modifica evento.
- **UI organizzatore (A)**: si adatta automaticamente al locale del dispositivo/browser; override manuale nelle impostazioni profilo, persistito (`profile.uiLanguage`).
- **Superfici partecipante (B + C)**: renderizzano **sempre** in `Event.language`, indipendentemente dalla lingua UI dell'organizzatore.
- **Fallback**: locale non supportato → **English** (coerente con `x-default=en` del sito). Lingue supportate: `[en, it]`.

## 3. Implementazione Flutter (superfici A + B)

- Usare l'approccio ufficiale **`flutter_localizations` + `intl` + file ARB** (`lib/l10n/app_en.arb`, `app_it.arb`) con generazione `AppLocalizations`. (In alternativa `easy_localization` se preferito dal team, ma ARB è lo standard.)
- **Esternalizzare TUTTE le stringhe hardcoded**: nessun literal italiano nei widget. Audit completo di `lib/features/**`.
- Risoluzione locale: `supportedLocales = [Locale('en'), Locale('it')]`, `localeResolutionCallback` con fallback a `en`.
- Override UI persistito (es. `shared_preferences` o profilo Firestore) che forza il `Locale` dell'app.
- **Formattazione** date/numeri/valuta via `intl` con il locale attivo. Mantenere il fix timezone **Europe/Rome** già presente per gli orari evento; localizzare solo le label/formati.
- La **pagina pubblica di registrazione (B)** deve forzare il `Locale` su `Event.language` (NON sul locale del visitatore), così il partecipante vede la pagina nella lingua scelta dall'organizzatore per quell'evento.

## 4. Backend / Cloud Functions (superficie C)

Le email transazionali sono oggi in italiano (con timezone Europe/Rome). Vanno localizzate per `Event.language`:
- Template multilingua per: **conferma iscrizione**, **reminder**, **ringraziamento/post-evento**, **email evento online** (bottone "Partecipa allo Streaming" → "Join the stream", link inviato solo dopo conferma).
- **Apple Wallet + Google Wallet pass**: label localizzate (event, date, time, gate, etc.) per `Event.language`.
- Selezione template lato Functions: leggere `event.language` dal documento evento e scegliere il set di stringhe.
- **Mantenere intatta** la logica di gating esistente (PDF biglietto / Wallet / notifiche solo Pro/Business; check-in QR ed email base anche Free). L'i18n NON deve toccare i permessi di piano.

## 5. Migrazione dati

- Aggiungere `language` ai documenti `event`. **Backfill eventi esistenti → `it`** (grandfathered: restano in italiano).
- Aggiungere `uiLanguage` al profilo organizzatore (opzionale; in mancanza si usa il locale dispositivo).
- Verificare le `firestore.rules` se introducono validazione sui nuovi campi.

## 6. Glossario — coerenza con il sito EN

L'inglese dell'app deve combaciare con quello del sito di marketing. Termini chiave già adottati sul sito:

| IT | EN (usare questo) |
|---|---|
| Check-in | Check-in |
| Fasce orarie | Time slots |
| Registrazione di gruppo | Group registration |
| Campi di registrazione personalizzati | Custom registration fields |
| Badge PDF | PDF badge |
| Stampa termica zero-tap | Zero-tap thermal printing |
| Partecipante | Attendee |
| Organizzatore | Organiser/Organizer |
| Evento (a pagamento / gratuito) | (Paid / Free) event |
| Iscrizione / registrazione | Registration / sign-up |
| Inizia gratis | Start for free |
| Avvisami (notifiche real-time) | Notify me |

## 7. Fuori scope (per ora)

- Lingue oltre IT/EN (ES/FR/DE): architettura pronta, contenuti dopo, sui dati.
- Sito di marketing pubblico (home/prezzi/blog): gestito separatamente, non da AG.

## 8. Criteri di accettazione (definition of done)

1. Dispositivo in inglese → app organizzatore interamente in inglese; in italiano → italiano. Override manuale funziona e persiste.
2. Creando un evento, la lingua si preimposta sulla UI corrente ed è modificabile (IT↔EN) liberamente.
3. Un evento con `language=en`: pagina di registrazione pubblica **e** email di conferma/reminder/wallet in inglese — anche se l'organizzatore usa l'app in italiano.
4. Un evento `language=it`: tutto in italiano (comportamento attuale).
5. Eventi preesistenti: invariati (italiano), nessuna regressione.
6. Nessun literal hardcoded rimasto; nessun impatto sul gating dei piani; orari ancora corretti in Europe/Rome.
