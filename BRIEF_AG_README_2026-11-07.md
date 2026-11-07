# Handoff per AG (Antigravity) — Ticketto, 7 novembre 2026

Da: Claude (marketing/sito Ticketto, sul Mac di Fabio). Per: AG, che ora lavora su bitle-srv1.
Repo del prodotto: https://github.com/fgabelli/eventflow (branch `main`). Il prodotto si chiama **Ticketto**;
"eventflow" è solo il nome storico del repo e del progetto Firebase `eventflow-3541b`.

Due lavori urgenti, in quest'ordine. I dettagli, il codice proposto e i test di accettazione sono in BRIEF_AG_ANTI_PHISHING.md e BRIEF_AG_GOOGLE_WALLET.md, nella radice di questo repo (/srv/data/progetti/Flutter/eventflow, già clonato e allineato a origin/main).

## 1) ANTI-PHISHING — `BRIEF_AG_ANTI_PHISHING.md`
Due account con email usa-e-getta hanno creato eventi "Your Amazon purchase invoice… call +1…" e uno ha testato
l'iscrizione di un esterno: Ticketto gli ha spedito la mail di conferma. Il vettore è la mail di conferma: le regole
Firestore permettono a chiunque, senza login, di creare `attendees` su qualsiasi evento (anche in bozza) e
`onAttendeeCreated` spedisce da event@ticketto.it con il titolo dell'evento nell'oggetto. `resendAttendeeConfirmation`
è un endpoint HTTP senza auth.
Fai PRIMA il Livello 1 (mezza giornata): filtro contenuti + rate limit in `onAttendeeCreated`, auth su
`resendAttendeeConfirmation`, regole Firestore (iscrizione solo a eventi `published`, pubblicazione solo con email
verificata) + grandfathering `trusted: true` sulle org esistenti (Devero SPA, Depaola.davide, The Spa, Polilogoi, Bitle,
TEST: hanno account password non verificati e non devono accorgersi di nulla). Poi Livello 2 (verifica email al signup,
domini disposable), Livello 4 (campo `blocked` + avviso a Fabio al primo evento pubblicato), Livello 3 (App Check).
Eventi e account spam sono già stati cancellati/disabilitati il 7/11.

## 2) GOOGLE WALLET — `BRIEF_AG_GOOGLE_WALLET.md`
La revisione Google è ferma dal 29/8 perché il supporto (ticket 05580142, 31/8) ha scritto "we cannot find the pass in
the event class, create at least one pass" e nessuno ha risposto. Con il JWT `savetowallet` l'oggetto nasce solo quando
un utente salva il pass: nella classe non c'è nulla e forse la classe `ticketto_demo` non esiste nemmeno via API.
Serve uno script one-shot con il service account `eventflow-3541b@appspot.gserviceaccount.com` (già utente
"Sviluppatore" nella console Wallet) che crea la classe generica `3388000000023089767.ticketto` con
`reviewStatus: UNDER_REVIEW` e almeno un `genericObject` di esempio con dati reali, poi verifica con `genericObject.list`.
Quando l'oggetto esiste, avvisa Fabio: risponde lui al ticket (testo pronto nel file). Il pulsante nelle email resta
spento finché Google non approva.

## Regole
- Non toccare il copy del sito (`web/index_landing.html`, `/prezzi/`, blog): lo fa Claude.
- Deploy sempre con `./deploy_landing.sh --deploy` e `--project eventflow-3541b` (vedi GEMINI.md nel repo).
- Commit + push su `main` a fine lavoro; segnala a Fabio quando il Livello 1 anti-phishing è in produzione.
