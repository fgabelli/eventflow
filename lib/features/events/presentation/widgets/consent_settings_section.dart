import 'package:flutter/material.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

/// Reusable section for toggling optional organizer communications and
/// photo/video consent checkboxes on an event's public registration form.
/// Available on all subscription plans (no plan gating).
class ConsentSettingsSection extends StatelessWidget {
  final bool isOnline;
  final bool showMarketingConsent;
  final bool showPhotoConsent;
  final ValueChanged<bool> onMarketingConsentChanged;
  final ValueChanged<bool> onPhotoConsentChanged;
  final Color? backgroundColor;

  const ConsentSettingsSection({
    super.key,
    required this.isOnline,
    required this.showMarketingConsent,
    required this.showPhotoConsent,
    required this.onMarketingConsentChanged,
    required this.onPhotoConsentChanged,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sectionBg = backgroundColor ?? AppColors.card;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l['consent_boxes_section_title'],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l['show_marketing_consent_label'],
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l['consent_toggle_helper'],
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: showMarketingConsent,
                onChanged: onMarketingConsentChanged,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (!isOnline) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l['show_photo_consent_label'],
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l['consent_toggle_helper'],
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: showPhotoConsent,
                  onChanged: onPhotoConsentChanged,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
