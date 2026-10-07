import 'package:flutter_test/flutter_test.dart';
import 'package:eventflow/core/models.dart';

void main() {
  group('Attendee GDPR and Consent Fields', () {
    test('Attendee default values are correct', () {
      final attendee = Attendee(
        id: 'att-1',
        eventId: 'event-1',
        orgId: 'org-1',
        firstName: 'Mario',
        lastName: 'Rossi',
        email: 'mario.rossi@example.com',
        qrCode: 'qr-12345',
      );

      expect(attendee.privacyAccepted, isTrue);
      expect(attendee.marketingConsent, isFalse);
      expect(attendee.photoConsent, isNull);
    });

    test('Attendee toFirestore maps consent fields properly', () {
      final now = DateTime.now();
      final attendee = Attendee(
        id: 'att-2',
        eventId: 'event-1',
        orgId: 'org-1',
        firstName: 'Luigi',
        lastName: 'Verdi',
        email: 'luigi.verdi@example.com',
        qrCode: 'qr-67890',
        privacyAccepted: true,
        privacyAcceptedAt: now,
        marketingConsent: true,
        marketingConsentAt: now,
        photoConsent: true,
        photoConsentAt: now,
      );

      final map = attendee.toFirestore();
      expect(map['privacyAccepted'], isTrue);
      expect(map['privacyAcceptedAt'], isNotNull);
      expect(map['marketingConsent'], isTrue);
      expect(map['marketingConsentAt'], isNotNull);
      expect(map['photoConsent'], isTrue);
      expect(map['photoConsentAt'], isNotNull);
    });

    test('Attendee copyWith updates consent fields properly', () {
      final attendee = Attendee(
        id: 'att-3',
        eventId: 'event-1',
        orgId: 'org-1',
        firstName: 'Anna',
        lastName: 'Bianchi',
        email: 'anna.bianchi@example.com',
        qrCode: 'qr-99999',
        marketingConsent: false,
        photoConsent: null,
      );

      final updated = attendee.copyWith(
        marketingConsent: true,
        photoConsent: false,
      );

      expect(updated.marketingConsent, isTrue);
      expect(updated.photoConsent, isFalse);
      expect(updated.firstName, equals('Anna'));
    });
  });
}
