---
title: "Commissioni biglietteria eventi: quanto pagano davvero gli organizzatori"
seoTitle: "Commissioni Biglietteria Eventi: Quanto Pagano gli Organizzatori [2026]"
description: "Analisi pratica di tutte le commissioni applicate dalle piattaforme di biglietteria online in Italia: platform fee, payment processing, service fee. Calcoli su 3 scenari reali e 5 leve per abbassarle."
date: 2026-04-04
updated: 2026-04-19
category: "Analisi costi"
image: "/blog/assets/img/posts/commissioni-biglietteria-eventi/hero.webp"
imageAlt: "Grafico a barre astratto con monete stilizzate che rappresenta le commissioni di una piattaforma di biglietteria"
toc: true
tags: ["post", "commissioni", "pricing", "costi"]
relatedPosts:
  - alternative-eventbrite-italia
  - biglietteria-online-guida
faqs:
  - q: "Perché le commissioni dichiarate sono diverse da quelle effettivamente addebitate?"
    a: "Perché una singola transazione può coinvolgere fino a 4 layer di commissione indipendenti: (1) <strong>platform fee</strong> della piattaforma di biglietteria, (2) <strong>payment processing fee</strong> del PSP (Stripe, PayPal), (3) eventuale <strong>service fee</strong> addebitata al partecipante come linea separata, (4) <strong>currency conversion</strong> per pagamenti esteri. Il conto finale è la somma dei quattro, ma nelle pagine pricing viene tipicamente menzionato solo il primo."
  - q: "Chi deve pagare la commissione: l'organizzatore o il partecipante?"
    a: "Dipende dalla tua strategia di pricing. <strong>Assorbirla dall'organizzatore</strong> tiene pulito il prezzo per il partecipante (leggi: tasso di abbandono al checkout più basso). <strong>Scaricarla come service fee</strong> preserva il margine ma può aumentare i drop-off del 5-15% a seconda del settore. Per eventi formativi e B2B è di solito più redditizio assorbirla; per festival e eventi a ticket basso, scaricarla è la norma del settore."
  - q: "A che volume mensile il canone fisso batte la commissione variabile?"
    a: "Regola pratica: il <strong>break-even point è tra €2.500 e €4.000 di GMV mensile</strong>. Sopra €4.000/mese con biglietti medi sopra i €30, un canone fisso (€29–€79/mese) con PSP diretto risparmia in media il 3-5% sul GMV rispetto a una commissione al 4-6%. Sotto €2.500/mese, la commissione variabile è più conveniente perché non paghi canone su mesi a basso volume."
  - q: "Le commissioni di Stripe si possono negoziare?"
    a: "Sì, sopra una certa soglia di volume. Stripe applica la tariffa standard (~1,5% per carte UE) fino a circa €50.000/mese di GMV. Sopra quella soglia è possibile richiedere pricing custom (tipicamente 1,1–1,3%). Lo stesso vale per altri PSP. Per ottenerla, contatta direttamente il sales Stripe con i tuoi dati di volume — non passa per la piattaforma di biglietteria."
  - q: "Cosa succede alle commissioni in caso di rimborso?"
    a: "Dipende dal PSP. <strong>Stripe</strong> non restituisce la fee fissa (€0,25) né quella percentuale in caso di rimborso — è una perdita secca per l'organizzatore. <strong>PayPal</strong> storicamente restituiva la commissione, ma dal 2019 ha uniformato la policy a Stripe. Alcune piattaforme di biglietteria applicano in aggiunta una <em>refund processing fee</em> di €1-€2 per rimborso: verifica questo punto specifico nei T&C prima della firma."
  - q: "Posso scaricare le commissioni fiscalmente come costo?"
    a: "Sì, sono costi di produzione deducibili al 100% (voce 'servizi di terzi' del conto economico). La piattaforma emette fattura mensile con ritenuta d'acconto applicabile se è italiana, o regime IVA UE se è basata in UE (Irlanda, Francia). Per Stripe US si applica il reverse charge: valutare con il commercialista l'impatto IVA."
---

> **In sintesi:** il costo totale di una piattaforma di biglietteria online non è solo il canone mensile che leggi sul sito. Ci sono fino a quattro layer di commissione che si sommano, e la differenza tra la cifra "marketing" e quella "in fattura a fine mese" può essere del 3-6% sul fatturato. Questa guida smonta il conto voce per voce, con tre scenari numerici reali e cinque leve pratiche per ridurre il totale del 50%.

---

## Le 4 voci di costo di una piattaforma di biglietteria

Partiamo dal mettere ordine. Ogni volta che un partecipante paga un biglietto, il denaro attraversa fino a **quattro livelli di commissione** prima di arrivare sul tuo conto. Ciascuno ha una sua logica economica, un suo beneficiario, e soprattutto un suo peso che nelle pagine pricing non sempre è chiaro.

