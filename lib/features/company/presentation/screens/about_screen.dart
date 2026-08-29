import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final maxWidth = isMobile ? double.infinity : 900.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, l, isMobile),

            // ─── Hero ───
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 64,
                vertical: isMobile ? 48 : 72,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF5F3FF), Color(0xFFEEF2FF), Colors.white],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/ticketto_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l['about_hero_title'],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 32 : 48,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Text(
                          l['about_hero_subtitle'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Mission ───
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
                      _sectionTitle(l['about_mission_title']),
                      const SizedBox(height: 16),
                      Text(
                        l['about_mission_body'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ─── Values ───
                      _sectionTitle(l['about_values_title']),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _valueCard(
                            Icons.speed_rounded,
                            l['about_val1_title'],
                            l['about_val1_desc'],
                            AppColors.primary,
                            isMobile,
                          ),
                          _valueCard(
                            Icons.lock_outline_rounded,
                            l['about_val2_title'],
                            l['about_val2_desc'],
                            AppColors.success,
                            isMobile,
                          ),
                          _valueCard(
                            Icons.favorite_outline_rounded,
                            l['about_val3_title'],
                            l['about_val3_desc'],
                            AppColors.warning,
                            isMobile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // ─── Tech stack ───
                      _sectionTitle(l['about_tech_title']),
                      const SizedBox(height: 16),
                      Text(
                        l['about_tech_body'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ─── CTA ───
                      Center(
                        child: ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 36, vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l['start_free'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _valueCard(
      IconData icon, String title, String desc, Color color, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 270,
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
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(desc,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
        ],
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
}
