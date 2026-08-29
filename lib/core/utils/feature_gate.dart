import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/theme/app_theme.dart';

/// Shows upgrade dialog when a feature is not available on the current plan.
/// Returns true if the feature is available, false otherwise.
bool checkFeatureAccess({
  required BuildContext context,
  required SubscriptionPlan currentPlan,
  required SubscriptionPlan requiredPlan,
  required String featureName,
}) {
  if (currentPlan.index >= requiredPlan.index) return true;

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.diamond_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Funzionalità Premium',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              '$featureName è disponibile dal piano ${requiredPlan.label}.\nPassa a ${requiredPlan.label} per sbloccare questa funzionalità.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            // Current plan info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Piano attuale: ${currentPlan.label}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Chiudi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/subscription');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Vedi Piani',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return false;
}

/// Quick check helpers
bool canImportCSV(BuildContext context, SubscriptionPlan plan) =>
    checkFeatureAccess(
      context: context,
      currentPlan: plan,
      requiredPlan: SubscriptionPlan.pro,
      featureName: 'Import CSV',
    );

bool canSendEmails(BuildContext context, SubscriptionPlan plan) =>
    checkFeatureAccess(
      context: context,
      currentPlan: plan,
      requiredPlan: SubscriptionPlan.pro,
      featureName: 'Email di conferma',
    );

bool canUseCustomDomain(BuildContext context, SubscriptionPlan plan) =>
    checkFeatureAccess(
      context: context,
      currentPlan: plan,
      requiredPlan: SubscriptionPlan.business,
      featureName: 'Dominio email custom',
    );

bool canViewAnalytics(BuildContext context, SubscriptionPlan plan) =>
    checkFeatureAccess(
      context: context,
      currentPlan: plan,
      requiredPlan: SubscriptionPlan.business,
      featureName: 'Analytics avanzati',
    );

bool canUseAiFeatures(BuildContext context, SubscriptionPlan plan) =>
    checkFeatureAccess(
      context: context,
      currentPlan: plan,
      requiredPlan: SubscriptionPlan.pro,
      featureName: 'AI Assistant',
    );

/// Check event limits - returns true if within limits
bool canCreateEvent(BuildContext context, SubscriptionPlan plan, int currentEventCount) {
  if (plan.isUnlimitedEvents) return true;
  if (currentEventCount < plan.maxEvents) return true;

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.event_busy_rounded, color: AppColors.warning, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Limite eventi raggiunto',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Il piano ${plan.label} permette ${plan.maxEvents} evento/i.\nPassa a un piano superiore per crearne di più.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Chiudi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/subscription');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Vedi Piani', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return false;
}

/// Check attendee limits per event - returns true if within limits
bool canAddAttendee(BuildContext context, SubscriptionPlan plan, int currentAttendeeCount) {
  if (plan.isUnlimitedAttendees) return true;
  if (currentAttendeeCount < plan.maxAttendeesPerEvent) return true;

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.people_outline_rounded, color: AppColors.warning, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Limite partecipanti raggiunto',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Il piano ${plan.label} permette massimo ${plan.maxAttendeesPerEvent} partecipanti per evento.\nPassa a un piano superiore per accettarne di più.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Chiudi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/subscription');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Vedi Piani', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return false;
}
