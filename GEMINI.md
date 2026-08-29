# Istruzioni Operative Progetto: Eventflow

## Repository e Hosting
- **Codice sorgente**: GitHub (Privato) -> `https://github.com/fgabelli/eventflow` (branch `main` per Flutter, branch `legacy-react-2025` per storico prototipo)
- **Ambiente di produzione**: Firebase Project `eventflow-3541b`
- **URL di produzione**: `https://eventflow-3541b.web.app`

## Regole Operative Fondamentali
1. **Persistenza e Versionamento**:
   - Il Mac è esclusivamente una postazione di lavoro temporanea e sostituibile.
   - Al termine di OGNI sessione o task che modifica il codice sorgente, eseguire sempre `git add`, `git commit` e `git push origin main`.
   - Tutto ciò che non è su GitHub è considerato perso.
2. **Sicurezza e Segreti**:
   - Non committare MAI certificati Apple Wallet (`functions/certs/` -> `wwdr.pem`, `pass.p12`, `pass_cert.pem`, `pass_key.pem`), file `.env`, service account JSON, o credenziali in chiaro.
   - Verificare sempre lo stato di `.gitignore` e `git status` prima di eseguire il push.
