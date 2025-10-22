# EventFlow 🎉

Piattaforma completa per la gestione eventi con sistema multi-organizzazione, registrazione partecipanti, check-in tramite QR code, campagne email e analisi.

![EventFlow](https://img.shields.io/badge/React-19-blue)
![TypeScript](https://img.shields.io/badge/TypeScript-5-blue)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-green)
![Tailwind CSS](https://img.shields.io/badge/Tailwind-4-cyan)

## ✨ Funzionalità Principali

### 🎫 Gestione Eventi
- **CRUD Completo**: Crea, modifica ed elimina eventi
- **Form Personalizzabili**: Campi personalizzati per la registrazione
- **QR Code Automatico**: Generazione automatica di QR code per ogni evento
- **Stati Evento**: Bozza, Pubblicato, Completato
- **Capacità e Limiti**: Gestione posti disponibili

### 👥 Gestione Partecipanti
- **Registrazione Completa**: Nome, email, telefono e dati personalizzati
- **QR Code Personale**: Ogni partecipante ha un QR code univoco
- **Import/Export**: Importazione massiva da CSV/Excel
- **Categorie**: Assegnazione di categorie e sottocategorie
- **Stati**: Registrato, Check-in effettuato, Annullato

### 📱 Sistema Check-in
- **Scanner QR Code**: Scansione in tempo reale tramite fotocamera
- **Feedback Visivo**: Conferma immediata di successo/errore
- **Statistiche Live**: Contatori in tempo reale
- **Storico**: Timestamp di ogni check-in

### 🏷️ Categorie
- **Gestione Categorie**: Crea e organizza categorie
- **Sottocategorie**: Sistema gerarchico a due livelli
- **Assegnazione Flessibile**: Assegna più categorie per partecipante

### 📊 Dashboard & Analytics
- **Statistiche Real-time**: Eventi attivi, partecipanti, check-in
- **Visualizzazioni**: Grafici e metriche chiave
- **Filtri Avanzati**: Per data, stato, categoria

### 🔐 Autenticazione & Sicurezza
- **Supabase Auth**: Sistema di autenticazione sicuro
- **Multi-organizzazione**: Isolamento completo dei dati
- **RLS Policies**: Row Level Security su tutte le tabelle
- **Ruoli**: Admin e Staff con permessi granulari

## 🛠️ Stack Tecnologico

### Frontend
- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool ultra-veloce
- **Tailwind CSS** - Utility-first CSS
- **shadcn/ui** - Componenti UI moderni
- **Wouter** - Routing leggero
- **React Hook Form** - Gestione form
- **Zod** - Validazione schema

### Backend & Database
- **Supabase** - Backend-as-a-Service
- **PostgreSQL** - Database relazionale
- **Row Level Security** - Sicurezza a livello di riga

### Librerie Aggiuntive
- **QRCode** - Generazione QR code
- **html5-qrcode** - Scanner QR code
- **date-fns** - Manipolazione date
- **sonner** - Toast notifications

## 🚀 Quick Start

### Prerequisiti
- Node.js 18+
- pnpm (o npm/yarn)
- Account Supabase

### Installazione

1. **Clona il repository**
```bash
git clone https://github.com/fgabelli/eventflow.git
cd eventflow
```

2. **Installa le dipendenze**
```bash
pnpm install
```

3. **Configura le variabili d'ambiente**
Crea un file `.env.local`:
```env
VITE_SUPABASE_URL=https://hokfbsubpcckffqhxfoj.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here
```

4. **Avvia il server di sviluppo**
```bash
pnpm dev
```

5. **Apri il browser**
```
http://localhost:3000
```

## 📁 Struttura del Progetto

```
eventflow/
├── client/
│   ├── src/
│   │   ├── components/
│   │   │   ├── ui/              # Componenti shadcn/ui
│   │   │   └── layout/          # Layout components
│   │   ├── contexts/            # React contexts
│   │   ├── pages/               # Pagine dell'app
│   │   ├── services/            # Service layer (API calls)
│   │   ├── lib/                 # Utilities e configurazioni
│   │   └── App.tsx              # Main app component
│   └── public/                  # Asset statici
├── shared/
│   └── database.types.ts        # TypeScript types dal DB
├── server/                      # Server configuration (se necessario)
└── vercel.json                  # Configurazione Vercel
```

## 🗄️ Schema Database

### Tabelle Principali

#### `organizations`
- `id` (UUID)
- `name` (TEXT)
- `owner_id` (UUID)
- `email_configuration` (JSONB)
- `created_at` (TIMESTAMP)

#### `users`
- `id` (UUID)
- `name` (TEXT)
- `email` (TEXT)
- `role` (TEXT) - admin/staff
- `organization_id` (UUID)
- `avatar` (TEXT)
- `created_at` (TIMESTAMP)

#### `events`
- `id` (UUID)
- `title` (TEXT)
- `description` (TEXT)
- `date` (TEXT)
- `start_time` (TEXT)
- `end_time` (TEXT)
- `location` (TEXT)
- `capacity` (INTEGER)
- `status` (TEXT) - draft/published/completed
- `qr_code_image` (TEXT)
- `form_fields` (JSONB)
- `organization_id` (UUID)
- `created_by` (UUID)

#### `attendees`
- `id` (UUID)
- `name` (TEXT)
- `email` (TEXT)
- `phone` (TEXT)
- `event_id` (UUID)
- `organization_id` (UUID)
- `status` (TEXT) - registered/checked_in/cancelled
- `qr_code` (TEXT)
- `checked_in_at` (TIMESTAMP)
- `profile_data` (JSONB)
- `category_ids` (UUID[])

#### `categories` & `subcategories`
- Sistema di categorizzazione gerarchico

#### `email_campaigns` & `email_logs`
- Gestione campagne email (da implementare)

#### `user_permissions`
- Permessi granulari per utenti staff

## 🎨 Design System

### Colori
- **Primary**: Blue (#3B82F6)
- **Success**: Green (#10B981)
- **Warning**: Orange (#F59E0B)
- **Error**: Red (#EF4444)

### Tipografia
- **Font**: Inter (Google Fonts)
- **Headings**: Bold, varie dimensioni
- **Body**: Regular, 16px base

### Componenti
Tutti i componenti UI sono basati su **shadcn/ui** con personalizzazioni per EventFlow.

## 📝 Funzionalità Future

- [ ] **Campagne Email**: Editor HTML e invio massivo
- [ ] **Team Management**: Inviti e gestione permessi
- [ ] **Analytics Avanzate**: Grafici e report dettagliati
- [ ] **Export PDF**: Badge e certificati partecipanti
- [ ] **Notifiche Push**: Notifiche real-time
- [ ] **Multi-lingua**: i18n completo (IT, EN, ES)
- [ ] **Mobile App**: App nativa per check-in
- [ ] **Integrazione Pagamenti**: Stripe/PayPal
- [ ] **API Pubblica**: REST API per integrazioni

## 🤝 Contribuire

Le contribuzioni sono benvenute! Per favore:

1. Fai un fork del progetto
2. Crea un branch per la tua feature (`git checkout -b feature/AmazingFeature`)
3. Commit le tue modifiche (`git commit -m 'Add some AmazingFeature'`)
4. Push al branch (`git push origin feature/AmazingFeature`)
5. Apri una Pull Request

## 📄 Licenza

Questo progetto è distribuito sotto licenza MIT. Vedi il file `LICENSE` per maggiori dettagli.

## 🔗 Link Utili

- **Repository**: https://github.com/fgabelli/eventflow
- **Supabase Dashboard**: https://supabase.com/dashboard/project/hokfbsubpcckffqhxfoj
- **Deployment Guide**: Vedi [DEPLOYMENT.md](./DEPLOYMENT.md)

## 📧 Supporto

Per domande o supporto:
- Apri una [Issue](https://github.com/fgabelli/eventflow/issues)
- Contatta: fabio@example.com

---

Sviluppato con ❤️ usando React, TypeScript e Supabase

