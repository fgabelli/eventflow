# Istruzioni Operative Progetto: Eventflow

## Repository e Hosting
- **Codice sorgente**: GitHub (Privato) -> `https://github.com/fgabelli/eventflow` (branch `main` per Flutter, branch `legacy-react-2025` per storico prototipo)
- **Ambiente di produzione**: Firebase Project `eventflow-3541b`
- **URL di produzione**: `https://ticketto.it` (hosting Firebase: `https://eventflow-3541b.web.app`)

## Regole Operative Fondamentali
1. **Persistenza e Versionamento**:
   - Il Mac è esclusivamente una postazione di lavoro temporanea e sostituibile.
   - Al termine di OGNI sessione o task che modifica il codice sorgente, eseguire sempre `git add`, `git commit` e `git push origin main`.
   - Tutto ciò che non è su GitHub è considerato perso.
2. **Sicurezza e Segreti**:
   - Non committare MAI certificati Apple Wallet (`functions/certs/` -> `wwdr.pem`, `pass.p12`, `pass_cert.pem`, `pass_key.pem`), file `.env`, service account JSON, o credenziali in chiaro.
   - Verificare sempre lo stato di `.gitignore` e `git status` prima di eseguire il push.
3. **Pubblicazione del sito (REGOLA CRITICA — non rompere la home di ticketto.it)**:
   - Su `ticketto.it` convivono due cose: la **landing di marketing** (statica, su `/`) e l'**app Flutter** (su `/app.html` e sulle rotte `/login`, `/signup`, ecc.). La landing porta il traffico SEO e le campagne: se si rompe, il danno non si vede nei test dell'app.
   - **Per pubblicare usare SEMPRE `./deploy_landing.sh --deploy`**, mai `firebase deploy` a mano. Lo script fa i due passaggi che `flutter build web` non fa (vedi sotto) e usa il progetto giusto.
   - **Indicare sempre il progetto**: `--project eventflow-3541b`. Senza, il deploy può finire su un altro progetto Firebase.
   - Due modi noti di rompere la home, entrambi silenziosi (build verde, deploy "OK", errore visibile solo aprendo il sito in un browser):
     1. `build/web/index.html` (la shell dell'app) resta al suo posto → Firebase serve quel file e il rewrite `"/" → /index_landing.html` non scatta: su `/` compare l'app invece della landing. Va rinominato in `app.html`.
     2. `build/web/flutter_service_worker.js` contiene nel manifest la entry `"/"` → il service worker già installato nei browser risponde per `/` con la shell dell'app tenuta in cache: l'utente vede il **login** al posto della landing, anche se il server risponde correttamente. Va ripulito con `python3 fix_service_worker.py` (incidente del 2026-09-06).
   - Entrambe le correzioni sono automatiche: `predeploy_guard.sh` è agganciato come hook `predeploy` in `firebase.json` e gira prima di **ogni** `firebase deploy` che tocchi l'hosting. Corregge da sé i due casi sopra e blocca il deploy se la landing manca o non è quella giusta.
   - **Non rimuovere né disattivare** `predeploy_guard.sh`, `fix_service_worker.py`, l'hook `predeploy` in `firebase.json`, il rewrite `"/" → /index_landing.html` e il file `web/index_landing.html`. Se un cambiamento li rende necessari da modificare, parlarne prima con Fabio.
   - **Verifica dopo ogni pubblicazione**: `curl -s https://ticketto.it/ | grep "<title>"` deve mostrare il titolo della landing (non "Ticketto" secco), e aprendo `https://ticketto.it/` in una finestra in incognito deve comparire la vetrina, non il login.
4. **Dominio Ufficiale e URL Pubblici (REGOLA CRITICA — Solo ticketto.it)**:
   - Qualsiasi link generato nell'applicazione, copiato negli appunti, inviato via email, stampato su PDF o codificato nei QR code DEVE usare esclusivamente il dominio ufficiale `https://ticketto.it` (utilizzando la costante `AppConfig.baseUrl` da `package:eventflow/core/constants/app_constants.dart`).
   - È TASSATIVAMENTE VIETATO usare o esporre l'URL predefinito di Firebase (`eventflow-3541b.web.app` o simili) in link utente, QR code, condivisioni o documentazione rivolta al pubblico.

