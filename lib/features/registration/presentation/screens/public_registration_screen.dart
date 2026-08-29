import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/analytics/analytics_service.dart';

class PublicRegistrationScreen extends StatefulWidget {
  final String eventId;
  const PublicRegistrationScreen({super.key, required this.eventId});

  @override
  State<PublicRegistrationScreen> createState() => _PublicRegistrationScreenState();
}

class _PublicRegistrationScreenState extends State<PublicRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _isRegistered = false;
  String? _registrationError;
  // Localized context from Builder below Localizations.override
  // so all methods use the event's language, not the device locale.
  BuildContext? _localizedCtx;
  String? _qrCodeData;
  String? _selectedSlotId;
  final Map<String, dynamic> _customFieldValues = {};

  // Group registration
  final List<_ExtraAttendee> _extraAttendees = [];
  static const int _maxGroupSize = 10;

  int get _totalAttendees => 1 + _extraAttendees.length;
  int get _availableExtraSlots => _maxGroupSize - 1;

  void _addExtraAttendee() {
    if (_extraAttendees.length >= _availableExtraSlots) return;
    setState(() => _extraAttendees.add(_ExtraAttendee()));
  }

  void _removeExtraAttendee(int index) {
    setState(() {
      _extraAttendees[index].dispose();
      _extraAttendees.removeAt(index);
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    for (final a in _extraAttendees) {
      a.dispose();
    }
    super.dispose();
  }

  bool get _isPaymentSuccess {
    final uri = Uri.base;
    return uri.queryParameters['payment'] == 'success';
  }

  Future<void> _submitRegistration(EventModel event) async {
    if (!_formKey.currentState!.validate()) return;

    // Validate time slot selection
    if (event.hasTimeSlots && event.timeSlots.isNotEmpty && _selectedSlotId == null) {
      setState(() {
        _registrationError = AppLocalizations.of(_localizedCtx ?? context)['please_select_slot'];
      });
      return;
    }

    // For paid events, redirect to Stripe Checkout
    if (event.isPaid && event.price != null && event.price! > 0) {
      await _initiatePayment(event);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _registrationError = null;
    });

    try {
      // Check capacity (overall or slot-based)
      if (event.hasTimeSlots && _selectedSlotId != null) {
        final selectedSlot = event.timeSlots.firstWhere((s) => s.id == _selectedSlotId);
        if (selectedSlot.isFull) {
          setState(() {
            _registrationError = AppLocalizations.of(_localizedCtx ?? context)['slot_full_error'];
            _isSubmitting = false;
          });
          return;
        }
      } else {
        // Check if enough capacity for the whole group
        final spotsLeft = event.maxAttendees - event.attendeesCount;
        if (spotsLeft < _totalAttendees) {
          setState(() {
            _registrationError = _totalAttendees > 1
                ? AppLocalizations.of(_localizedCtx ?? context)['not_enough_spots']
                : AppLocalizations.of(_localizedCtx ?? context)['event_full_error'];
            _isSubmitting = false;
          });
          return;
        }
      }

      final db = FirebaseFirestore.instance;

      // Register primary attendee
      final email = _emailCtrl.text.trim().toLowerCase();
      final docId = '${widget.eventId}_${email.hashCode.abs()}';
      final docRef = db.collection(Collections.attendees).doc(docId);

      try {
        final existingDoc = await docRef.get();
        if (existingDoc.exists) {
          setState(() {
            _registrationError = AppLocalizations.of(_localizedCtx ?? context)['already_registered'];
            _isSubmitting = false;
          });
          return;
        }
      } catch (_) {}

      final qrCode = const Uuid().v4();
      _qrCodeData = qrCode;
      await docRef.set({
        'eventId': widget.eventId,
        'orgId': event.orgId,
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'email': email,
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'category': 'Standard',
        'status': RegistrationStatus.confirmed.name,
        'checkInStatus': CheckInStatus.notCheckedIn.name,
        'checkInTime': null,
        'qrCode': qrCode,
        'timeSlotId': _selectedSlotId,
        'customData': _customFieldValues,
        'registeredAt': Timestamp.now(),
      });

      // Register extra attendees
      for (final extra in _extraAttendees) {
        final extraEmail = extra.emailCtrl.text.trim().toLowerCase();
        if (extraEmail.isEmpty) continue;
        final extraDocId = '${widget.eventId}_${extraEmail.hashCode.abs()}';
        final extraQr = const Uuid().v4();
        try {
          await db.collection(Collections.attendees).doc(extraDocId).set({
            'eventId': widget.eventId,
            'orgId': event.orgId,
            'firstName': extra.firstNameCtrl.text.trim(),
            'lastName': extra.lastNameCtrl.text.trim(),
            'email': extraEmail,
            'phone': null,
            'category': 'Standard',
            'status': RegistrationStatus.confirmed.name,
            'checkInStatus': CheckInStatus.notCheckedIn.name,
            'checkInTime': null,
            'qrCode': extraQr,
            'timeSlotId': _selectedSlotId,
            'customData': _customFieldValues,
            'registeredAt': Timestamp.now(),
          });
        } catch (_) {}
      }

      // Track successful registration
      AnalyticsService.instance.logEvent('registration_completed', params: {
        'is_group': _extraAttendees.isNotEmpty,
        'party_size': _totalAttendees,
        'event_id': widget.eventId,
      });

      setState(() {
        _isRegistered = true;
        _isSubmitting = false;
      });
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('already-exists')) {
        setState(() {
          _registrationError = AppLocalizations.of(_localizedCtx ?? context)['already_registered'];
          _isSubmitting = false;
        });
      } else {
        setState(() {
          _registrationError = '${AppLocalizations.of(_localizedCtx ?? context)['registration_failed']}: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _initiatePayment(EventModel event) async {
    setState(() {
      _isSubmitting = true;
      _registrationError = null;
    });

    try {
      // Build all attendees list for group registration
      final allAttendees = [
        {
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().toLowerCase(),
          'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        },
        ..._extraAttendees.map((a) => {
          'firstName': a.firstNameCtrl.text.trim(),
          'lastName': a.lastNameCtrl.text.trim(),
          'email': a.emailCtrl.text.trim().toLowerCase(),
          'phone': null,
        }),
      ];

      final response = await http.post(
        Uri.parse('https://us-central1-eventflow-3541b.cloudfunctions.net/createTicketCheckout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'eventId': widget.eventId,
          'orgId': event.orgId,
          'eventTitle': event.title,
          'price': event.price,
          'quantity': _totalAttendees,
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().toLowerCase(),
          'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'slotId': _selectedSlotId,
          'customData': _customFieldValues,
          'extraAttendees': _extraAttendees.isEmpty ? null : allAttendees.sublist(1),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['url'] != null) {
        await launchUrl(Uri.parse(data['url']), mode: LaunchMode.externalApplication);
      } else {
        setState(() {
          _registrationError = data['error'] ?? AppLocalizations.of(_localizedCtx ?? context)['payment_init_failed'];
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _registrationError = '${AppLocalizations.of(_localizedCtx ?? context)['error_generic_short']}: $e';
        _isSubmitting = false;
      });
    }
  }

  String? _eventLanguage;

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
            backgroundColor: AppColors.surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            body: _buildErrorState(AppLocalizations.of(_localizedCtx ?? context)['event_not_found_title'], AppLocalizations.of(_localizedCtx ?? context)['event_not_found_desc']),
          );
        }

        final event = EventModel.fromFirestore(snapshot.data!);
        final eventLocale = Locale(event.language);

        // Wrap EVERYTHING including Scaffold in Localizations.override.
        // The Builder provides a new BuildContext (ctx) that is below the
        // Localizations.override, so AppLocalizations.of(ctx) returns
        // strings in the event's language.
        return Localizations.override(
          context: context,
          locale: eventLocale,
          child: Builder(
            builder: (ctx) {
              _localizedCtx = ctx;
              return Scaffold(
                backgroundColor: AppColors.surface,
                body: _buildBodyContent(ctx, event),
              );
            },
          ),
        );
      },
    );
  }

  Color _parseColor(String? hexString, {Color defaultColor = AppColors.primary}) {
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

  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.65;
  }

  /// Routing method that uses [ctx] from the Builder below Localizations.override.
  /// All helper methods called from here receive the correctly-localized context.
  Widget _buildBodyContent(BuildContext ctx, EventModel event) {
    if (event.status != EventStatus.published) {
      return _buildErrorState(AppLocalizations.of(ctx)['registration_closed_title'], AppLocalizations.of(ctx)['registration_closed_desc']);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.organizations)
          .doc(event.orgId)
          .snapshots(),
      builder: (context, orgSnap) {
        Organization? org;
        if (orgSnap.hasData && orgSnap.data!.exists) {
          org = Organization.fromFirestore(orgSnap.data!);
        }

        if (_isPaymentSuccess) {
          return _buildPaymentSuccessState(event, org);
        }

        if (_isRegistered) {
          return _buildSuccessState(event, org);
        }

        return _buildRegistrationForm(event, org);
      },
    );
  }

  Widget _buildRegistrationForm(EventModel event, Organization? org) {
    final primaryColor = _parseColor(event.primaryColor ?? org?.primaryColor);
    final isWhiteOrLight = _isLightColor(primaryColor);

    final cardBg = isWhiteOrLight
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

    final titleColor = isWhiteOrLight ? AppColors.textPrimary : Colors.white;
    final descColor = isWhiteOrLight ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.88);
    final infoIconColor = isWhiteOrLight ? (primaryColor == Colors.white ? AppColors.textPrimary : primaryColor) : Colors.white.withValues(alpha: 0.85);
    final infoTextColor = isWhiteOrLight ? AppColors.textPrimary : Colors.white.withValues(alpha: 0.95);
    final btnBgColor = isWhiteOrLight ? (primaryColor == Colors.white ? AppColors.textPrimary : primaryColor) : primaryColor;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Organization Header (Logo & Name)
              _buildOrgHeader(org),

              // Event info card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: cardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.isPaid && event.price != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWhiteOrLight
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '€${event.price!.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isWhiteOrLight ? AppColors.primary : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      event.title,
                      style: TextStyle(color: titleColor, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        event.description!,
                        style: TextStyle(color: descColor, fontSize: 14, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _EventInfoRow(
                      icon: Icons.calendar_today,
                      text: '${event.date.day}/${event.date.month}/${event.date.year} - ${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}',
                      iconColor: infoIconColor,
                      textColor: infoTextColor,
                    ),
                    if (event.location != null)
                      _EventInfoRow(
                        icon: Icons.location_on_outlined,
                        text: event.location!,
                        iconColor: infoIconColor,
                        textColor: infoTextColor,
                      ),
                    if (event.showAttendeesCount)
                      _EventInfoRow(
                        icon: Icons.people_outlined,
                        text: '${event.attendeesCount}/${event.maxAttendees} ${AppLocalizations.of(_localizedCtx ?? context)['registered_label']}',
                        iconColor: infoIconColor,
                        textColor: infoTextColor,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Capacity warning
              if (event.isFull) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: AppColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(_localizedCtx ?? context)['event_full_warning'],
                          style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Registration Form
              if (!event.isFull) ...[
                Text(
                  AppLocalizations.of(_localizedCtx ?? context)['register_title'],
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(_localizedCtx ?? context)['register_subtitle'],
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameCtrl,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(_localizedCtx ?? context)['first_name_reg'],
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameCtrl,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(_localizedCtx ?? context)['last_name_reg'],
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(_localizedCtx ?? context)['email_reg'],
                          prefixIcon: const Icon(Icons.email_outlined),
                          hintText: 'your@email.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return AppLocalizations.of(_localizedCtx ?? context)['required_field'];
                          if (!v.contains('@') || !v.contains('.')) return AppLocalizations.of(_localizedCtx ?? context)['invalid_email'];
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(_localizedCtx ?? context)['phone_reg'],
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                      ),

                      // Custom Fields
                      if (event.customFields.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        ...event.customFields.map((field) => _buildCustomField(field)),
                      ],

                      // Time Slot Selection
                      if (event.hasTimeSlots && event.timeSlots.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          AppLocalizations.of(_localizedCtx ?? context)['select_time_slot_reg'],
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        ...event.timeSlots.map((slot) {
                          final isSelected = _selectedSlotId == slot.id;
                          final isSlotFull = slot.isFull;
                          return GestureDetector(
                            onTap: isSlotFull ? null : () => setState(() => _selectedSlotId = slot.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSlotFull
                                    ? AppColors.surface
                                    : isSelected
                                        ? AppColors.primary.withValues(alpha: 0.08)
                                        : AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: isSlotFull
                                        ? AppColors.textTertiary
                                        : isSelected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          slot.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isSlotFull ? AppColors.textTertiary : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${slot.startTime} – ${slot.endTime}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isSlotFull ? AppColors.textTertiary : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSlotFull
                                          ? AppColors.error.withValues(alpha: 0.1)
                                          : AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isSlotFull ? AppLocalizations.of(_localizedCtx ?? context)['slot_full'] : '${slot.availableSpots} ${AppLocalizations.of(_localizedCtx ?? context)['slot_left']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSlotFull ? AppColors.error : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),

                // Group Registration (only if organizer enabled it)
                if (event.allowGroupRegistration && !event.isFull) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.group_add_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(_localizedCtx ?? context)['group_registration_label'],
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                            ),
                            const Spacer(),
                            if (_extraAttendees.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  AppLocalizations.of(_localizedCtx ?? context)['register_group']
                                      .replaceFirst('{count}', '$_totalAttendees'),
                                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(_localizedCtx ?? context)['group_max_hint']
                              .replaceFirst('{max}', '$_maxGroupSize'),
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),

                        // Extra attendees list
                        ..._extraAttendees.asMap().entries.map((entry) {
                          final i = entry.key;
                          final extra = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      child: Text('${i + 2}', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${AppLocalizations.of(_localizedCtx ?? context)['person_label']} ${i + 2}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () => _removeExtraAttendee(i),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 16, color: AppColors.error),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: extra.firstNameCtrl,
                                        decoration: InputDecoration(labelText: '${AppLocalizations.of(_localizedCtx ?? context)['first_name_reg']}', isDense: true),
                                        textCapitalization: TextCapitalization.words,
                                        validator: (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: extra.lastNameCtrl,
                                        decoration: InputDecoration(labelText: '${AppLocalizations.of(_localizedCtx ?? context)['last_name_reg']}', isDense: true),
                                        textCapitalization: TextCapitalization.words,
                                        validator: (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: extra.emailCtrl,
                                  decoration: InputDecoration(labelText: '${AppLocalizations.of(_localizedCtx ?? context)['email_reg']}', isDense: true),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return AppLocalizations.of(_localizedCtx ?? context)['required_field'];
                                    if (!v.contains('@') || !v.contains('.')) return AppLocalizations.of(_localizedCtx ?? context)['invalid_email'];
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          );
                        }),

                        if (_extraAttendees.length < _availableExtraSlots) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addExtraAttendee,
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: Text(AppLocalizations.of(_localizedCtx ?? context)['add_person']),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (_registrationError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_registrationError!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Total price for group paid events
                if (event.isPaid && event.price != null && _totalAttendees > 1) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Totale ($_totalAttendees × €${event.price!.toStringAsFixed(2)})',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        Text(
                          '€${(event.price! * _totalAttendees).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _submitRegistration(event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnBgColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(event.isPaid && event.price != null
                            ? _totalAttendees > 1
                                ? AppLocalizations.of(_localizedCtx ?? context)['pay_and_register_group']
                                    .replaceFirst('{amount}', (event.price! * _totalAttendees).toStringAsFixed(2))
                                    .replaceFirst('{count}', '$_totalAttendees')
                                : AppLocalizations.of(_localizedCtx ?? context)['pay_and_register']
                                    .replaceFirst('{amount}', event.price!.toStringAsFixed(2))
                            : _totalAttendees > 1
                                ? AppLocalizations.of(_localizedCtx ?? context)['register_group']
                                    .replaceFirst('{count}', '$_totalAttendees')
                                : AppLocalizations.of(_localizedCtx ?? context)['register_now']),
                  ),
                ),
              ],

              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomField(CustomField field) {
    final label = '${field.label}${field.required ? ' *' : ''}';

    switch (field.type) {
      case 'select':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.list_rounded),
            ),
            items: (field.options ?? []).map((opt) => DropdownMenuItem(
              value: opt,
              child: Text(opt),
            )).toList(),
            onChanged: (v) => _customFieldValues[field.id] = v,
            validator: field.required
                ? (v) => v == null || v.isEmpty ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null
                : null,
          ),
        );

      case 'checkbox':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FormField<bool>(
            initialValue: _customFieldValues[field.id] == true,
            validator: field.required
                ? (v) => v != true ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null
                : null,
            builder: (formState) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    final newVal = !(_customFieldValues[field.id] == true);
                    setState(() => _customFieldValues[field.id] = newVal);
                    formState.didChange(newVal);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _customFieldValues[field.id] == true
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: formState.hasError
                            ? AppColors.error
                            : _customFieldValues[field.id] == true
                                ? AppColors.primary
                                : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _customFieldValues[field.id] == true
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: _customFieldValues[field.id] == true
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            field.label,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontWeight: _customFieldValues[field.id] == true
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (field.required)
                          const Text('*', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                if (formState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      formState.errorText!,
                      style: const TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),
        );

      case 'number':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: label,
              hintText: field.placeholder,
              prefixIcon: const Icon(Icons.tag_rounded),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _customFieldValues[field.id] = v,
            validator: field.required
                ? (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null
                : null,
          ),
        );

      case 'email':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: label,
              hintText: field.placeholder ?? 'email@example.com',
              prefixIcon: const Icon(Icons.email_rounded),
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => _customFieldValues[field.id] = v,
            validator: (v) {
              if (field.required && (v == null || v.trim().isEmpty)) return AppLocalizations.of(_localizedCtx ?? context)['required_field'];
              if (v != null && v.isNotEmpty && (!v.contains('@') || !v.contains('.'))) return AppLocalizations.of(_localizedCtx ?? context)['invalid_email'];
              return null;
            },
          ),
        );

      case 'phone':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: label,
              hintText: field.placeholder ?? '+39...',
              prefixIcon: const Icon(Icons.phone_rounded),
            ),
            keyboardType: TextInputType.phone,
            onChanged: (v) => _customFieldValues[field.id] = v,
            validator: field.required
                ? (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null
                : null,
          ),
        );

      case 'text':
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: label,
              hintText: field.placeholder,
              prefixIcon: const Icon(Icons.short_text_rounded),
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => _customFieldValues[field.id] = v,
            validator: field.required
                ? (v) => v == null || v.trim().isEmpty ? AppLocalizations.of(_localizedCtx ?? context)['required_field'] : null
                : null,
          ),
        );
    }
  }

  Widget _buildOrgLogoImage(String? url, {double? maxHeight = 64, double? maxWidth = 240, Widget Function()? fallback}) {
    if (url == null || url.trim().isEmpty) {
      return fallback != null ? fallback() : const SizedBox.shrink();
    }
    final trimmed = url.trim();
    if (trimmed.startsWith('data:image/')) {
      try {
        final comma = trimmed.indexOf(',');
        if (comma != -1) {
          final bytes = base64Decode(trimmed.substring(comma + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallback != null ? fallback() : const SizedBox.shrink(),
          );
        }
      } catch (_) {}
    }
    return Image.network(
      trimmed,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback != null ? fallback() : const SizedBox.shrink(),
    );
  }

  Widget _buildOrgHeader(Organization? org) {
    if (org == null) {
      return const SizedBox(height: 24);
    }

    final hasLogo = org.logo != null && org.logo!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasLogo) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 64, maxWidth: 240),
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildOrgLogoImage(
                  org.logo,
                  fallback: () => _buildOrgTextBadge(org),
                ),
              ),
            ),
          ] else ...[
            _buildOrgTextBadge(org),
          ],
        ],
      ),
    );
  }

  Widget _buildOrgTextBadge(Organization org) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              org.name.isNotEmpty ? org.name[0].toUpperCase() : '🏢',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            org.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                'assets/images/ticketto_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Powered by Ticketto',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSuccessState(EventModel event, Organization? org) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOrgHeader(org),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(_localizedCtx ?? context)['payment_complete_title'],
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(_localizedCtx ?? context)['payment_complete_desc']
                    .replaceFirst('{title}', event.title),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(_localizedCtx ?? context)['payment_email_notice'],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textTertiary, height: 1.5),
              ),
              if (event.price != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.success),
                      const SizedBox(width: 12),
                      Text(
                        '${AppLocalizations.of(_localizedCtx ?? context)['amount_paid']}: €${event.price!.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState(EventModel event, Organization? org) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildOrgHeader(org),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 72),
              ),
              const SizedBox(height: 28),
              Text(
                AppLocalizations.of(_localizedCtx ?? context)['registration_success_title'],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '${AppLocalizations.of(_localizedCtx ?? context)['registration_success_desc']} "${event.title}"',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // QR Code
              if (_qrCodeData != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(_localizedCtx ?? context)['your_qr'],
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(_localizedCtx ?? context)['save_qr'],
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: _qrCodeData!,
                        version: QrVersions.auto,
                        size: 200,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF1A1A2E),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _DetailRow(label: AppLocalizations.of(_localizedCtx ?? context)['first_name'], value: '${_firstNameCtrl.text} ${_lastNameCtrl.text}'),
                    const Divider(height: 24),
                    _DetailRow(label: 'Email', value: _emailCtrl.text),
                    const Divider(height: 24),
                    _DetailRow(label: AppLocalizations.of(_localizedCtx ?? context)['date_label'], value: '${event.date.day}/${event.date.month}/${event.date.year}'),
                    if (event.location != null) ...[
                      const Divider(height: 24),
                      _DetailRow(label: AppLocalizations.of(_localizedCtx ?? context)['location_label'], value: event.location!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.screenshot_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(_localizedCtx ?? context)['confirmation_email'],
                        style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy, size: 56, color: AppColors.error),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EventInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  final Color? textColor;
  const _EventInfoRow({
    required this.icon,
    required this.text,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? Colors.white.withValues(alpha: 0.8), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ),
      ],
    );
  }
}

class _ExtraAttendee {
  final TextEditingController firstNameCtrl = TextEditingController();
  final TextEditingController lastNameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();

  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
  }
}
