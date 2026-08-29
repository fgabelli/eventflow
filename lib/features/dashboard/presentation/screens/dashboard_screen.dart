import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/widgets/help_tip.dart';
import 'package:eventflow/features/onboarding/presentation/onboarding_tutorial.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _tutorialChecked = false;

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrgProvider).value;
    final appUser = ref.watch(appUserProvider).value;
    final l = AppLocalizations.of(context);

    // Trigger tutorial on first build
    if (!_tutorialChecked && appUser != null) {
      _tutorialChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeShowTutorial(context, ref);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.surface,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting(l)},',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  appUser?.displayName ?? '',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Stats cards
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: _buildStatsSection(context, org, l),
            ),
          ),

          // Quick Actions
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _buildQuickActions(context, l),
            ),
          ),

          // Recent events
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: _buildRecentEvents(context, org, l),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  String _getGreeting(AppLocalizations l) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l['good_morning'];
    if (hour < 17) return l['good_afternoon'];
    return l['good_evening'];
  }

  Widget _buildStatsSection(BuildContext context, Organization? org, AppLocalizations l) {
    if (org == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.events)
          .where('orgId', isEqualTo: org.id)
          .snapshots(),
      builder: (context, eventSnap) {
        final events = eventSnap.data?.docs
            .map((d) => EventModel.fromFirestore(d))
            .toList() ?? [];
        final activeEvents = events.where((e) => e.status == EventStatus.published).length;
        final totalAttendees = events.fold<int>(0, (sum, e) => sum + e.attendeesCount);
        final totalRevenue = events.fold<double>(0, (sum, e) => sum + e.revenue);

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  icon: Icons.event_rounded,
                  label: l['total_events'],
                  value: '${events.length}',
                  color: AppColors.primary,
                  trend: '+$activeEvents ${l['active_trend']}',
                ),
                _StatCard(
                  icon: Icons.people_rounded,
                  label: l['attendees_stat'],
                  value: '$totalAttendees',
                  color: AppColors.accent,
                  trend: l['all_events_trend'],
                ),
                _StatCard(
                  icon: Icons.check_circle_rounded,
                  label: l['active_events'],
                  value: '$activeEvents',
                  color: AppColors.success,
                  trend: l['published_trend'],
                ),
                _StatCard(
                  icon: Icons.euro_rounded,
                  label: l['revenue'],
                  value: '€${totalRevenue.toStringAsFixed(0)}',
                  color: AppColors.warning,
                  trend: l['total_trend'],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l['quick_actions'], style: Theme.of(context).textTheme.titleLarge),
            HelpTip(text: l['help_quick_actions']),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_circle_rounded,
                label: l['new_event'],
                color: AppColors.primary,
                onTap: () => context.go('/events'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Check-in',
                color: AppColors.accent,
                onTap: () => context.go('/checkin'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.people_rounded,
                label: l['attendees_stat'],
                color: AppColors.success,
                onTap: () => context.go('/attendees'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentEvents(BuildContext context, Organization? org, AppLocalizations l) {
    if (org == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l['recent_events'], style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/events'),
              child: Text(l['view_all']),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(Collections.events)
              .where('orgId', isEqualTo: org.id)
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data?.docs
                .map((d) => EventModel.fromFirestore(d))
                .toList() ?? [];

            if (events.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l['no_events_yet'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l['create_first_event'],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/events'),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l['create_event_btn']),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: events.map((event) => _EventListItem(event: event)).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String trend;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Card ─────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Event List Item ───────────────────────────────────────────────

class _EventListItem extends StatelessWidget {
  final EventModel event;
  const _EventListItem({required this.event});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/events/${event.id}'),
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
          // Date badge
          Container(
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${event.date.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _monthAbbr(event.date.month, l),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location ?? l['no_location'],
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status chip
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

          const SizedBox(width: 12),

          // Attendees count
          Column(
            children: [
              Text(
                '${event.attendeesCount}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '/${event.maxAttendees}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    ),
      ),
    );
  }

  String _monthAbbr(int month, AppLocalizations l) {
    const keys = ['', 'month_jan', 'month_feb', 'month_mar', 'month_apr', 'month_may', 'month_jun',
                    'month_jul', 'month_aug', 'month_sep', 'month_oct', 'month_nov', 'month_dec'];
    return l[keys[month]];
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
