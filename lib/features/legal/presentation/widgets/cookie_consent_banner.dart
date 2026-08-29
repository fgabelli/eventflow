import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/analytics/analytics_service.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class CookieConsentBanner extends StatefulWidget {
  final Widget child;
  const CookieConsentBanner({super.key, required this.child});

  @override
  State<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends State<CookieConsentBanner>
    with SingleTickerProviderStateMixin {
  bool _showBanner = false;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _checkConsent();
  }

  void _checkConsent() {
    try {
      final saved = html.window.localStorage['cookie_consent'];
      if (saved == null) {
        // No choice made yet — show banner
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() => _showBanner = true);
            _animController.forward();
          }
        });
      }
    } catch (_) {}
  }

  void _acceptAll() {
    try {
      (html.window as dynamic).grantMarketingConsent();
    } catch (_) {}
    AnalyticsService.instance.enableAnalytics();
    _dismiss();
  }

  void _rejectMarketing() {
    try {
      (html.window as dynamic).revokeMarketingConsent();
    } catch (_) {}
    AnalyticsService.instance.disableAnalytics();
    _dismiss();
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner) _buildBanner(context),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 40,
                vertical: 20,
              ),
              child: isMobile
                  ? _buildMobileLayout(l)
                  : _buildDesktopLayout(l),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(AppLocalizations l) {
    return Row(
      children: [
        const Icon(Icons.cookie_outlined, color: AppColors.primary, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l['cookie_banner_title'],
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l['cookie_banner_body'],
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        OutlinedButton(
          onPressed: _rejectMarketing,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(l['cookie_reject']),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _acceptAll,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(l['cookie_accept']),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.cookie_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              l['cookie_banner_title'],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l['cookie_banner_body'],
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _rejectMarketing,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(l['cookie_reject']),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _acceptAll,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(l['cookie_accept']),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
