import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/utils/feature_gate.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/widgets/help_tip.dart';
import 'package:eventflow/core/analytics/analytics_service.dart';

// ─── Events Provider ───────────────────────────────────────────────

final eventsProvider = StreamProvider<List<EventModel>>((ref) {
  final org = ref.watch(currentOrgProvider).value;
  if (org == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection(Collections.events)
      .where('orgId', isEqualTo: org.id)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => EventModel.fromFirestore(d)).toList());
});

// ─── Events Service ────────────────────────────────────────────────

class EventsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createEvent(EventModel event) async {
    final ref = _db.collection(Collections.events).doc();
    final newEvent = EventModel(
      id: ref.id,
      orgId: event.orgId,
      title: event.title,
      description: event.description,
      date: event.date,
      endDate: event.endDate,
      location: event.location,
      status: event.status,
      maxAttendees: event.maxAttendees,
      registrationDeadline: event.registrationDeadline,
      categories: event.categories,
      customFields: event.customFields,
      isPaid: event.isPaid,
      price: event.price,
      hasTimeSlots: event.hasTimeSlots,
      timeSlots: event.timeSlots,
    );
    await ref.set(newEvent.toFirestore());
    return ref.id;
  }

  Future<void> updateEvent(EventModel event) async {
    await _db.collection(Collections.events).doc(event.id).update(event.toFirestore());
  }

  Future<void> updateEventStatus(String eventId, EventStatus status) async {
    await _db.collection(Collections.events).doc(eventId).update({
      'status': status.name,
    });
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.collection(Collections.events).doc(eventId).delete();
  }
}

final eventsServiceProvider = Provider<EventsService>((ref) => EventsService());

// ─── Events Screen ─────────────────────────────────────────────────

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String _filter = 'all'; // 'all', 'published', 'draft', 'completed'

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.surface,
            title: Text(AppLocalizations.of(context)['events'], style: Theme.of(context).textTheme.headlineMedium),
            actions: [
              FilledButton.icon(
                onPressed: () => _tryCreateEvent(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocalizations.of(context)['new_event']),
              ),
              const SizedBox(width: 16),
            ],
          ),
          
          // Filter chips
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(label: AppLocalizations.of(context)['filter_all'], value: 'all', selected: _filter, onSelected: (v) => setState(() => _filter = v)),
                    _FilterChip(label: AppLocalizations.of(context)['filter_published'], value: 'published', selected: _filter, onSelected: (v) => setState(() => _filter = v)),
                    _FilterChip(label: AppLocalizations.of(context)['filter_draft'], value: 'draft', selected: _filter, onSelected: (v) => setState(() => _filter = v)),
                    _FilterChip(label: AppLocalizations.of(context)['filter_completed'], value: 'completed', selected: _filter, onSelected: (v) => setState(() => _filter = v)),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Events list
          eventsAsync.when(
            data: (events) {
              final filtered = _filterEvents(events);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(context),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _EventCard(
                      event: filtered[index],
                      onStatusChange: (status) => _changeStatus(filtered[index].id, status),
                      onDelete: () => _deleteEvent(filtered[index].id),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('${AppLocalizations.of(context)['error_generic_short']}: $e')),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<EventModel> _filterEvents(List<EventModel> events) {
    if (_filter == 'all') return events;
    return events.where((e) => e.status.name == _filter).toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_rounded, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)['no_events'],
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)['create_first_event'],
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _tryCreateEvent(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(AppLocalizations.of(context)['create_event']),
          ),
        ],
      ),
    );
  }

  void _changeStatus(String eventId, EventStatus status) {
    ref.read(eventsServiceProvider).updateEventStatus(eventId, status);
  }

  void _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l['delete_event']),
          content: Text(l['delete_confirm']),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l['cancel'])),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(l['delete']),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      try {
        await ref.read(eventsServiceProvider).deleteEvent(eventId);
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

  void _tryCreateEvent(BuildContext context) {
    final org = ref.read(currentOrgProvider).value;
    final plan = org?.plan ?? SubscriptionPlan.free;
    final events = ref.read(eventsProvider).value ?? [];
    // Only count active events (draft + published)
    final activeEvents = events.where((e) => e.status == EventStatus.draft || e.status == EventStatus.published).length;

    if (!canCreateEvent(context, plan, activeEvents)) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateEventSheet(),
    );
  }

}

