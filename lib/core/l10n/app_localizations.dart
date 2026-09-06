import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Supported Locales ───────────────────────────────────────────
const _supportedLanguageCodes = ['it', 'en'];

// ─── Locale Provider ─────────────────────────────────────────────
// Priority: 1) Firestore uiLanguage (set after login via initLocaleFromProfile)
//           2) LocalStorage ui_language preference
//           3) ?lang= query param from website link (pre-login)
//           4) Device locale
//           5) Fallback 'en'
final localeProvider = StateProvider<Locale>((ref) {
  // Check ?lang= query parameter (e.g. from EN website linking to /login?lang=en)
  try {
    final langParam = Uri.base.queryParameters['lang'];
    if (langParam != null && _supportedLanguageCodes.contains(langParam)) {
      return Locale(langParam);
    }
  } catch (_) {
    // Uri.base may throw on some platforms; ignore
  }

  // Check LocalStorage ui_language
  try {
    final localLang = html.window.localStorage['ui_language'];
    if (localLang != null && _supportedLanguageCodes.contains(localLang)) {
      return Locale(localLang);
    }
  } catch (_) {
    // LocalStorage may not be available or throw in some environments; ignore
  }

  // Fallback: device locale
  final deviceLocale = ui.PlatformDispatcher.instance.locale;
  if (_supportedLanguageCodes.contains(deviceLocale.languageCode)) {
    return Locale(deviceLocale.languageCode);
  }
  return const Locale('en');
});

// ─── Init locale from Firestore (call once after login) ──────────
Future<void> initLocaleFromProfile(WidgetRef ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final uiLang = doc.data()?['uiLanguage'] as String?;
    if (uiLang != null && _supportedLanguageCodes.contains(uiLang)) {
      ref.read(localeProvider.notifier).state = Locale(uiLang);
      // Persist to LocalStorage
      try {
        html.window.localStorage['ui_language'] = uiLang;
      } catch (_) {}
    }
  } catch (_) {
    // Silently ignore — keep current locale
  }
}

// ─── Persist locale to Firestore ─────────────────────────────────
Future<void> setAndPersistLocale(WidgetRef ref, String languageCode) async {
  ref.read(localeProvider.notifier).state = Locale(languageCode);
  // Persist to LocalStorage
  try {
    html.window.localStorage['ui_language'] = languageCode;
  } catch (_) {}
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'uiLanguage': languageCode});
  } catch (_) {
    // Silently ignore write errors
  }
}

