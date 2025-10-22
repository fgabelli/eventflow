# EventFlow - Guida al Deployment

## Deployment su Vercel

### Prerequisiti
- Account Vercel (gratuito)
- Repository GitHub: https://github.com/fgabelli/eventflow

### Passi per il Deployment

1. **Accedi a Vercel**
   - Vai su https://vercel.com
   - Effettua il login con il tuo account GitHub

2. **Importa il Progetto**
   - Clicca su "Add New..." → "Project"
   - Seleziona il repository `fgabelli/eventflow`
   - Clicca su "Import"

3. **Configura il Progetto**
   - **Framework Preset**: Vite
   - **Root Directory**: `./` (default)
   - **Build Command**: `pnpm build`
   - **Output Directory**: `dist`
   - **Install Command**: `pnpm install`

4. **Configura le Variabili d'Ambiente**
   Aggiungi le seguenti variabili d'ambiente:
   
   ```
   VITE_SUPABASE_URL=https://hokfbsubpcckffqhxfoj.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhva2Zic3VicGNja2ZmcWh4Zm9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDQxMDcsImV4cCI6MjA1OTYyMDEwN30.hX7bTti8Hb4Zs7gMf2aLq6y99r_KOXVEJHBaqkA5lgQ
   ```

5. **Deploy**
   - Clicca su "Deploy"
   - Attendi il completamento del deployment (circa 2-3 minuti)

6. **Configura Supabase**
   Dopo il deployment, copia l'URL di produzione di Vercel (es: `https://eventflow-xxx.vercel.app`) e aggiungilo alle impostazioni di Supabase:
   
   - Vai su https://supabase.com/dashboard/project/hokfbsubpcckffqhxfoj
   - Vai in "Authentication" → "URL Configuration"
   - Aggiungi l'URL di Vercel a:
     - **Site URL**: `https://eventflow-xxx.vercel.app`
     - **Redirect URLs**: `https://eventflow-xxx.vercel.app/**`

### Auto-Deploy

Una volta configurato, ogni push su GitHub attiverà automaticamente un nuovo deployment su Vercel.

## Configurazione Locale

### Installazione Dipendenze
```bash
pnpm install
```

### Avvio Server di Sviluppo
```bash
pnpm dev
```

### Build di Produzione
```bash
pnpm build
```

### Preview Build
```bash
pnpm preview
```

## Variabili d'Ambiente

Crea un file `.env.local` nella root del progetto con:

```env
VITE_SUPABASE_URL=https://hokfbsubpcckffqhxfoj.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhva2Zic3VicGNja2ZmcWh4Zm9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDQxMDcsImV4cCI6MjA1OTYyMDEwN30.hX7bTti8Hb4Zs7gMf2aLq6y99r_KOXVEJHBaqkA5lgQ
```

## Troubleshooting

### Errore di Build
- Verifica che tutte le dipendenze siano installate
- Controlla che le variabili d'ambiente siano configurate correttamente

### Errore di Autenticazione
- Verifica che l'URL di Vercel sia aggiunto alle Redirect URLs di Supabase
- Controlla che le chiavi API di Supabase siano corrette

### Errore 404 sulle Route
- Vercel dovrebbe gestire automaticamente le SPA routes
- Se necessario, aggiungi un file `vercel.json` con le regole di rewrite

## Supporto

Per problemi o domande:
- Repository: https://github.com/fgabelli/eventflow
- Supabase Dashboard: https://supabase.com/dashboard/project/hokfbsubpcckffqhxfoj

