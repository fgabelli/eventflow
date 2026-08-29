import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
            // ─── Header ───
            Container(
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
            ),

            // ─── Content ───
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
                        l['privacy_title'],
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

  List<Widget> _buildSections(AppLocalizations l) {
    final isIt = l.locale.languageCode == 'it';

    final sections = isIt
        ? _italianSections
        : _englishSections;

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
      'title': '1. Titolare del trattamento',
      'body': 'Il titolare del trattamento dei dati personali è Ticketto, '
          'raggiungibile all\'indirizzo email: privacy@ticketto.it. '
          'Ci impegniamo a proteggere la privacy dei nostri utenti e a trattare '
          'i dati personali in conformità al Regolamento (UE) 2016/679 (GDPR).',
    },
    {
      'title': '2. Dati raccolti',
      'body': 'Raccogliamo le seguenti categorie di dati:\n\n'
          '• Dati di registrazione: nome, cognome, indirizzo email, password\n'
          '• Dati di autenticazione: credenziali Google Sign-In\n'
          '• Dati degli eventi: informazioni sugli eventi creati, partecipanti, check-in\n'
          '• Dati tecnici: indirizzo IP, tipo di browser, dispositivo utilizzato\n'
          '• Dati di pagamento: elaborati tramite Stripe (non conserviamo dati delle carte)',
    },
    {
      'title': '3. Finalità del trattamento',
      'body': 'I dati personali vengono trattati per:\n\n'
          '• Fornire e gestire il servizio Ticketto\n'
          '• Creare e gestire il tuo account\n'
          '• Elaborare i pagamenti degli abbonamenti\n'
          '• Inviare comunicazioni relative al servizio\n'
          '• Migliorare il funzionamento della piattaforma\n'
          '• Adempiere agli obblighi legali',
    },
    {
      'title': '4. Base giuridica',
      'body': 'Il trattamento dei dati si basa su:\n\n'
          '• Esecuzione del contratto (art. 6.1.b GDPR)\n'
          '• Consenso dell\'utente (art. 6.1.a GDPR)\n'
          '• Legittimo interesse (art. 6.1.f GDPR)\n'
          '• Obbligo legale (art. 6.1.c GDPR)',
    },
    {
      'title': '5. Conservazione dei dati',
      'body': 'I dati personali vengono conservati per la durata necessaria '
          'alle finalità per cui sono stati raccolti. In caso di cancellazione '
          'dell\'account, i dati verranno eliminati entro 30 giorni, salvo '
          'obblighi legali di conservazione.',
    },
    {
      'title': '6. Condivisione dei dati',
      'body': 'I dati possono essere condivisi con:\n\n'
          '• Google Firebase (hosting e database)\n'
          '• Stripe (elaborazione pagamenti)\n'
          '• Resend (invio email transazionali)\n'
          '• Google Ads (tracciamento conversioni — solo con consenso cookie)\n'
          '• TikTok Ads (tracciamento conversioni — solo con consenso cookie)\n\n'
          'Non vendiamo né condividiamo i dati personali con terze parti per '
          'finalità di marketing diretto. I servizi di tracciamento pubblicitario '
          'vengono attivati solo con il consenso esplicito dell\'utente.',
    },
    {
      'title': '7. Diritti dell\'utente',
      'body': 'In conformità al GDPR, hai diritto a:\n\n'
          '• Accedere ai tuoi dati personali\n'
          '• Rettificare i dati inesatti\n'
          '• Cancellare i tuoi dati (diritto all\'oblio)\n'
          '• Limitare il trattamento\n'
          '• Portabilità dei dati\n'
          '• Opporti al trattamento\n'
          '• Revocare il consenso ai cookie di marketing\n\n'
          'Per esercitare questi diritti, scrivi a privacy@ticketto.it.',
    },
    {
      'title': '8. Cookie',
      'body': 'Ticketto utilizza cookie tecnici necessari per il funzionamento '
          'del servizio. Con il consenso esplicito dell\'utente, vengono utilizzati '
          'anche cookie di marketing (Google Ads, TikTok Pixel) per misurare '
          'l\'efficacia delle campagne pubblicitarie. Per maggiori dettagli, '
          'consulta la nostra Cookie Policy.',
    },
    {
      'title': '9. Contatti',
      'body': 'Per qualsiasi domanda sulla privacy, puoi contattarci a:\n'
          'Email: privacy@ticketto.it',
    },
  ];

  static const _englishSections = [
    {
      'title': '1. Data Controller',
      'body': 'The data controller is Ticketto, reachable at: privacy@ticketto.it. '
          'We are committed to protecting the privacy of our users and processing '
          'personal data in accordance with Regulation (EU) 2016/679 (GDPR).',
    },
    {
      'title': '2. Data Collected',
      'body': 'We collect the following categories of data:\n\n'
          '• Registration data: first name, last name, email address, password\n'
          '• Authentication data: Google Sign-In credentials\n'
          '• Event data: information about events created, attendees, check-ins\n'
          '• Technical data: IP address, browser type, device used\n'
          '• Payment data: processed through Stripe (we do not store card data)',
    },
    {
      'title': '3. Purposes of Processing',
      'body': 'Personal data is processed to:\n\n'
          '• Provide and manage the Ticketto service\n'
          '• Create and manage your account\n'
          '• Process subscription payments\n'
          '• Send service-related communications\n'
          '• Improve platform functionality\n'
          '• Comply with legal obligations',
    },
    {
      'title': '4. Legal Basis',
      'body': 'Data processing is based on:\n\n'
          '• Performance of a contract (Art. 6.1.b GDPR)\n'
          '• User consent (Art. 6.1.a GDPR)\n'
          '• Legitimate interest (Art. 6.1.f GDPR)\n'
          '• Legal obligation (Art. 6.1.c GDPR)',
    },
    {
      'title': '5. Data Retention',
      'body': 'Personal data is retained for as long as necessary for the '
          'purposes for which it was collected. Upon account deletion, data will '
          'be removed within 30 days, unless legal retention obligations apply.',
    },
    {
      'title': '6. Data Sharing',
      'body': 'Data may be shared with:\n\n'
          '• Google Firebase (hosting and database)\n'
          '• Stripe (payment processing)\n'
          '• Resend (transactional emails)\n'
          '• Google Ads (conversion tracking — only with cookie consent)\n'
          '• TikTok Ads (conversion tracking — only with cookie consent)\n\n'
          'We do not sell or share personal data with third parties for direct '
          'marketing purposes. Advertising tracking services are activated only '
          'with the user\'s explicit consent.',
    },
    {
      'title': '7. User Rights',
      'body': 'Under the GDPR, you have the right to:\n\n'
          '• Access your personal data\n'
          '• Rectify inaccurate data\n'
          '• Erase your data (right to be forgotten)\n'
          '• Restrict processing\n'
          '• Data portability\n'
          '• Object to processing\n'
          '• Revoke marketing cookie consent\n\n'
          'To exercise these rights, contact privacy@ticketto.it.',
    },
    {
      'title': '8. Cookies',
      'body': 'Ticketto uses essential technical cookies required for the service '
          'to function. With the user\'s explicit consent, marketing cookies '
          '(Google Ads, TikTok Pixel) are also used to measure advertising '
          'campaign effectiveness. For more details, see our Cookie Policy.',
    },
    {
      'title': '9. Contact',
      'body': 'For any privacy questions, you can contact us at:\n'
          'Email: privacy@ticketto.it',
    },
  ];
}
