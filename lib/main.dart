import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eventflow/firebase_options.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/analytics/analytics_service.dart';
import 'package:eventflow/routing/app_router.dart';
import 'package:eventflow/features/legal/presentation/widgets/cookie_consent_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Analytics must never block app startup: telemetry is non-critical and can
  // throw on some web environments. Guard it so runApp always runs.
  try {
    await AnalyticsService.instance.init();
  } catch (_) {
    // Analytics unavailable — continue without it.
  }
  runApp(const ProviderScope(child: TickettoApp()));
}

class TickettoApp extends ConsumerWidget {
  const TickettoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Ticketto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return CookieConsentBanner(child: child ?? const SizedBox());
      },
    );
  }
}
