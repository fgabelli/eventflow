import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

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
                        l['contact_title'],
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 28 : 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l['contact_subtitle'],
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ─── Contact cards ───
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _contactCard(
                            icon: Icons.email_outlined,
                            title: l['contact_email_title'],
                            subtitle: l['contact_email_desc'],
                            action: 'info@ticketto.it',
                            color: AppColors.primary,
                            onTap: () => _launchUrl('mailto:info@ticketto.it'),
                            isMobile: isMobile,
                          ),
                          _contactCard(
                            icon: Icons.support_agent_rounded,
                            title: l['contact_support_title'],
                            subtitle: l['contact_support_desc'],
                            action: 'support@ticketto.it',
                            color: AppColors.success,
                            onTap: () => _launchUrl('mailto:support@ticketto.it'),
                            isMobile: isMobile,
                          ),
                          _contactCard(
                            icon: Icons.shield_outlined,
                            title: l['contact_privacy_title'],
                            subtitle: l['contact_privacy_desc'],
                            action: 'privacy@ticketto.it',
                            color: AppColors.warning,
                            onTap: () => _launchUrl('mailto:privacy@ticketto.it'),
                            isMobile: isMobile,
                          ),
                        ],
                      ),

                      const SizedBox(height: 56),

                      // ─── FAQ section ───
                      Text(
                        l['contact_faq_title'],
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ..._buildFaqItems(l),

                      const SizedBox(height: 48),
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

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required Color color,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            child: Text(
              action,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFaqItems(AppLocalizations l) {
    final isIt = l.locale.languageCode == 'it';
    final faqs = isIt ? _italianFaqs : _englishFaqs;

    return faqs.map((faq) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            faq['q']!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            Text(
              faq['a']!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
                    child: Image.asset('assets/images/ticketto_logo.png',
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

  static const _italianFaqs = [
    {
      'q': 'Ticketto è gratuito?',
      'a': 'Sì! Il piano Free include 1 evento attivo con fino a 50 partecipanti, '
          'check-in QR code e pagina di registrazione pubblica. Puoi fare upgrade '
          'in qualsiasi momento.',
    },
    {
      'q': 'Come funziona il check-in QR code?',
      'a': 'Ogni partecipante registrato riceve un QR code unico via email. '
          'Il giorno dell\'evento, il tuo team può scansionarlo direttamente '
          'dallo smartphone per verificare l\'accesso in tempo reale.',
    },
    {
      'q': 'Posso vendere biglietti a pagamento?',
      'a': 'Sì, puoi vendere biglietti tramite Stripe Connect. Ticketto applica '
          'una commissione del 5% sul prezzo del biglietto. I pagamenti vengono '
          'trasferiti direttamente sul tuo conto.',
    },
    {
      'q': 'I miei dati sono al sicuro?',
      'a': 'Assolutamente sì. Utilizziamo Google Firebase per l\'hosting e '
          'l\'autenticazione, con crittografia end-to-end. Siamo conformi al GDPR '
          'e non condividiamo i tuoi dati con terze parti.',
    },
    {
      'q': 'Posso cancellare il mio account?',
      'a': 'Sì, puoi cancellare il tuo account in qualsiasi momento dalle '
          'impostazioni. I tuoi dati verranno eliminati entro 30 giorni.',
    },
  ];

  static const _englishFaqs = [
    {
      'q': 'Is Ticketto free?',
      'a': 'Yes! The Free plan includes 1 active event with up to 50 attendees, '
          'QR code check-in, and a public registration page. You can upgrade '
          'at any time.',
    },
    {
      'q': 'How does QR code check-in work?',
      'a': 'Each registered attendee receives a unique QR code via email. '
          'On the day of the event, your team can scan it directly from a '
          'smartphone to verify access in real time.',
    },
    {
      'q': 'Can I sell paid tickets?',
      'a': 'Yes, you can sell tickets through Stripe Connect. Ticketto applies '
          'a 5% commission on the ticket price. Payments are transferred directly '
          'to your account.',
    },
    {
      'q': 'Is my data secure?',
      'a': 'Absolutely. We use Google Firebase for hosting and authentication, '
          'with end-to-end encryption. We are GDPR compliant and do not share '
          'your data with third parties.',
    },
    {
      'q': 'Can I delete my account?',
      'a': 'Yes, you can delete your account at any time from the settings. '
          'Your data will be removed within 30 days.',
    },
  ];
}
