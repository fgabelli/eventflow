import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/widgets/help_tip.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  String? _selectedEventId;
  final _searchController = TextEditingController();
  bool _showScanner = false;
  String? _lastScannedCode;
  String? _scanMessage;
  bool _scanSuccess = false;

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
      appBar: AppBar(
        title: Row(
          children: [
            Text(AppLocalizations.of(context)['checkin_title'], style: Theme.of(context).textTheme.headlineMedium),
            HelpTip(text: AppLocalizations.of(context)['help_checkin_qr']),
          ],
        ),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          // Event selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _buildEventSelector(org),
          ),

          // Search + Scanner toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)['search_name_email'],
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _showScanner ? AppColors.primary : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showScanner ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: _showScanner ? Colors.white : AppColors.textPrimary,
                    ),
                    onPressed: () => setState(() {
                      _showScanner = !_showScanner;
                      _scanMessage = null;
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Scanner area
          if (_showScanner) _buildScannerArea(),

          // Scan result message
          if (_scanMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _scanSuccess
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _scanSuccess ? AppColors.success : AppColors.error,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _scanSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _scanSuccess ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _scanMessage!,
                      style: TextStyle(
                        color: _scanSuccess ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _scanMessage = null),
                  ),
                ],
              ),
            ),

          // Attendees list
          Expanded(
            child: _selectedEventId == null
                ? _buildSelectEventPrompt()
                : _buildAttendeesList(),
          ),
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
          .where('status', isEqualTo: EventStatus.published.name)
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        final events = snapshot.data?.docs
            .map((d) => EventModel.fromFirestore(d))
            .toList() ?? [];

        return DropdownButtonFormField<String>(
          value: _selectedEventId,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)['select_event_label'],
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

  Widget _buildScannerArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final code = barcodes.first.rawValue;
              if (code != null && code != _lastScannedCode) {
                _lastScannedCode = code;
                _handleQrScan(code);
              }
            },
          ),
          // Overlay
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQrScan(String qrCode) async {
    if (_selectedEventId == null) {
      setState(() {
        _scanMessage = AppLocalizations.of(context)['select_event_first'];
        _scanSuccess = false;
      });
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection(Collections.attendees)
          .where('eventId', isEqualTo: _selectedEventId)
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _scanMessage = AppLocalizations.of(context)['attendee_not_found'];
          _scanSuccess = false;
        });
        return;
      }

      final doc = query.docs.first;
      final attendee = Attendee.fromFirestore(doc);

      if (attendee.checkInStatus == CheckInStatus.checkedIn) {
        setState(() {
          _scanMessage = '${attendee.fullName} ${AppLocalizations.of(context)['already_checked_in']}';
          _scanSuccess = false;
        });
        return;
      }

      await doc.reference.update({
        'checkInStatus': CheckInStatus.checkedIn.name,
        'checkInTime': Timestamp.now(),
      });

      setState(() {
        _scanMessage = '✓ ${attendee.fullName} ${AppLocalizations.of(context)['checked_in_success']}';
        _scanSuccess = true;
        _lastScannedCode = null; // Allow re-scan
      });
    } catch (e) {
      setState(() {
        _scanMessage = '${AppLocalizations.of(context)['error_generic_short']}: $e';
        _scanSuccess = false;
      });
    }
  }

  Widget _buildSelectEventPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)['select_event_checkin'], style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildAttendeesList() {
    final searchQuery = _searchController.text.toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.attendees)
          .where('eventId', isEqualTo: _selectedEventId)
          .orderBy('lastName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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

        final checkedIn = attendees.where((a) => a.checkInStatus == CheckInStatus.checkedIn).length;

        return Column(
          children: [
            // Stats bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CountStat(label: AppLocalizations.of(context)['total'], count: attendees.length, color: AppColors.primary),
                  _CountStat(label: AppLocalizations.of(context)['checked_in'], count: checkedIn, color: AppColors.success),
                  _CountStat(label: AppLocalizations.of(context)['remaining'], count: attendees.length - checkedIn, color: AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: attendees.isEmpty
                  ? Center(
                      child: Text(AppLocalizations.of(context)['no_attendees_found'], style: Theme.of(context).textTheme.bodyMedium),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: attendees.length,
                      itemBuilder: (context, index) => _AttendeeCheckInTile(
                        attendee: attendees[index],
                        onCheckIn: () => _manualCheckIn(attendees[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _manualCheckIn(Attendee attendee) async {
    if (attendee.checkInStatus == CheckInStatus.checkedIn) return;
    
    await FirebaseFirestore.instance
        .collection(Collections.attendees)
        .doc(attendee.id)
        .update({
      'checkInStatus': CheckInStatus.checkedIn.name,
      'checkInTime': Timestamp.now(),
    });
  }
}

class _CountStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountStat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AttendeeCheckInTile extends StatelessWidget {
  final Attendee attendee;
  final VoidCallback onCheckIn;

  const _AttendeeCheckInTile({required this.attendee, required this.onCheckIn});

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = attendee.checkInStatus == CheckInStatus.checkedIn;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCheckedIn
            ? AppColors.success.withValues(alpha: 0.04)
            : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCheckedIn ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: isCheckedIn
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.1),
            child: isCheckedIn
                ? const Icon(Icons.check, color: AppColors.success, size: 20)
                : Text(
                    attendee.firstName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendee.fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(attendee.email, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),

          // Check-in time or button
          if (isCheckedIn)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppLocalizations.of(context)['checked_in'],
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (attendee.checkInTime != null)
                  Text(
                    '${attendee.checkInTime!.hour.toString().padLeft(2, '0')}:${attendee.checkInTime!.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            )
          else
            FilledButton.tonal(
              onPressed: onCheckIn,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(AppLocalizations.of(context)['check_in_btn']),
            ),
        ],
      ),
    );
  }
}
