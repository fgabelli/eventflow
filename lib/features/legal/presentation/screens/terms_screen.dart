import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
                        l['terms_title'],
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 28 : 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${l['last_updated']}: 17 Febbraio 2026',
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
      'title': '1. Accettazione dei termini',
      'body': 'Utilizzando il servizio Ticketto, accetti di essere vincolato '
          'dai presenti Termini e Condizioni. Se non accetti questi termini, '
          'non utilizzare il servizio. L\'uso continuato del servizio costituisce '
          'accettazione di eventuali modifiche ai termini.',
    },
    {
      'title': '2. Descrizione del servizio',
      'body': 'Ticketto è una piattaforma SaaS per la gestione di eventi che include:\n\n'
          '• Creazione e gestione di eventi\n'
          '• Registrazione partecipanti e check-in QR code\n'
          '• Gestione fasce orarie e capienza\n'
          '• Import CSV dei partecipanti\n'
          '• Email di conferma automatiche\n'
          '• Gestione team con ruoli differenziati\n'
          '• Vendita biglietti tramite Stripe Connect',
    },
    {
      'title': '3. Account utente',
      'body': 'Per utilizzare Ticketto devi creare un account fornendo '
          'informazioni accurate e complete. Sei responsabile della '
          'riservatezza delle tue credenziali e di tutte le attività '
          'svolte dal tuo account. Devi comunicarci immediatamente qualsiasi '
          'uso non autorizzato del tuo account.',
    },
    {
      'title': '4. Piani e pagamenti',
      'body': 'Ticketto offre diversi piani tariffari:\n\n'
          '• Free: funzionalità base, 1 evento, max 50 partecipanti\n'
          '• Pro (€29/mese): funzionalità avanzate, 10 eventi, 500 partecipanti\n'
          '• Business (€79/mese): funzionalità illimitate\n\n'
          'I pagamenti vengono elaborati tramite Stripe. I rinnovi sono automatici. '
          'Puoi cancellare il tuo abbonamento in qualsiasi momento; l\'accesso '
          'al piano premium rimarrà attivo fino alla fine del periodo pagato.',
    },
    {
      'title': '5. Vendita biglietti e commissioni',
      'body': 'Per la vendita di biglietti tramite Ticketto, viene applicata '
          'una commissione del 5% sul prezzo del biglietto. I pagamenti vengono '
          'trasferiti direttamente al tuo account Stripe Connect dopo la '
          'deduzione della commissione. Ticketto non è responsabile per '
          'rimborsi o contestazioni tra organizzatori e partecipanti.',
    },
    {
      'title': '6. Obblighi dell\'utente',
      'body': 'L\'utente si impegna a:\n\n'
          '• Utilizzare il servizio in conformità alle leggi vigenti\n'
          '• Non utilizzare il servizio per scopi illegali o non autorizzati\n'
          '• Non violare i diritti di proprietà intellettuale di terzi\n'
          '• Non tentare di accedere a sistemi o dati non autorizzati\n'
          '• Fornire informazioni accurate per gli eventi pubblicati',
    },
    {
      'title': '7. Proprietà intellettuale',
      'body': 'Tutti i contenuti, marchi, loghi e software di Ticketto sono di '
          'proprietà di Ticketto o dei suoi licenziatari. Non è consentito '
          'copiare, modificare, distribuire o creare opere derivate senza '
          'autorizzazione scritta.',
    },
    {
      'title': '8. Limitazione di responsabilità',
      'body': 'Ticketto fornisce il servizio "così com\'è". Non garantiamo che '
          'il servizio sia privo di errori o interruzioni. In nessun caso '
          'Ticketto sarà responsabile per danni indiretti, incidentali o '
          'consequenziali derivanti dall\'uso del servizio.',
    },
    {
      'title': '9. Risoluzione',
      'body': 'Ticketto si riserva il diritto di sospendere o terminare il '
          'tuo account in caso di violazione dei presenti termini. Puoi '
          'cancellare il tuo account in qualsiasi momento dalle impostazioni.',
    },
    {
      'title': '10. Legge applicabile',
      'body': 'I presenti termini sono regolati dalla legge italiana. Per '
          'qualsiasi controversia sarà competente il Foro di Roma.\n\n'
          'Per domande: legal@ticketto.it',
    },
  ];

  static const _englishSections = [
    {
      'title': '1. Acceptance of Terms',
      'body': 'By using the Ticketto service, you agree to be bound by these '
          'Terms and Conditions. If you do not accept these terms, do not use '
          'the service. Continued use of the service constitutes acceptance of '
          'any modifications to the terms.',
    },
    {
      'title': '2. Service Description',
      'body': 'Ticketto is a SaaS platform for event management that includes:\n\n'
          '• Event creation and management\n'
          '• Attendee registration and QR code check-in\n'
          '• Time slot and capacity management\n'
          '• CSV attendee import\n'
          '• Automatic confirmation emails\n'
          '• Team management with differentiated roles\n'
          '• Ticket sales via Stripe Connect',
    },
    {
      'title': '3. User Account',
      'body': 'To use Ticketto you must create an account providing accurate '
          'and complete information. You are responsible for the confidentiality '
          'of your credentials and all activities performed under your account. '
          'You must notify us immediately of any unauthorized use of your account.',
    },
    {
      'title': '4. Plans and Payments',
      'body': 'Ticketto offers various pricing plans:\n\n'
          '• Free: basic features, 1 event, max 50 attendees\n'
          '• Pro (€29/month): advanced features, 10 events, 500 attendees\n'
          '• Business (€79/month): unlimited features\n\n'
          'Payments are processed through Stripe. Renewals are automatic. You '
          'can cancel your subscription at any time; premium access will remain '
          'active until the end of the paid period.',
    },
    {
      'title': '5. Ticket Sales and Fees',
      'body': 'For ticket sales through Ticketto, a 5% commission is applied '
          'on the ticket price. Payments are transferred directly to your '
          'Stripe Connect account after the commission is deducted. Ticketto '
          'is not responsible for refunds or disputes between organizers and '
          'attendees.',
    },
    {
      'title': '6. User Obligations',
      'body': 'The user agrees to:\n\n'
          '• Use the service in compliance with applicable laws\n'
          '• Not use the service for illegal or unauthorized purposes\n'
          '• Not infringe third-party intellectual property rights\n'
          '• Not attempt to access unauthorized systems or data\n'
          '• Provide accurate information for published events',
    },
    {
      'title': '7. Intellectual Property',
      'body': 'All content, trademarks, logos and software of Ticketto are the '
          'property of Ticketto or its licensors. Copying, modifying, '
          'distributing or creating derivative works without written '
          'authorization is not permitted.',
    },
    {
      'title': '8. Limitation of Liability',
      'body': 'Ticketto provides the service "as is". We do not guarantee that '
          'the service will be error-free or uninterrupted. In no event shall '
          'Ticketto be liable for indirect, incidental or consequential damages '
          'arising from the use of the service.',
    },
    {
      'title': '9. Termination',
      'body': 'Ticketto reserves the right to suspend or terminate your account '
          'in case of violation of these terms. You can delete your account at '
          'any time from the settings.',
    },
    {
      'title': '10. Governing Law',
      'body': 'These terms are governed by Italian law. Any disputes will be '
          'subject to the jurisdiction of the Court of Rome.\n\n'
          'For questions: legal@ticketto.it',
    },
  ];
}