// ─── Filter Chip ───────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => onSelected(value),
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isActive ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

// ─── Event Card ────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final EventModel event;
  final ValueChanged<EventStatus> onStatusChange;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/events/${event.id}'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Date badge
                    Container(
                      width: 52,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${event.date.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _monthAbbr(event.date.month, context),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Event info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          if (event.location != null)
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.location!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Status & menu
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor(event.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.status.label,
                            style: TextStyle(
                              color: _statusColor(event.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textTertiary),
                          itemBuilder: (context) => [
                            if (event.status == EventStatus.draft)
                              PopupMenuItem(value: 'publish', child: Text(AppLocalizations.of(context)['publish'])),
                            if (event.status == EventStatus.published)
                              PopupMenuItem(value: 'complete', child: Text(AppLocalizations.of(context)['mark_complete'])),
                            PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context)['delete'], style: const TextStyle(color: AppColors.error))),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'publish':
                                onStatusChange(EventStatus.published);
                              case 'complete':
                                onStatusChange(EventStatus.completed);
                              case 'delete':
                                onDelete();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  children: [
                    _EventStat(
                      icon: Icons.people_outline,
                      label: '${event.attendeesCount}/${event.maxAttendees}',
                    ),
                    const SizedBox(width: 24),
                    _EventStat(
                      icon: Icons.access_time,
                      label: _formatTime(event.date),
                    ),
                    if (event.isPaid && event.price != null) ...[
                      const SizedBox(width: 24),
                      _EventStat(
                        icon: Icons.euro,
                        label: '€${event.price!.toStringAsFixed(2)}',
                      ),
                    ],
                    const Spacer(),
                    // Language badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.language == 'it' ? '🇮🇹' : '🇬🇧',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (event.isFull) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'FULL',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthAbbr(int month, BuildContext context) {
    final l = AppLocalizations.of(context);
    const keys = ['', 'month_jan', 'month_feb', 'month_mar', 'month_apr', 'month_may', 'month_jun',
                    'month_jul', 'month_aug', 'month_sep', 'month_oct', 'month_nov', 'month_dec'];
    return l[keys[month]];
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(EventStatus status) {
    switch (status) {
      case EventStatus.published: return AppColors.success;
      case EventStatus.draft: return AppColors.warning;
      case EventStatus.canceled: return AppColors.error;
      case EventStatus.completed: return AppColors.textSecondary;
    }
  }
}

class _EventStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EventStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ─── Create Event Sheet ────────────────────────────────────────────

class _CreateEventSheet extends ConsumerStatefulWidget {
  const _CreateEventSheet();

  @override
  ConsumerState<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends ConsumerState<_CreateEventSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetingUrlController = TextEditingController();
  final _maxAttendeesController = TextEditingController(text: '50');
  final _priceController = TextEditingController();
  final _hexColorController = TextEditingController(text: '#6366F1');
  String? _selectedColor = '#6366F1';
  bool _showAttendeesCount = false;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  bool _isPaid = false;
  bool _isOnline = false;
  bool _isLoading = false;
  bool _hasTimeSlots = false;
  List<TimeSlot> _timeSlots = [];
  List<CustomField> _customFields = [];
  bool _notifyOrganizer = false;
  bool _allowGroupRegistration = false;
  late String _eventLanguage;
  bool _eventLanguageInitialized = false;

  @override
  void initState() {
    super.initState();
    // Default event language = current UI language
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize once from the current locale — don't overwrite user selection
    if (!_eventLanguageInitialized) {
      _eventLanguageInitialized = true;
      _eventLanguage = Localizations.localeOf(context).languageCode;
      if (!['it', 'en'].contains(_eventLanguage)) _eventLanguage = 'en';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _meetingUrlController.dispose();
    _maxAttendeesController.dispose();
    _priceController.dispose();
    _hexColorController.dispose();
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

  Future<void> _createEvent() async {
    if (_titleController.text.trim().isEmpty) return;

    final org = ref.read(currentOrgProvider).value;
    if (org == null) return;

    setState(() => _isLoading = true);

    final eventDate = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );

    try {
      await ref.read(eventsServiceProvider).createEvent(EventModel(
        id: '',
        orgId: org.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        date: eventDate,
        isOnline: _isOnline,
        meetingUrl: _isOnline ? _meetingUrlController.text.trim() : null,
        location: _isOnline ? null : (_locationController.text.trim().isEmpty ? null : _locationController.text.trim()),
        status: EventStatus.draft,
        maxAttendees: () {
          final plan = org.plan;
          final parsed = int.tryParse(_maxAttendeesController.text) ?? 50;
          return plan.isUnlimitedAttendees ? parsed : parsed.clamp(1, plan.maxAttendeesPerEvent);
        }(),
        isPaid: _isPaid && org.plan.isPaid,
        price: (_isPaid && org.plan.isPaid) ? double.tryParse(_priceController.text) : null,
        hasTimeSlots: _hasTimeSlots,
        timeSlots: _hasTimeSlots ? _timeSlots : [],
        customFields: _customFields,
        primaryColor: _selectedColor,
        showAttendeesCount: _showAttendeesCount,
        notifyOrganizerOnNewRegistration: _notifyOrganizer,
        allowGroupRegistration: _allowGroupRegistration && !org.plan.isFree,
        language: _eventLanguage,
      ));

      // Track event creation
      final maxAtt = int.tryParse(_maxAttendeesController.text) ?? 50;
      AnalyticsService.instance.logEvent('event_created', params: {
        'is_free': !(_isPaid && org.plan.isPaid),
        'capacity_tier': maxAtt >= 500 ? 'unlimited' : (maxAtt > 50 ? '500' : '50'),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)['event_created_success']),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)['error_generic_short']}: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrgProvider).value;
    final isPremium = org != null && (org.plan.name == 'pro' || org.plan.name == 'business');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)['new_event'], style: Theme.of(context).textTheme.headlineMedium),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Form
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: true,
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  _buildLabelWithHelp(AppLocalizations.of(context)['event_title_label'], AppLocalizations.of(context)['help_event_title']),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Annual Tech Conference',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Event Language
                  _buildLabel(AppLocalizations.of(context)['event_language_label']),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _LanguageChip(
                        flag: '🇮🇹',
                        label: 'Italiano',
                        isSelected: _eventLanguage == 'it',
                        onTap: () => setState(() => _eventLanguage = 'it'),
                      ),
                      const SizedBox(width: 8),
                      _LanguageChip(
                        flag: '🇬🇧',
                        label: 'English',
                        isSelected: _eventLanguage == 'en',
                        onTap: () => setState(() => _eventLanguage = 'en'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)['event_language_hint'],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _buildLabelWithHelp(AppLocalizations.of(context)['description_label'], AppLocalizations.of(context)['help_event_description']),
                  TextField(
                    controller: _descController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)['event_desc_hint'],
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Date & Time
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabelWithHelp(AppLocalizations.of(context)['date_label'], AppLocalizations.of(context)['help_event_date']),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18, color: AppColors.textTertiary),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(AppLocalizations.of(context)['time_label']),
                            InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: AppColors.textTertiary),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Appearance & Color Customization
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
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
                                  _hexColorController.text = hex;
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
                                controller: _hexColorController,
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

                  // Location / Online Event
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabelWithHelp(AppLocalizations.of(context)['event_type_label'], AppLocalizations.of(context)['event_type_hint']),
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
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)['location_hint'],
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                    )
                  else
                    TextField(
                      controller: _meetingUrlController,
                      decoration: const InputDecoration(
                        hintText: 'https://zoom.us/j/123456...',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                    ),
                  const SizedBox(height: 20),

                  // Max Attendees
                  _buildLabelWithHelp(AppLocalizations.of(context)['max_attendees_label'], AppLocalizations.of(context)['help_max_attendees']),
                  Builder(builder: (_) {
                    final plan = ref.watch(currentOrgProvider).value?.plan ?? SubscriptionPlan.free;
                    final limitText = plan.isUnlimitedAttendees
                        ? AppLocalizations.of(context)['unlimited_attendees']
                        : 'Max ${plan.maxAttendeesPerEvent} (${plan.label})';
                    return TextField(
                      controller: _maxAttendeesController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.people_outline),
                        helperText: limitText,
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    );
                  }),
                  const SizedBox(height: 20),

                  // Paid Event
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(AppLocalizations.of(context)['paid_event'], style: Theme.of(context).textTheme.titleMedium),
                                    HelpTip(text: AppLocalizations.of(context)['help_paid_event']),
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
                                Text(
                                  AppLocalizations.of(context)['enable_pricing'],
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Switch(
                              value: _isPaid,
                              onChanged: (v) {
                                final plan = ref.read(currentOrgProvider).value?.plan ?? SubscriptionPlan.free;
                                if (v && plan.isFree) {
                                  checkFeatureAccess(
                                    context: context,
                                    currentPlan: plan,
                                    requiredPlan: SubscriptionPlan.pro,
                                    featureName: AppLocalizations.of(context)['paid_event'],
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
                          TextField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.euro),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Group Registration
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(AppLocalizations.of(context)['group_registration_label'], style: Theme.of(context).textTheme.titleMedium),
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
                              Text(
                                AppLocalizations.of(context)['group_registration_desc'],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
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
                                featureName: AppLocalizations.of(context)['group_registration_label'],
                              );
                              return;
                            }
                            setState(() => _allowGroupRegistration = v);
                          },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time Slots
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(AppLocalizations.of(context)['time_slot_booking'], style: Theme.of(context).textTheme.titleMedium),
                                    HelpTip(text: AppLocalizations.of(context)['help_time_slots']),
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
                                Text(
                                  AppLocalizations.of(context)['time_slot_desc'],
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Switch(
                              value: _hasTimeSlots,
                              onChanged: (v) {
                                final plan = ref.read(currentOrgProvider).value?.plan ?? SubscriptionPlan.free;
                                if (v && plan.isFree) {
                                  checkFeatureAccess(
                                    context: context,
                                    currentPlan: plan,
                                    requiredPlan: SubscriptionPlan.pro,
                                    featureName: AppLocalizations.of(context)['time_slot_booking'],
                                  );
                                  return;
                                }
                                setState(() => _hasTimeSlots = v);
                              },
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                        if (_hasTimeSlots) ...[
                          const SizedBox(height: 16),
                          ..._timeSlots.asMap().entries.map((entry) {
                            final i = entry.key;
                            final slot = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          slot.label.isNotEmpty ? slot.label : 'Slot ${i + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Text(
                                        '${slot.startTime} – ${slot.endTime}',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${slot.maxCapacity} ${AppLocalizations.of(context)['spots_label']}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => setState(() => _timeSlots.removeAt(i)),
                                        child: const Icon(Icons.close, size: 18, color: AppColors.error),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          OutlinedButton.icon(
                            onPressed: () => _showAddSlotDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(AppLocalizations.of(context)['add_time_slot']),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Custom Fields
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.dynamic_form_rounded, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Text(AppLocalizations.of(context)['custom_fields_label'], style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                                  ),
                                  HelpTip(text: AppLocalizations.of(context)['help_custom_fields']),
                                  Text(
                                    AppLocalizations.of(context)['custom_fields_desc'],
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_customFields.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ..._customFields.asMap().entries.map((entry) {
                            final i = entry.key;
                            final field = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(_fieldTypeIcon(field.type), size: 18, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                field.label,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (field.required) ...[
                                              const SizedBox(width: 4),
                                              const Text('*', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                field.typeLabel,
                                                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            if (field.type == 'select' && field.options != null) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                AppLocalizations.of(context)['options_count'].replaceAll('{count}', field.options!.length.toString()),
                                                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => setState(() => _customFields.removeAt(i)),
                                    child: const Icon(Icons.close, size: 18, color: AppColors.error),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            final plan = ref.read(currentOrgProvider).value?.plan ?? SubscriptionPlan.free;
                            if (plan.isFree) {
                              checkFeatureAccess(
                                context: context,
                                currentPlan: plan,
                                requiredPlan: SubscriptionPlan.pro,
                                featureName: AppLocalizations.of(context)['custom_fields_label'],
                              );
                              return;
                            }
                            _showAddCustomFieldDialog();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(AppLocalizations.of(context)['add_field']),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Notifications Toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(AppLocalizations.of(context)['realtime_notifications_label'], style: Theme.of(context).textTheme.titleMedium),
                                  if (!isPremium) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.lock, size: 14, color: AppColors.textTertiary),
                                  ],
                                ],
                              ),
                              Text(
                                AppLocalizations.of(context)['realtime_notifications_desc'],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (!isPremium)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    AppLocalizations.of(context)['available_pro_business'],
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
                  ),

                  const SizedBox(height: 16),

                  const SizedBox(height: 32),

                  // Submit
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createEvent,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(AppLocalizations.of(context)['create_event']),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }

  Widget _buildLabelWithHelp(String text, String helpText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(text, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 4),
          HelpTip(text: helpText, iconSize: 16),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  void _showAddSlotDialog() {
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
                   decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)['slot_label_field'],
                    hintText: 'e.g. Morning Session',
                  ),
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
                   decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)['max_capacity'],
                    prefixIcon: const Icon(Icons.people_outline),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)['cancel']),
              ),
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
                  setState(() => _timeSlots.add(slot));
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

  IconData _fieldTypeIcon(String type) {
    switch (type) {
      case 'text': return Icons.short_text_rounded;
      case 'select': return Icons.list_rounded;
      case 'number': return Icons.tag_rounded;
      case 'checkbox': return Icons.check_box_rounded;
      case 'email': return Icons.email_rounded;
      case 'phone': return Icons.phone_rounded;
      default: return Icons.text_fields_rounded;
    }
  }

  void _showAddCustomFieldDialog() {
    final labelCtrl = TextEditingController();
    final placeholderCtrl = TextEditingController();
    String selectedType = 'text';
    bool isRequired = false;
    final List<String> options = [];
    final optionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)['add_field']),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Field label
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome del campo *',
                      hintText: 'es. Azienda, Ruolo, Allergie...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field type
                  const Text('Tipo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _typeChip('text', 'Testo', Icons.short_text_rounded, selectedType, (v) => setDialogState(() => selectedType = v)),
                      _typeChip('select', 'Selezione', Icons.list_rounded, selectedType, (v) => setDialogState(() => selectedType = v)),
                      _typeChip('number', 'Numero', Icons.tag_rounded, selectedType, (v) => setDialogState(() => selectedType = v)),
                      _typeChip('checkbox', 'Checkbox', Icons.check_box_rounded, selectedType, (v) => setDialogState(() => selectedType = v)),
                      _typeChip('email', 'Email', Icons.email_rounded, selectedType, (v) => setDialogState(() => selectedType = v)),
                      _typeChip('phone', 'Telefono', Icons.phone_rounded, selectedType, (v) => setDialogState(() => selectedType = v)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Placeholder
                  TextField(
                    controller: placeholderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Placeholder (opzionale)',
                      hintText: 'es. Inserisci il nome...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Required toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Obbligatorio', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Switch(
                        value: isRequired,
                        onChanged: (v) => setDialogState(() => isRequired = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),

                  // Options (for select type)
                  if (selectedType == 'select') ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)['options_label'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...options.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 6, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14))),
                          InkWell(
                            onTap: () => setDialogState(() => options.removeAt(e.key)),
                            child: const Icon(Icons.close, size: 16, color: AppColors.error),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: optionCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Nuova opzione...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                setDialogState(() {
                                  options.add(v.trim());
                                  optionCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            if (optionCtrl.text.trim().isNotEmpty) {
                              setDialogState(() {
                                options.add(optionCtrl.text.trim());
                                optionCtrl.clear();
                              });
                            }
                          },
                          icon: const Icon(Icons.add_circle, color: AppColors.primary),
                          iconSize: 22,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)['cancel']),
              ),
              FilledButton(
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty) return;
                  if (selectedType == 'select' && options.isEmpty) return;

                  final field = CustomField(
                    label: labelCtrl.text.trim(),
                    type: selectedType,
                    required: isRequired,
                    options: selectedType == 'select' ? List.from(options) : null,
                    placeholder: placeholderCtrl.text.trim().isEmpty ? null : placeholderCtrl.text.trim(),
                  );
                  setState(() => _customFields.add(field));
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

  Widget _typeChip(String value, String label, IconData icon, String selected, ValueChanged<String> onTap) {
    final isActive = value == selected;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? AppColors.primary : AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Language Chip Widget ────────────────────────────────────────

class _LanguageChip extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
