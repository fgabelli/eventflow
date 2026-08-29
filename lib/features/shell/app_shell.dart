import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    // Load persisted language preference from Firestore on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_localeInitialized) {
        _localeInitialized = true;
        initLocaleFromProfile(ref);
      }
    });
  }

  int get _selectedIndex {
    final location = GoRouterState.of(context).matchedLocation;
    // Exact match first
    for (int i = 0; i < _navItems.length; i++) {
      if (_navItems[i].path == location) return i;
    }
    // Prefix match for sub-routes (e.g. /events/123 → Events)
    for (int i = _navItems.length - 1; i >= 0; i--) {
      if (_navItems[i].path != '/' && location.startsWith(_navItems[i].path)) return i;
    }
    // Default: no match → -1 (nothing highlighted)
    return -1;
  }

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, labelKey: 'nav_dashboard', path: '/'),
    _NavItem(icon: Icons.event_rounded, labelKey: 'nav_events', path: '/events'),
    _NavItem(icon: Icons.people_rounded, labelKey: 'nav_attendees', path: '/attendees'),
    _NavItem(icon: Icons.qr_code_scanner_rounded, labelKey: 'nav_checkin', path: '/checkin'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final appUser = ref.watch(appUserProvider).value;
    final org = ref.watch(currentOrgProvider).value;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _buildSideNav(context, appUser, org),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildSideNav(BuildContext context, dynamic appUser, dynamic org) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/ticketto_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ticketto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (org != null)
                        Text(
                          org.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),

          // Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                for (int i = 0; i < _navItems.length; i++)
                  _buildSideNavItem(i, _navItems[i]),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),

          // Bottom section - settings & user
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildSettingsNavItem(),
                const SizedBox(height: 4),
                _buildUpgradeButton(),
                const SizedBox(height: 8),
                // User info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          (appUser?.displayName ?? appUser?.email ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appUser?.displayName ?? appUser?.email ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => ref.read(authServiceProvider).signOut(),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(int index, _NavItem item) {
    final isSelected = index == _selectedIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(_navItems[index].path),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? AppColors.primaryLight : Colors.white54,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)[item.labelKey],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        destinations: _navItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon, color: AppColors.textTertiary),
            selectedIcon: Icon(item.icon, color: AppColors.primary),
            label: AppLocalizations.of(context)[item.labelKey],
          );
        }).toList(),
      ),
    );
  }

  void _onNavTap(int index) {
    context.go(_navItems[index].path);
  }

  Widget _buildSettingsNavItem() {
    final isSelected = GoRouterState.of(context).matchedLocation == '/settings';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/settings'),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: isSelected ? AppColors.primaryLight : Colors.white54,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)['nav_settings'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeButton() {
    final org = ref.watch(currentOrgProvider).value;
    final plan = org?.plan ?? SubscriptionPlan.free;
    final isOnSubscription = GoRouterState.of(context).matchedLocation == '/subscription';

    if (plan.isFree) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/subscription'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: isOnSubscription ? null : AppColors.primaryGradient,
                color: isOnSubscription ? AppColors.primary.withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.diamond_rounded,
                    size: 20,
                    color: isOnSubscription ? AppColors.primaryLight : Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)['upgrade'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Paid plan - show plan name
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/subscription'),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isOnSubscription
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 20,
                  color: isOnSubscription ? AppColors.primaryLight : const Color(0xFFFFD700),
                ),
                const SizedBox(width: 12),
                Text(
                  'Piano ${plan.label}',
                  style: TextStyle(
                    color: isOnSubscription ? Colors.white : Colors.white54,
                    fontSize: 14,
                    fontWeight: isOnSubscription ? FontWeight.w600 : FontWeight.w400,
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

class _NavItem {
  final IconData icon;
  final String labelKey;
  final String path;

  const _NavItem({
    required this.icon,
    required this.labelKey,
    required this.path,
  });
}
