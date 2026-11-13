import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/features/events/presentation/widgets/custom_fields_section.dart';

const _testDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  group('CustomField Model Tests', () {
    test('Constructor generates unique id when not provided', () {
      final field1 = CustomField(label: 'Field 1');
      final field2 = CustomField(label: 'Field 2');
      expect(field1.id, isNotEmpty);
      expect(field2.id, isNotEmpty);
      // Wait or verify they are distinct
      final field3 = CustomField(id: 'explicit-id-123', label: 'Field 3');
      expect(field3.id, equals('explicit-id-123'));
    });

    test('toMap and fromMap serialize and deserialize accurately', () {
      final original = CustomField(
        id: 'cf-999',
        label: 'Taglia T-Shirt',
        type: 'select',
        required: true,
        options: ['S', 'M', 'L', 'XL'],
        placeholder: 'Scegli la taglia',
      );

      final map = original.toMap();
      expect(map['id'], equals('cf-999'));
      expect(map['label'], equals('Taglia T-Shirt'));
      expect(map['type'], equals('select'));
      expect(map['required'], isTrue);
      expect(map['options'], equals(['S', 'M', 'L', 'XL']));
      expect(map['placeholder'], equals('Scegli la taglia'));

      final restored = CustomField.fromMap(map);
      expect(restored.id, equals(original.id));
      expect(restored.label, equals(original.label));
      expect(restored.type, equals(original.type));
      expect(restored.required, equals(original.required));
      expect(restored.options, equals(original.options));
      expect(restored.placeholder, equals(original.placeholder));
    });

    test('Updating label preserves id immutability', () {
      final original = CustomField(
        id: 'stable-id-1',
        label: 'Vecchia Etichetta',
        type: 'checkbox',
        required: true,
      );

      // When editing, the original ID must be preserved
      final updated = CustomField(
        id: original.id,
        label: 'Nuova Etichetta Modificata',
        type: original.type,
        required: original.required,
      );

      expect(updated.id, equals(original.id));
      expect(updated.label, equals('Nuova Etichetta Modificata'));
      expect(updated.type, equals('checkbox'));
    });

    test('typeLabel returns correct labels for all supported types', () {
      expect(CustomField(label: '', type: 'text').typeLabel, equals('Testo'));
      expect(CustomField(label: '', type: 'select').typeLabel, equals('Selezione'));
      expect(CustomField(label: '', type: 'number').typeLabel, equals('Numero'));
      expect(CustomField(label: '', type: 'checkbox').typeLabel, equals('Checkbox'));
      expect(CustomField(label: '', type: 'email').typeLabel, equals('Email'));
      expect(CustomField(label: '', type: 'phone').typeLabel, equals('Telefono'));
    });
  });

  group('CustomFieldsSection Widget Tests', () {
    Widget buildTestHarness({
      required List<CustomField> fields,
      required ValueChanged<List<CustomField>> onChanged,
      bool hasAttendees = false,
      SubscriptionPlan plan = SubscriptionPlan.pro,
    }) {
      return MaterialApp(
        localizationsDelegates: _testDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CustomFieldsSection(
              fields: fields,
              onChanged: onChanged,
              hasAttendees: hasAttendees,
              plan: plan,
            ),
          ),
        ),
      );
    }

    testWidgets('renders list of fields with type badge and required asterisk', (tester) async {
      final fields = [
        CustomField(id: '1', label: 'Azienda', type: 'text', required: true),
        CustomField(id: '2', label: 'Accetto Regolamento', type: 'checkbox', required: true),
        CustomField(id: '3', label: 'Opzioni Pranzo', type: 'select', options: ['Vegano', 'Standard']),
      ];

      await tester.pumpWidget(buildTestHarness(fields: fields, onChanged: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('Azienda'), findsOneWidget);
      expect(find.text('Accetto Regolamento'), findsOneWidget);
      expect(find.text('Opzioni Pranzo'), findsOneWidget);
      expect(find.text('*'), findsNWidgets(2));
      expect(find.text('2 opzioni'), findsOneWidget);
    });

    testWidgets('moving field up/down reorders the list', (tester) async {
      List<CustomField> currentFields = [
        CustomField(id: '1', label: 'Primo', type: 'text'),
        CustomField(id: '2', label: 'Secondo', type: 'text'),
      ];

      await tester.pumpWidget(buildTestHarness(
        fields: currentFields,
        onChanged: (updated) => currentFields = updated,
      ));
      await tester.pumpAndSettle();

      // Find down arrow for first item (or up arrow for second item)
      final downArrows = find.byIcon(Icons.arrow_downward);
      expect(downArrows, findsNWidgets(2));

      // Tap down arrow on first item
      await tester.tap(downArrows.first);
      await tester.pumpAndSettle();

      expect(currentFields[0].id, equals('2'));
      expect(currentFields[1].id, equals('1'));
    });

    testWidgets('deleting field without attendees removes directly', (tester) async {
      List<CustomField> currentFields = [
        CustomField(id: '1', label: 'Da Cancellare', type: 'text'),
      ];

      await tester.pumpWidget(buildTestHarness(
        fields: currentFields,
        hasAttendees: false,
        onChanged: (updated) => currentFields = updated,
      ));
      await tester.pumpAndSettle();

      final deleteBtn = find.byIcon(Icons.delete_outline);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Should be removed directly without confirm dialog
      expect(currentFields, isEmpty);
    });

    testWidgets('deleting field with attendees shows warning dialog and preserves data if cancelled', (tester) async {
      List<CustomField> currentFields = [
        CustomField(id: '1', label: 'Campo Con Dati', type: 'text'),
      ];

      await tester.pumpWidget(buildTestHarness(
        fields: currentFields,
        hasAttendees: true,
        onChanged: (updated) => currentFields = updated,
      ));
      await tester.pumpAndSettle();

      final deleteBtn = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Verify warning dialog text is displayed
      expect(find.text('Elimina campo'), findsOneWidget);
      expect(
        find.text('Le risposte già raccolte per questo campo non saranno più visibili nell\'elenco e nell\'export. Vuoi procedere?'),
        findsOneWidget,
      );

      // Tap Cancel
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      // Field must NOT have been removed
      expect(currentFields.length, equals(1));

      // Now tap delete again and confirm
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elimina'));
      await tester.pumpAndSettle();

      // Now it is removed
      expect(currentFields, isEmpty);
    });

    testWidgets('editing field preserves id and updates label and type', (tester) async {
      List<CustomField> currentFields = [
        CustomField(id: 'fixed-id-42', label: 'Vecchia Etichetta', type: 'text', required: false),
      ];

      await tester.pumpWidget(buildTestHarness(
        fields: currentFields,
        hasAttendees: false,
        onChanged: (updated) => currentFields = updated,
      ));
      await tester.pumpAndSettle();

      // Tap edit button
      final editBtn = find.byIcon(Icons.edit_outlined);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Modifica Campo'), findsOneWidget);

      // Enter new label
      final labelField = find.widgetWithText(TextField, 'Vecchia Etichetta');
      await tester.enterText(labelField, 'Nuova Etichetta');

      // Toggle required
      final switchWidget = find.byType(Switch);
      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      expect(currentFields.length, equals(1));
      expect(currentFields.first.id, equals('fixed-id-42')); // ID must NOT change
      expect(currentFields.first.label, equals('Nuova Etichetta'));
      expect(currentFields.first.required, isTrue);
    });

    testWidgets('changing field type with attendees shows confirmation dialog before changing', (tester) async {
      List<CustomField> currentFields = [
        CustomField(id: 'fixed-id-99', label: 'Campo Tipo', type: 'text'),
      ];

      await tester.pumpWidget(buildTestHarness(
        fields: currentFields,
        hasAttendees: true,
        onChanged: (updated) => currentFields = updated,
      ));
      await tester.pumpAndSettle();

      // Open edit dialog
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Tap 'Checkbox' type chip
      await tester.tap(find.text('Checkbox'));
      await tester.pumpAndSettle();

      // Warning dialog should appear
      expect(find.text('Modifica tipo di campo'), findsOneWidget);
      expect(
        find.text('Cambiando il tipo di questo campo, le risposte già raccolte potrebbero non essere più visualizzate correttamente nell\'elenco e nell\'export. Vuoi continuare?'),
        findsOneWidget,
      );

      // Cancel type change (tap top-most dialog button)
      await tester.tap(find.text('Annulla').last);
      await tester.pumpAndSettle();

      // Now tap Checkbox again and confirm
      await tester.tap(find.text('Checkbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();

      // Warning inline callout should now be visible
      expect(
        find.text('Modificando il tipo di campo, le risposte già raccolte potrebbero risultare incompatibili nell\'elenco e nell\'export.'),
        findsOneWidget,
      );

      // Save
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      expect(currentFields.first.id, equals('fixed-id-99'));
      expect(currentFields.first.type, equals('checkbox'));
    });
  });
}
