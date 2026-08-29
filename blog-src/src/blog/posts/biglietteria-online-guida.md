---             
title: "Biglietteria online: guida definitiva per organizzatori di eventi [2026]"                                                                                         
seoTitle: "Biglietteria Online: Guida Definitiva 2026"                                                                                                         
description: "Tutto quello che serve sapere prima di scegliere una piattaforma di biglietteria online in Italia: costi, commissioni, check-in, SIAE, integrazione Stripe. Guida pratica per organizzatori."                                                                                                                                         
date: 2026-04-01
updated: 2026-04-19                                                                                                                                                       
category: "Guida completa"
image: "/blog/assets/img/posts/biglietteria-online-guida/hero.jpg"                                                                                                        
imageAlt: "Organizzatore di evento che controlla la dashboard di una piattaforma di biglietteria online"                                                                  
toc: true                                                                                                                                                                 
tags: ["post", "pillar", "biglietteria", "gestione-eventi"]                                                                                                               
faqs:                                                                                                                                                                     
  - q: "Quanto costa una piattaforma di biglietteria online?"
    a: "I modelli di pricing sono due: <strong>canone fisso mensile</strong> (da €0 fino a €150 a seconda delle funzionalità) oppure <strong>commissione per biglietto venduto</strong> (tipicamente 2,5%–6,95% + costo fisso per transazione). Per eventi con prezzi medio-alti e volumi costanti il canone è quasi sempre più conveniente; per eventi sporadici la commissione variabile evita costi fissi."
  - q: "Serve la SIAE per vendere biglietti online?"                                                                                                                      
    a: "Dipende dal tipo di evento. Per <strong>spettacoli dal vivo con musica</strong> (concerti, feste, dj set) è necessario il permesso SIAE e il borderò. Per <strong>eventi formativi, corsi, convention aziendali, mostre senza musica</strong> normalmente non serve. La piattaforma non gestisce la SIAE al posto tuo: è una responsabilità dell'organizzatore."                                                                                                                                       
  - q: "Devo emettere fattura elettronica per i biglietti venduti online?"                                                                                                
    a: "Sì, se sei un soggetto titolare di partita IVA residente in Italia. La fattura va emessa verso l'acquirente finale (B2C con codice fiscale o B2B con partita IVA) tramite SDI. Alcune piattaforme permettono l'esportazione CSV dei dati partecipanti per caricarli nel tuo gestionale; altre hanno integrazioni native con servizi di fatturazione."                                                                                                                                                            
  - q: "Che differenza c'è tra check-in con lettore QR dedicato e check-in con smartphone?"                                                                               
    a: "Un <strong>lettore QR dedicato</strong> è un dispositivo hardware (tipo Honeywell o Zebra) che costa €150–€400 e richiede configurazione. Un <strong>check-in via smartphone</strong> usa la fotocamera del telefono dello staff e un'app web o nativa: copertura istantanea di più postazioni, nessun costo hardware, nessuna sincronizzazione offline se la piattaforma la gestisce in cloud."                                                                                                         
  - q: "Che cosa succede se un partecipante vuole il rimborso?"                                                                                                           
    a: "La piattaforma di biglietteria gestisce il flusso tecnico del rimborso (reverse su Stripe, notifica via email), ma <strong>la decisione di concedere il rimborso resta all'organizzatore</strong>. Stripe consente rimborsi totali o parziali entro 180 giorni dal pagamento originale. Definisci a priori una refund policy pubblica nei termini di acquisto, per evitare controversie."                                                                                                                           
  - q: "I dati dei partecipanti sono a norma GDPR?"                                                                                                                       
    a: "Devono esserlo. Verifica che la piattaforma: (1) sia basata in UE o che trasferisca dati fuori UE con Clausole Contrattuali Standard (SCC), (2) offra un DPA (Data Processing Agreement) firmabile, (3) elimini automaticamente i dati dopo un periodo di retention dichiarato, (4) permetta l'export dati dell'interessato e la cancellazione su richiesta."                                                                                                                                              
  - q: "Come posso ridurre le commissioni sulla biglietteria?"                                                                                                            
    a: "Quattro leve concrete: (1) passare da un modello commissione-per-biglietto a un <strong>canone fisso</strong> se il volume mensile supera €3.000; (2) scegliere un <strong>PSP diretto</strong> (Stripe) invece di una piattaforma-aggregatore che trattiene margine; (3) scaricare la commissione sul partecipante come <strong>service fee</strong> trasparente; (4) negoziare tariffe custom se superi €50K/anno di GMV."                                                                                       
