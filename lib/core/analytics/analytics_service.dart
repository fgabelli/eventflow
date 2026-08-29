import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show NavigatorObserver;

import 'consent_helper_stub.dart'
    if (dart.library.html) 'consent_helper_web.dart' as helper;

/// Singleton wrapper for Firebase Analytics.
///
/// All analytics calls go through here. No-ops when marketing consent
/// has not been granted (respects the cookie consent banner).
///
/// **Web:** events are sent via `gtag('event', ...)` directly (the gtag.js
/// script is already loaded in index.html with `G-JS3J7696GM`). This bypasses
/// the `firebase_analytics` MethodChannel which doesn't work on Flutter Web.
///
/// **Mobile (iOS/Android):** events go through `FirebaseAnalytics` SDK as normal.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  // Only used on mobile — on web we go via gtag.
  FirebaseAnalytics? _analytics;
  bool _consentGranted = false;

  /// The [NavigatorObserver] for automatic screen tracking (mobile only).
  /// On web, screen tracking goes via gtag in the redirect callback.
  NavigatorObserver get observer {
    try {
      _analytics ??= FirebaseAnalytics.instance;
      return FirebaseAnalyticsObserver(analytics: _analytics!);
    } catch (_) {
      // Return a no-op observer if FirebaseAnalytics is unavailable
      return NavigatorObserver();
    }
  }

  // ─── Lifecycle ────────────────────────────────────────────────

  /// Call once after [Firebase.initializeApp].
  /// Disables collection by default, then re-enables if consent was
  /// previously granted (stored in localStorage on web).
  Future<void> init() async {
    try {
      if (!kIsWeb) {
        _analytics = FirebaseAnalytics.instance;
        await _analytics!.setAnalyticsCollectionEnabled(false);
      }
      // Check if consent was previously granted
      final saved = helper.getSavedConsent();
      if (saved == 'granted') {
        _consentGranted = true;
        if (!kIsWeb) {
          await _analytics!.setAnalyticsCollectionEnabled(true);
        }
      }
    } catch (_) {
      // Analytics unavailable on this environment — never block startup.
    }
  }

  /// Called when the user accepts marketing cookies.
  Future<void> enableAnalytics() async {
    _consentGranted = true;
    try {
      if (!kIsWeb && _analytics != null) {
        await _analytics!.setAnalyticsCollectionEnabled(true);
      }
    } catch (_) {}
  }

  /// Called when the user rejects / revokes marketing cookies.
  Future<void> disableAnalytics() async {
    _consentGranted = false;
    try {
      if (!kIsWeb && _analytics != null) {
        await _analytics!.setAnalyticsCollectionEnabled(false);
      }
    } catch (_) {}
  }

  // ─── Tracking ─────────────────────────────────────────────────

  /// Log a custom or recommended GA4 event.
  /// **No-op** if marketing consent has not been granted.
  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    if (!_consentGranted) return;
    try {
      if (kIsWeb) {
        // gtag.js already respects Consent Mode v2; this is double safety.
        helper.gtagLogEvent(name, params);
      } else {
        _analytics ??= FirebaseAnalytics.instance;
        await _analytics!.logEvent(name: name, parameters: params);
      }
    } catch (_) {}
  }

  /// Set the Firebase user ID for cross-device attribution.
  /// Pass `null` on sign-out.
  Future<void> setUserId(String? uid) async {
    // Always allow clearing the user ID on sign-out
    if (!_consentGranted && uid != null) return;
    try {
      if (kIsWeb) {
        helper.gtagSetUserId(uid);
      } else {
        _analytics ??= FirebaseAnalytics.instance;
        await _analytics!.setUserId(id: uid);
      }
    } catch (_) {}
  }

  /// Log a screen_view event for route changes.
  Future<void> logScreenView(String screenName) async {
    if (!_consentGranted) return;
    try {
      if (kIsWeb) {
        helper.gtagLogEvent('screen_view', {'firebase_screen': screenName});
      } else {
        _analytics ??= FirebaseAnalytics.instance;
        await _analytics!.logEvent(
          name: 'screen_view',
          parameters: {'firebase_screen': screenName},
        );
      }
    } catch (_) {}
  }
}
