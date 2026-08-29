import 'dart:convert';
import 'dart:math' show max;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:csv/csv.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/features/events/presentation/screens/events_screen.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/widgets/help_tip.dart';
import 'package:eventflow/core/utils/feature_gate.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isEditing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _maxAttendeesCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _printerIpCtrl;
  late TextEditingController _meetingUrlCtrl;
  late TextEditingController _hexColorCtrl;
  String? _selectedColor = '#6366F1';
  bool _showAttendeesCount = false;
  bool _isPaid = false;
  bool _allowGroupRegistration = false;
  bool _isSaving = false;
  bool _hasTimeSlots = false;
  List<TimeSlot> _editTimeSlots = [];
  bool _showQrCode = false;
  // Automated emails
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 1;
  bool _postEventEmailEnabled = false;
  bool _notifyOrganizer = false;
  
  // Printing settings
  bool _autoPrintOnCheckIn = false;

  // Online Event
  bool _isOnline = false;

  // Bug #7: Date/time fields for editing
  late DateTime _editDate;
  late TimeOfDay _editTime;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _maxAttendeesCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _printerIpCtrl = TextEditingController();
    _meetingUrlCtrl = TextEditingController();
    _hexColorCtrl = TextEditingController(text: '#6366F1');
    _editDate = DateTime.now();
    _editTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _maxAttendeesCtrl.dispose();
    _priceCtrl.dispose();
    _printerIpCtrl.dispose();
    _meetingUrlCtrl.dispose();
    _hexColorCtrl.dispose();
    super.dispose();
  }

  Color _parseHexColor(String? hexString, {Color defaultColor = AppColors.primary}) {
    if (hexString == null || hexString.isEmpty) {
      return defaultColor;
    }
    final buffer = StringBuffer();
    String clean = hexString.replaceAll('#', '').trim();
    if (clean.length == 6) {
      buffer.write('ff$clean');
    } else if (clean.length == 8) {
      buffer.write(clean);
    } else {
      return defaultColor;
    }
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  void _populateFields(EventModel event) {
    _titleCtrl.text = event.title;
    _descCtrl.text = event.description ?? '';
    _locationCtrl.text = event.location ?? '';
    _maxAttendeesCtrl.text = event.maxAttendees.toString();
    _priceCtrl.text = event.price?.toStringAsFixed(2) ?? '';
    _isPaid = event.isPaid;
    _allowGroupRegistration = event.allowGroupRegistration;
    _hasTimeSlots = event.hasTimeSlots;
    _editTimeSlots = List.from(event.timeSlots);
    _selectedColor = event.primaryColor ?? '#6366F1';
    _hexColorCtrl.text = _selectedColor ?? '#6366F1';
    _showAttendeesCount = event.showAttendeesCount;
    _reminderEnabled = event.reminderEnabled;
    _reminderDaysBefore = event.reminderDaysBefore;
    _postEventEmailEnabled = event.postEventEmailEnabled;
    _notifyOrganizer = event.notifyOrganizerOnNewRegistration;
    _printerIpCtrl.text = event.printerIpAddress ?? '';
    _autoPrintOnCheckIn = event.autoPrintOnCheckIn;
    _isOnline = event.isOnline;
    _meetingUrlCtrl.text = event.meetingUrl ?? '';
    _editDate = event.date;
    _editTime = TimeOfDay(hour: event.date.hour, minute: event.date.minute);
  }

  Future<void> _saveEvent(EventModel event) async {
    setState(() => _isSaving = true);
    try {
      final newDate = DateTime(
        _editDate.year, _editDate.month, _editDate.day,
        _editTime.hour, _editTime.minute,
      );
      await FirebaseFirestore.instance
          .collection(Collections.events)
          .doc(event.id)
          .update({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'isOnline': _isOnline,
        'meetingUrl': _isOnline ? _meetingUrlCtrl.text.trim() : null,
        'location': _isOnline ? null : (_locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim()),
        'maxAttendees': () {
          final org = ref.read(currentOrgProvider).value;
          final plan = org?.plan ?? SubscriptionPlan.free;
          final parsedMax = int.tryParse(_maxAttendeesCtrl.text) ?? 50;
          return plan.isUnlimitedAttendees
              ? parsedMax
              : parsedMax.clamp(1, max(plan.maxAttendeesPerEvent, event.maxAttendees));
        }(),
        'isPaid': _isPaid,
        'price': _isPaid ? double.tryParse(_priceCtrl.text) : null,
        'hasTimeSlots': _hasTimeSlots,
        'timeSlots': _hasTimeSlots ? _editTimeSlots.map((s) => s.toMap()).toList() : [],
        'primaryColor': _selectedColor,
        'showAttendeesCount': _showAttendeesCount,
        'date': Timestamp.fromDate(newDate),
        'reminderEnabled': _reminderEnabled,
        'reminderDaysBefore': _reminderDaysBefore,
        'postEventEmailEnabled': _postEventEmailEnabled,
        'notifyOrganizerOnNewRegistration': _notifyOrganizer,
        'printerIpAddress': _printerIpCtrl.text.trim().isEmpty ? null : _printerIpCtrl.text.trim(),
        'autoPrintOnCheckIn': _autoPrintOnCheckIn,
        'allowGroupRegistration': _allowGroupRegistration,
      });
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)['event_saved_msg']), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)['error_generic_short']}: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l['delete_event']),
          content: Text(l['delete_confirm']),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l['cancel'])),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(l['delete']),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      try {
        await ref.read(eventsServiceProvider).deleteEvent(widget.eventId);
        if (mounted) context.go('/events');
      } catch (e) {
        if (mounted) {
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l['error_generic_short']}: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _changeStatus(EventStatus status) async {
    await FirebaseFirestore.instance
        .collection(Collections.events)
        .doc(widget.eventId)
        .update({'status': status.name});
  }
  void _showAttendeeQuickView(BuildContext context, Attendee attendee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    '${attendee.firstName[0]}${attendee.lastName[0]}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 22),
                  ),
                ),
                const SizedBox(height: 12),
                Text(attendee.fullName, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(attendee.email, style: TextStyle(color: AppColors.textSecondary)),
                if (attendee.phone != null && attendee.phone!.isNotEmpty)
                  Text(attendee.phone!, style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (attendee.status == RegistrationStatus.confirmed
                                ? AppColors.success
                                : attendee.status == RegistrationStatus.pending
                                    ? AppColors.warning
                                    : AppColors.error)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                         attendee.status == RegistrationStatus.confirmed
                            ? AppLocalizations.of(context)['status_confirmed']
                            : attendee.status == RegistrationStatus.pending
                                ? AppLocalizations.of(context)['status_pending']
                                : AppLocalizations.of(context)['status_canceled'],
                        style: TextStyle(
                          color: attendee.status == RegistrationStatus.confirmed
                              ? AppColors.success
                              : attendee.status == RegistrationStatus.pending
                                  ? AppColors.warning
                                  : AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (attendee.checkInStatus == CheckInStatus.checkedIn) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                           AppLocalizations.of(context)['checked_in_label'],
                           style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                if (attendee.qrCode.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(AppLocalizations.of(context)['entry_qr_code'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 12),
                        QrImageView(
                          data: attendee.qrCode,
                          version: QrVersions.auto,
                          size: 180,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A2E)),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A2E)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          attendee.qrCode.substring(0, 8).toUpperCase(),
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 11, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _quickDetailRow(AppLocalizations.of(context)['category_label'], attendee.category),
                      _quickDetailRow(AppLocalizations.of(context)['registered_at_label'], '${attendee.registeredAt.day}/${attendee.registeredAt.month}/${attendee.registeredAt.year} ${attendee.registeredAt.hour.toString().padLeft(2, '0')}:${attendee.registeredAt.minute.toString().padLeft(2, '0')}'),
                      if (attendee.customData != null)
                        ...attendee.customData!.entries.map((e) => _quickDetailRow(e.key, e.value.toString())),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quickDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _exportCSV(EventModel event) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating CSV...'), duration: Duration(seconds: 1)),
      );

      // Fetch all attendees
      final snapshot = await FirebaseFirestore.instance
          .collection(Collections.attendees)
          .where('eventId', isEqualTo: event.id)
          .where('orgId', isEqualTo: event.orgId)
          .get();

      final attendees = snapshot.docs.map((d) => Attendee.fromFirestore(d)).toList();

      if (attendees.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)['no_attendees_export']), backgroundColor: AppColors.warning),
          );
        }
        return;
      }

      // Collect all unique custom data keys
      final customKeys = <String>{};
      for (final a in attendees) {
        customKeys.addAll(a.customData.keys);
      }
      final sortedCustomKeys = customKeys.toList()..sort();

      // Build custom field label lookup (id -> label)
      final fieldLabelMap = <String, String>{};
      for (final cf in event.customFields) {
        fieldLabelMap[cf.id] = cf.label;
      }

      // Build CSV header
      final header = [
        'First Name', 'Last Name', 'Email', 'Phone',
        'Category', 'Status', 'Check-in Status', 'Check-in Time',
        'Time Slot', 'Registered At',
        ...sortedCustomKeys.map((k) => fieldLabelMap[k] ?? k),
      ];

      // Build rows
      final rows = <List<String>>[header];
      for (final a in attendees) {
        // Resolve time slot label
        String slotLabel = '';
        if (a.timeSlotId != null) {
          final slot = event.timeSlots.where((s) => s.id == a.timeSlotId).firstOrNull;
          slotLabel = slot != null ? '${slot.label} (${slot.startTime}-${slot.endTime})' : a.timeSlotId!;
        }

        rows.add([
          a.firstName,
          a.lastName,
          a.email,
          a.phone ?? '',
          a.category,
          a.status.name,
          a.checkInStatus.name,
          a.checkInTime != null ? '${a.checkInTime!.day}/${a.checkInTime!.month}/${a.checkInTime!.year} ${a.checkInTime!.hour.toString().padLeft(2, '0')}:${a.checkInTime!.minute.toString().padLeft(2, '0')}' : '',
          slotLabel,
          '${a.registeredAt.day}/${a.registeredAt.month}/${a.registeredAt.year} ${a.registeredAt.hour.toString().padLeft(2, '0')}:${a.registeredAt.minute.toString().padLeft(2, '0')}',
          ...sortedCustomKeys.map((k) {
            final v = a.customData[k];
            if (v is bool) return v ? 'Sì' : 'No';
            return v?.toString() ?? '';
          }),
        ]);
      }

      final csvString = CsvCodec().encoder.convert(rows);

      if (kIsWeb) {
        // Web download via blob
        _downloadWebFile(csvString, '${event.title.replaceAll(' ', '_')}_attendees.csv');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                ? '${attendees.length} partecipanti esportati — CSV scaricato!'
                : '${attendees.length} partecipanti esportati',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)['export_error']}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _downloadWebFile(String content, String fileName) {
    // ignore: avoid_web_libraries_in_flutter
    // Use universal_html for web file download
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _duplicateEvent(EventModel event) async {
    try {
      final newId = await ref.read(eventsServiceProvider).createEvent(EventModel(
        id: '',
        orgId: event.orgId,
        title: '${event.title} (Copy)',
        description: event.description,
        date: event.date,
        endDate: event.endDate,
        location: event.location,
        status: EventStatus.draft,
        maxAttendees: event.maxAttendees,
        registrationDeadline: event.registrationDeadline,
        categories: event.categories,
        customFields: event.customFields,
        isPaid: event.isPaid,
        price: event.price,
        hasTimeSlots: event.hasTimeSlots,
        timeSlots: event.timeSlots.map((s) => TimeSlot(
          id: DateTime.now().millisecondsSinceEpoch.toString() + s.id,
          label: s.label,
          startTime: s.startTime,
          endTime: s.endTime,
          maxCapacity: s.maxCapacity,
          bookedCount: 0,
        )).toList(),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)['event_duplicated']),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/events/$newId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)['error_generic_short']}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _printQrCode(EventModel event) {
    final url = 'https://ticketto.it/register/${widget.eventId}';
    final dateStr = '${event.date.day}/${event.date.month}/${event.date.year}';
    final timeStr = '${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}';
    final locationStr = event.location ?? '';
    final escapedTitle = event.title.replaceAll("'", "\\'").replaceAll('"', '&quot;');
    final escapedLocation = locationStr.replaceAll("'", "\\'").replaceAll('"', '&quot;');

    final printHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>QR Code - ${escapedTitle}</title>
  <script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.3/build/qrcode.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    @page { size: A4; margin: 20mm; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background: #fff;
      color: #1a1a2e;
    }
    .card {
      text-align: center;
      padding: 48px 40px;
      border: 3px dashed #e0e0e0;
      border-radius: 24px;
      max-width: 420px;
      width: 100%;
    }
    .event-title {
      font-size: 24px;
      font-weight: 800;
      margin-bottom: 6px;
      color: #1a1a2e;
    }
    .event-meta {
      font-size: 14px;
      color: #666;
      margin-bottom: 4px;
    }
    .qr-container {
      margin: 28px auto;
      display: inline-block;
      padding: 16px;
      background: #fff;
      border-radius: 16px;
      box-shadow: 0 2px 16px rgba(0,0,0,0.06);
    }
    .scan-label {
      font-size: 18px;
      font-weight: 600;
      color: #1a1a2e;
      margin-top: 20px;
      margin-bottom: 8px;
    }
    .url-label {
      font-size: 11px;
      color: #999;
      word-break: break-all;
      margin-top: 12px;
    }
    .footer {
      margin-top: 24px;
      font-size: 11px;
      color: #bbb;
      letter-spacing: 1px;
      text-transform: uppercase;
    }
    @media print {
      body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .card { border-color: #ccc; }
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="event-title">${escapedTitle}</div>
    <div class="event-meta">📅 $dateStr  •  🕐 $timeStr</div>
    ${escapedLocation.isNotEmpty ? '<div class="event-meta">📍 $escapedLocation</div>' : ''}
    <div class="qr-container">
      <canvas id="qr"></canvas>
    </div>
    <div class="scan-label">📱 Scan to Register</div>
    <div class="url-label">$url</div>
    <div class="footer">Powered by Ticketto</div>
  </div>
  <script>
    QRCode.toCanvas(document.getElementById('qr'), '$url', {
      width: 280,
      margin: 1,
      color: { dark: '#1a1a2e', light: '#ffffff' }
    }, function(err) {
      if (!err) setTimeout(function() { window.print(); }, 500);
    });
  </script>
</body>
</html>
''';

    final blob = html.Blob([printHtml], 'text/html');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(blobUrl, '_blank');
    // Cleanup after a delay
    Future.delayed(const Duration(seconds: 5), () => html.Url.revokeObjectUrl(blobUrl));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.events)
          .doc(widget.eventId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)['event_not_found']),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/events'),
                    child: Text(AppLocalizations.of(context)['back_to_events']),
                  ),
                ],
              ),
            ),
          );
        }

        final event = EventModel.fromFirestore(snapshot.data!);

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/events');
                }
              },
            ),
            title: Text(_isEditing ? AppLocalizations.of(context)['edit_event'] : event.title),
            actions: [
              if (!_isEditing) ...[
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: AppLocalizations.of(context)['share_link_tooltip'],
                  onPressed: () {
                    final url = 'https://ticketto.it/register/${widget.eventId}';
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)['link_copied']),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(AppLocalizations.of(context)['edit'] ?? 'Modifica'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _populateFields(event);
                    setState(() => _isEditing = true);
                  },
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    if (event.status == EventStatus.draft)
                      PopupMenuItem(value: 'publish', child: Text(AppLocalizations.of(context)['publish'])),
                    if (event.status == EventStatus.published)
                      PopupMenuItem(value: 'complete', child: Text(AppLocalizations.of(context)['mark_complete'])),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          const Icon(Icons.download_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)['export_csv']),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          const Icon(Icons.copy_all_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)['duplicate_event']),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(AppLocalizations.of(context)['delete'], style: const TextStyle(color: AppColors.error)),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'publish': _changeStatus(EventStatus.published);
                      case 'complete': _changeStatus(EventStatus.completed);
                      case 'export': _exportCSV(event);
                      case 'duplicate': _duplicateEvent(event);
                      case 'delete': _deleteEvent();
                    }
                  },
                ),
              ] else ...[
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: Text(AppLocalizations.of(context)['cancel']),
                ),
                FilledButton(
                  onPressed: _isSaving ? null : () => _saveEvent(event),
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(AppLocalizations.of(context)['save']),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          body: _isEditing ? _buildEditForm(event) : _buildDetailView(event),
        );
      },
    );
  }

  Widget _buildDetailView(EventModel event) {
    final primaryColor = _parseHexColor(event.primaryColor);
    final isWhiteOrLight = primaryColor.computeLuminance() > 0.65;
    final cardDecoration = isWhiteOrLight
        ? BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          )
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                HSLColor.fromColor(primaryColor)
                    .withLightness((HSLColor.fromColor(primaryColor).lightness * 0.8).clamp(0.0, 1.0))
                    .toColor(),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          );

    final headerTextColor = isWhiteOrLight ? AppColors.textPrimary : Colors.white;
    final headerSubTextColor = isWhiteOrLight ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.85);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Status + Date header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isWhiteOrLight ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.status.label,
                      style: TextStyle(
                        color: isWhiteOrLight ? AppColors.primary : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (event.isPaid && event.price != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isWhiteOrLight ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '€${event.price!.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isWhiteOrLight ? AppColors.primary : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                event.title,
                style: TextStyle(color: headerTextColor, fontSize: 26, fontWeight: FontWeight.w700),
              ),
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: TextStyle(color: headerSubTextColor, fontSize: 14, height: 1.5),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: headerSubTextColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${event.date.day}/${event.date.month}/${event.date.year} ${AppLocalizations.of(context)['date_at']} ${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: headerTextColor, fontSize: 14),
                  ),
                ],
              ),
              if (event.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: headerSubTextColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: TextStyle(color: headerTextColor, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick Appearance & Color card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  border: isWhiteOrLight ? Border.all(color: AppColors.border, width: 1.5) : null,
                ),
                child: Icon(Icons.palette_outlined, size: 18, color: isWhiteOrLight ? AppColors.textPrimary : Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)['event_color'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      event.primaryColor != null && event.primaryColor!.isNotEmpty
                          ? 'Colore impostato: ${event.primaryColor}'
                          : 'Colore predefinito (#6366F1)',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.colorize_outlined, size: 14),
                label: const Text('Cambia'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  _populateFields(event);
                  setState(() => _isEditing = true);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Stats cards
        Row(
          children: [
            Expanded(child: _StatBox(label: AppLocalizations.of(context)['attendees_stat_label'], value: '${event.attendeesCount}/${event.maxAttendees}', icon: Icons.people, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _StatBox(label: AppLocalizations.of(context)['revenue_stat_label'], value: '€${event.revenue.toStringAsFixed(0)}', icon: Icons.euro, color: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _StatBox(label: AppLocalizations.of(context)['capacity_stat_label'], value: '${((event.attendeesCount / event.maxAttendees) * 100).toStringAsFixed(0)}%', icon: Icons.pie_chart, color: AppColors.accent)),
          ],
        ),

        const SizedBox(height: 20),

        // Analytics Dashboard
        _buildAnalyticsDashboard(event),

        const SizedBox(height: 20),

        // Registration Link section (only for published events)
        if (event.status == EventStatus.published) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)['registration_link'], style: Theme.of(context).textTheme.titleMedium),
                    HelpTip(text: AppLocalizations.of(context)['help_registration_link'], iconSize: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'https://ticketto.it/register/${widget.eventId}',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                            text: 'https://ticketto.it/register/${widget.eventId}',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)['link_copied_short']),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(AppLocalizations.of(context)['copy_label'], style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // QR Code toggle button
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _showQrCode = !_showQrCode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showQrCode ? Icons.qr_code_2 : Icons.qr_code,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showQrCode ? AppLocalizations.of(context)['hide_qr'] : AppLocalizations.of(context)['show_qr'],
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showQrCode ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                // QR Code section (animated)
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                event.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${event.date.day}/${event.date.month}/${event.date.year}',
                                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              ),
                              const SizedBox(height: 16),
                              QrImageView(
                                data: 'https://ticketto.it/register/${widget.eventId}',
                                version: QrVersions.auto,
                                size: 200,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.primary,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.textPrimary,
                                ),
                                gapless: true,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(context)['scan_to_register'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Print QR Code button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _printQrCode(event),
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: Text(AppLocalizations.of(context)['print_qr']),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)['qr_print_hint'],
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 11, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _showQrCode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Time Slots Section
        if (event.hasTimeSlots && event.timeSlots.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)['time_slot_booking'], style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${event.timeSlots.length} ${AppLocalizations.of(context)['time_slots_count']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...event.timeSlots.map((slot) {
                  final progress = slot.maxCapacity > 0 ? slot.bookedCount / slot.maxCapacity : 0.0;
                  final isFull = slot.isFull;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                slot.label,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${slot.startTime} – ${slot.endTime}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            color: isFull ? AppColors.error : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${slot.bookedCount}/${slot.maxCapacity} booked',
                              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                            ),
                            Text(
                              isFull ? AppLocalizations.of(context)['slot_full'] : '${slot.availableSpots} ${AppLocalizations.of(context)['available_label']}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isFull ? AppColors.error : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 4),

        // Attendees section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)['attendees'], style: Theme.of(context).textTheme.titleLarge),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/attendees'),
              icon: const Icon(Icons.people, size: 16),
              label: Text(AppLocalizations.of(context)['manage']),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Recent attendees
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(Collections.attendees)
              .where('eventId', isEqualTo: widget.eventId)
              .where('orgId', isEqualTo: event.orgId)
              .limit(5)
              .snapshots(),
          builder: (context, snap) {
            final attendees = snap.data?.docs
                .map((d) => Attendee.fromFirestore(d))
                .toList() ?? [];

            if (attendees.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_add, size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(AppLocalizations.of(context)['no_attendees_detail'], style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              );
            }

            return Column(
              children: attendees.map((a) => InkWell(
                onTap: () => _showAttendeeQuickView(context, a),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        '${a.firstName[0]}${a.lastName[0]}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.fullName, style: Theme.of(context).textTheme.titleSmall),
                          Text(a.email, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: a.checkInStatus == CheckInStatus.checkedIn
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        a.checkInStatus == CheckInStatus.checkedIn ? 'In' : a.status.label,
                        style: TextStyle(
                          color: a.checkInStatus == CheckInStatus.checkedIn ? AppColors.success : AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ],
                ),
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnalyticsDashboard(EventModel event) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.attendees)
          .where('eventId', isEqualTo: event.id)
          .where('orgId', isEqualTo: event.orgId)
          .snapshots(),
      builder: (context, snapshot) {
        final attendees = snapshot.data?.docs
            .map((d) => Attendee.fromFirestore(d))
            .toList() ?? [];

        final checkedIn = attendees.where((a) => a.checkInStatus == CheckInStatus.checkedIn).length;
        final checkInRate = attendees.isNotEmpty ? checkedIn / attendees.length : 0.0;
        final capacityRate = event.maxAttendees > 0 ? event.attendeesCount / event.maxAttendees : 0.0;

        // Registration timeline (last 7 days)
        final now = DateTime.now();
        final days = List.generate(7, (i) {
          final day = now.subtract(Duration(days: 6 - i));
          return DateTime(day.year, day.month, day.day);
        });
        final dayCounts = <DateTime, int>{};
        for (final d in days) {
          dayCounts[d] = 0;
        }
        for (final a in attendees) {
          final regDay = DateTime(a.registeredAt.year, a.registeredAt.month, a.registeredAt.day);
          if (dayCounts.containsKey(regDay)) {
            dayCounts[regDay] = dayCounts[regDay]! + 1;
          }
        }
        final maxDayCount = dayCounts.values.fold<int>(0, (m, v) => v > m ? v : m);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)['analytics_label'], style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 20),

              // Capacity bar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLocalizations.of(context)['capacity_stat_label'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            Text(
                              '${event.attendeesCount}/${event.maxAttendees}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: capacityRate.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: AppColors.surface,
                            valueColor: AlwaysStoppedAnimation(
                              capacityRate > 0.9 ? AppColors.error
                                : capacityRate > 0.7 ? AppColors.warning
                                : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Check-in rate circle
                  Column(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                value: checkInRate,
                                strokeWidth: 6,
                                backgroundColor: AppColors.surface,
                                valueColor: const AlwaysStoppedAnimation(AppColors.success),
                              ),
                            ),
                            Text(
                              '${(checkInRate * 100).toInt()}%',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check-in',
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Registration timeline
              Text(AppLocalizations.of(context)['registrations_chart'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),

              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days.map((day) {
                    final count = dayCounts[day] ?? 0;
                    final barHeight = maxDayCount > 0 ? (count / maxDayCount) * 80 : 0.0;
                    final isToday = day.day == now.day && day.month == now.month && day.year == now.year;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (count > 0)
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isToday ? AppColors.primary : AppColors.textSecondary,
                                ),
                              ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              height: barHeight > 0 ? barHeight : 4,
                              decoration: BoxDecoration(
                                gradient: isToday
                                    ? AppColors.primaryGradient
                                    : LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.3),
                                          AppColors.primary.withValues(alpha: 0.15),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${day.day}/${day.month}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isToday ? AppColors.primary : AppColors.textTertiary,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Additional stats row
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniStat(label: AppLocalizations.of(context)['confirmed_stat'], value: '${attendees.where((a) => a.status == RegistrationStatus.confirmed).length}', icon: Icons.check_circle_outline, color: AppColors.success),
                  const SizedBox(width: 16),
                  _MiniStat(label: AppLocalizations.of(context)['pending_stat'], value: '${attendees.where((a) => a.status == RegistrationStatus.pending).length}', icon: Icons.schedule, color: AppColors.warning),
                  const SizedBox(width: 16),
                  _MiniStat(label: AppLocalizations.of(context)['checked_in_stat'], value: '$checkedIn', icon: Icons.login_rounded, color: AppColors.accent),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditForm(EventModel event) {
    final org = ref.watch(currentOrgProvider).value;
    final isPremium = org != null && (org.plan.name == 'pro' || org.plan.name == 'business');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildLabel(AppLocalizations.of(context)['event_title_label']),
        TextField(controller: _titleCtrl, decoration: InputDecoration(hintText: AppLocalizations.of(context)['event_title_hint'])),
        const SizedBox(height: 20),

        _buildLabel(AppLocalizations.of(context)['description_label']),
        TextField(controller: _descCtrl, maxLines: 3, decoration: InputDecoration(hintText: AppLocalizations.of(context)['description_label'])),
        const SizedBox(height: 20),

        _buildLabel(AppLocalizations.of(context)['location_label']),
        // Location / Online Event
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Tipologia Evento'),
            Row(
              children: [
                Text('Online', style: Theme.of(context).textTheme.bodySmall),
                Switch(
                  value: _isOnline,
                  onChanged: (v) => setState(() => _isOnline = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
        if (!_isOnline)
          TextField(controller: _locationCtrl, decoration: InputDecoration(hintText: AppLocalizations.of(context)['venue_hint'], prefixIcon: const Icon(Icons.location_on_outlined)))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _meetingUrlCtrl, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://zoom.us/j/123456...', prefixIcon: Icon(Icons.link))),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '🔒 Il link viene incluso nell\'email di conferma solo dopo la registrazione (o il pagamento). Non sarà mai visibile prima.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),

        _buildLabel(AppLocalizations.of(context)['max_attendees_label']),
        TextField(
          controller: _maxAttendeesCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.people_outline),
            helperText: () {
              final plan = ref.read(currentOrgProvider).value?.plan ?? SubscriptionPlan.free;
              return plan.isUnlimitedAttendees ? 'Illimitati' : 'Max ${plan.maxAttendeesPerEvent} (piano ${plan.label})';
            }(),
          ),
        ),
        const SizedBox(height: 20),

        // Date & Time pickers (Bug #7)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(AppLocalizations.of(context)['edit_date_label']),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _editDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _editDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        '${_editDate.day.toString().padLeft(2, '0')}/${_editDate.month.toString().padLeft(2, '0')}/${_editDate.year}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(AppLocalizations.of(context)['edit_time_label']),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _editTime,
                      );
                      if (picked != null) setState(() => _editTime = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.access_time_outlined),
                      ),
                      child: Text(
                        '${_editTime.hour.toString().padLeft(2, '0')}:${_editTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ─── Personalizzazione & Colore ───────────────────────
        Container(
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
                  const Icon(Icons.palette_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)['event_color'], style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  {'name': 'Viola', 'hex': '#6366F1', 'color': const Color(0xFF6366F1)},
                  {'name': 'Blu Oceano', 'hex': '#1B5E9E', 'color': const Color(0xFF1B5E9E)},
                  {'name': 'Teal', 'hex': '#0D9488', 'color': const Color(0xFF0D9488)},
                  {'name': 'Smeraldo', 'hex': '#10B981', 'color': const Color(0xFF10B981)},
                  {'name': 'Ambra', 'hex': '#D97706', 'color': const Color(0xFFD97706)},
                  {'name': 'Rosso', 'hex': '#E11D48', 'color': const Color(0xFFE11D48)},
                  {'name': 'Dark Grafite', 'hex': '#1E293B', 'color': const Color(0xFF1E293B)},
                  {'name': AppLocalizations.of(context)['color_white_minimal'], 'hex': '#FFFFFF', 'color': const Color(0xFFFFFFFF)},
                ].map((preset) {
                  final hex = preset['hex'] as String;
                  final isSelected = _selectedColor?.toUpperCase() == hex.toUpperCase();
                  final color = preset['color'] as Color;
                  final isWhite = hex == '#FFFFFF';

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = hex;
                        _hexColorCtrl.text = hex;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isWhite ? Border.all(color: AppColors.border, width: 1.5) : null,
                            ),
                            child: isSelected
                                ? Icon(Icons.check, size: 12, color: isWhite ? Colors.black : Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            preset['name'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexColorCtrl,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)['custom_hex_color'],
                        hintText: '#1B5E9E',
                        prefixIcon: const Icon(Icons.colorize_outlined),
                      ),
                      onChanged: (val) {
                        if (val.trim().startsWith('#') && (val.trim().length == 7 || val.trim().length == 9)) {
                          setState(() => _selectedColor = val.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _parseHexColor(_selectedColor),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)['show_attendees_count'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          AppLocalizations.of(context)['show_attendees_count_desc'],
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _showAttendeesCount,
                    onChanged: (v) => setState(() => _showAttendeesCount = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)['enable_pricing'], style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                  ),
                  Switch(
                    value: _isPaid,
                    onChanged: (v) {
                      final org = ref.read(currentOrgProvider).value;
                      final plan = org?.plan ?? SubscriptionPlan.free;
                      if (v && plan.isFree) {
                        checkFeatureAccess(
                          context: context,
                          currentPlan: plan,
                          requiredPlan: SubscriptionPlan.pro,
                          featureName: 'Eventi a pagamento',
                        );
                        return;
                      }
                      setState(() => _isPaid = v);
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              if (_isPaid) ...[
                const SizedBox(height: 12),
                TextField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '0.00', prefixIcon: Icon(Icons.euro))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Group Registration
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrazione di gruppo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                  ),
                  const SizedBox(height: 2),
                  Text('Consenti la prenotazione per più persone', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: _allowGroupRegistration,
              onChanged: (v) {
                final plan = ref.read(currentOrgProvider).value?.plan ?? SubscriptionPlan.free;
                if (v && plan.isFree) {
                  checkFeatureAccess(
                    context: context,
                    currentPlan: plan,
                    requiredPlan: SubscriptionPlan.pro,
                    featureName: 'Registrazione di gruppo',
                  );
                  return;
                }
                setState(() => _allowGroupRegistration = v);
              },
              activeColor: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Time Slots Edit
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)['time_slot_booking'], style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                  ),
                  Switch(value: _hasTimeSlots, onChanged: (v) {
                    final plan = ref.read(currentOrgProvider).value?.plan ?? SubscriptionPlan.free;
                    if (v && plan.isFree) {
                      checkFeatureAccess(
                        context: context,
                        currentPlan: plan,
                        requiredPlan: SubscriptionPlan.pro,
                        featureName: 'Prenotazione Fasce Orarie',
                      );
                      return;
                    }
                    setState(() => _hasTimeSlots = v);
                  }, activeColor: AppColors.primary),
                ],
              ),
              if (_hasTimeSlots) ...[
                const SizedBox(height: 12),
                ..._editTimeSlots.asMap().entries.map((entry) {
                  final i = entry.key;
                  final slot = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(slot.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${slot.startTime} – ${slot.endTime}  •  ${slot.maxCapacity} ${AppLocalizations.of(context)['spots_label']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _editTimeSlots.removeAt(i)),
                          child: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        ),
                      ],
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: () => _showEditAddSlotDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(AppLocalizations.of(context)['add_time_slot']),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Automated Emails Section ────────────────────────
        Container(
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
                  Icon(Icons.email_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Email automatiche', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              // Reminder
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📅 Promemoria pre-evento', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Invia un reminder ai partecipanti', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(value: _reminderEnabled, onChanged: (v) => setState(() => _reminderEnabled = v), activeColor: AppColors.primary),
                ],
              ),
              if (_reminderEnabled) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _reminderDaysBefore,
                  decoration: const InputDecoration(
                    labelText: 'Quando inviare',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 giorno prima')),
                    DropdownMenuItem(value: 3, child: Text('3 giorni prima')),
                    DropdownMenuItem(value: 7, child: Text('1 settimana prima')),
                  ],
                  onChanged: (v) => setState(() => _reminderDaysBefore = v ?? 1),
                ),
              ],
              const Divider(height: 24),
              // Post-event thank you
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🙏 Ringraziamento post-evento', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Email con link per lasciare feedback', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(value: _postEventEmailEnabled, onChanged: (v) => setState(() => _postEventEmailEnabled = v), activeColor: AppColors.primary),
                ],
              ),
              const Divider(height: 24),
              // Notification for new registrations
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🔔 Notifiche real-time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                            ),
                          ],
                        ),
                        Text('Ricevi un\'email per ogni iscrizione', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (!isPremium)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Disponibile nei piani Pro e Business',
                              style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notifyOrganizer, 
                    onChanged: isPremium ? (v) => setState(() => _notifyOrganizer = v) : null, 
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Hardware & Check-in ─────────────────────────────
        Container(
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
                  Icon(Icons.print_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Hardware & Stampa (Zero-Tap)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('BUSINESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Stampa termica diretta su rete locale (TCP porta 9100). Compatibile con Zebra ZPL e Brother QL/RJ. La stampante deve essere sulla stessa rete Wi-Fi dei device staff.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _printerIpCtrl,
                enabled: org?.plan.name == 'business',
                decoration: const InputDecoration(
                  labelText: 'Indirizzo IP Stampante',
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.router_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Es. 192.168.1.100 — lo trovi stampando il report di rete dalla tua Zebra/Brother.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚡ Stampa automatica', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Stampa il badge istantaneamente dopo lo scan', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoPrintOnCheckIn,
                    onChanged: org?.plan.name == 'business' ? (v) => setState(() => _autoPrintOnCheckIn = v) : null,
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              if (org?.plan.name != 'business')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Disponibile solo con piano Business',
                    style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  void _showEditAddSlotDialog() {
    final labelCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '10');
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)['add_time_slot']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)['slot_label_field'], hintText: AppLocalizations.of(context)['slot_hint']),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: ctx, initialTime: startTime);
                          if (t != null) setDialogState(() => startTime = t);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: AppLocalizations.of(context)['start_label']),
                          child: Text('${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: ctx, initialTime: endTime);
                          if (t != null) setDialogState(() => endTime = t);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: AppLocalizations.of(context)['end_label']),
                          child: Text('${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capacityCtrl,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)['max_capacity'], prefixIcon: const Icon(Icons.people_outline)),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)['cancel'])),
              FilledButton(
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty) return;
                  final slot = TimeSlot(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    label: labelCtrl.text.trim(),
                    startTime: '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                    endTime: '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                    maxCapacity: int.tryParse(capacityCtrl.text) ?? 10,
                  );
                  setState(() => _editTimeSlots.add(slot));
                  Navigator.pop(ctx);
                },
                child: Text(AppLocalizations.of(context)['add']),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
