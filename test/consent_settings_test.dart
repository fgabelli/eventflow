import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/features/events/presentation/widgets/consent_settings_section.dart';

const _testDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  group('EventModel Consent Settings Tests', () {
    test('Defaults showMarketingConsent and showPhotoConsent to true', () {
      final event = EventModel(
        id: 'ev-1',
        orgId: 'org-1',
        title: 'Test Event',
        date: DateTime(2026, 12, 1),
      );
      expect(event.showMarketingConsent, isTrue);
      expect(event.showPhotoConsent, isTrue);

      // Existing event map without these fields behaves identically to today
      final legacy = EventModel.fromMap({
        'orgId': 'org-1',
        'title': 'Legacy Event',
        'date': DateTime(2026, 12, 1),
      }, id: 'ev-legacy');
      expect(legacy.showMarketingConsent, isTrue);
      expect(legacy.showPhotoConsent, isTrue);
    });

    test('toMap, fromMap and copyWith preserve consent toggles', () {
      final event = EventModel(
        id: 'ev-2',
        orgId: 'org-1',
        title: 'AREL Event',
        date: DateTime(2026, 12, 1),
        showMarketingConsent: false,
        showPhotoConsent: false,
      );

      final map = event.toMap();
      expect(map['showMarketingConsent'], isFalse);
      expect(map['showPhotoConsent'], isFalse);

      final restored = EventModel.fromMap(map, id: 'ev-2');
      expect(restored.showMarketingConsent, isFalse);
      expect(restored.showPhotoConsent, isFalse);

      final updated = restored.copyWith(showMarketingConsent: true);
      expect(updated.showMarketingConsent, isTrue);
      expect(updated.showPhotoConsent, isFalse);
    });
  });

  group('Attendee Consent Serialization Tests', () {
    test('Persists marketingConsentShown and null photoConsent', () {
      final attendee = Attendee(
        id: 'att-1',
        eventId: 'ev-2',
        orgId: 'org-1',
        firstName: 'Anna',
        lastName: 'Bianchi',
        email: 'anna@example.com',
        qrCode: 'qr-1',
        marketingConsent: false,
        marketingConsentShown: false,
        photoConsent: null,
      );

      final map = attendee.toFirestore();
      expect(map['marketingConsent'], isFalse);
      expect(map['marketingConsentShown'], isFalse);
      expect(map['photoConsent'], isNull);

      final copy = attendee.copyWith(marketingConsentShown: true, marketingConsent: true);
      expect(copy.marketingConsentShown, isTrue);
      expect(copy.marketingConsent, isTrue);
    });
  });

  group('ConsentSettingsSection Widget Tests', () {
    testWidgets('Shows both toggles for in-presence events and hides photo toggle for online events', (tester) async {
      bool mktg = true;
      bool photo = true;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          supportedLocales: const [Locale('it'), Locale('en')],
          localizationsDelegates: _testDelegates,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ConsentSettingsSection(
                isOnline: false,
                showMarketingConsent: mktg,
                showPhotoConsent: photo,
                onMarketingConsentChanged: (v) => setState(() => mktg = v),
                onPhotoConsentChanged: (v) => setState(() => photo = v),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mostra casella consenso comunicazioni dell\'organizzatore'), findsOneWidget);
      expect(find.text('Mostra casella consenso foto/video'), findsOneWidget);
      expect(find.text('Spegnila se la tua informativa privacy copre già questo consenso.'), findsNWidgets(2));
      expect(find.byType(Switch), findsNWidgets(2));

      // Toggle both off
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(mktg, isFalse);
      expect(photo, isFalse);

      // Online event: hides photo/video switch
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('it'), Locale('en')],
          localizationsDelegates: _testDelegates,
          home: Scaffold(
            body: ConsentSettingsSection(
              isOnline: true,
              showMarketingConsent: true,
              showPhotoConsent: true,
              onMarketingConsentChanged: (_) {},
              onPhotoConsentChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show organizer communications consent checkbox'), findsOneWidget);
      expect(find.text('Show photo/video release consent checkbox'), findsNothing);
      expect(find.text('Turn off if your privacy policy already covers this consent.'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}