---                                                                                                                                                                       
                                                                                                                                                                          
> **In sintesi:** una piattaforma di biglietteria online efficace combina pagina di registrazione, incasso via PSP come Stripe, check-in digitale, dashboard in tempo
reale e gestione post-evento. Il costo vero non è il canone della piattaforma: sono le commissioni nascoste, il tempo perso al check-in e gli errori che fanno saltare la 
serata. Questa guida spiega come valutare tutto questo prima di firmare.
                                                                                                                                                                          
---             

## Che cos'è una piattaforma di biglietteria online                                                                                                                       
 
Una piattaforma di biglietteria online è un software as a service (SaaS) che permette a un organizzatore di eventi di vendere biglietti o gestire registrazioni via web,  
incassare pagamenti, inviare conferme automatiche e controllare l'accesso dei partecipanti il giorno dell'evento.
                                                                                                                                                                          
Non è solo "un form + PayPal": un tool serio copre l'intero ciclo di vita dell'evento — dalla creazione della pagina pubblica fino al reportistica post-evento — e        
sostituisce decine di ore di lavoro manuale su fogli Excel, email copia-incolla e check-in con pennarello.
                                                                                                                                                                          
Le piattaforme moderne servono cinque categorie principali di organizzatori:                                                                                              
 
- **Eventi formativi** (corsi, masterclass, workshop, convention aziendali)                                                                                               
- **Eventi culturali e spettacoli** (concerti, teatro, mostre, festival)
- **Conferenze e B2B** (fiere, summit, eventi di networking, lanci di prodotto)                                                                                           
- **Associazioni e no-profit** (raccolte fondi, cene sociali, attività per tesserati)                                                                                     
- **Eventi aziendali interni** (kick-off, team building, premiazioni)                                                                                                     
                                                                                                                                                                          
Se organizzi anche solo uno di questi tipi di evento più di due volte l'anno e hai più di 50 partecipanti per volta, un gestionale dedicato ripaga il costo nel primo     
evento — spesso anche prima.                                                                                                                                              
                                                                                                                                                                          
---             

## I 7 componenti di una buona piattaforma di biglietteria

Ogni piattaforma racconta la stessa storia nel marketing. La differenza vera è nei dettagli operativi. Questi sono i sette moduli che devi controllare uno per uno prima  
di scegliere.
                                                                                                                                                                          
### 1. Pagina pubblica di registrazione                                                                                                                                   
 
È la landing che il tuo partecipante vede prima di pagare. Controlla:                                                                                                     
                
- **Domini personalizzati** (`eventi.miosito.it`) o branding rimovibile                                                                                                   
- **Campi form personalizzabili** (dieta, taglia maglietta, consensi marketing)
- **Codici sconto** e **liste accesso ristrette**                                                                                                                         
- **Design mobile-first**: oltre il 70% delle registrazioni oggi arriva da smartphone

Per approfondire come progettare una pagina che massimizzi il conversion rate, vedi la [guida sulla pagina di registrazione evento](/blog/pagina-registrazione-evento-che-converte/).                                                                                     
                                                                                                                                                                          
### 2. Pagamenti                                                                                                                                                          
                                                                                                                                                                          
Il cuore economico. Verifica il **Payment Service Provider (PSP)** utilizzato: Stripe, PayPal, Satispay, Nexi, Redsys. Le differenze:                                     
 
