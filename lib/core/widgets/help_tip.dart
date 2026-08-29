import 'package:flutter/material.dart';
import 'package:eventflow/core/theme/app_theme.dart';

/// Contextual help tooltip — a small "?" icon that shows a popup with
/// an explanation when tapped. Use this next to any feature label.
///
/// Example:
/// ```dart
/// Row(
///   children: [
///     Text('Evento a pagamento'),
///     HelpTip(text: l['help_paid_event']),
///   ],
/// )
/// ```
class HelpTip extends StatelessWidget {
  final String text;
  final double iconSize;
  final Color? iconColor;

  const HelpTip({
    super.key,
    required this.text,
    this.iconSize = 18,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showHelp(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.help_outline_rounded,
          size: iconSize,
          color: iconColor ?? AppColors.textTertiary,
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => _HelpDialog(text: text),
    );
  }
}

class _HelpDialog extends StatelessWidget {
  final String text;
  const _HelpDialog({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
