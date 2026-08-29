import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/features/auth/presentation/screens/login_screen.dart';
import 'package:eventflow/features/organizations/presentation/screens/create_org_screen.dart';
import 'package:eventflow/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:eventflow/features/events/presentation/screens/events_screen.dart';
import 'package:eventflow/features/events/presentation/screens/event_detail_screen.dart';
import 'package:eventflow/features/attendees/presentation/screens/attendees_screen.dart';
import 'package:eventflow/features/checkin/presentation/screens/checkin_screen.dart';
import 'package:eventflow/features/settings/presentation/screens/settings_screen.dart';
import 'package:eventflow/features/settings/presentation/screens/team_screen.dart';
import 'package:eventflow/features/registration/presentation/screens/public_registration_screen.dart';
import 'package:eventflow/features/subscription/presentation/screens/subscription_screen.dart';

import 'package:eventflow/features/legal/presentation/screens/privacy_screen.dart';
import 'package:eventflow/features/legal/presentation/screens/terms_screen.dart';
import 'package:eventflow/features/legal/presentation/screens/cookie_screen.dart';
import 'package:eventflow/features/company/presentation/screens/about_screen.dart';
import 'package:eventflow/features/company/presentation/screens/contact_screen.dart';
import 'package:eventflow/features/feedback/presentation/screens/feedback_screen.dart';
import 'package:eventflow/features/shell/app_shell.dart';
import 'package:eventflow/core/analytics/analytics_service.dart';

// Notifier that tells GoRouter to re-evaluate redirects
class _RouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();

  // Listen to auth changes and trigger redirect re-evaluation
  // (NOT watch — watch would recreate the entire GoRouter and lose the current URL)
  ref.listen(authStateProvider, (_, __) => notifier.notify());
  ref.listen(appUserProvider, (_, __) => notifier.notify());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    observers: [AnalyticsService.instance.observer],
    redirect: (context, state) {
      final path = state.uri.path;

      // Public routes: skip ALL auth checks
      if (path.startsWith('/register') ||
          path == '/privacy' ||
          path == '/terms' ||
          path == '/cookies' ||
          path == '/about' ||
          path == '/contacts' ||
          path.startsWith('/feedback')) {
        return null;
      }

      // Read (not watch) current auth state
      final authState = ref.read(authStateProvider);
      final appUser = ref.read(appUserProvider);

      // Still loading auth
      if (authState.isLoading || appUser.isLoading) return null;
      
      final firebaseUser = authState.value;
      final isLoggedIn = firebaseUser != null;
      final isOnLogin = path == '/login';
      final user = appUser.value;
      final hasOrg = user != null && user.organizationIds.isNotEmpty;

      // Not logged in -> go to login
      if (!isLoggedIn) return isOnLogin ? null : '/login';
      
      // Logged in but on login page -> redirect
      if (isOnLogin) return hasOrg ? '/' : '/create-org';

      // Logged in but no organization -> create one
      if (!hasOrg && path != '/create-org') {
        return '/create-org';
      }

      return null;
    },
    routes: [
      // ─── Public routes (no auth required) ──────────────────
      GoRoute(
        path: '/register/:eventId',
        builder: (_, state) => PublicRegistrationScreen(
          eventId: state.pathParameters['eventId']!,
        ),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, state) => const TermsScreen(),
      ),
      GoRoute(
        path: '/cookies',
        builder: (_, state) => const CookieScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (_, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (_, state) => const ContactScreen(),
      ),
      GoRoute(
        path: '/feedback/:eventId',
        builder: (_, state) => FeedbackScreen(
          eventId: state.pathParameters['eventId']!,
        ),
      ),

      // ─── Auth routes ───────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/create-org',
        builder: (_, state) => const CreateOrgScreen(),
      ),

      // ─── Authenticated routes ──────────────────────────────
      ShellRoute(
        builder: (_, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/events',
            builder: (_, state) => const EventsScreen(),
          ),
          GoRoute(
            path: '/events/:id',
            builder: (_, state) => EventDetailScreen(
              eventId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/attendees',
            builder: (_, state) => const AttendeesScreen(),
          ),
          GoRoute(
            path: '/checkin',
            builder: (_, state) => const CheckInScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/team',
            builder: (_, state) => const TeamScreen(),
          ),
          GoRoute(
            path: '/subscription',
            builder: (_, state) => const SubscriptionScreen(),
          ),
        ],
      ),
    ],
  );
});
