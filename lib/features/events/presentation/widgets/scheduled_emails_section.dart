import 'dart:math' show min;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/utils/feature_gate.dart';
import 'package:eventflow/core/widgets/ticket_badge.dart';
import 'package:eventflow/features/events/presentation/widgets/html_email_preview_stub.dart'
    if (dart.library.html) 'package:eventflow/features/events/presentation/widgets/html_email_preview_web.dart';

class ScheduledEmailsSection extends StatefulWidget {
  final String eventId;
  final SubscriptionPlan plan;
  final bool canManageEmails; // owner or admin
  final bool reminderEnabled;
  final ValueChanged<bool> onReminderEnabledChanged;
  final int reminderDaysBefore;
  final ValueChanged<int> onReminderDaysBeforeChanged;
  final TextEditingController reminderCustomMessageController;
  final bool postEventEmailEnabled;
  final ValueChanged<bool> onPostEventEmailEnabledChanged;
  final TextEditingController thankYouCustomMessageController;
  final bool notifyOrganizer;
  final ValueChanged<bool> onNotifyOrganizerChanged;

  const ScheduledEmailsSection({
    super.key,
    required this.eventId,
    required this.plan,
    required this.canManageEmails,
    required this.reminderEnabled,
    required this.onReminderEnabledChanged,
    required this.reminderDaysBefore,
    required this.onReminderDaysBeforeChanged,
    required this.reminderCustomMessageController,
    required this.postEventEmailEnabled,
    required this.onPostEventEmailEnabledChanged,
    required this.thankYouCustomMessageController,
    required this.notifyOrganizer,
    required this.onNotifyOrganizerChanged,
  });

  @override
  State<ScheduledEmailsSection> createState() => _ScheduledEmailsSectionState();
}

class _ScheduledEmailsSectionState extends State<ScheduledEmailsSection> {
  String? _sendingTestType;

  bool get _isPremium => widget.plan == SubscriptionPlan.pro || widget.plan == SubscriptionPlan.business;

  String _currentCustomMessageFor(String type) {
    if (type == 'reminder') {
      return widget.reminderCustomMessageController.text;
    }
    return widget.thankYouCustomMessageController.text;
  }

