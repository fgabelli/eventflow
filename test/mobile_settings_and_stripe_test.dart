import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/widgets/mobile_settings_button.dart';
import 'package:eventflow/features/events/presentation/widgets/stripe_warning_banner.dart';

const _testDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  group('MobileSettingsButton Widget Tests', () {
    testWidgets('shows gear icon on mobile screen (390px width)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: _testDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('it'),
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: Row(
                children: [
                  MobileSettingsButton(),
                ],
              ),
            ),
            body: Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Gear icon should be visible
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byKey(const Key('mobile_settings_button')), findsOneWidget);
    });

    testWidgets('hides gear icon on desktop screen (1024px width)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: _testDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('it'),
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: Row(
                children: [
                  MobileSettingsButton(),
                ],
              ),
            ),
            body: Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Gear icon should NOT be visible on desktop
      expect(find.byIcon(Icons.settings_rounded), findsNothing);
      expect(find.byKey(const Key('mobile_settings_button')), findsNothing);
    });
  });

  group('StripeWarningBanner on Mobile (390px width)', () {
    testWidgets('renders cleanly without overflow at 390px and shows connect prompt', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final orgWithoutStripe = Organization(
        id: 'org_test_1',
        name: 'Test Mobile Org',
        paymentMode: null,
        stripeChargesEnabled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _testDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StripeWarningBanner(
                org: orgWithoutStripe,
                userEmail: 'organizer@test.com',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check text and button
      expect(find.text('Per vendere biglietti collega il tuo account Stripe'), findsOneWidget);
      expect(find.text('Collega Stripe'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Verify no exceptions were thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows complete prompt when stripe is pending', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final orgPending = Organization(
        id: 'org_test_2',
        name: 'Test Mobile Org Pending',
        paymentMode: 'standard',
        stripeConnectStatus: 'pending',
        stripeChargesEnabled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _testDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StripeWarningBanner(
                org: orgPending,
                userEmail: 'organizer@test.com',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check text and button for pending
      expect(find.text('Completa la configurazione di Stripe'), findsOneWidget);
      expect(find.text('Completa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('showStripeRequiredDialog on Mobile', () {
    testWidgets('shows dialog with correct texts and buttons', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final org = Organization(
        id: 'org_dialog_1',
        name: 'Dialog Org',
        paymentMode: null,
        stripeChargesEnabled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _testDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showStripeRequiredDialog(
                    ctx,
                    org: org,
                    userEmail: 'test@example.com',
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Configurazione Stripe richiesta'), findsOneWidget);
      expect(find.text('Per vendere biglietti collega il tuo account Stripe'), findsOneWidget);
      expect(find.text('Annulla'), findsOneWidget);
      expect(find.text('Collega Stripe'), findsOneWidget);

      // Close dialog via cancel
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.text('Configurazione Stripe richiesta'), findsNothing);
    });
  });
}