- **Stripe** è lo standard de facto B2B: setup in 10 minuti, commissioni trasparenti (1,5% + €0,25 su carte UE), supporto per Apple Pay e Google Pay nativo.              
- **Piattaforme-aggregatore** (tipo Eventbrite) inseriscono un loro margine sopra Stripe — paghi due volte.
- **Attenzione alla SCA/PSD2**: il PSP deve supportare la 3D Secure 2.0 automaticamente, altrimenti hai un tasso di fallimento superiore al 30%.                          
                                                                                                                                                                          
### 3. Gestione fasce orarie (time slots)                                                                                                                                 
                                                                                                                                                                          
Se il tuo evento ha ingressi scaglionati (visite guidate, corsi con turni, ristoranti per una cena evento), questa funzionalità non è un "nice to have": è la differenza  
tra una coda ordinata e trenta persone che si lamentano in 15 minuti. Verifica che la piattaforma consenta:
                                                                                                                                                                          
- Limiti di capienza per singolo slot                                                                                                                                     
- Sovra-prenotazione configurabile per gestire i no-show
- Notifiche automatiche quando uno slot si apre

> Per un approfondimento operativo su dimensionamento capienza, gestione no-show e modelli di prenotazione, vedi la [guida alla gestione delle fasce orarie](/blog/gestione-fasce-orarie-eventi/).
                
### 4. Import massivo                                                                                                                                                     
                
Indispensabile per eventi ripetuti o migrazioni da sistemi vecchi. Devi poter caricare un CSV di 2.000 partecipanti con email, nome e dati custom, e generare             
automaticamente biglietti, QR code e conferme. Senza questa funzione, a 500 partecipanti sei fuori.
                                                                                                                                                                          
### 5. Comunicazioni automatiche                                                                                                                                          
 
Email di conferma, reminder automatici (24h prima, 1h prima), notifiche post-evento per feedback e upsell. Verifica:                                                      
                
- **Template personalizzabili** con variabili (nome, biglietto, QR inline)                                                                                                
- **Trigger temporali** configurabili
- **Compliance GDPR**: consenso esplicito separato per marketing, unsubscribe one-click                                                                                   
                                                                                                                                                                          
### 6. Check-in digitale                                                                                                                                                  
                                                                                                                                                                          
L'operatività della giornata dell'evento vive o muore qui. Valuta:                                                                                                        
 
- **Hardware**: serve lettore QR dedicato o basta lo smartphone dello staff?                                                                                              
- **Multi-postazione**: più addetti devono poter scannerizzare in contemporanea senza duplicare il check-in
- **Sincronizzazione in tempo reale** per evitare che lo stesso biglietto passi due volte su due postazioni diverse                                                       
- **Modalità offline**: se l'area è senza connessione (capannone, tenda, stadio), l'app deve gestire la coda locale e sincronizzare dopo                                  

*Per approfondire operativamente questo step, leggi la nostra [guida operativa al check-in da smartphone](/blog/check-in-evento-smartphone/).*
                                  
                                                                                                                                                                          
### 7. Dashboard e reportistica                                                                                                                                           
                                                                                                                                                                          
Dopo l'evento serve sapere: quante vendite, provenienza traffico, tasso di conversione per canale, no-show rate, feedback medio. Una dashboard seria esporta in CSV/Excel 
e integra UTM per tracciare le campagne Meta o Google Ads.
                                                                                                                                                                          
---             

## Come scegliere: 8 criteri pratici                                                                                                                                      
 
Una tabella comparativa dei pricing è inutile se non sai cosa cercare. Questi sono i criteri in ordine di impatto reale sull'esperienza.                                  
                
