import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class CookieScreen extends StatelessWidget {
  const CookieScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final maxWidth = isMobile ? double.infinity : 800.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, l, isMobile),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 64,
                vertical: 48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l['cookie_title'],
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 28 : 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${l['last_updated']}: 18 Aprile 2026',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),
                      ..._buildSections(l),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/landing'),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                        'assets/images/ticketto_logo.png',
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Ticketto',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => context.go('/landing'),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(l['back']),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(AppLocalizations l) {
    final isIt = l.locale.languageCode == 'it';
    final sections = isIt ? _italianSections : _englishSections;

    return sections.expand((section) => [
      Text(
        section['title']!,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        section['body']!,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textSecondary,
          height: 1.7,
        ),
      ),
      const SizedBox(height: 28),
    ]).toList();
  }

  static const _italianSections = [
    {
      'title': '1. Cosa sono i cookie',
      'body': 'I cookie sono piccoli file di testo che vengono salvati sul tuo '
          'dispositivo quando visiti un sito web. Vengono utilizzati per far '
          'funzionare il sito, migliorarne l\'efficienza e fornire informazioni '
          'ai proprietari del sito.',
    },
    {
      'title': '2. Cookie tecnici (necessari)',
      'body': 'Ticketto utilizza cookie tecnici necessari per il '
          'funzionamento della piattaforma. Questi cookie sono sempre attivi '
          'e non richiedono il tuo consenso:\n\n'
          '• Cookie di sessione: mantengono attiva la tua sessione di login\n'
          '• Cookie di autenticazione Firebase: gestiscono l\'autenticazione sicura\n'
          '• Cookie di preferenze: salvano le tue preferenze (es. lingua, consenso cookie)\n'
          '• Cookie di consenso: memorizzano la tua scelta sui cookie',
    },
    {
      'title': '3. Cookie di marketing (opzionali)',
      'body': 'Con il tuo consenso esplicito, Ticketto utilizza cookie di marketing '
          'per misurare l\'efficacia delle campagne pubblicitarie e migliorare '
          'il servizio:\n\n'
          '• Google Ads (AW-417739561): tracciamento delle conversioni pubblicitarie '
          'e remarketing. Questi cookie sono gestiti da Google LLC.\n'
          '• TikTok Pixel (D7FANQ3C77UB0P249JEG): tracciamento delle conversioni '
          'da campagne TikTok Ads. Questi cookie sono gestiti da TikTok Inc.\n\n'
          'Questi cookie vengono attivati SOLO dopo che hai dato il tuo consenso '
          'tramite il banner cookie. Puoi revocare il consenso in qualsiasi momento.',
    },
    {
      'title': '4. Cookie di terze parti',
      'body': 'I seguenti servizi di terze parti possono impostare i propri cookie:\n\n'
          '• Google Firebase: autenticazione e hosting\n'
          '• Stripe: elaborazione pagamenti sicuri\n'
          '• Google Ads: tracciamento conversioni (solo con consenso)\n'
          '• TikTok: tracciamento conversioni (solo con consenso)\n\n'
          'Ti invitiamo a consultare le rispettive privacy policy per informazioni '
          'sull\'uso dei cookie da parte di questi servizi.',
    },
    {
      'title': '5. Durata dei cookie',
      'body': 'I cookie utilizzati da Ticketto hanno le seguenti durate:\n\n'
          '• Cookie di sessione: vengono eliminati alla chiusura del browser\n'
          '• Cookie di autenticazione: durata massima di 30 giorni\n'
          '• Cookie di preferenze: durata massima di 1 anno\n'
          '• Cookie di consenso: durata massima di 1 anno\n'
          '• Cookie Google Ads: fino a 2 anni (se consenso dato)\n'
          '• Cookie TikTok: fino a 13 mesi (se consenso dato)',
    },
    {
      'title': '6. Come gestire i cookie',
      'body': 'Al primo accesso, ti verrà mostrato un banner per scegliere '
          'quali cookie accettare. Puoi:\n\n'
          '• Accettare tutti i cookie (tecnici + marketing)\n'
          '• Accettare solo i cookie necessari\n\n'
          'Puoi anche gestire le impostazioni dei cookie attraverso il tuo browser. '
          'Tieni presente che disabilitando i cookie tecnici, alcune funzionalità '
          'di Ticketto potrebbero non funzionare correttamente.',
    },
    {
      'title': '7. Aggiornamenti',
      'body': 'Questa Cookie Policy può essere aggiornata periodicamente. '
          'Ti consigliamo di consultare questa pagina regolarmente per '
          'rimanere aggiornato su eventuali modifiche.\n\n'
          'Per domande: privacy@ticketto.it',
    },
  ];

  static const _englishSections = [
    {
      'title': '1. What are cookies',
      'body': 'Cookies are small text files that are saved on your device when '
          'you visit a website. They are used to make the site work, improve its '
          'efficiency, and provide information to site owners.',
    },
    {
      'title': '2. Technical cookies (essential)',
      'body': 'Ticketto uses essential technical cookies required for the '
          'platform to function. These cookies are always active '
          'and do not require your consent:\n\n'
          '• Session cookies: keep your login session active\n'
          '• Firebase authentication cookies: manage secure authentication\n'
          '• Preference cookies: save your preferences (e.g., language, cookie consent)\n'
          '• Consent cookies: store your cookie choice',
    },
    {
      'title': '3. Marketing cookies (optional)',
      'body': 'With your explicit consent, Ticketto uses marketing cookies '
          'to measure the effectiveness of advertising campaigns and improve '
          'the service:\n\n'
          '• Google Ads (AW-417739561): advertising conversion tracking '
          'and remarketing. These cookies are managed by Google LLC.\n'
          '• TikTok Pixel (D7FANQ3C77UB0P249JEG): conversion tracking '
          'from TikTok Ads campaigns. These cookies are managed by TikTok Inc.\n\n'
          'These cookies are activated ONLY after you give your consent '
          'through the cookie banner. You can revoke consent at any time.',
    },
    {
      'title': '4. Third-party cookies',
      'body': 'The following third-party services may set their own cookies:\n\n'
          '• Google Firebase: authentication and hosting\n'
          '• Stripe: secure payment processing\n'
          '• Google Ads: conversion tracking (consent required)\n'
          '• TikTok: conversion tracking (consent required)\n\n'
          'Please refer to their respective privacy policies for information '
          'about their use of cookies.',
    },
    {
      'title': '5. Cookie duration',
      'body': 'The cookies used by Ticketto have the following durations:\n\n'
          '• Session cookies: deleted when you close the browser\n'
          '• Authentication cookies: maximum duration of 30 days\n'
          '• Preference cookies: maximum duration of 1 year\n'
          '• Consent cookies: maximum duration of 1 year\n'
          '• Google Ads cookies: up to 2 years (if consent given)\n'
          '• TikTok cookies: up to 13 months (if consent given)',
    },
    {
      'title': '6. How to manage cookies',
      'body': 'On your first visit, a banner will be shown so you can choose '
          'which cookies to accept. You can:\n\n'
          '• Accept all cookies (technical + marketing)\n'
          '• Accept only essential cookies\n\n'
          'You can also manage cookie settings through your browser. Please note '
          'that disabling technical cookies may cause some Ticketto features to '
          'not work properly.',
    },
    {
      'title': '7. Updates',
      'body': 'This Cookie Policy may be updated periodically. We recommend '
          'checking this page regularly for any changes.\n\n'
          'For questions: privacy@ticketto.it',
    },
  ];
}
