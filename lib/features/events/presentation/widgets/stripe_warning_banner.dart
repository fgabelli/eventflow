import 'package:flutter/material.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/services/stripe_connect_service.dart';

/// Warning banner displayed when an event is paid (isPaid == true)
/// but the organization does not have an active Stripe standard account.
class StripeWarningBanner extends StatelessWidget {
  final Organization org;
  final String? userEmail;

  const StripeWarningBanner({
    super.key,
    required this.org,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isPending = org.isStripePending;
    final message = isPending ? l['stripe_complete_prompt'] : l['stripe_connect_prompt'];
    final buttonLabel = isPending ? l['stripe_complete_btn'] : l['connect_stripe'];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF925700),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => StripeConnectService.connectStripe(
                context,
                orgId: org.id,
                orgName: org.name,
                userEmail: userEmail,
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog that blocks publishing a paid event when Stripe is not active.
Future<void> showStripeRequiredDialog(
  BuildContext context, {
  required Organization org,
  String? userEmail,
}) {
  final l = AppLocalizations.of(context);
  final isPending = org.isStripePending;
  final message = isPending ? l['stripe_complete_prompt'] : l['stripe_connect_prompt'];
  final buttonLabel = isPending ? l['stripe_complete_btn'] : l['connect_stripe'];

  return showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l['stripe_required_title'],
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l['cancel']),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              StripeConnectService.connectStripe(
                context,
                orgId: org.id,
                orgName: org.name,
                userEmail: userEmail,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text(buttonLabel),
          ),
        ],
      );
    },
  );
}