| # | Criterio | Domanda operativa |                                                                                                                                      
|---|---|---|   
| 1 | Modello di pricing | Canone fisso o commissione? A quale volume mensile il primo conviene sul secondo? |
| 2 | Trasparenza costi | C'è una fee nascosta caricata sul partecipante che l'organizzatore non vede? |                                                                  
| 3 | PSP usato | È Stripe diretto o un aggregatore che trattiene margine? |                                                                                              
| 4 | Dominio/branding | Posso usare il mio dominio? Posso nascondere il brand della piattaforma? |                                                                       
| 5 | Check-in hardware | Serve hardware dedicato o basta lo smartphone? Quanti device in parallelo? |                                                                    
| 6 | GDPR/DPA | Fornisce un DPA firmato? Dati ospitati in UE? |                                                                                                          
| 7 | Supporto | C'è supporto real-time il giorno dell'evento? In che lingua, su che canale? |                                                                            
| 8 | Export dati | Posso esportare tutti i dati in qualunque momento senza restrizioni? |                                                                                
                                                                                                                                                                          
Ogni criterio pesa diversamente in base al tuo contesto. Un festival con 10.000 partecipanti in una serata ha bisogno ossessivo del criterio #5. Un corso da 40 persone a €500 ciascuno si gioca tutto sul #1 e sul #3 — le commissioni sulle somme alte sono una tassa enorme.

Se vuoi un confronto diretto su queste dimensioni con i nomi di mercato, ho messo a confronto Eventbrite e 5 alternative europee e italiane nella [guida alle alternative a Eventbrite in Italia](/blog/alternative-eventbrite-italia/).                                                                     
                                                                                                                                                                          
---             

## Costi reali: commissioni vs canone                                                                                                                                     
 
Facciamo i conti veri. Simuliamo un organizzatore italiano con **20 eventi l'anno, 150 partecipanti medi per evento, biglietto medio €45**.                               
                
**Volume annuo**: 20 × 150 × €45 = **€135.000 di GMV**.                                                                                                                   
                
**Scenario A — Piattaforma commissione-based al 6% sul partecipante:**                                                                                                    
- Commissione totale: €135.000 × 6% = **€8.100/anno**
- Più €0,99 fissi per biglietto: 3.000 × €0,99 = **€2.970**                                                                                                               
- **Costo totale: €11.070/anno**                                                                                                                                          
                                                                                                                                                                          
**Scenario B — Piattaforma a canone fisso €79/mese + Stripe diretto:**                                                                                                    
- Canone: 12 × €79 = **€948**
- Stripe (1,5% + €0,25 per transazione UE): €135.000 × 1,5% + 3.000 × €0,25 = **€2.025 + €750 = €2.775**                                                                  
- **Costo totale: €3.723/anno**                                                                                                                                           
                                                                                                                                                                          
**Risparmio annuo: €7.347** — cioè il costo di un dipendente part-time per 4 mesi, solo spostando la biglietteria. Il punto di pareggio tra i due modelli è intorno ai    
**€25.000 di GMV annuo**: sotto, la commissione variabile conviene; sopra, il canone fisso si ripaga in modo esponenziale.
                                                                                                                                                                          
---             

## Aspetti normativi in Italia

Tre capitoli da non sottovalutare. Nessuna piattaforma ti mette al riparo dalle responsabilità legali dell'organizzatore.                                                 
 
### SIAE                                                                                                                                                                  
                
Per ogni evento che prevede **esecuzione di musica tutelata** (concerti, feste con musicista/DJ, spettacoli con colonna sonora) serve:                                    
 
1. Permesso SIAE richiesto **prima dell'evento**                                                                                                                          
2. Borderò presentato **entro 5 giorni**
3. Pagamento dei diritti calcolato su incassi e capienza                                                                                                                  
                                                                                                                                                                          
La piattaforma di biglietteria fornisce i dati (numero biglietti venduti, prezzi) ma non presenta il borderò al tuo posto.                                                
                                                                                                                                                                          
### Fatturazione elettronica                                                                                                                                              
                
Dal 2019 in Italia è obbligatoria per tutti i soggetti IVA. Ogni biglietto venduto a un soggetto italiano richiede fattura elettronica via SDI. Le opzioni:               
 