  Future<void> _sendTestEmail(String type) async {
    if (_sendingTestType != null) return;
    final l = AppLocalizations.of(context);
    setState(() => _sendingTestType = type);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('sendTestScheduledEmail');
      final res = await callable.call({
        'eventId': widget.eventId,
        'type': type,
        'customMessage': _currentCustomMessageFor(type),
      });
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final toEmail = (data['to'] as String?) ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l['email_test_sent_msg'].replaceAll('{email}', toEmail)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'resource-exhausted'
          ? l['email_test_rate_limit_msg']
          : '${l['error_generic_short']}: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l['error_generic_short']}: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _sendingTestType = null);
    }
  }

  void _openPreviewDialog(String type) {
    final l = AppLocalizations.of(context);
    final dialogTitle = type == 'reminder'
        ? l['email_preview_dialog_title_reminder']
        : l['email_preview_dialog_title_thank_you'];
    final customMsg = _currentCustomMessageFor(type);

    showDialog(
      context: context,
      builder: (ctx) => _ScheduledEmailPreviewDialog(
        eventId: widget.eventId,
        type: type,
        customMessage: customMsg,
        title: dialogTitle,
        isPremium: _isPremium,
        onSendTest: _isPremium ? () => _sendTestEmail(type) : null,
      ),
    );
  }

  Widget _buildProUpgradeHint(BuildContext context, String featureName) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => checkFeatureAccess(
          context: context,
          currentPlan: widget.plan,
          requiredPlan: SubscriptionPlan.pro,
          featureName: featureName,
        ),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            l['available_from_pro'],
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailActions(BuildContext context, String type) {
    if (!widget.canManageEmails) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final isSending = _sendingTestType == type;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _openPreviewDialog(type),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(l['email_preview_btn']),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (_isPremium)
            OutlinedButton.icon(
              onPressed: isSending ? null : () => _sendTestEmail(type),
              icon: isSending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 15),
              label: Text(l['email_send_test_btn']),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(l['scheduled_emails_title'], style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),

          // ─── 1. Reminder Email ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l['reminder_email_title'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const TicketBadge(label: 'PRO'),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l['reminder_email_subtitle'],
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (!_isPremium)
                      _buildProUpgradeHint(context, l['reminder_email_title']),
                  ],
                ),
              ),
              Switch(
                value: _isPremium && widget.reminderEnabled,
                onChanged: _isPremium ? widget.onReminderEnabledChanged : null,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_isPremium && widget.reminderEnabled) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey(widget.reminderDaysBefore),
              initialValue: widget.reminderDaysBefore,
              decoration: InputDecoration(
                labelText: l['reminder_when_label'],
                prefixIcon: const Icon(Icons.schedule),
              ),
              items: [
                DropdownMenuItem(value: 1, child: Text(l['reminder_1_day_before'])),
                DropdownMenuItem(value: 3, child: Text(l['reminder_3_days_before'])),
                DropdownMenuItem(value: 7, child: Text(l['reminder_7_days_before'])),
              ],
              onChanged: (v) => widget.onReminderDaysBeforeChanged(v ?? 1),
            ),
          ],
          if (_isPremium) ...[
            const SizedBox(height: 12),
            TextField(
              controller: widget.reminderCustomMessageController,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l['email_custom_message_label'],
                hintText: l['reminder_custom_message_hint'],
                alignLabelWithHint: true,
              ),
            ),
          ],
          _buildEmailActions(context, 'reminder'),

          const Divider(height: 24),

          // ─── 2. Post-event Thank You Email ───────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l['thank_you_email_title'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const TicketBadge(label: 'PRO'),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l['thank_you_email_subtitle'],
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l['thank_you_auto_timing_note'],
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                    ),
                    if (!_isPremium)
                      _buildProUpgradeHint(context, l['thank_you_email_title']),
                  ],
                ),
              ),
              Switch(
                value: _isPremium && widget.postEventEmailEnabled,
                onChanged: _isPremium ? widget.onPostEventEmailEnabledChanged : null,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_isPremium) ...[
            const SizedBox(height: 12),
            TextField(
              controller: widget.thankYouCustomMessageController,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l['email_custom_message_label'],
                hintText: l['thank_you_custom_message_hint'],
                alignLabelWithHint: true,
              ),
            ),
          ],
          _buildEmailActions(context, 'thankYou'),

          const Divider(height: 24),

          // ─── 3. Real-time Organizer Notification ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l['realtime_notifications_title'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const TicketBadge(label: 'PRO'),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l['realtime_notifications_desc'],
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (!_isPremium)
                      _buildProUpgradeHint(context, l['realtime_notifications_label']),
                  ],
                ),
              ),
              Switch(
                value: _isPremium && widget.notifyOrganizer,
                onChanged: _isPremium ? widget.onNotifyOrganizerChanged : null,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduledEmailPreviewDialog extends StatefulWidget {
  final String eventId;
  final String type;
  final String customMessage;
  final String title;
  final bool isPremium;
  final Future<void> Function()? onSendTest;

  const _ScheduledEmailPreviewDialog({
    required this.eventId,
    required this.type,
    required this.customMessage,
    required this.title,
    required this.isPremium,
    this.onSendTest,
  });

  @override
  State<_ScheduledEmailPreviewDialog> createState() => _ScheduledEmailPreviewDialogState();
}

class _ScheduledEmailPreviewDialogState extends State<_ScheduledEmailPreviewDialog> {
  bool _loading = true;
  String? _error;
  String _subject = '';
  String _html = '';
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('previewScheduledEmail');
      final res = await callable.call({
        'eventId': widget.eventId,
        'type': widget.type,
        'customMessage': widget.customMessage,
      });
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _subject = (data['subject'] as String?) ?? '';
        _html = (data['html'] as String?) ?? '';
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? e.code;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = min(screenSize.width - 32, 680.0);
    final dialogHeight = min(screenSize.height * 0.85, 740.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            if (!_loading && _error == null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        children: [
                          TextSpan(
                            text: '${l['email_preview_subject_label']} ',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          TextSpan(
                            text: _subject,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l['email_preview_fake_attendee_note'],
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  '${l['error_generic_short']}: $_error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _loadPreview,
                                  child: Text(l['email_preview_retry']),
                                ),
                              ],
                            ),
                          ),
                        )
                      : buildHtmlEmailPreview(_html),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.isPremium && widget.onSendTest != null && !_loading && _error == null) ...[
                    OutlinedButton.icon(
                      onPressed: _sendingTest
                          ? null
                          : () async {
                              setState(() => _sendingTest = true);
                              await widget.onSendTest!();
                              if (mounted) setState(() => _sendingTest = false);
                            },
                      icon: _sendingTest
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 16),
                      label: Text(l['email_send_test_btn']),
                    ),
                    const SizedBox(width: 10),
                  ],
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: Text(l['close']),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
