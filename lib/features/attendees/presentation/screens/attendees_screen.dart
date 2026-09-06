import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/utils/feature_gate.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/widgets/help_tip.dart';
import 'package:eventflow/core/services/badge_printing_service.dart';
import 'package:eventflow/core/analytics/analytics_service.dart';

class AttendeesScreen extends ConsumerStatefulWidget {
  const AttendeesScreen({super.key});

  @override
  ConsumerState<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends ConsumerState<AttendeesScreen> {
  String? _selectedEventId;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrgProvider).value;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.surface,
            title: Row(
              children: [
                Text(AppLocalizations.of(context)['attendees'], style: Theme.of(context).textTheme.headlineMedium),
                HelpTip(text: AppLocalizations.of(context)['help_attendees_list']),
              ],
            ),
            actions: [
              if (org != null && (org.plan == 'pro' || org.plan == 'business'))
                IconButton(
                  onPressed: () => _exportBadgesA4(context, org),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'Stampa Badge (A4)', 
                ),
              IconButton(
                onPressed: () => _exportAllAttendeesCSV(context),
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Esporta Tutto (CSV)', // Tooltip in IT/EN
              ),
              const SizedBox(width: 4),
              if (_selectedEventId != null) ...[
                IconButton(
                  onPressed: () => _tryImportCSV(context),
                  icon: const Icon(Icons.upload_file),
                  tooltip: AppLocalizations.of(context)['import_csv_tooltip'],
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: () => _tryAddAttendee(context),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: Text(AppLocalizations.of(context)['add']),
                ),
              ],
              const SizedBox(width: 16),
            ],
          ),

          // Event selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildEventSelector(org),
            ),
          ),

          // Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)['search_attendees'],
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Attendees content
          _selectedEventId == null
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.people_rounded, size: 48, color: AppColors.primary),
                        ),
                        const SizedBox(height: 24),
                        Text(AppLocalizations.of(context)['select_event'], style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)['choose_event_attendees'],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              : _buildAttendeesGrid(),
        ],
      ),
    );
  }

  Widget _buildEventSelector(Organization? org) {
    if (org == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.events)
          .where('orgId', isEqualTo: org.id)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final events = snapshot.data?.docs
            .map((d) => EventModel.fromFirestore(d))
            .toList() ?? [];

        return DropdownButtonFormField<String>(
          value: _selectedEventId,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)['event_label'],
            prefixIcon: const Icon(Icons.event),
          ),
          items: events
              .map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.title, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedEventId = value),
        );
      },
    );
  }

  Widget _buildAttendeesGrid() {
    final searchQuery = _searchController.text.toLowerCase();
    final org = ref.watch(currentOrgProvider).value;

    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(Collections.attendees)
            .where('eventId', isEqualTo: _selectedEventId)
            .where('orgId', isEqualTo: org?.id)
            .orderBy('registeredAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)['error_loading_attendees'], style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          var attendees = snapshot.data?.docs
              .map((d) => Attendee.fromFirestore(d))
              .toList() ?? [];

          if (searchQuery.isNotEmpty) {
            attendees = attendees.where((a) =>
              a.fullName.toLowerCase().contains(searchQuery) ||
              a.email.toLowerCase().contains(searchQuery)
            ).toList();
          }

          if (attendees.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      searchQuery.isNotEmpty ? AppLocalizations.of(context)['no_results_found'] : AppLocalizations.of(context)['no_attendees_yet_short'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          // Summary stats
          final confirmed = attendees.where((a) => a.status == RegistrationStatus.confirmed).length;
          final pending = attendees.where((a) => a.status == RegistrationStatus.pending).length;
          final checkedIn = attendees.where((a) => a.checkInStatus == CheckInStatus.checkedIn).length;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Stats row
                Row(
                  children: [
                    Expanded(child: _StatCard(icon: Icons.people, label: AppLocalizations.of(context)['total_stat'], value: '${attendees.length}', color: AppColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(icon: Icons.check_circle, label: AppLocalizations.of(context)['confirmed_stat'], value: '$confirmed', color: AppColors.success)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(icon: Icons.pending, label: AppLocalizations.of(context)['pending_stat'], value: '$pending', color: AppColors.warning)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(icon: Icons.login, label: AppLocalizations.of(context)['checked_in_stat'], value: '$checkedIn', color: AppColors.accent)),
                  ],
                ),
                const SizedBox(height: 16),

                // List
                ...attendees.map((attendee) => _AttendeeCard(
                  attendee: attendee,
                  onStatusChange: (status) => _changeStatus(attendee.id, status),
                  onDelete: () => _deleteAttendee(attendee.id),
                  onTap: () {
                    if (org != null) _showAttendeeDetail(context, attendee, org);
                  },
                )),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  void _changeStatus(String attendeeId, RegistrationStatus status) {
    FirebaseFirestore.instance
        .collection(Collections.attendees)
        .doc(attendeeId)
        .update({'status': status.name});
  }

  Future<void> _deleteAttendee(String attendeeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l['remove_attendee']),
          content: Text(l['remove_confirm']),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l['cancel'])),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(l['remove']),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection(Collections.attendees)
          .doc(attendeeId)
          .delete();
    }
  }

  void _showAttendeeDetail(BuildContext context, Attendee attendee, Organization org) {
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
                // Handle
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Avatar
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

                // Status badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DetailBadge(
                      label: attendee.status == RegistrationStatus.confirmed
                          ? AppLocalizations.of(context)['status_confirmed']
                          : attendee.status == RegistrationStatus.pending
                              ? AppLocalizations.of(context)['status_pending']
                              : AppLocalizations.of(context)['status_canceled'],
                      color: attendee.status == RegistrationStatus.confirmed
                          ? AppColors.success
                          : attendee.status == RegistrationStatus.pending
                              ? AppColors.warning
                              : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    if (attendee.checkInStatus == CheckInStatus.checkedIn)
                      _DetailBadge(label: AppLocalizations.of(context)['checked_in_label'], color: AppColors.accent),
                  ],
                ),

                const SizedBox(height: 24),

                // QR Code
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

                // Details list
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(label: AppLocalizations.of(context)['category_label'], value: attendee.category),
                      if (attendee.timeSlotId != null && _selectedEventId != null)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection(Collections.events)
                              .doc(_selectedEventId)
                              .get(),
                          builder: (context, snap) {
                            if (!snap.hasData) return const SizedBox.shrink();
                            final event = EventModel.fromFirestore(snap.data!);
                            final slot = event.timeSlots.where((s) => s.id == attendee.timeSlotId).firstOrNull;
                            if (slot == null) return const SizedBox.shrink();
                            return _DetailRow(
                              label: AppLocalizations.of(context)['time_slot_label'],
                              value: '${slot.label}  (${slot.startTime} \u2013 ${slot.endTime})',
                            );
                          },
                        ),
                      _DetailRow(
                        label: AppLocalizations.of(context)['registered_at_label'],
                        value: DateFormat('dd/MM/yyyy HH:mm').format(attendee.registeredAt),
                      ),
                      if (attendee.checkInTime != null)
                        _DetailRow(
                          label: AppLocalizations.of(context)['checked_in_at_label'],
                          value: DateFormat('dd/MM/yyyy HH:mm').format(attendee.checkInTime!),
                        ),
                    ],
                  ),
                ),

                // Custom Data
                if (attendee.customData.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.dynamic_form_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)['additional_data'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...attendee.customData.entries.map((entry) {
                          String displayValue;
                          if (entry.value is bool) {
                            displayValue = entry.value ? 'Sì' : 'No';
                          } else {
                            displayValue = entry.value?.toString() ?? '-';
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    displayValue,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                if (org.plan == 'business') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => _printSingleBadge(context, attendee, org),
                      icon: const Icon(Icons.print_rounded),
                      label: Text(AppLocalizations.of(context)['print_single_badge']),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Bug #10: Edit/Delete buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditAttendeeDialog(context, attendee);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(AppLocalizations.of(context)['edit']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteAttendee(attendee.id);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        label: Text(AppLocalizations.of(context)['remove'], style: const TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditAttendeeDialog(BuildContext context, Attendee attendee) {
    final firstNameCtrl = TextEditingController(text: attendee.firstName);
    final lastNameCtrl = TextEditingController(text: attendee.lastName);
    final emailCtrl = TextEditingController(text: attendee.email);
    final phoneCtrl = TextEditingController(text: attendee.phone ?? '');

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
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.of(context)['edit_attendee'], style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 20),
                  TextField(
                    controller: firstNameCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)['first_name']),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)['last_name']),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)['email_label']),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)['phone_label']),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (firstNameCtrl.text.isEmpty || lastNameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;

                        await FirebaseFirestore.instance
                            .collection(Collections.attendees)
                            .doc(attendee.id)
                            .update({
                          'firstName': firstNameCtrl.text.trim(),
                          'lastName': lastNameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'phone': phoneCtrl.text.isNotEmpty ? phoneCtrl.text.trim() : null,
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)['attendee_updated']),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      child: Text(AppLocalizations.of(context)['save']),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _downloadWebFile(String content, String fileName) {
    if (!kIsWeb) return;
    // ignore: avoid_web_libraries_in_flutter
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _exportAllAttendeesCSV(BuildContext context) async {
    final org = ref.read(currentOrgProvider).value;
    if (org == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)['generating_backup_csv']), duration: const Duration(seconds: 1)),
      );

      // Fetch ALL attendees for this org
      final snapshot = await FirebaseFirestore.instance
          .collection(Collections.attendees)
          .where('orgId', isEqualTo: org.id)
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

      // We need event details to know titles and custom fields
      final eventsSnap = await FirebaseFirestore.instance
          .collection(Collections.events)
          .where('orgId', isEqualTo: org.id)
          .get();
          
      final eventsMap = <String, EventModel>{};
      for (final doc in eventsSnap.docs) {
        final ev = EventModel.fromFirestore(doc);
        eventsMap[ev.id] = ev;
      }

      // Collect all unique custom data keys across ALL events
      final customKeys = <String>{};
      for (final a in attendees) {
        customKeys.addAll(a.customData.keys);
      }
      final sortedCustomKeys = customKeys.toList()..sort();

      // We can also make a global custom field label mapping for nicer headers
      // Since different events might have the same custom data keys with different labels, 
      // we'll try to map it based on the first occurrence.
      final globalFieldLabelMap = <String, String>{};
      for (final ev in eventsMap.values) {
        for (final cf in ev.customFields) {
          if (!globalFieldLabelMap.containsKey(cf.id)) {
            globalFieldLabelMap[cf.id] = cf.label;
          }
        }
      }

      // Build CSV header
      final header = [
        'Event Title', 'Event Date',
        'First Name', 'Last Name', 'Email', 'Phone',
        'Category', 'Status', 'Check-in Status', 'Check-in Time',
        'Time Slot', 'Registered At',
        ...sortedCustomKeys.map((k) => globalFieldLabelMap[k] ?? k),
      ];

      // Build rows
      final rows = <List<String>>[header];
      for (final a in attendees) {
        final ev = eventsMap[a.eventId];
        final eventTitle = ev?.title ?? 'Unknown Event';
        final eventDate = ev != null 
          ? '${ev.date.day}/${ev.date.month}/${ev.date.year}'
          : '';

        // Resolve time slot label
        String slotLabel = '';
        if (a.timeSlotId != null && ev != null) {
          final slot = ev.timeSlots.where((s) => s.id == a.timeSlotId).firstOrNull;
          slotLabel = slot != null ? '${slot.label} (${slot.startTime}-${slot.endTime})' : a.timeSlotId!;
        }

        rows.add([
          eventTitle,
          eventDate,
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
        _downloadWebFile(csvString, 'ticketto_attendees_db_dump.csv');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                ? '${attendees.length} partecipanti esportati in totale!'
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

  Future<void> _tryImportCSV(BuildContext context) async {
    final org = ref.read(currentOrgProvider).value;
    if (org == null || _selectedEventId == null) return;
    final plan = org.plan;

    // CSV import requires Pro or above
    if (!canImportCSV(context, plan)) return;

    // Also check attendee limit
    final attendeesSnap = await FirebaseFirestore.instance
        .collection(Collections.attendees)
        .where('eventId', isEqualTo: _selectedEventId)
        .where('orgId', isEqualTo: org.id)
        .get();
    final currentCount = attendeesSnap.docs.length;

    if (!canAddAttendee(context, plan, currentCount)) return;

    if (!context.mounted) return;
    _importAttendeesFromCSV(context);
  }

  Future<void> _tryAddAttendee(BuildContext context) async {
    final org = ref.read(currentOrgProvider).value;
    if (org == null || _selectedEventId == null) return;
    final plan = org.plan;

    // Check attendee limit
    final attendeesSnap = await FirebaseFirestore.instance
        .collection(Collections.attendees)
        .where('eventId', isEqualTo: _selectedEventId)
        .where('orgId', isEqualTo: org.id)
        .get();
    final currentCount = attendeesSnap.docs.length;

    if (!canAddAttendee(context, plan, currentCount)) return;

    if (!context.mounted) return;
    _showAddAttendeeDialog(context);
  }

  Future<void> _importAttendeesFromCSV(BuildContext context) async {
    final org = ref.read(currentOrgProvider).value;
    if (org == null || _selectedEventId == null) return;

    // Show instructions first
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.upload_file, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)['import_csv']),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)['csv_prepare_instructions'],
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📄 Record Layout',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'first_name, last_name, email, phone, time_slot',
                      style: TextStyle(color: Color(0xFF82AAFF), fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '📝 Example',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'first_name,last_name,email,phone,time_slot\n'
                      'Mario,Rossi,mario@email.com,3331234567,21.00 - 22.00\n'
                      'Anna,Bianchi,anna@email.com,3479876543,22.00 - 23.00\n'
                      'Luca,Verdi,luca@company.it,,',
                      style: TextStyle(color: Color(0xFFC3E88D), fontFamily: 'monospace', fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)['csv_note_title'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('• ${AppLocalizations.of(context)["csv_note_headers"]}', style: const TextStyle(fontSize: 12)),
                    Text('• ${AppLocalizations.of(context)["csv_note_email_mandatory"]}', style: const TextStyle(fontSize: 12)),
                    Text('• ${AppLocalizations.of(context)["csv_note_phone_optional"]}', style: const TextStyle(fontSize: 12)),
                    Text('• ${AppLocalizations.of(context)["csv_note_time_slot"]}', style: const TextStyle(fontSize: 12)),
                    Text('• ${AppLocalizations.of(context)["csv_note_no_slot"]}', style: const TextStyle(fontSize: 12)),
                    Text('• ${AppLocalizations.of(context)["csv_note_format"]}', style: const TextStyle(fontSize: 12)),
                    Text('• ${AppLocalizations.of(context)["csv_note_duplicates"]}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)['csv_note_aliases_title'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('• ${AppLocalizations.of(context)["csv_note_alias_first_name"]}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('• ${AppLocalizations.of(context)["csv_note_alias_last_name"]}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('• ${AppLocalizations.of(context)["csv_note_alias_email"]}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('• ${AppLocalizations.of(context)["csv_note_alias_phone"]}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('• ${AppLocalizations.of(context)["csv_note_alias_time_slot"]}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)['cancel'])),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.file_open, size: 18),
            label: Text(AppLocalizations.of(context)['choose_file']),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    try {
      // 1. Pick CSV file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)['file_error']), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      // 2. Parse CSV
      final csvString = utf8.decode(file.bytes!);
      final rows = CsvCodec(autoDetect: true).decoder.convert(csvString);

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)['file_empty']), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      // 3. Detect header columns
      final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      
      // Map common column names
      int firstNameCol = _findColumn(header, ['first_name', 'firstname', 'nome', 'first name', 'name']);
      int lastNameCol = _findColumn(header, ['last_name', 'lastname', 'cognome', 'last name', 'surname']);
      int emailCol = _findColumn(header, ['email', 'e-mail', 'mail']);
      int phoneCol = _findColumn(header, ['phone', 'telefono', 'tel', 'cellulare', 'mobile']);

      // Check if header row exists or if first row is data
      bool hasHeader = firstNameCol >= 0 || emailCol >= 0;
      
      if (!hasHeader) {
        // Try positional: assume col0=firstName, col1=lastName, col2=email, col3=phone
        firstNameCol = 0;
        lastNameCol = header.length > 1 ? 1 : -1;
        emailCol = header.length > 2 ? 2 : -1;
        phoneCol = header.length > 3 ? 3 : -1;
      }

      if (emailCol < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)['csv_no_email_column']),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // 4. Parse data rows
      final dataRows = hasHeader ? rows.skip(1).toList() : rows;
      
      final List<Map<String, String>> parsedAttendees = [];
      for (final row in dataRows) {
        if (row.isEmpty) continue;
        final email = emailCol < row.length ? row[emailCol].toString().trim() : '';
        if (email.isEmpty || !email.contains('@')) continue;

        parsedAttendees.add({
          'firstName': firstNameCol >= 0 && firstNameCol < row.length ? row[firstNameCol].toString().trim() : '',
          'lastName': lastNameCol >= 0 && lastNameCol < row.length ? row[lastNameCol].toString().trim() : '',
          'email': email.toLowerCase(),
          'phone': phoneCol >= 0 && phoneCol < row.length ? row[phoneCol].toString().trim() : '',
        });
      }

      if (parsedAttendees.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)['no_valid_attendees']), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      // 5. Fetch event to check for time slots
      final eventDoc = await FirebaseFirestore.instance
          .collection(Collections.events)
          .doc(_selectedEventId)
          .get();
      final event = EventModel.fromFirestore(eventDoc);

      // Check for time_slot column in CSV
      int timeSlotCol = _findColumn(header, ['time_slot', 'timeslot', 'fascia', 'fascia_oraria', 'slot']);
      bool csvHasSlotColumn = hasHeader && timeSlotCol >= 0;

      // If event has time slots and CSV has slot column, map them
      if (csvHasSlotColumn && event.hasTimeSlots) {
        // Parse time slot from CSV rows
        final dataRowsList = hasHeader ? rows.skip(1).toList() : rows;
        parsedAttendees.clear();
        for (final row in dataRowsList) {
          if (row.isEmpty) continue;
          final email = emailCol < row.length ? row[emailCol].toString().trim() : '';
          if (email.isEmpty || !email.contains('@')) continue;

          final slotLabel = timeSlotCol < row.length ? row[timeSlotCol].toString().trim() : '';
          // Find matching slot by label
          String? matchedSlotId;
          if (slotLabel.isNotEmpty) {
            final matchedSlot = event.timeSlots.where(
              (s) => s.label.toLowerCase() == slotLabel.toLowerCase()
            ).firstOrNull;
            matchedSlotId = matchedSlot?.id;
          }

          parsedAttendees.add({
            'firstName': firstNameCol >= 0 && firstNameCol < row.length ? row[firstNameCol].toString().trim() : '',
            'lastName': lastNameCol >= 0 && lastNameCol < row.length ? row[lastNameCol].toString().trim() : '',
            'email': email.toLowerCase(),
            'phone': phoneCol >= 0 && phoneCol < row.length ? row[phoneCol].toString().trim() : '',
            'timeSlotId': matchedSlotId ?? '',
          });
        }
      }

      // Show preview dialog with time slot selection
      if (!mounted) return;
      
      String? selectedSlotId;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              // Calculate available spots for selected slot
              int? availableSpots;
              if (event.hasTimeSlots && selectedSlotId != null) {
                final slot = event.timeSlots.where((s) => s.id == selectedSlotId).firstOrNull;
                if (slot != null) {
                  availableSpots = slot.maxCapacity - slot.bookedCount;
                }
              }

              return AlertDialog(
                title: Text(AppLocalizations.of(context)['import_attendees']),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(
                              '${parsedAttendees.length} attendees found',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ],
                        ),
                      ),

                      // Time slot selection (if event has time slots and CSV doesn't have slot column)
                      if (event.hasTimeSlots && !csvHasSlotColumn) ...[
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)['assign_time_slot'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedSlotId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            hintText: AppLocalizations.of(context)['select_time_slot'],
                          ),
                          items: event.timeSlots.map((slot) {
                            final remaining = slot.maxCapacity - slot.bookedCount;
                            return DropdownMenuItem(
                              value: slot.id,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${slot.label}  (${slot.startTime} – ${slot.endTime})', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$remaining left',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: remaining > 0 ? AppColors.success : AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setDialogState(() => selectedSlotId = v),
                        ),
                        if (availableSpots != null && parsedAttendees.length > availableSpots)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Only $availableSpots spots available. ${parsedAttendees.length - availableSpots} attendees will be skipped.',
                                      style: const TextStyle(fontSize: 12, color: AppColors.warning),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],

                      // CSV has slot column info
                      if (event.hasTimeSlots && csvHasSlotColumn) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.success, size: 18),
                              SizedBox(width: 8),
                              Expanded(child: Text(
                                'Time slots will be assigned from the CSV column.',
                                style: TextStyle(fontSize: 12, color: AppColors.success),
                              )),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)['preview_label'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: parsedAttendees.length > 5 ? 5 : parsedAttendees.length,
                          itemBuilder: (context, i) {
                            final a = parsedAttendees[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      '${a['firstName']?.isNotEmpty == true ? a['firstName']![0] : '?'}${a['lastName']?.isNotEmpty == true ? a['lastName']![0] : '?'}',
                                      style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${a['firstName']} ${a['lastName']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        Text(a['email']!, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (parsedAttendees.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                             '... ${AppLocalizations.of(context)['and_x_more']} ${parsedAttendees.length - 5}',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)['all_confirmed'],
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)['cancel'])),
                  FilledButton(
                    onPressed: (event.hasTimeSlots && !csvHasSlotColumn && selectedSlotId == null)
                        ? null  // Disabled until slot is selected
                        : () => Navigator.pop(ctx, true),
                    child: Text('${AppLocalizations.of(context)['import_x']} ${parsedAttendees.length}'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || !mounted) return;

      // 6. Batch write to Firestore
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(AppLocalizations.of(context)['importing_attendees']),
            ],
          ),
        ),
      );

      final db = FirebaseFirestore.instance;
      int imported = 0;
      int skipped = 0;

      // Track capacity per slot for CSV-based slot assignment
      final Map<String, int> slotImportCounts = {};

      // Determine max capacity per slot
      final Map<String, int> slotAvailable = {};
      if (event.hasTimeSlots) {
        for (final slot in event.timeSlots) {
          slotAvailable[slot.id] = slot.maxCapacity - slot.bookedCount;
          slotImportCounts[slot.id] = 0;
        }
      }

      // Firestore batches max 500 operations
      for (int i = 0; i < parsedAttendees.length; i += 250) {
        final batch = db.batch();
        final chunk = parsedAttendees.skip(i).take(250);

        for (final a in chunk) {
          // Determine time slot for this attendee
          String? attendeeSlotId;
          if (event.hasTimeSlots) {
            if (csvHasSlotColumn) {
              attendeeSlotId = a['timeSlotId']?.isNotEmpty == true ? a['timeSlotId'] : null;
            } else {
              attendeeSlotId = selectedSlotId;
            }

            // Check capacity
            if (attendeeSlotId != null) {
              final available = (slotAvailable[attendeeSlotId] ?? 0) - (slotImportCounts[attendeeSlotId] ?? 0);
              if (available <= 0) {
                skipped++;
                continue;
              }
              slotImportCounts[attendeeSlotId] = (slotImportCounts[attendeeSlotId] ?? 0) + 1;
            }
          }

          final email = a['email']!;
          final docId = '${_selectedEventId}_${email.hashCode.abs()}';
          final docRef = db.collection(Collections.attendees).doc(docId);
          
          final qrCode = const Uuid().v4();
          batch.set(docRef, {
            'eventId': _selectedEventId,
            'orgId': org.id,
            'firstName': a['firstName'],
            'lastName': a['lastName'],
            'email': email,
            'phone': a['phone']?.isNotEmpty == true ? a['phone'] : null,
            'category': 'Standard',
            'status': RegistrationStatus.confirmed.name,
            'checkInStatus': CheckInStatus.notCheckedIn.name,
            'checkInTime': null,
            'qrCode': qrCode,
            'timeSlotId': attendeeSlotId,
            'customData': {},
            'registeredAt': Timestamp.now(),
          }, SetOptions(merge: false));
          imported++;
        }

        await batch.commit();
      }

      // Note: attendeesCount is incremented server-side by Cloud Functions (onAttendeeCreated).
      // If time slots were assigned during import, update their bookedCounts.
      if (event.hasTimeSlots && slotImportCounts.isNotEmpty) {
        final updatedSlots = event.timeSlots.map((s) {
          final map = s.toMap();
          if (slotImportCounts.containsKey(s.id)) {
            map['bookedCount'] = s.bookedCount + slotImportCounts[s.id]!;
          }
          return map;
        }).toList();
        await db.collection(Collections.events).doc(_selectedEventId).update({'timeSlots': updatedSlots});
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show result
      if (mounted) {
        final message = skipped > 0
            ? '✅ ${AppLocalizations.of(context)['import_x']} $imported ${AppLocalizations.of(context)['imported_success']} ($skipped ${AppLocalizations.of(context)['imported_skipped']})'
            : '✅ $imported ${AppLocalizations.of(context)['imported_success']}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)['import_error']}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  int _findColumn(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = header.indexOf(candidate);
      if (idx >= 0) return idx;
    }
    return -1;
  }

  void _showAddAttendeeDialog(BuildContext context) {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

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
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.of(context)['add_attendee'], style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 20),
                  TextField(
                    controller: firstNameCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)['first_name']),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)['last_name']),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)['email_label']),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)['phone_label']),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (firstNameCtrl.text.isEmpty || lastNameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;

                        final org = ref.read(currentOrgProvider).value;
                        if (org == null) return;

                        try {
                          final attendee = Attendee(
                            id: '',
                            eventId: _selectedEventId!,
                            orgId: org.id,
                            firstName: firstNameCtrl.text.trim(),
                            lastName: lastNameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            phone: phoneCtrl.text.isNotEmpty ? phoneCtrl.text.trim() : null,
                            qrCode: const Uuid().v4(),
                            status: RegistrationStatus.confirmed,
                          );

                          final docRef = FirebaseFirestore.instance.collection(Collections.attendees).doc();
                          await docRef.set(attendee.toFirestore());

                          // Track attendee added
                          // Note: attendeesCount is incremented server-side by Cloud Function (onAttendeeCreated)
                          AnalyticsService.instance.logEvent('attendee_added');

                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          // Silently fail — the dialog stays open
                        }
                      },
                      child: Text(AppLocalizations.of(context)['add_attendee']),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Future<void> _exportBadgesA4(BuildContext context, Organization org) async {
    if (_selectedEventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)['select_event_first_msg']), backgroundColor: AppColors.warning),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)['generating_pdf']), duration: const Duration(seconds: 2)),
      );

      final eventDoc = await FirebaseFirestore.instance.collection(Collections.events).doc(_selectedEventId).get();
      if (!eventDoc.exists) return;
      final event = EventModel.fromFirestore(eventDoc);

      final attendeesSnap = await FirebaseFirestore.instance
          .collection(Collections.attendees)
          .where('eventId', isEqualTo: _selectedEventId)
          .get();
      
      final attendees = attendeesSnap.docs.map((d) => Attendee.fromFirestore(d)).toList();
      if (attendees.isEmpty) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(AppLocalizations.of(context)['no_attendees_print']), backgroundColor: AppColors.warning),
           );
        }
        return;
      }

      await BadgePrintingService.printA4Grid(attendees, event, org.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)["error_generic_short"]}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _printSingleBadge(BuildContext context, Attendee attendee, Organization org) async {
    try {
      final eventDoc = await FirebaseFirestore.instance.collection(Collections.events).doc(attendee.eventId).get();
      if (!eventDoc.exists) return;
      final event = EventModel.fromFirestore(eventDoc);

      await BadgePrintingService.printSingleLabel(attendee, event, org.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)["print_error"]}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  final Attendee attendee;
  final ValueChanged<RegistrationStatus> onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _AttendeeCard({
    required this.attendee,
    required this.onStatusChange,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              '${attendee.firstName[0]}${attendee.lastName[0]}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attendee.fullName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(attendee.email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(attendee.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        attendee.status == RegistrationStatus.confirmed
                            ? AppLocalizations.of(context)['status_confirmed']
                            : attendee.status == RegistrationStatus.pending
                                ? AppLocalizations.of(context)['status_pending']
                                : AppLocalizations.of(context)['status_canceled'],
                        style: TextStyle(
                          color: _statusColor(attendee.status),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (attendee.checkInStatus == CheckInStatus.checkedIn) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 10, color: AppColors.success),
                            SizedBox(width: 2),
                            Text(
                              'IN',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textTertiary),
            itemBuilder: (_) => [
              if (attendee.status == RegistrationStatus.pending)
                PopupMenuItem(value: 'confirm', child: Text(AppLocalizations.of(context)['confirm'])),
              if (attendee.status == RegistrationStatus.confirmed)
                PopupMenuItem(value: 'cancel', child: Text(AppLocalizations.of(context)['cancel_registration'])),
              PopupMenuItem(
                value: 'delete',
                child: Text(AppLocalizations.of(context)['remove'], style: const TextStyle(color: AppColors.error)),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'confirm':
                  onStatusChange(RegistrationStatus.confirmed);
                case 'cancel':
                  onStatusChange(RegistrationStatus.canceled);
                case 'delete':
                  onDelete();
              }
            },
          ),
        ],
      ),
    ),
    );
  }

  Color _statusColor(RegistrationStatus status) {
    switch (status) {
      case RegistrationStatus.confirmed: return AppColors.success;
      case RegistrationStatus.pending: return AppColors.warning;
      case RegistrationStatus.canceled: return AppColors.error;
      case RegistrationStatus.waitlist: return AppColors.textTertiary;
    }
  }

}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _DetailBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