- **Export CSV + gestionale esterno** (Fatture in Cloud, FattureInCloud, Aruba)                                                                                           
- **Integrazione nativa** della piattaforma con sistema di fatturazione
- **Delega a commercialista** con invio mensile                                                                                                                           
                                                                                                                                                                          
Se vendi a privati senza codice fiscale (biglietto a bassa fedeltà), scontrino fiscale elettronico via registratore telematico o piattaforma abilitata.                   
                                                                                                                                                                          
### GDPR                                                                                                                                                                  
                
Ogni partecipante è un "interessato" ai sensi del Regolamento. La piattaforma deve:                                                                                       
 
- Essere nominata **Responsabile del trattamento** con DPA firmato                                                                                                        
- Ospitare dati in UE o applicare SCC per trasferimenti extra-UE (esempio: Stripe US usa SCC)
- Consentire export dati e cancellazione su richiesta entro 30 giorni                                                                                                     
- Garantire registrazione consensi granulare per ogni finalità marketing
                                                                                                                                                                          
---             
                                                                                                                                                                          
## Integrazione con i pagamenti                                                                                                                                           
 
Il PSP non è un dettaglio tecnico: determina l'80% dell'esperienza di pagamento del partecipante. Quattro criteri da controllare:                                         
                
1. **Tasso di accettazione**: Stripe ha un'accettazione media del 95%+ sulle carte italiane grazie a machine learning antifrode. Gateway meno noti scendono sotto l'85%.  
2. **Supporto metodi locali**: oltre alle carte, servono Apple Pay, Google Pay e — per il mercato italiano — **Satispay** (quota in crescita, soprattutto sub-30).
3. **Payout**: ogni quanto ricevi i soldi? Stripe tipicamente T+7 per il primo mese, poi T+2. Piattaforme-aggregatore possono trattenere fino a 30 giorni dopo l'evento.  
4. **Dispute e chargeback**: chi gestisce le contestazioni? Chi paga? Leggi sempre la sezione "Reverse & disputes" nei T&C della piattaforma.                             
                                                                                                                                                                          
---                                                                                                                                                                       
                                                                                                                                                                          
## Il check-in: hardware dedicato vs smartphone

Questa è forse la decisione più sottovalutata. Fino a 5 anni fa era scontato comprare un lettore QR professionale. Oggi non più.                                          
 
**Hardware dedicato** (Honeywell EDA51, Zebra TC21, POS Zebra):                                                                                                           
- Costo: €150–€450 per unità + configurazione MDM
- Vantaggi: robustezza, autonomia batteria, scanner laser potente                                                                                                         
- Svantaggi: costo iniziale, obsolescenza rapida, training staff, stock management                                                                                        
                                                                                                                                                                          
**Smartphone dello staff** (app web o nativa):                                                                                                                            
- Costo hardware: **zero** (usa il device dello staff)                                                                                                                    
- Vantaggi: scalabilità immediata (10 postazioni = 10 smartphone diversi), familiarità UI, nessun setup                                                                   
- Svantaggi: autonomia batteria inferiore, velocità scan leggermente più bassa su QR piccoli                                                                              
                                                                                                                                                                          
Per eventi sotto i 3.000 partecipanti la scelta smartphone è quasi sempre migliore. Sopra, dipende dalla densità di accesso: uno stadio con 3 varchi e 5.000 persone in   
mezz'ora chiede hardware dedicato; una convention con 3.000 persone distribuite in 3 ore la fa tranquillamente via smartphone.                                            
                                                                                                                                                                          
> **Il nostro bias**: noi di Ticketto abbiamo progettato la piattaforma proprio per rendere lo smartphone dello staff un lettore professionale. Non lo facciamo perché    
odiamo l'hardware — lo facciamo perché per il 90% degli organizzatori italiani il TCO di una flotta di lettori non si giustifica.
                                                                                                                                                                          