// ─── AppLocalizations ────────────────────────────────────────────

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('it'),
    Locale('en'),
  ];

  // ─── Translation Map ───────────────────────────────────────────
  static final Map<String, Map<String, String>> _translations = {
    'it': _it,
    'en': _en,
  };

  String get(String key) {
    return _translations[locale.languageCode]?[key] ??
        _translations['it']?[key] ??
        key;
  }

  // Shortcut
  String operator [](String key) => get(key);

  // ═══════════════════════════════════════════════════════════════
  // ITALIAN
  // ═══════════════════════════════════════════════════════════════
  static const Map<String, String> _it = {
    // ─── Navbar / General ───
    'app_name': 'Ticketto',
    'features': 'Funzionalità',
    'pricing': 'Prezzi',
    'login': 'Accedi',
    'signup': 'Registrati',
    'start_free': 'Inizia Gratis',
    'logout': 'Esci',

    // ─── Hero ───
    'hero_badge': 'La piattaforma italiana per i tuoi eventi',
    'hero_title': 'Gestisci i tuoi eventi\ncome un professionista',
    'hero_subtitle':
        'Registrazioni, check-in con QR code, gestione accessi e fasce orarie. '
            'Tutto in un\'unica piattaforma semplice e potente.',
    'discover_features': 'Scopri le funzionalità',
    'no_credit_card': 'Nessuna carta di credito richiesta',

    // ─── Social Proof ───
    'social_proof': 'SCELTO DA ORGANIZZATORI IN TUTTA ITALIA',
    'stat_events': 'Eventi gestiti',
    'stat_checkins': 'Check-in effettuati',
    'stat_uptime': 'Uptime',

    // ─── Features ───
    'features_title': 'Tutto quello che serve',
    'features_subtitle':
        'Strumenti professionali per gestire ogni aspetto del tuo evento',
    'feat_qr_title': 'Check-in QR Code',
    'feat_qr_desc':
        'Scansiona e verifica gli accessi in tempo reale con il QR code unico per ogni partecipante.',
    'feat_reg_title': 'Registrazione Pubblica',
    'feat_reg_desc':
        'Pagina di registrazione personalizzata con il branding del tuo evento. Condividi il link e raccogli iscrizioni.',
    'feat_slots_title': 'Fasce Orarie',
    'feat_slots_desc':
        'Gestisci eventi contingentati con fasce orarie e capienza massima per ogni slot.',
    'feat_csv_title': 'Import CSV',
    'feat_csv_desc':
        'Importa centinaia di partecipanti in pochi secondi con un file CSV. Niente più inserimenti manuali.',
    'feat_email_title': 'Email Automatiche',
    'feat_email_desc':
        'Conferma automatica con QR code via email appena un partecipante si registra.',
    'feat_team_title': 'Team & Ruoli',
    'feat_team_desc':
        'Invita il tuo team con ruoli diversi: admin, staff per il check-in, o solo visualizzazione.',

    // ─── How It Works ───
    'how_title': 'Come funziona',
    'how_subtitle': 'Tre semplici passaggi per gestire il tuo evento',
    'how_step1_title': 'Crea il tuo evento',
    'how_step1_desc':
        'Inserisci i dettagli, imposta le fasce orarie e personalizza la registrazione.',
    'how_step2_title': 'Condividi il link',
    'how_step2_desc':
        'Invia il link di registrazione ai tuoi invitati o pubblicalo sui social.',
    'how_step3_title': 'Gestisci il check-in',
    'how_step3_desc':
        'Il giorno dell\'evento, scansiona i QR code con il tuo smartphone.',

    // ─── Pricing ───
    'pricing_title': 'Prezzi semplici e trasparenti',
    'pricing_subtitle': 'Inizia gratis, scala quando cresci',
    'per_month': '/mese',
    'most_popular': 'PIÙ POPOLARE',
    'try_free': 'Prova Gratis',
    'plan_free_1': '1 evento attivo',
    'plan_free_2': 'Fino a 50 partecipanti',
    'plan_free_3': 'Check-in QR code',
    'plan_free_4': 'Pagina registrazione',
    'plan_pro_1': '10 eventi attivi',
    'plan_pro_2': 'Fino a 500 partecipanti',
    'plan_pro_3': 'Import CSV',
    'plan_pro_4': 'Email di conferma',
    'plan_pro_5': '5 membri team',
    'plan_biz_1': 'Eventi illimitati',
    'plan_biz_2': 'Partecipanti illimitati',
    'plan_biz_3': 'Team illimitato',
    'plan_biz_4': 'Analytics avanzati',
    'plan_biz_5': 'Supporto prioritario',

    // ─── CTA ───
    'cta_title': 'Pronto a semplificare\ni tuoi eventi?',
    'cta_subtitle':
        'Unisciti a centinaia di organizzatori che già usano Ticketto.',
    'cta_button': 'Inizia Gratis Ora',
    'cta_note': 'Setup in meno di 2 minuti • Nessuna carta richiesta',

    // ─── Footer ───
    'footer_tagline': 'Gestione eventi, semplificata.',
    'footer_product': 'Prodotto',
    'footer_company': 'Azienda',
    'footer_legal': 'Legale',
    'footer_about': 'Chi siamo',
    'footer_blog': 'Blog',
    'footer_contacts': 'Contatti',
    'footer_api': 'API',
    'footer_privacy': 'Privacy Policy',
    'footer_terms': 'Termini e Condizioni',
    'footer_cookies': 'Cookie',
    'footer_copyright': '© 2026 Ticketto. Tutti i diritti riservati.',

    // ─── Login Screen ───
    'welcome_back': 'Bentornato',
    'create_account': 'Crea il tuo account',
    'sign_in_subtitle': 'Accedi per gestire i tuoi eventi',
    'signup_subtitle': 'Inizia con Ticketto',
    'continue_google': 'Continua con Google',
    'or': 'oppure',
    'full_name': 'Nome completo',
    'email_address': 'Indirizzo email',
    'password': 'Password',
    'sign_in': 'Accedi',
    'sign_up_btn': 'Crea Account',
    'no_account': 'Non hai un account? ',
    'has_account': 'Hai già un account? ',
    'fill_all_fields': 'Compila tutti i campi',
    'enter_name': 'Inserisci il tuo nome',
    'error_user_not_found': 'Nessun account trovato con questa email',
    'error_wrong_password': 'Password errata',
    'error_email_in_use': 'Email già registrata',
    'error_weak_password': 'La password è troppo debole',
    'error_invalid_email': 'Indirizzo email non valido',
    'error_generic': 'Si è verificato un errore. Riprova.',

    // ─── Privacy / Terms / Cookie ───
    'privacy_title': 'Privacy Policy',
    'terms_title': 'Termini e Condizioni',
    'cookie_title': 'Cookie Policy',
    'last_updated': 'Ultimo aggiornamento',
    'back': 'Indietro',

    // ─── Cookie Consent Banner ───
    'cookie_banner_title': 'Utilizziamo i cookie',
    'cookie_banner_body': 'Utilizziamo cookie tecnici necessari e, con il tuo consenso, cookie di marketing per migliorare la tua esperienza e mostrarti contenuti pertinenti. Puoi cambiare idea in qualsiasi momento nelle Impostazioni.',
    'cookie_accept': 'Accetta tutti',
    'cookie_reject': 'Solo necessari',

    // ─── Onboarding Tutorial ───
    'tutorial_welcome_title': 'Benvenuto su Ticketto! 🎉',
    'tutorial_welcome_body': 'Questa è la tua dashboard. Da qui puoi monitorare tutti i tuoi eventi a colpo d\'occhio.',
    'tutorial_events_title': 'I tuoi eventi',
    'tutorial_events_body': 'Qui trovi tutti i tuoi eventi. Crea il tuo primo evento con il pulsante +.',
    'tutorial_attendees_title': 'Partecipanti',
    'tutorial_attendees_body': 'Gestisci i partecipanti: importa CSV, invia email di conferma e visualizza lo stato.',
    'tutorial_checkin_title': 'Check-in QR',
    'tutorial_checkin_body': 'Il giorno dell\'evento, scansiona i QR code per verificare gli accessi in tempo reale.',
    'tutorial_settings_title': 'Impostazioni',
    'tutorial_settings_body': 'Configura il tuo team, collega Stripe per i pagamenti e personalizza le preferenze.',
    'tutorial_done_title': 'Sei pronto! 🚀',
    'tutorial_done_body': 'Crea il tuo primo evento per iniziare.',
    'tutorial_next': 'Avanti',
    'tutorial_skip': 'Salta',
    'tutorial_done_btn': 'Crea il tuo primo evento',
    'tutorial_step': 'Passo',
    'tutorial_of': 'di',
    'tutorial_restart': 'Rilancia tutorial',

    // ─── Contextual Help Tips ───
    // Event Creation
    'help_event_title': 'Il nome del tuo evento. Sarà visibile ai partecipanti nella pagina di registrazione e nelle email di conferma.',
    'help_event_description': 'Una descrizione dettagliata dell\'evento. Sarà visibile nella pagina di registrazione pubblica.',
    'help_event_date': 'La data e l\'ora di inizio dell\'evento. I partecipanti la vedranno nella conferma e nel pass Wallet.',
    'help_event_location': 'Il luogo dell\'evento. Verrà mostrato nella pagina di registrazione e nel pass Wallet.',
    'help_max_attendees': 'Il numero massimo di partecipanti. Una volta raggiunto il limite, le iscrizioni verranno automaticamente chiuse.',
    'help_paid_event': 'Abilita la vendita di biglietti. Dovrai collegare un account Stripe nelle Impostazioni per ricevere i pagamenti.',
    'help_event_price': 'Il prezzo del biglietto in euro. I pagamenti vengono elaborati tramite Stripe e accreditati direttamente sul tuo account.',
    'help_time_slots': 'Dividi l\'evento in fasce orarie con posti limitati. Utile per visite guidate, workshop o appuntamenti. Ogni partecipante sceglie uno slot durante l\'iscrizione.',
    'help_custom_fields': 'Aggiungi campi extra al modulo di registrazione (es. taglia t-shirt, allergie, azienda). I dati raccolti saranno visibili nella lista partecipanti.',
    'help_event_status': 'Bozza: visibile solo a te. Pubblicato: le iscrizioni sono aperte. Completato: l\'evento è concluso.',
    'help_registration_link': 'Condividi questo link per permettere ai partecipanti di iscriversi. Funziona anche senza account Ticketto.',
    'help_ai_creator': 'L\'AI genera automaticamente titolo, descrizione, data, luogo e impostazioni dell\'evento a partire dalla tua descrizione.',
    // Attendees
    'help_attendees_list': 'Lista di tutti i partecipanti iscritti. Puoi filtrarli per stato (confermato, in attesa, check-in effettuato).',
    'help_import_csv': 'Importa una lista di partecipanti da un file CSV. Il file deve contenere le colonne: nome, cognome, email.',
    'help_send_confirmation': 'Invia email di conferma con QR code e pass Wallet (Apple/Google) a tutti i partecipanti confermati.',
    'help_attendee_status': 'Confermato: iscritto e pagamento ricevuto. In attesa: in attesa di pagamento. Checked-in: ha effettuato l\'accesso.',
    // Check-in
    'help_checkin_qr': 'Scansiona il QR code del partecipante per registrare l\'accesso. Funziona anche offline.',
    'help_checkin_manual': 'Cerca un partecipante per nome o email e registra l\'accesso manualmente.',
    // Dashboard
    'help_dashboard_stats': 'Panoramica in tempo reale dei tuoi eventi: totale eventi, partecipanti, eventi attivi e ricavi.',
    'help_quick_actions': 'Azioni rapide per le operazioni più comuni: crea evento, check-in, gestisci partecipanti.',
    // Settings
    'help_stripe_connect': 'Collega il tuo account Stripe per ricevere i pagamenti dei biglietti direttamente sul tuo conto bancario.',
    'help_team': 'Invita membri del team per gestire gli eventi insieme. Ogni membro può creare eventi e gestire partecipanti.',
    'help_language': 'Cambia la lingua dell\'interfaccia. La piattaforma supporta Italiano e Inglese.',
    // Subscription
    'help_subscription': 'Il tuo piano determina il numero massimo di eventi attivi e partecipanti. Puoi fare upgrade in qualsiasi momento.',

    // ─── About ───
    'about_hero_title': 'Semplifichiamo la\ngestione degli eventi',
    'about_hero_subtitle': 'Ticketto nasce dalla passione per la tecnologia e la volontà di rendere la gestione degli eventi accessibile a tutti.',
    'about_mission_title': 'La nostra missione',
    'about_mission_body': 'Crediamo che organizzare un evento non debba essere complicato. Che tu stia gestendo una conferenza, un workshop, un festival o un evento aziendale, meriti strumenti professionali che funzionano. Ticketto è stato creato per eliminare la complessità dalla gestione degli eventi, permettendoti di concentrarti su ciò che conta davvero: creare esperienze memorabili per i tuoi partecipanti.',
    'about_values_title': 'I nostri valori',
    'about_val1_title': 'Semplicità',
    'about_val1_desc': 'Interfacce intuitive che non richiedono formazione. Setup in meno di 2 minuti.',
    'about_val2_title': 'Sicurezza',
    'about_val2_desc': 'I tuoi dati sono protetti con crittografia enterprise. GDPR compliant al 100%.',
    'about_val3_title': 'Passione',
    'about_val3_desc': 'Costruito con cura da organizzatori di eventi per organizzatori di eventi.',
    'about_tech_title': 'Tecnologia',
    'about_tech_body': 'Ticketto è costruito con le migliori tecnologie disponibili: Flutter per un\'esperienza cross-platform fluida, Firebase per affidabilità e scalabilità, e Stripe per pagamenti sicuri. La nostra architettura cloud-native garantisce performance elevate e disponibilità 24/7.',

    // ─── Contact ───
    'contact_title': 'Contattaci',
    'contact_subtitle': 'Hai domande, suggerimenti o bisogno di assistenza? Siamo qui per aiutarti.',
    'contact_email_title': 'Informazioni generali',
    'contact_email_desc': 'Per domande generali su Ticketto e i nostri servizi.',
    'contact_support_title': 'Supporto tecnico',
    'contact_support_desc': 'Problemi tecnici o assistenza con il tuo account.',
    'contact_privacy_title': 'Privacy e dati',
    'contact_privacy_desc': 'Per richieste relative alla privacy e al trattamento dati.',
    'contact_faq_title': 'Domande frequenti',

    // ─── App Screens ───
    'events': 'Eventi',
    'new_event': 'Nuovo Evento',
    'create_event': 'Crea Evento',
    'delete_event': 'Elimina Evento',
    'delete_confirm': 'Sei sicuro? Questa azione non può essere annullata.',
    'cancel': 'Annulla',
    'delete': 'Elimina',
    'save': 'Salva',
    'add': 'Aggiungi',
    'edit': 'Modifica',
    'close': 'Chiudi',
    'filter_all': 'Tutti',
    'filter_published': 'Pubblicati',
    'filter_draft': 'Bozze',
    'filter_completed': 'Completati',
    'no_events': 'Nessun evento',
    'no_events_filtered': 'Nessun evento trovato',
    'create_first_event': 'Crea il tuo primo evento per iniziare',
    'publish': 'Pubblica',
    'mark_complete': 'Segna come completato',
    'paid_event': 'Evento a pagamento',
    'add_time_slot': 'Aggiungi Fascia Oraria',
    'add_field': 'Aggiungi Campo',
    'event_name': 'Nome evento',
    'location': 'Luogo',
    'description': 'Descrizione',
    'max_attendees': 'Max partecipanti',
    'price': 'Prezzo',
    'event_saved': 'Evento salvato',
    'event_not_found': 'Evento non trovato',
    'back_to_events': 'Torna agli eventi',
    'export_csv': 'Esporta CSV',
    'duplicate_event': 'Duplica Evento',
    'no_attendees_export': 'Nessun partecipante da esportare',
    'print_qr': 'Stampa QR Code',

    // ─── Settings ───
    'settings': 'Impostazioni',
    'profile': 'Profilo',
    'organization': 'Organizzazione',
    'plan_label': 'Piano',
    'team_members': 'Membri del team',
    'manage_roles': 'Gestisci ruoli e permessi',
    'switch_org': 'Cambia Organizzazione',
    'payments': 'Pagamenti',
    'notifications': 'Notifiche',
    'info': 'Info',
    'sign_out': 'Esci',
    'sign_out_confirm': 'Sei sicuro di voler uscire?',
    'language': 'Lingua',
    'italian': 'Italiano',
    'english': 'Inglese',

    // ─── Stripe ───
    'connect_stripe': 'Collega Stripe',
    'stripe_subtitle': 'Ricevi pagamenti per i tuoi biglietti',
    'stripe_pending': 'Setup Stripe in corso',
    'stripe_pending_desc': 'Completa la configurazione del tuo account',
    'stripe_complete_btn': 'Completa',
    'stripe_connected': 'Stripe Collegato',
    'stripe_connecting': 'Connessione a Stripe in corso...',
    'stripe_error': 'Errore nella connessione a Stripe',
    'stripe_how_title': 'Come funziona',
    'stripe_step1_title': 'Premi "Collega Stripe"',
    'stripe_step1_desc': 'Verrai reindirizzato alla pagina di registrazione Stripe.',
    'stripe_step2_title': 'Completa la registrazione',
    'stripe_step2_desc': 'Stripe ti chiederà dati personali, indirizzo, documento di identità e coordinate bancarie (IBAN).',
    'stripe_step3_title': 'Inizia a incassare',
    'stripe_step3_desc': 'Una volta verificato, i pagamenti dei biglietti verranno accreditati direttamente sul tuo conto.',
    'stripe_fee_note': 'Su ogni vendita viene applicata una commissione piattaforma del 5% + le commissioni Stripe standard.',
    'stripe_security_note': 'Ticketto non memorizza mai i dati della tua carta o del tuo conto. Tutto è gestito in sicurezza da Stripe.',

    // ─── Attendees ───
    'attendees': 'Partecipanti',
    'add_attendee': 'Aggiungi Partecipante',
    'remove_attendee': 'Rimuovi Partecipante',
    'remove_confirm': 'Sei sicuro di voler rimuovere questo partecipante?',
    'remove': 'Rimuovi',
    'confirm': 'Conferma',
    'cancel_registration': 'Annulla Registrazione',
    'import_csv': 'Importa da CSV',
    'choose_file': 'Scegli File',
    'import_attendees': 'Importa Partecipanti',
    'file_empty': 'Il file è vuoto',
    'file_error': 'Impossibile leggere il file',
    'no_valid_attendees': 'Nessun partecipante valido trovato nel file',
    'manage': 'Gestisci',
    'search': 'Cerca',
    'checked_in': 'Check-in effettuato',
    'not_checked_in': 'Non registrato',
    'select_event': 'Seleziona un evento',
    'choose_event_attendees': 'Scegli un evento per visualizzare i partecipanti',
    'search_attendees': 'Cerca partecipanti...',
    'event_label': 'Evento',
    'first_name': 'Nome *',
    'last_name': 'Cognome *',
    'email_label': 'Email *',
    'phone_label': 'Telefono',
    'all_confirmed': 'Tutti i partecipanti saranno registrati come Confermati.',
    'select_time_slot': 'Seleziona una fascia oraria',
    'email_field': 'Indirizzo Email *',

    // ─── Navigation / Sidebar ───
    'nav_dashboard': 'Dashboard',
    'nav_events': 'Eventi',
    'nav_attendees': 'Partecipanti',
    'nav_checkin': 'Check-in',
    'nav_settings': 'Impostazioni',
    'upgrade': 'Upgrade',

    // ─── Check-in ───
    'checkin_title': 'Check-in',
    'select_event_checkin': 'Seleziona un evento per il check-in',
    'search_name_email': 'Cerca per nome o email...',
    'select_event_label': 'Seleziona Evento',
    'select_event_first': 'Seleziona prima un evento',
    'attendee_not_found': 'Partecipante non trovato',
    'already_checked_in': 'ha già effettuato il check-in',
    'checked_in_success': 'check-in effettuato!',
    'total': 'Totale',
    'remaining': 'Rimanenti',
    'no_attendees_found': 'Nessun partecipante trovato',
    'check_in_btn': 'Check In',
    'event_duplicated': 'Evento duplicato! Apertura copia...',
    'event_saved_msg': 'Evento salvato',

    // ─── Team ───
    'team': 'Team',
    'invite_member': 'Invita Membro',
    'role_admin': 'Admin',
    'role_staff': 'Staff',
    'role_viewer': 'Visualizzatore',
    'remove_member': 'Rimuovi membro',

    // ─── Dashboard ───
    'good_morning': 'Buongiorno',
    'good_afternoon': 'Buon pomeriggio',
    'good_evening': 'Buonasera',
    'total_events': 'Eventi Totali',
    'attendees_stat': 'Partecipanti',
    'active_events': 'Eventi Attivi',
    'revenue': 'Ricavi',
    'active_trend': 'attivi',
    'all_events_trend': 'Tutti gli eventi',
    'published_trend': 'Pubblicati',
    'total_trend': 'Totale',
    'quick_actions': 'Azioni Rapide',
    'recent_events': 'Eventi Recenti',
    'view_all': 'Vedi tutti',
    'no_events_yet': 'Nessun evento ancora',
    'create_event_btn': 'Crea Evento',
    'no_location': 'Nessuna sede',
    'month_jan': 'Gen',
    'month_feb': 'Feb',
    'month_mar': 'Mar',
    'month_apr': 'Apr',
    'month_may': 'Mag',
    'month_jun': 'Giu',
    'month_jul': 'Lug',
    'month_aug': 'Ago',
    'month_sep': 'Set',
    'month_oct': 'Ott',
    'month_nov': 'Nov',
    'month_dec': 'Dic',

    // ─── Public Registration ───
    'event_not_found_title': 'Evento non trovato',
    'event_not_found_desc': 'Questo evento non esiste o è stato rimosso.',
    'registration_closed_title': 'Registrazioni Chiuse',
    'registration_closed_desc': 'Le registrazioni per questo evento non sono attualmente aperte.',
    'event_full_warning': 'Questo evento è completo. Non si accettano più registrazioni.',
    'register_title': 'Registrati',
    'register_subtitle': 'Compila i tuoi dati per registrarti a questo evento.',
    'first_name_reg': 'Nome *',
    'last_name_reg': 'Cognome *',
    'email_reg': 'Email *',
    'phone_reg': 'Telefono (opzionale)',
    'select_time_slot_reg': 'Seleziona una Fascia Oraria *',
    'slot_full': 'Completo',
    'slot_left': 'rimasti',
    'register_now': 'Registrati Ora',
    'required_field': 'Obbligatorio',
    'invalid_email': 'Email non valida',
    'please_select_slot': 'Seleziona una fascia oraria.',
    'slot_full_error': 'Questa fascia oraria è completa.',
    'event_full_error': 'Questo evento è completo.',
    'already_registered': 'Questa email è già registrata per questo evento.',
    'registration_failed': 'Registrazione fallita',
    'payment_init_failed': 'Inizializzazione pagamento fallita',
    'registration_success_title': 'Registrazione Completata! 🎉',
    'registration_success_desc': 'Sei registrato con successo a',
    'save_qr': 'Salva il QR code qui sotto per il check-in all\'evento.',
    'your_qr': 'Il tuo QR Code',
    'registered_label': 'registrati',
    'confirmation_email': 'Un\'email di conferma è stata inviata al tuo indirizzo.',

    // ─── Payment & Registration Buttons ───
    'pay_and_register': 'Paga €{amount} e Registrati',
    'pay_and_register_group': 'Paga €{amount} e Registra {count} persone',
    'register_group': 'Registra {count} persone',
    'not_enough_spots': 'Non ci sono abbastanza posti disponibili.',
    'payment_complete_title': 'Pagamento Completato!',
    'payment_complete_desc': 'Il tuo biglietto per "{title}" è stato acquistato con successo.',
    'payment_email_notice': 'Riceverai un\'email di conferma con il QR code del tuo biglietto.',
    'amount_paid': 'Importo pagato',
    'group_registration_label': 'Registrazione di gruppo',
    'group_registration_desc': 'Consenti la prenotazione per più persone',
    'custom_fields_label': 'Campi Registrazione',
    'custom_fields_desc': 'Aggiungi campi personalizzati al form di iscrizione',
    'options_count': '{count} opzioni',
    'options_label': 'Opzioni',
    'show_chatbot_label': 'Assistente AI',
    'show_chatbot_desc': 'Mostra l\'assistente in basso a destra',
    'realtime_notifications_label': 'Notifiche in tempo reale',
    'realtime_notifications_desc': 'Ricevi un\'email per ogni nuova iscrizione',
    'available_pro_business': 'Disponibile nei piani Pro e Business',
    'group_max_hint': 'Puoi registrare fino a {max} persone in una sola prenotazione.',
    'add_person': 'Aggiungi persona',
    'person_label': 'Persona',

    'event_title_label': 'Titolo Evento *',
    'description_label': 'Descrizione',
    'event_desc_hint': 'Descrizione evento...',
    'date_label': 'Data',
    'time_label': 'Ora',
    'location_label': 'Sede',
    'location_hint': 'Indirizzo sede o Online',
    'max_attendees_label': 'Partecipanti Massimi',
    'enable_pricing': 'Abilita tariffazione biglietti',
    'event_color': 'Colore Evento',
    'custom_hex_color': 'Codice HEX (es. #1B5E9E)',
    'color_white_minimal': 'Bianco Minimal',
    'show_attendees_count': 'Mostra posti disponibili',
    'show_attendees_count_desc': 'Mostra il conteggio iscritti sulla pagina di registrazione',
    'org_branding': 'Organizzazione & Branding',
    'org_name_label': 'Nome Organizzazione',
    'org_logo_label': 'Logo Organizzazione',
    'org_logo_url_hint': 'URL del logo (o carica file)',
    'upload_logo_btn': 'Carica Logo',
    'save_changes': 'Salva Modifiche',
    'powered_by_ticketto': 'Powered by Ticketto',
    'time_slot_booking': 'Prenotazione Fasce Orarie',
    'time_slot_desc': 'Limita l\'accesso per finestre temporali',
    'slot_label_field': 'Nome Fascia *',
    'slot_hint': 'es. Sessione Mattutina',
    'start_label': 'Inizio',
    'end_label': 'Fine',
    'max_capacity': 'Capienza Massima',
    'registration_link': 'Link Registrazione',
    'link_copied': 'Link registrazione copiato!',
    'available_label': 'disponibili',
    'registrations_chart': 'Registrazioni (ultimi 7 giorni)',
    'error_generic_short': 'Errore',

    // ─── Team Screen ───
    'no_team_members': 'Nessun membro nel team',
    'members_stat': 'Membri',
    'admins_stat': 'Admin',
    'staff_stat': 'Staff',
    'invite_team_member': 'Invita Membro del Team',
    'add_to_team_subtitle': 'Aggiungi un nuovo membro a',
    'role_label': 'Ruolo',
    'add_member_btn': 'Aggiungi Membro',
    'added_as_member': 'aggiunto come',
    'make_role': 'Imposta come',
    'you_label': 'Tu',
    'role_admin_desc': 'Può gestire eventi, partecipanti e team',
    'role_staff_desc': 'Può gestire eventi e fare check-in',
    'role_viewer_desc': 'Può visualizzare eventi e partecipanti (sola lettura)',
    'role_owner_desc': 'Accesso completo',

    // ─── Attendees Screen ───
    'import_csv_tooltip': 'Importa CSV',
    'error_loading_attendees': 'Errore caricamento partecipanti',
    'no_results_found': 'Nessun risultato trovato',
    'no_attendees_yet_short': 'Nessun partecipante ancora',
    'total_stat': 'Totale',
    'confirmed_stat': 'Confermati',
    'pending_stat': 'In attesa',
    'checked_in_stat': 'Check-in',
    'import_x': 'Importa',
    'importing_attendees': 'Importazione partecipanti...',
    'import_error': 'Errore importazione',
    'imported_success': 'partecipanti importati con successo!',
    'imported_skipped': 'saltati per limiti di capienza',
    'and_x_more': 'e altri',

    // ─── Event Detail Screen ───
    'edit_event': 'Modifica Evento',
    'share_link_tooltip': 'Condividi Link Registrazione',
    'export_error': 'Errore esportazione',
    'no_attendees_detail': 'Nessun partecipante ancora',
    'hide_qr': 'Nascondi QR Code',
    'show_qr': 'Mostra QR Code',
    'copy_label': 'Copia',
    'link_copied_short': 'Link copiato!',
    'analytics_label': 'Analitiche',
    'attendees_stat_label': 'Partecipanti',
    'revenue_stat_label': 'Ricavi',
    'capacity_stat_label': 'Capienza',
    'event_title_hint': 'Titolo evento',
    'venue_hint': 'Sede',
    'spots_label': 'posti',
    'scan_to_register': 'Scansiona per registrarsi',

    // ─── Bug Fixes - Additional Keys ───
    'event_created_success': 'Evento creato con successo!',
    'entry_qr_code': 'QR Code Ingresso',
    'category_label': 'Categoria',
    'registered_at_label': 'Registrato il',
    'checked_in_at_label': 'Check-in alle',
    'time_slot_label': 'Fascia Oraria',
    'status_confirmed': 'CONFERMATO',
    'status_pending': 'IN ATTESA',
    'status_canceled': 'ANNULLATO',
    'checked_in_label': 'CHECK-IN',
    'edit_date_label': 'Data Evento',
    'edit_time_label': 'Ora Evento',
    'additional_data': 'Dati Aggiuntivi',
    'edit_attendee': 'Modifica Partecipante',
    'attendee_updated': 'Partecipante aggiornato',
    'date_at': 'alle',
    'qr_print_hint': 'Stampa o esponi questo QR code nella sede per la registrazione in loco.',
    'time_slots_count': 'fasce',

    // ─── i18n: Event Language ───
    'event_language_label': 'Lingua Evento',
    'event_language_hint': 'La lingua usata per la pagina di registrazione, le email e i pass Wallet dei partecipanti.',
    'event_type_label': 'Tipologia Evento',
    'event_type_hint': 'Puoi organizzare un evento fisico o un webinar/diretta online.',
    'unlimited_attendees': 'Illimitati',
    'max_plan_attendees': 'Max {max} (piano {plan})',

    // ─── i18n: Hardcoded strings cleanup ───
    'start_now': 'Inizia Subito',
    'org_already_exists': 'Hai già un workspace attivo. Ti stiamo reindirizzando.',
    'print_single_badge': 'Stampa Badge Singolo',
    'generating_backup_csv': 'Generazione CSV di backup...',
    'select_event_first_msg': 'Seleziona prima un evento.',
    'generating_pdf': 'Generazione PDF in corso...',
    'no_attendees_print': 'Nessun partecipante da stampare.',
    'print_error': 'Errore di stampa',
    'csv_note_title': 'ℹ️  Note',
    'csv_prepare_instructions': 'Prepara un file CSV con le seguenti colonne:',
    'csv_note_headers': 'La prima riga deve contenere le intestazioni delle colonne',
    'csv_note_email_mandatory': 'email è l\'unica colonna obbligatoria',
    'csv_note_phone_optional': 'phone è opzionale (lascia vuoto se non disponibile)',
    'csv_note_time_slot': 'time_slot è opzionale: usa il nome della fascia per assegnamento automatico',
    'csv_note_no_slot': 'Senza colonna time_slot, puoi scegliere una fascia durante l\'importazione',
    'csv_note_format': 'Formato accettato: .csv o .txt',
    'csv_note_duplicates': 'Email duplicate verranno sovrascritte',
    'csv_note_aliases_title': 'Alias colonne accettati:',
    'csv_note_alias_first_name': 'first_name → nome, firstname, name',
    'csv_note_alias_last_name': 'last_name → cognome, lastname, surname',
    'csv_note_alias_email': 'email → e-mail, mail',
    'csv_note_alias_phone': 'phone → telefono, tel, cellulare, mobile',
    'csv_note_alias_time_slot': 'time_slot → timeslot, fascia, fascia_oraria, slot',
    'csv_no_email_column': 'Impossibile trovare una colonna email. Assicurati che il tuo CSV abbia le intestazioni.',
    'assign_time_slot': 'Assegna a Fascia Oraria *',
    'preview_label': 'Anteprima:',
    'custom_field_type_text': 'Testo',
    'custom_field_type_select': 'Selezione',
    'custom_field_type_number': 'Numero',
    'custom_field_type_phone': 'Telefono',

    // ─── Promozioni & Voucher ───
    'nav_promotions': 'Promozioni',
    'promotions_title': 'Promozioni & Convenzioni',
    'promotions_subtitle': 'Gestisci offerte speciali, collaborazioni partner e coupon con QR code sequenziali.',
    'new_promotion_btn': 'Nuova Offerta',
    'redeem_voucher_btn': 'Convalida / Riscatta in Cassa',
    'no_promotions_yet': 'Nessuna promozione creata',
    'no_promotions_desc': 'Crea offerte speciali o convenzioni (es. 2x1 con palestre o hotel partner) e genera coupon con QR code pronti per la stampa.',
    'active_promos_count': 'Offerte Attive',
    'total_vouchers': 'Voucher Totali',
    'claimed_vouchers': 'Attivati',
    'redeemed_vouchers': 'Riscattati',
    'voucher_code': 'Codice Voucher',
    'is_partnership_toggle': 'È una collaborazione con un partner esterno?',
    'is_partnership_subtitle': 'Se disattivato, sarà una promozione interna della tua struttura con solo il tuo logo.',
    'partner_name': 'Nome Attività Partner',
    'partner_hint': 'es. Palestra FitCenter, Hotel Riviera...',
    'partner_logo_label': 'Logo del Partner (Opzionale)',
    'partner_logo_hint': 'URL immagine o carica file PNG/JPG',
    'upload_partner_logo': 'Carica Logo Partner',
    'org_logo_preview': 'Logo Struttura',
    'partner_logo_preview': 'Logo Partner',
    'both_logos_printed': 'Entrambi i loghi appariranno affiancati sui coupon',
    'single_logo_printed': 'Apparirà solo il logo della tua struttura sui coupon',
    'offer_title': 'Titolo Offerta',
    'offer_title_hint': 'es. Offerta 2x1 Ingresso SPA',
    'offer_description': 'Descrizione e Condizioni',
    'offer_type': 'Tipo di Offerta',
    'discount_value': 'Valore Sconto',
    'offer_price': 'Prezzo di Riferimento (€)',
    'payment_method': 'Modalità di Pagamento',
    'payment_at_venue': 'Paga in struttura (alla reception)',
    'payment_online': 'Paga online subito (Stripe)',
    'payment_free': 'Gratuito / Omaggio',
    'code_prefix': 'Prefisso Codice',
    'code_prefix_hint': 'es. FIT, SPA, PROMO',
    'vouchers_quantity': 'Quantità Voucher da generare',
    'vouchers_quantity_hint': 'es. 25, 50, 100',
    'expiration_date': 'Data di Scadenza',
    'voucher_validity_label': 'Validità Voucher dalla Registrazione',
    'voucher_validity_helper': 'Il voucher scadrà esattamente dopo i giorni indicati dalla registrazione online del cliente.',
    'campaign_deadline_label': 'Termine Registrazione / Fine Accordo (Opzionale)',
    'campaign_deadline_helper': 'Data limite entro cui il cliente può attivare il coupon. I voucher già registrati resteranno validi per la durata impostata.',
    'enable_registration_deadline': 'Imposta scadenza per registrarsi',
    'no_registration_deadline': 'Senza scadenza (accordo sempre aperto)',
    'campaign_deadline_note': 'I voucher registrati prima di questa data rimangono validi per tutta la durata impostata anche dopo la chiusura.',
    'promo_registration_closed_title': 'Registrazioni Chiuse',
    'promo_registration_closed_desc': 'Il termine per attivare nuovi coupon per questo accordo è scaduto.',
    'deal_closed_voucher_valid': 'Accordo chiuso a nuove registrazioni, ma voucher cliente valido.',
    'validity_days_unit': 'giorni',
    'voucher_expires_on': 'Scadenza Voucher',
    'voucher_days_remaining': 'giorni rimanenti',
    'voucher_expired_alert': 'Voucher Scaduto',
    'linked_event_optional': 'Collega a un Evento (Opzionale)',
    'linked_event_none': 'Nessun evento (Accesso Struttura / Servizio Generale)',
    'print_coupons_pdf': 'Stampa Coupon PDF',
    'print_coupons_desc': 'Genera un foglio A4 pronto da stampare con coupon e QR code univoci',
    'generate_more_vouchers': 'Aggiungi Voucher',
    'voucher_status_available': 'Disponibile',
    'voucher_status_claimed': 'Attivato da Cliente',
    'voucher_status_redeemed': 'Riscattato',
    'voucher_status_cancelled': 'Annullato',
    'redeem_dialog_title': 'Convalida & Riscatto Voucher in Cassa',
    'redeem_dialog_hint': 'Cerca per codice voucher, nome, cognome o email del cliente, oppure scansiona il QR code',
    'redeem_code_label': 'Codice Voucher o Dati Cliente (Nome, Email)',
    'redeem_search_btn': 'Cerca Codice',
    'redeem_confirm_btn': 'Conferma Riscatto',
    'redeem_success': 'Voucher riscattato con successo!',
    'redeem_already_used': 'Questo voucher è già stato utilizzato',
    'redeem_expired': 'Questo voucher è scaduto',
    'redeem_not_found': 'Codice voucher non trovato',
    'redeem_venue_payment_alert': 'Importo da incassare in struttura:',
    'public_voucher_title': 'Attivazione Offerta Speciale',
    'public_voucher_valid_until': 'Valido fino al',
    'public_voucher_form_title': 'Inserisci i tuoi dati per attivare la promozione',
    'public_voucher_activate_venue': 'Attiva Offerta (Paga in struttura)',
    'public_voucher_activate_online': 'Paga e Attiva Offerta',
    'public_voucher_success_title': 'Offerta Attivata!',
    'public_voucher_success_desc': 'Il tuo voucher è stato attivato con successo. Presenta questo pass o il coupon alla reception.',
    'public_voucher_already_claimed': 'Offerta già attivata',
    'public_voucher_already_redeemed': 'Questo voucher è già stato utilizzato presso la struttura.',
    'public_voucher_expired': 'Spiacenti, questa offerta è scaduta.',
  };

  // ═══════════════════════════════════════════════════════════════
  // ENGLISH
  // ═══════════════════════════════════════════════════════════════
  static const Map<String, String> _en = {
    // ─── Navbar / General ───
    'app_name': 'Ticketto',
    'features': 'Features',
    'pricing': 'Pricing',
    'login': 'Login',
    'signup': 'Sign Up',
    'start_free': 'Start Free',
    'logout': 'Logout',

    // ─── Hero ───
    'hero_badge': 'The Italian platform for your events',
    'hero_title': 'Manage your events\nlike a pro',
    'hero_subtitle':
        'Registrations, QR code check-in, access control and time slots. '
            'Everything in one simple and powerful platform.',
    'discover_features': 'Discover features',
    'no_credit_card': 'No credit card required',

    // ─── Social Proof ───
    'social_proof': 'TRUSTED BY ORGANIZERS ACROSS ITALY',
    'stat_events': 'Events managed',
    'stat_checkins': 'Check-ins done',
    'stat_uptime': 'Uptime',

    // ─── Features ───
    'features_title': 'Everything you need',
    'features_subtitle':
        'Professional tools to manage every aspect of your event',
    'feat_qr_title': 'QR Code Check-in',
    'feat_qr_desc':
        'Scan and verify access in real time with a unique QR code for every attendee.',
    'feat_reg_title': 'Public Registration',
    'feat_reg_desc':
        'Custom registration page with your event branding. Share the link and collect sign-ups.',
    'feat_slots_title': 'Time Slots',
    'feat_slots_desc':
        'Manage timed events with slots and maximum capacity per session.',
    'feat_csv_title': 'CSV Import',
    'feat_csv_desc':
        'Import hundreds of attendees in seconds with a CSV file. No more manual entry.',
    'feat_email_title': 'Automatic Emails',
    'feat_email_desc':
        'Automatic confirmation with QR code via email as soon as an attendee registers.',
    'feat_team_title': 'Team & Roles',
    'feat_team_desc':
        'Invite your team with different roles: admin, check-in staff, or view-only.',

    // ─── How It Works ───
    'how_title': 'How it works',
    'how_subtitle': 'Three simple steps to manage your event',
    'how_step1_title': 'Create your event',
    'how_step1_desc':
        'Enter details, set up time slots and customize registration.',
    'how_step2_title': 'Share the link',
    'how_step2_desc':
        'Send the registration link to your guests or post it on social media.',
    'how_step3_title': 'Manage check-in',
    'how_step3_desc':
        'On the day of the event, scan QR codes with your smartphone.',

    // ─── Pricing ───
    'pricing_title': 'Simple and transparent pricing',
    'pricing_subtitle': 'Start free, scale as you grow',
    'per_month': '/month',
    'most_popular': 'MOST POPULAR',
    'try_free': 'Try Free',
    'plan_free_1': '1 active event',
    'plan_free_2': 'Up to 50 attendees',
    'plan_free_3': 'QR code check-in',
    'plan_free_4': 'Registration page',
    'plan_pro_1': '10 active events',
    'plan_pro_2': 'Up to 500 attendees',
    'plan_pro_3': 'CSV import',
    'plan_pro_4': 'Confirmation emails',
    'plan_pro_5': '5 team members',
    'plan_biz_1': 'Unlimited events',
    'plan_biz_2': 'Unlimited attendees',
    'plan_biz_3': 'Unlimited team',
    'plan_biz_4': 'Advanced analytics',
    'plan_biz_5': 'Priority support',

    // ─── CTA ───
    'cta_title': 'Ready to simplify\nyour events?',
    'cta_subtitle':
        'Join hundreds of organizers already using Ticketto.',
    'cta_button': 'Start Free Now',
    'cta_note': 'Setup in less than 2 minutes • No card required',

    // ─── Footer ───
    'footer_tagline': 'Event management, simplified.',
    'footer_product': 'Product',
    'footer_company': 'Company',
    'footer_legal': 'Legal',
    'footer_about': 'About us',
    'footer_blog': 'Blog',
    'footer_contacts': 'Contact',
    'footer_api': 'API',
    'footer_privacy': 'Privacy Policy',
    'footer_terms': 'Terms & Conditions',
    'footer_cookies': 'Cookies',
    'footer_copyright': '© 2026 Ticketto. All rights reserved.',

    // ─── Login Screen ───
    'welcome_back': 'Welcome back',
    'create_account': 'Create account',
    'sign_in_subtitle': 'Sign in to manage your events',
    'signup_subtitle': 'Get started with Ticketto',
    'continue_google': 'Continue with Google',
    'or': 'or',
    'full_name': 'Full name',
    'email_address': 'Email address',
    'password': 'Password',
    'sign_in': 'Sign In',
    'sign_up_btn': 'Create Account',
    'no_account': "Don't have an account? ",
    'has_account': 'Already have an account? ',
    'fill_all_fields': 'Please fill in all fields',
    'enter_name': 'Please enter your name',
    'error_user_not_found': 'No account found with this email',
    'error_wrong_password': 'Incorrect password',
    'error_email_in_use': 'Email already registered',
    'error_weak_password': 'Password is too weak',
    'error_invalid_email': 'Invalid email address',
    'error_generic': 'An error occurred. Please try again.',

    // ─── Privacy / Terms / Cookie ───
    'privacy_title': 'Privacy Policy',
    'terms_title': 'Terms & Conditions',
    'cookie_title': 'Cookie Policy',
    'last_updated': 'Last updated',
    'back': 'Back',

    // ─── Cookie Consent Banner ───
    'cookie_banner_title': 'We use cookies',
    'cookie_banner_body': 'We use essential technical cookies and, with your consent, marketing cookies to improve your experience and show you relevant content. You can change your mind at any time in Settings.',
    'cookie_accept': 'Accept all',
    'cookie_reject': 'Essential only',

    // ─── Onboarding Tutorial ───
    'tutorial_welcome_title': 'Welcome to Ticketto! 🎉',
    'tutorial_welcome_body': 'This is your dashboard. Monitor all your events at a glance from here.',
    'tutorial_events_title': 'Your events',
    'tutorial_events_body': 'Here you\'ll find all your events. Create your first one with the + button.',
    'tutorial_attendees_title': 'Attendees',
    'tutorial_attendees_body': 'Manage attendees: import CSV, send confirmation emails, and track status.',
    'tutorial_checkin_title': 'QR Check-in',
    'tutorial_checkin_body': 'On event day, use QR check-in to scan attendees in real-time.',
    'tutorial_settings_title': 'Settings',
    'tutorial_settings_body': 'Set up your team, connect Stripe for payments, and customize your preferences.',
    'tutorial_done_title': 'You\'re all set! 🚀',
    'tutorial_done_body': 'Create your first event to get started.',
    'tutorial_next': 'Next',
    'tutorial_skip': 'Skip',
    'tutorial_done_btn': 'Create your first event',
    'tutorial_step': 'Step',
    'tutorial_of': 'of',
    'tutorial_restart': 'Restart tutorial',

    // ─── Contextual Help Tips ───
    // Event Creation
    'help_event_title': 'Your event name. It will be visible to attendees on the registration page and in confirmation emails.',
    'help_event_description': 'A detailed description of the event. It will be shown on the public registration page.',
    'help_event_date': 'The event start date and time. Attendees will see it in the confirmation and Wallet pass.',
    'help_event_location': 'The event venue. It will be displayed on the registration page and Wallet pass.',
    'help_max_attendees': 'The maximum number of attendees. Once the limit is reached, registrations will be automatically closed.',
    'help_paid_event': 'Enable ticket sales. You\'ll need to connect a Stripe account in Settings to receive payments.',
    'help_event_price': 'The ticket price in euros. Payments are processed through Stripe and credited directly to your account.',
    'help_time_slots': 'Split the event into time slots with limited capacity. Great for guided tours, workshops, or appointments. Each attendee picks a slot during registration.',
    'help_custom_fields': 'Add extra fields to the registration form (e.g., t-shirt size, allergies, company). Collected data will be visible in the attendees list.',
    'help_event_status': 'Draft: visible only to you. Published: registrations are open. Completed: the event is over.',
    'help_registration_link': 'Share this link to let people register. It works without a Ticketto account.',
    'help_ai_creator': 'AI automatically generates title, description, date, location and event settings from your description.',
    // Attendees
    'help_attendees_list': 'List of all registered attendees. You can filter them by status (confirmed, pending, checked-in).',
    'help_import_csv': 'Import an attendee list from a CSV file. The file must contain columns: first name, last name, email.',
    'help_send_confirmation': 'Send confirmation emails with QR code and Wallet pass (Apple/Google) to all confirmed attendees.',
    'help_attendee_status': 'Confirmed: registered and payment received. Pending: awaiting payment. Checked-in: access recorded.',
    // Check-in
    'help_checkin_qr': 'Scan the attendee\'s QR code to record access. Also works offline.',
    'help_checkin_manual': 'Search for an attendee by name or email and manually record access.',
    // Dashboard
    'help_dashboard_stats': 'Real-time overview of your events: total events, attendees, active events, and revenue.',
    'help_quick_actions': 'Quick actions for the most common operations: create event, check-in, manage attendees.',
    // Settings
    'help_stripe_connect': 'Connect your Stripe account to receive ticket payments directly to your bank account.',
    'help_team': 'Invite team members to manage events together. Each member can create events and manage attendees.',
    'help_language': 'Change the interface language. The platform supports Italian and English.',
    // Subscription
    'help_subscription': 'Your plan determines the maximum number of active events and attendees. You can upgrade at any time.',

    // ─── About ───
    'about_hero_title': 'We simplify\nevent management',
    'about_hero_subtitle': 'Ticketto was born from a passion for technology and the desire to make event management accessible to everyone.',
    'about_mission_title': 'Our mission',
    'about_mission_body': 'We believe that organizing an event shouldn\'t be complicated. Whether you\'re managing a conference, a workshop, a festival, or a corporate event, you deserve professional tools that work. Ticketto was created to eliminate complexity from event management, letting you focus on what really matters: creating memorable experiences for your attendees.',
    'about_values_title': 'Our values',
    'about_val1_title': 'Simplicity',
    'about_val1_desc': 'Intuitive interfaces that require no training. Setup in less than 2 minutes.',
    'about_val2_title': 'Security',
    'about_val2_desc': 'Your data is protected with enterprise encryption. 100% GDPR compliant.',
    'about_val3_title': 'Passion',
    'about_val3_desc': 'Built with care by event organizers for event organizers.',
    'about_tech_title': 'Technology',
    'about_tech_body': 'Ticketto is built with the best available technologies: Flutter for a smooth cross-platform experience, Firebase for reliability and scalability, and Stripe for secure payments. Our cloud-native architecture ensures high performance and 24/7 availability.',

    // ─── Contact ───
    'contact_title': 'Contact us',
    'contact_subtitle': 'Have questions, suggestions, or need assistance? We\'re here to help.',
    'contact_email_title': 'General inquiries',
    'contact_email_desc': 'For general questions about Ticketto and our services.',
    'contact_support_title': 'Technical support',
    'contact_support_desc': 'Technical issues or help with your account.',
    'contact_privacy_title': 'Privacy & data',
    'contact_privacy_desc': 'For requests related to privacy and data processing.',
    'contact_faq_title': 'Frequently asked questions',

    // ─── App Screens ───
    'events': 'Events',
    'new_event': 'New Event',
    'create_event': 'Create Event',
    'delete_event': 'Delete Event',
    'delete_confirm': 'Are you sure? This action cannot be undone.',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'save': 'Save',
    'add': 'Add',
    'edit': 'Edit',
    'close': 'Close',
    'filter_all': 'All',
    'filter_published': 'Published',
    'filter_draft': 'Draft',
    'filter_completed': 'Completed',
    'no_events': 'No events yet',
    'no_events_filtered': 'No events found',
    'create_first_event': 'Create your first event to get started',
    'publish': 'Publish',
    'mark_complete': 'Mark Complete',
    'paid_event': 'Paid Event',
    'add_time_slot': 'Add Time Slot',
    'add_field': 'Add Field',
    'event_name': 'Event name',
    'location': 'Location',
    'description': 'Description',
    'max_attendees': 'Max attendees',
    'price': 'Price',
    'event_saved': 'Event saved',
    'event_not_found': 'Event not found',
    'back_to_events': 'Back to Events',
    'export_csv': 'Export CSV',
    'duplicate_event': 'Duplicate Event',
    'no_attendees_export': 'No attendees to export',
    'print_qr': 'Print QR Code',

    // ─── Settings ───
    'settings': 'Settings',
    'profile': 'Profile',
    'organization': 'Organization',
    'plan_label': 'Plan',
    'team_members': 'Team Members',
    'manage_roles': 'Manage roles and permissions',
    'switch_org': 'Switch Organization',
    'payments': 'Payments',
    'notifications': 'Notifications',
    'info': 'About',
    'sign_out': 'Sign Out',
    'sign_out_confirm': 'Are you sure you want to sign out?',
    'language': 'Language',
    'italian': 'Italian',
    'english': 'English',

    // ─── Stripe ───
    'connect_stripe': 'Connect Stripe',
    'stripe_subtitle': 'Receive payments for your tickets',
    'stripe_pending': 'Stripe setup in progress',
    'stripe_pending_desc': 'Complete your account configuration',
    'stripe_complete_btn': 'Complete',
    'stripe_connected': 'Stripe Connected',
    'stripe_connecting': 'Connecting to Stripe...',
    'stripe_error': 'Error connecting to Stripe',
    'stripe_how_title': 'How it works',
    'stripe_step1_title': 'Press "Connect Stripe"',
    'stripe_step1_desc': 'You will be redirected to the Stripe registration page.',
    'stripe_step2_title': 'Complete registration',
    'stripe_step2_desc': 'Stripe will ask for personal details, address, ID document and bank details (IBAN).',
    'stripe_step3_title': 'Start earning',
    'stripe_step3_desc': 'Once verified, ticket payments will be credited directly to your account.',
    'stripe_fee_note': 'A 5% platform fee + standard Stripe fees are applied to each sale.',
    'stripe_security_note': 'Ticketto never stores your card or bank details. Everything is securely managed by Stripe.',

    // ─── Attendees ───
    'attendees': 'Attendees',
    'add_attendee': 'Add Attendee',
    'remove_attendee': 'Remove Attendee',
    'remove_confirm': 'Are you sure you want to remove this attendee?',
    'remove': 'Remove',
    'confirm': 'Confirm',
    'cancel_registration': 'Cancel Registration',
    'import_csv': 'Import from CSV',
    'choose_file': 'Choose File',
    'import_attendees': 'Import Attendees',
    'file_empty': 'File is empty',
    'file_error': 'Could not read file',
    'no_valid_attendees': 'No valid attendees found in file',
    'manage': 'Manage',
    'search': 'Search',
    'checked_in': 'Checked in',
    'not_checked_in': 'Not checked in',
    'select_event': 'Select an event',
    'choose_event_attendees': 'Choose an event to view its attendees',
    'search_attendees': 'Search attendees...',
    'event_label': 'Event',
    'first_name': 'First Name *',
    'last_name': 'Last Name *',
    'email_label': 'Email *',
    'phone_label': 'Phone',
    'all_confirmed': 'All attendees will be registered as Confirmed.',
    'select_time_slot': 'Select a time slot',
    'email_field': 'Email Address *',

    // ─── Navigation / Sidebar ───
    'nav_dashboard': 'Dashboard',
    'nav_events': 'Events',
    'nav_attendees': 'Attendees',
    'nav_checkin': 'Check-in',
    'nav_settings': 'Settings',
    'upgrade': 'Upgrade',

    // ─── Check-in ───
    'checkin_title': 'Check-in',
    'select_event_checkin': 'Select an event to start check-in',
    'search_name_email': 'Search by name or email...',
    'select_event_label': 'Select Event',
    'select_event_first': 'Please select an event first',
    'attendee_not_found': 'Attendee not found',
    'already_checked_in': 'is already checked in',
    'checked_in_success': 'checked in successfully!',
    'total': 'Total',
    'remaining': 'Remaining',
    'no_attendees_found': 'No attendees found',
    'check_in_btn': 'Check In',
    'event_duplicated': 'Event duplicated! Opening copy...',
    'event_saved_msg': 'Event saved',

    // ─── Team ───
    'team': 'Team',
    'invite_member': 'Invite Member',
    'role_admin': 'Admin',
    'role_staff': 'Staff',
    'role_viewer': 'Viewer',
    'remove_member': 'Remove member',

    // ─── Dashboard ───
    'good_morning': 'Good morning',
    'good_afternoon': 'Good afternoon',
    'good_evening': 'Good evening',
    'total_events': 'Total Events',
    'attendees_stat': 'Attendees',
    'active_events': 'Active Events',
    'revenue': 'Revenue',
    'active_trend': 'active',
    'all_events_trend': 'All events',
    'published_trend': 'Published',
    'total_trend': 'Total',
    'quick_actions': 'Quick Actions',
    'recent_events': 'Recent Events',
    'view_all': 'View all',
    'no_events_yet': 'No events yet',
    'create_event_btn': 'Create Event',
    'no_location': 'No location',
    'month_jan': 'Jan',
    'month_feb': 'Feb',
    'month_mar': 'Mar',
    'month_apr': 'Apr',
    'month_may': 'May',
    'month_jun': 'Jun',
    'month_jul': 'Jul',
    'month_aug': 'Aug',
    'month_sep': 'Sep',
    'month_oct': 'Oct',
    'month_nov': 'Nov',
    'month_dec': 'Dec',

    // ─── Public Registration ───
    'event_not_found_title': 'Event not found',
    'event_not_found_desc': 'This event does not exist or has been removed.',
    'registration_closed_title': 'Registration Closed',
    'registration_closed_desc': 'Registrations for this event are not currently open.',
    'event_full_warning': 'This event is full. No more registrations are accepted.',
    'register_title': 'Register',
    'register_subtitle': 'Fill in your details to register for this event.',
    'first_name_reg': 'First Name *',
    'last_name_reg': 'Last Name *',
    'email_reg': 'Email *',
    'phone_reg': 'Phone (optional)',
    'select_time_slot_reg': 'Select a Time Slot *',
    'slot_full': 'Full',
    'slot_left': 'left',
    'register_now': 'Register Now',
    'required_field': 'Required',
    'invalid_email': 'Invalid email',
    'please_select_slot': 'Please select a time slot.',
    'slot_full_error': 'Sorry, this time slot is full.',
    'event_full_error': 'Sorry, this event is full.',
    'already_registered': 'This email is already registered for this event.',
    'registration_failed': 'Registration failed',
    'payment_init_failed': 'Payment initialization failed',
    'registration_success_title': 'Registration Complete! 🎉',
    'registration_success_desc': 'You have successfully registered for',
    'save_qr': 'Save the QR code below for event check-in.',
    'your_qr': 'Your QR Code',
    'registered_label': 'registered',
    'confirmation_email': 'A confirmation email has been sent to your address.',

    // ─── Payment & Registration Buttons ───
    'pay_and_register': 'Pay €{amount} and Register',
    'pay_and_register_group': 'Pay €{amount} and Register {count} people',
    'register_group': 'Register {count} people',
    'not_enough_spots': 'Not enough spots available.',
    'payment_complete_title': 'Payment Complete!',
    'payment_complete_desc': 'Your ticket for "{title}" has been purchased successfully.',
    'payment_email_notice': 'You will receive a confirmation email with your ticket QR code.',
    'amount_paid': 'Amount paid',
    'group_registration_label': 'Group Registration',
    'group_registration_desc': 'Allow booking for multiple people',
    'custom_fields_label': 'Registration Fields',
    'custom_fields_desc': 'Add custom fields to the registration form',
    'options_count': '{count} options',
    'options_label': 'Options',
    'show_chatbot_label': 'AI Assistant',
    'show_chatbot_desc': 'Show assistant in bottom right corner',
    'realtime_notifications_label': 'Real-time Notifications',
    'realtime_notifications_desc': 'Receive an email for each new registration',
    'available_pro_business': 'Available on Pro and Business plans',
    'group_max_hint': 'You can register up to {max} people in a single booking.',
    'add_person': 'Add person',
    'person_label': 'Person',

    // ─── Events Form ───
    'event_title_label': 'Event Title *',
    'description_label': 'Description',
    'event_desc_hint': 'Event description...',
    'date_label': 'Date',
    'time_label': 'Time',
    'location_label': 'Location',
    'location_hint': 'Venue address or Online',
    'max_attendees_label': 'Max Attendees',
    'enable_pricing': 'Enable ticket pricing',
    'event_color': 'Event Color',
    'custom_hex_color': 'HEX code (e.g. #1B5E9E)',
    'color_white_minimal': 'Minimal White',
    'show_attendees_count': 'Show available spots',
    'show_attendees_count_desc': 'Show attendee counter on public registration page',
    'org_branding': 'Organization & Branding',
    'org_name_label': 'Organization Name',
    'org_logo_label': 'Organization Logo',
    'org_logo_url_hint': 'Logo URL (or upload file)',
    'upload_logo_btn': 'Upload Logo',
    'save_changes': 'Save Changes',
    'powered_by_ticketto': 'Powered by Ticketto',
    'time_slot_booking': 'Time Slot Booking',
    'time_slot_desc': 'Limit access by time windows',
    'slot_label_field': 'Slot Label *',
    'slot_hint': 'e.g. Morning Session',
    'start_label': 'Start',
    'end_label': 'End',
    'max_capacity': 'Max Capacity',
    'registration_link': 'Registration Link',
    'link_copied': 'Registration link copied to clipboard!',
    'available_label': 'available',
    'registrations_chart': 'Registrations (last 7 days)',
    'error_generic_short': 'Error',

    // ─── Team Screen ───
    'no_team_members': 'No team members',
    'members_stat': 'Members',
    'admins_stat': 'Admins',
    'staff_stat': 'Staff',
    'invite_team_member': 'Invite Team Member',
    'add_to_team_subtitle': 'Add a new member to',
    'role_label': 'Role',
    'add_member_btn': 'Add Member',
    'added_as_member': 'added as',
    'make_role': 'Make',
    'you_label': 'You',
    'role_admin_desc': 'Can manage events, attendees, and team',
    'role_staff_desc': 'Can manage events and check-in attendees',
    'role_viewer_desc': 'Can view events and attendees (read-only)',
    'role_owner_desc': 'Full access',

    // ─── Attendees Screen ───
    'import_csv_tooltip': 'Import CSV',
    'error_loading_attendees': 'Error loading attendees',
    'no_results_found': 'No results found',
    'no_attendees_yet_short': 'No attendees yet',
    'total_stat': 'Total',
    'confirmed_stat': 'Confirmed',
    'pending_stat': 'Pending',
    'checked_in_stat': 'Checked In',
    'import_x': 'Import',
    'importing_attendees': 'Importing attendees...',
    'import_error': 'Import error',
    'imported_success': 'attendees imported successfully!',
    'imported_skipped': 'skipped due to capacity limits',
    'and_x_more': 'and more',

    // ─── Event Detail Screen ───
    'edit_event': 'Edit Event',
    'share_link_tooltip': 'Share Registration Link',
    'export_error': 'Export error',
    'no_attendees_detail': 'No attendees yet',
    'hide_qr': 'Hide QR Code',
    'show_qr': 'Show QR Code',
    'copy_label': 'Copy',
    'link_copied_short': 'Link copied!',
    'analytics_label': 'Analytics',
    'attendees_stat_label': 'Attendees',
    'revenue_stat_label': 'Revenue',
    'capacity_stat_label': 'Capacity',
    'event_title_hint': 'Event title',
    'venue_hint': 'Venue',
    'spots_label': 'spots',
    'scan_to_register': 'Scan to register',

    // ─── Bug Fixes - Additional Keys ───
    'event_created_success': 'Event created successfully!',
    'entry_qr_code': 'Entry QR Code',
    'category_label': 'Category',
    'registered_at_label': 'Registered',
    'checked_in_at_label': 'Checked In At',
    'time_slot_label': 'Time Slot',
    'status_confirmed': 'CONFIRMED',
    'status_pending': 'PENDING',
    'status_canceled': 'CANCELED',
    'checked_in_label': 'CHECKED IN',
    'edit_date_label': 'Event Date',
    'edit_time_label': 'Event Time',
    'additional_data': 'Additional Data',
    'edit_attendee': 'Edit Attendee',
    'attendee_updated': 'Attendee updated',
    'date_at': 'at',
    'qr_print_hint': 'Print or display this QR code at your venue for on-site registration.',
    'time_slots_count': 'slots',

    // ─── i18n: Event Language ───
    'event_language_label': 'Event Language',
    'event_language_hint': 'The language used for the registration page, emails, and Wallet passes for attendees.',
    'event_type_label': 'Event Type',
    'event_type_hint': 'You can organize an in-person event or a webinar/live stream.',
    'unlimited_attendees': 'Unlimited',
    'max_plan_attendees': 'Max {max} ({plan} plan)',

    // ─── i18n: Hardcoded strings cleanup ───
    'start_now': 'Start Now',
    'org_already_exists': 'You already have an active workspace. Redirecting you now.',
    'print_single_badge': 'Print Single Badge',
    'generating_backup_csv': 'Generating backup CSV...',
    'select_event_first_msg': 'Please select an event first.',
    'generating_pdf': 'Generating PDF...',
    'no_attendees_print': 'No attendees to print.',
    'print_error': 'Print error',
    'csv_note_title': 'ℹ️  Notes',
    'csv_prepare_instructions': 'Prepare a CSV file with the following columns:',
    'csv_note_headers': 'The first row must contain the column headers',
    'csv_note_email_mandatory': 'email is the only mandatory column',
    'csv_note_phone_optional': 'phone is optional (leave empty if not available)',
    'csv_note_time_slot': 'time_slot is optional: use the slot label to auto-assign',
    'csv_note_no_slot': 'Without time_slot column, you can choose a slot during import',
    'csv_note_format': 'Accepted file format: .csv or .txt',
    'csv_note_duplicates': 'Duplicate emails will be overwritten',
    'csv_note_aliases_title': 'Accepted column aliases:',
    'csv_note_alias_first_name': 'first_name → nome, firstname, name',
    'csv_note_alias_last_name': 'last_name → cognome, lastname, surname',
    'csv_note_alias_email': 'email → e-mail, mail',
    'csv_note_alias_phone': 'phone → telefono, tel, cellulare, mobile',
    'csv_note_alias_time_slot': 'time_slot → timeslot, fascia, fascia_oraria, slot',
    'csv_no_email_column': 'Could not find an email column. Please ensure your CSV has headers.',
    'assign_time_slot': 'Assign to Time Slot *',
    'preview_label': 'Preview:',
    'custom_field_type_text': 'Text',
    'custom_field_type_select': 'Select',
    'custom_field_type_number': 'Number',
    'custom_field_type_phone': 'Phone',

    // ─── Promozioni & Voucher ───
    'nav_promotions': 'Promotions',
    'promotions_title': 'Promotions & Partnerships',
    'promotions_subtitle': 'Manage special deals, partner collaborations and QR-coded sequential coupons.',
    'new_promotion_btn': 'New Offer',
    'redeem_voucher_btn': 'Validate / Redeem at Desk',
    'no_promotions_yet': 'No promotions created yet',
    'no_promotions_desc': 'Create special deals or partner partnerships (e.g. 2x1 with gyms or hotels) and generate printable QR code coupons.',
    'active_promos_count': 'Active Deals',
    'total_vouchers': 'Total Vouchers',
    'claimed_vouchers': 'Activated',
    'redeemed_vouchers': 'Redeemed',
    'voucher_code': 'Voucher Code',
    'is_partnership_toggle': 'Is this a partnership with an external partner?',
    'is_partnership_subtitle': 'If disabled, it will be an internal venue promotion displaying only your logo.',
    'partner_name': 'Partner Business Name',
    'partner_hint': 'e.g. FitCenter Gym, Grand Hotel...',
    'partner_logo_label': 'Partner Logo (Optional)',
    'partner_logo_hint': 'Image URL or upload PNG/JPG file',
    'upload_partner_logo': 'Upload Partner Logo',
    'org_logo_preview': 'Venue Logo',
    'partner_logo_preview': 'Partner Logo',
    'both_logos_printed': 'Both logos will appear side by side on printed coupons',
    'single_logo_printed': 'Only your venue logo will appear on printed coupons',
    'offer_title': 'Offer Title',
    'offer_title_hint': 'e.g. 2x1 SPA Entry Special Deal',
    'offer_description': 'Description & Terms',
    'offer_type': 'Offer Type',
    'discount_value': 'Discount Value',
    'offer_price': 'Reference Price (€)',
    'payment_method': 'Payment Method',
    'payment_at_venue': 'Pay at venue (at front desk)',
    'payment_online': 'Pay online immediately (Stripe)',
    'payment_free': 'Free Access / Complimentary',
    'code_prefix': 'Code Prefix',
    'code_prefix_hint': 'e.g. FIT, SPA, PROMO',
    'vouchers_quantity': 'Vouchers to generate',
    'vouchers_quantity_hint': 'e.g. 25, 50, 100',
    'expiration_date': 'Expiration Date',
    'voucher_validity_label': 'Voucher Validity from Registration',
    'voucher_validity_helper': 'The voucher will expire exactly after the specified days from the customer\'s online registration.',
    'campaign_deadline_label': 'Registration Deadline / Deal End (Optional)',
    'campaign_deadline_helper': 'Latest date by which coupons can be registered. Vouchers already claimed stay valid for their full period.',
    'enable_registration_deadline': 'Set deadline to register',
    'no_registration_deadline': 'No deadline (deal stays open indefinitely)',
    'campaign_deadline_note': 'Vouchers claimed before this date remain valid for their full duration even after deal ends.',
    'promo_registration_closed_title': 'Registrations Closed',
    'promo_registration_closed_desc': 'The deadline to claim new coupons for this deal has expired.',
    'deal_closed_voucher_valid': 'Deal closed to new claims, but customer voucher is valid.',
    'validity_days_unit': 'days',
    'voucher_expires_on': 'Voucher Expiration',
    'voucher_days_remaining': 'days remaining',
    'voucher_expired_alert': 'Voucher Expired',
    'linked_event_optional': 'Link to an Event (Optional)',
    'linked_event_none': 'No event (Venue / General Service Access)',
    'print_coupons_pdf': 'Print Coupons PDF',
    'print_coupons_desc': 'Generate an A4 sheet ready to print with coupons and unique QR codes',
    'generate_more_vouchers': 'Add More Vouchers',
    'voucher_status_available': 'Available',
    'voucher_status_claimed': 'Activated by Customer',
    'voucher_status_redeemed': 'Redeemed',
    'voucher_status_cancelled': 'Cancelled',
    'redeem_dialog_title': 'Voucher Desk Validation & Redemption',
    'redeem_dialog_hint': 'Search by voucher code, customer name, email, or scan QR code',
    'redeem_code_label': 'Voucher Code or Customer Details (Name, Email)',
    'redeem_search_btn': 'Search Code',
    'redeem_confirm_btn': 'Confirm Redemption',
    'redeem_success': 'Voucher redeemed successfully!',
    'redeem_already_used': 'This voucher has already been redeemed',
    'redeem_expired': 'This voucher has expired',
    'redeem_not_found': 'Voucher code not found',
    'redeem_venue_payment_alert': 'Amount to collect at front desk:',
    'public_voucher_title': 'Special Offer Activation',
    'public_voucher_valid_until': 'Valid until',
    'public_voucher_form_title': 'Enter your details to activate this offer',
    'public_voucher_activate_venue': 'Activate Offer (Pay at venue)',
    'public_voucher_activate_online': 'Pay and Activate Offer',
    'public_voucher_success_title': 'Offer Activated!',
    'public_voucher_success_desc': 'Your voucher has been activated successfully. Present this pass or coupon at the reception desk.',
    'public_voucher_already_claimed': 'Offer already activated',
    'public_voucher_already_redeemed': 'This voucher has already been used at the venue.',
    'public_voucher_expired': 'Sorry, this offer has expired.',
  };
}

// ─── Delegate ────────────────────────────────────────────────────

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['it', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate old) => false;
}
