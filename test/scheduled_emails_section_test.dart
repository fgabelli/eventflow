import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/features/events/presentation/widgets/scheduled_emails_section.dart';

const _testDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _wrapWithApp(Widget child, {Locale locale = const Locale('it')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('it'), Locale('en')],
    localizationsDelegates: _testDelegates,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('EventModel scheduled email custom messages', () {
    test('toFirestore, fromMap, and copyWith preserve custom messages', () {
      final event = EventModel(
        id: 'ev-1',
        orgId: 'org-1',
        title: 'Conferenza 2026',
        date: DateTime(2026, 11, 20, 10, 0),
        reminderEnabled: true,
        reminderDaysBefore: 3,
        reminderCustomMessage: 'Portare il badge.',
        postEventEmailEnabled: true,
        thankYouCustomMessage: 'Grazie per la presenza!',
      );

      final map = event.toFirestore();
      expect(map['reminderCustomMessage'], equals('Portare il badge.'));
      expect(map['thankYouCustomMessage'], equals('Grazie per la presenza!'));

      final restored = EventModel.fromMap(map, id: 'ev-1');
      expect(restored.reminderCustomMessage, equals('Portare il badge.'));
      expect(restored.thankYouCustomMessage, equals('Grazie per la presenza!'));

      final updated = restored.copyWith(thankYouCustomMessage: 'Nuovo messaggio');
      expect(updated.reminderCustomMessage, equals('Portare il badge.'));
      expect(updated.thankYouCustomMessage, equals('Nuovo messaggio'));
    });
  });

  group('ScheduledEmailsSection UI gating & localization', () {
    testWidgets('Free plan disables switches, shows PRO badges and Pro hint (IT)', (tester) async {
      final remCtrl = TextEditingController();
      final tyCtrl = TextEditingController();
      addTearDown(() {
        remCtrl.dispose();
        tyCtrl.dispose();
      });

      await tester.pumpWidget(
        _wrapWithApp(
          ScheduledEmailsSection(
            eventId: 'ev-free',
            plan: SubscriptionPlan.free,
            canManageEmails: true,
            reminderEnabled: true, // even if true in state, Free displays off & disabled
            onReminderEnabledChanged: (_) {},
            reminderDaysBefore: 1,
            onReminderDaysBeforeChanged: (_) {},
            reminderCustomMessageController: remCtrl,
            postEventEmailEnabled: true,
            onPostEventEmailEnabledChanged: (_) {},
            thankYouCustomMessageController: tyCtrl,
            notifyOrganizer: false,
            onNotifyOrganizerChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, equals(3));
      for (final sw in switches) {
        expect(sw.onChanged, isNull);
        expect(sw.value, isFalse);
      }

      expect(find.text('PRO'), findsNWidgets(3));
      expect(find.text('Disponibile dal piano Pro'), findsNWidgets(3));
      expect(
        find.text("Parte da sola il giorno dopo l'evento, a chi ha fatto check-in."),
        findsOneWidget,
      );
      expect(find.text('Anteprima'), findsNWidgets(2));
      expect(find.text('Invia una prova a me'), findsNothing);
    });

    testWidgets('Pro plan enables switches, custom message fields, preview and test buttons (IT & EN)', (tester) async {
      final remCtrl = TextEditingController(text: 'Msg reminder');
      final tyCtrl = TextEditingController(text: 'Msg grazie');
      addTearDown(() {
        remCtrl.dispose();
        tyCtrl.dispose();
      });

      bool reminderVal = true;
      bool thankYouVal = true;

      await tester.pumpWidget(
        _wrapWithApp(
          StatefulBuilder(
            builder: (ctx, setState) => ScheduledEmailsSection(
              eventId: 'ev-pro',
              plan: SubscriptionPlan.pro,
              canManageEmails: true,
              reminderEnabled: reminderVal,
              onReminderEnabledChanged: (v) => setState(() => reminderVal = v),
              reminderDaysBefore: 1,
              onReminderDaysBeforeChanged: (_) {},
              reminderCustomMessageController: remCtrl,
              postEventEmailEnabled: thankYouVal,
              onPostEventEmailEnabledChanged: (v) => setState(() => thankYouVal = v),
              thankYouCustomMessageController: tyCtrl,
              notifyOrganizer: true,
              onNotifyOrganizerChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      for (final sw in switches) {
        expect(sw.onChanged, isNotNull);
        expect(sw.value, isTrue);
      }

      expect(find.text('Disponibile dal piano Pro'), findsNothing);
      expect(find.text('Messaggio personale (facoltativo)'), findsNWidgets(2));
      expect(find.text('Anteprima'), findsNWidgets(2));
      expect(find.text('Invia una prova a me'), findsNWidgets(2));

      // Verify English strings as well
      await tester.pumpWidget(
        _wrapWithApp(
          ScheduledEmailsSection(
            eventId: 'ev-pro',
            plan: SubscriptionPlan.pro,
            canManageEmails: true,
            reminderEnabled: true,
            onReminderEnabledChanged: (_) {},
            reminderDaysBefore: 1,
            onReminderDaysBeforeChanged: (_) {},
            reminderCustomMessageController: remCtrl,
            postEventEmailEnabled: true,
            onPostEventEmailEnabledChanged: (_) {},
            thankYouCustomMessageController: tyCtrl,
            notifyOrganizer: true,
            onNotifyOrganizerChanged: (_) {},
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal message (optional)'), findsNWidgets(2));
      expect(find.text('Preview'), findsNWidgets(2));
      expect(find.text('Send test to me'), findsNWidgets(2));
      expect(
        find.text('Sent automatically the day after the event to checked-in attendees.'),
        findsOneWidget,
      );
    });
  });
}