---             

## Gli errori che si pagano caro                                                                                                                                          
 
Quindici anni di lavoro sul campo hanno insegnato che gli stessi sei errori si ripetono identici ogni volta.                                                              
                
1. **Testare la piattaforma il giorno stesso dell'evento.** Se il primo scan dal vivo è il primo scan reale, hai già perso. Dev'esserci stata una prova completa —        
biglietto di test, QR sul vero smartphone, scan al vero varco — almeno 48 ore prima.
2. **Non prevedere piano B per la connessione.** Capannoni e tende hanno reti instabili. Lavora con piattaforma che ha modalità offline **reale** (non "sincronizza       
dopo").                                                                                                                                                                   
3. **Affidarsi al CSV come fonte di verità.** Chi esporta un CSV la mattina e fa check-in "a mano" su tablet perderà aggiornamenti dell'ultima ora (biglietti venduti il
giorno stesso, cambi nome).                                                                                                                                               
4. **Ignorare i reminder automatici.** Senza reminder 24h prima, il no-show rate tipico sale del 15–25%. Un reminder è la cosa più semplice e più redditizia che puoi
attivare.                                                                                                                                                                 
5. **Non tracciare le UTM.** Se spendi in Meta o Google Ads, devi sapere quale campagna ha venduto quale biglietto. Senza UTM nel link di registrazione, ottimizzare è
cieco.                                                                                                                                                                    
6. **Non avere una refund policy pubblica.** Senza una policy chiara nei termini di acquisto, ogni rimborso diventa una trattativa individuale via email, che fa perdere
ore.                                                                                                                                                                      
                
---                                                                                                                                                                       
                
## Checklist pre-go-live

Stampa questa checklist e firmala quando ogni punto è verificato.                                                                                                         
 
- [ ] Il link pubblico dell'evento funziona da mobile e desktop                                                                                                           
- [ ] Il flow di pagamento è stato completato almeno una volta con carta reale (poi rimborsata)
- [ ] L'email di conferma arriva in <60 secondi e non va in spam                                                                                                          
- [ ] Il QR code si apre correttamente e legge al primo scan                                                                                                              
- [ ] Il reminder 24h prima è programmato con il testo giusto                                                                                                             
- [ ] Lo staff ha ricevuto credenziali di check-in e ha fatto almeno uno scan di test                                                                                     
- [ ] È chiaro chi è responsabile della connessione al varco (hotspot di backup?)                                                                                         
- [ ] La policy di rimborso è linkata dal checkout                                                                                                                        
- [ ] Il DPA con la piattaforma è firmato                                                                                                                                 
- [ ] Il borderò SIAE è stato richiesto (se applicabile)                                                                                                                  
- [ ] I dati partecipanti sono esportabili in qualsiasi momento                                                                                                           
- [ ] Hai un contatto diretto col supporto piattaforma per il giorno dell'evento                                                                                          
                                                                                                                                                                          
---                                                                                                                                                                       
                                                                                                                                                                          
## Conclusioni  

Una piattaforma di biglietteria non è un costo. È un moltiplicatore di margine e di qualità dell'esperienza. Il punto non è risparmiare €50 al mese: è evitare che la tua 
serata si giochi tutta su dieci minuti di coda al varco o su un'email che non arriva.
                                                                                                                                                                          
Se stai valutando oggi la tua prima piattaforma (o stai cambiando perché quella attuale non ti soddisfa), ti consiglio di scaricare la checklist di questa guida, fare un 
pilot con un evento piccolo e solo dopo estendere. Costa mezza giornata di lavoro; risparmia mesi di rimbalzi.
                                                                                                                                                                          
Su Ticketto facciamo esattamente questa promessa: un mese gratuito per testare, zero commissioni piattaforma sui piani a canone, check-in da smartphone senza hardware.   
[Prova Ticketto gratis](/app.html#signup) — crei il primo evento in cinque minuti.