### 1. Platform fee (commissione della piattaforma)

È la commissione che la piattaforma di biglietteria trattiene per il servizio di SaaS offerto: pagina di registrazione, check-in, dashboard, supporto. Varia tipicamente tra **2% e 7%** a seconda del piano e del volume. Alcune piattaforme non la applicano se sei su un canone fisso (è il caso di Ticketto sui piani Pro/Business).

### 2. Payment processing fee (commissione del PSP)

È la commissione del Payment Service Provider (Stripe, PayPal, Nexi, Satispay) per l'effettiva elaborazione del pagamento. Su Stripe standard per carte UE è **1,5% + €0,25** per transazione. Questa commissione è **indipendente** dalla platform fee: le paghi entrambe.

Attenzione al trucco del **PSP inserito in mezzo**: alcune piattaforme di biglietteria non usano Stripe direttamente ma hanno un proprio gateway aggregatore che trattiene un margine di 0,5-1% sopra Stripe. Il costo reale del pagamento diventa 2-2,5% invece di 1,5%. Risulta visibile solo leggendo attentamente i T&C.

### 3. Service fee (commissione addebitata al partecipante)

È una commissione che alcune piattaforme — tipicamente Eventbrite, TicketOne, Vivaticket — **addebitano al partecipante** come riga separata al checkout, oltre al prezzo del biglietto. Esempio: biglietto €30 + service fee €2,50 = totale €32,50. L'organizzatore riceve comunque €30 puliti, ma il costo economico viene scaricato sul partecipante. Su piattaforme che la applicano, varia tra **2% e 5%**.

Questo modello ha vantaggi per l'organizzatore (margine pulito) ma crea frizione al checkout: è uno dei principali driver di abbandono (+5-15% rispetto al prezzo singolo).

### 4. Currency conversion / FX fee

Se il tuo evento vende a partecipanti di altri Paesi con valute diverse da EUR, il PSP aggiunge una **FX fee del 1-2%** per la conversione. Su Stripe è attorno all'1,5% per conversioni non-EUR. Trascurabile per eventi 100% italiani, materiale per convention internazionali e corsi online B2B.

---

## 3 scenari numerici reali

Basta teoria. Ecco come si traducono queste percentuali in cifre vere su tre casi tipici.

### Scenario A — Corso formativo B2B

**Setup**: 1 corso al mese, 100 partecipanti, biglietto €200. GMV mensile €20.000.

| Voce | Piattaforma commission-based (es. 6% + €1 fisso) | Piattaforma canone fisso + Stripe diretto |
|---|---|---|
| Platform fee | €1.200 | **€79 (canone Pro)** |
| Per-ticket fixed fee | €100 | €0 |
| Stripe (1,5% + €0,25 × 100) | — | €300 + €25 = **€325** |
| **Totale mensile** | **€1.300** | **€404** |
| **Costo effettivo su GMV** | 6,5% | 2,0% |

**Differenza**: €896/mese di margine recuperato, ovvero **€10.752/anno**. Pari al costo di uno stipendio junior part-time o di un evento corporate extra l'anno.

### Scenario B — Convention aziendale

**Setup**: 4 convention l'anno, 400 partecipanti per evento, biglietto €120. GMV annuo €192.000.

| Voce | Commission-based 4,5% + €0,99 | Canone Business + Stripe |
|---|---|---|
| Platform fee | €8.640 | **€948 (12×€79)** |
| Per-ticket fixed | €1.584 | €0 |
| Stripe (1,5% + €0,25 × 1.600) | — | €2.880 + €400 = **€3.280** |
| **Totale annuo** | **€10.224** | **€4.228** |
| **Costo su GMV** | 5,3% | 2,2% |

**Differenza**: €5.996/anno di risparmio, cioè il costo di due trasferte executive o sei mesi di ads.

### Scenario C — Festival musicale

**Setup**: 1 festival/anno, 2.000 partecipanti, biglietto €35 (più service fee a carico del partecipante se si sceglie quel modello). GMV €70.000.

In questo scenario conta anche il **tasso di conversione al checkout**. Chi scarica la service fee sul partecipante (~€2-3 extra) registra un drop-off del 10% rispetto a chi assorbe la commissione e mostra il prezzo pulito.

| Voce | Commission-based con service fee | Canone fisso, prezzo pulito |
|---|---|---|
| Vendite effettive (dopo drop-off) | 1.800 biglietti (~€63.000 GMV) | 2.000 biglietti (€70.000 GMV) |
| Commissioni | €0 (le paga il partecipante) | €79 × 6 mesi setup + Stripe €1.550 = €2.024 |
| **Margine lordo per organizzatore** | **€63.000** | **€67.976** |

Anche assorbendo le commissioni dal proprio tasca, il margine finale può essere **superiore** grazie al minor drop-off al checkout. Conta: misura sempre l'intera funnel, non solo la commissione.

---

## Assorbire o scaricare: una scelta strategica

La scelta di dove far ricadere la commissione non è banale. Ecco i pro e contro delle due opzioni, con evidenza di quando ciascuna è preferibile.

**Assorbire la commissione (organizzatore paga)**
- ✅ Prezzo visualizzato = prezzo incassato dal partecipante → zero sorprese al checkout
- ✅ Tasso di conversione più alto (fino al +10-15% su ticket sotto €50)
- ✅ Trasparenza di brand
- ❌ Margine netto leggermente inferiore

**Scaricare come service fee (partecipante paga)**
- ✅ Margine pulito per l'organizzatore
- ✅ Adatto a eventi grandi dove il costo è percepito come "fisiologico"
- ❌ Drop-off più alto al checkout
- ❌ Esperienza utente meno pulita, potenziale danno al brand

**Regola pratica**:
- Eventi formativi B2B e corsi premium → **assorbi** (l'utente si aspetta prezzo fisso e chiaro)
- Festival, concerti, eventi di intrattenimento → **scarica** (è la norma del settore, accettata culturalmente)
- Eventi gratuiti → non applicabile (nessuna commissione)

---

## 5 leve concrete per ridurre il totale

Azioni che si possono fare **questa settimana** per abbassare il costo totale, in ordine di impatto.

1. **Passa a un modello a canone fisso sopra €25K GMV/anno.** Come visto negli scenari, il break-even point è intorno ai €25-30K di GMV annuo. Sopra, il canone fisso (€29-€79/mese) batte sistematicamente la commissione variabile.
2. **Scegli una piattaforma con PSP diretto.** Se la piattaforma usa un gateway aggregatore in mezzo, stai pagando 0,5-1% in più "per niente". Cerca soluzioni che si collegano direttamente a Stripe o PayPal.
3. **Negozia tariffe custom con il PSP.** Sopra €50K GMV/mese, Stripe e competitor hanno pricing custom. Una telefonata al loro sales commerciale può farti risparmiare 0,2-0,4% sul processato. Sono soldi che ritornano nel tuo margine senza sforzo.
4. **Ottimizza il mix hardware.** Ogni euro speso in lettori QR dedicati è un euro che non torna. Usa lo smartphone dello staff ([guida operativa qui](/blog/check-in-evento-smartphone/)) e riduci la spesa TCO di centinaia di euro per evento.
5. **Valuta lo switch.** Se stai usando Eventbrite o un competitor con commissioni 5-7%, il saving potenziale su un anno copre spesso il costo di migrazione decuplicato. Ti abbiamo messo a confronto [Eventbrite e 5 alternative](/blog/alternative-eventbrite-italia/) così hai i dati per decidere.

---

## Canone fisso vs commissione: il break-even

Se c'è una slide da salvare di tutto questo articolo, è questa.

| GMV mensile | Commissione variabile (5% medio) | Canone Pro (€29) + Stripe | Canone Business (€79) + Stripe |
|---|---|---|---|
| €1.000 | €50 | €44 | €94 |
| €2.500 | €125 | €67 | €117 |
| **€4.000** | **€200** | **€89** ⭐ | €139 |
| €10.000 | €500 | €179 | €229 |
| €25.000 | €1.250 | €404 | €454 ⭐ |
| €50.000 | €2.500 | €779 | €829 |

**Interpretazione**:
- Sotto €2.500/mese: commissione variabile ancora conveniente
- €2.500–€4.000/mese: inizia a pagare il piano Pro
- **Sopra €4.000/mese**: canone fisso risparmia minimo 50-60% del costo
- Sopra €25.000/mese: passa al Business per supporto dedicato e limiti più alti

---

## Conclusione

Il prezzo "marketing" di una piattaforma di biglietteria è quasi sempre diverso dal costo reale in fattura. La differenza è nelle 4 voci di commissione che si sommano: platform, PSP, service fee, FX. Conoscere il valore di ciascuna — e chi davvero la paga — è la base per scegliere la piattaforma giusta e per negoziare condizioni migliori dove possibile.

Se la tua platform fee attuale è sopra il 3-4% e il tuo volume è consistente, lo switch a un canone fisso ripaga il costo di migrazione in meno di 2 mesi. Ticketto applica il modello canone fisso (€0, €29 o €79/mese) con Stripe diretto e **zero commissioni piattaforma** — il solo costo variabile è la fee PSP standard. [Prova Ticketto gratis](/app.html#signup) per due mesi, poi fai i tuoi conti.

Se vuoi inquadrare la scelta in un framework più ampio (non solo commissioni, ma anche features e conformità), parti dalla nostra [guida alla biglietteria online](/blog/biglietteria-online-guida/).
