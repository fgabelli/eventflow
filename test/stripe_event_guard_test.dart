import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

void main() {
  group('Organization Stripe Connect status checks', () {
    test('hasActiveStripe is true only when paymentMode is standard and stripeChargesEnabled is true', () {
      final orgActive = Organization(
        id: 'org_1',
        name: 'Active Org',
        paymentMode: 'standard',
        stripeChargesEnabled: true,
        stripeConnectStatus: 'active',
        stripeConnectAccountId: 'acct_123',
      );
      expect(orgActive.hasActiveStripe, isTrue);

      final orgPending = Organization(
        id: 'org_2',
        name: 'Pending Org',
        paymentMode: 'standard',
        stripeChargesEnabled: false,
        stripeConnectStatus: 'pending',
      );
      expect(orgPending.hasActiveStripe, isFalse);

      final orgNoMode = Organization(
        id: 'org_3',
        name: 'Legacy Org',
        paymentMode: null,
        stripeChargesEnabled: true,
      );
      expect(orgNoMode.hasActiveStripe, isFalse);

      final orgDefault = Organization(
        id: 'org_4',
        name: 'Default Org',
      );
      expect(orgDefault.hasActiveStripe, isFalse);
      expect(orgDefault.stripeChargesEnabled, isFalse);
    });

    test('isStripePending is true for pending and pending_verification', () {
      final orgPending = Organization(
        id: 'org_1',
        name: 'Org 1',
        stripeConnectStatus: 'pending',
      );
      expect(orgPending.isStripePending, isTrue);

      final orgPendingVerif = Organization(
        id: 'org_2',
        name: 'Org 2',
        stripeConnectStatus: 'pending_verification',
      );
      expect(orgPendingVerif.isStripePending, isTrue);

      final orgActive = Organization(
        id: 'org_3',
        name: 'Org 3',
        stripeConnectStatus: 'active',
      );
      expect(orgActive.isStripePending, isFalse);

      final orgNone = Organization(
        id: 'org_4',
        name: 'Org 4',
        stripeConnectStatus: 'none',
      );
      expect(orgNone.isStripePending, isFalse);
    });

    test('toFirestore includes Stripe connect fields', () {
      final org = Organization(
        id: 'org_1',
        name: 'Test Org',
        paymentMode: 'standard',
        stripeConnectAccountId: 'acct_test',
        stripeConnectStatus: 'pending',
        stripeChargesEnabled: false,
      );
      final map = org.toFirestore();
      expect(map['paymentMode'], 'standard');
      expect(map['stripeConnectAccountId'], 'acct_test');
      expect(map['stripeConnectStatus'], 'pending');
      expect(map['stripeChargesEnabled'], isFalse);
    });
  });

  group('Stripe Event Guard Localizations', () {
    test('Italian localizations contain all required Stripe strings', () {
      final lIt = AppLocalizations(const Locale('it'));
      expect(lIt['stripe_connect_prompt'], 'Per vendere biglietti collega il tuo account Stripe');
      expect(lIt['stripe_complete_prompt'], 'Completa la configurazione di Stripe');
      expect(lIt['stripe_required_title'], 'Configurazione Stripe richiesta');
      expect(lIt['ticket_sales_not_active'], 'La vendita dei biglietti non è ancora attiva, riprova più tardi');
      expect(lIt['connect_stripe'], 'Collega Stripe');
      expect(lIt['stripe_complete_btn'], 'Completa');
    });

    test('English localizations contain all required Stripe strings', () {
      final lEn = AppLocalizations(const Locale('en'));
      expect(lEn['stripe_connect_prompt'], 'To sell tickets, connect your Stripe account');
      expect(lEn['stripe_complete_prompt'], 'Complete Stripe configuration');
      expect(lEn['stripe_required_title'], 'Stripe configuration required');
      expect(lEn['ticket_sales_not_active'], 'Ticket sales are not active yet, please try again later');
      expect(lEn['connect_stripe'], 'Connect Stripe');
      expect(lEn['stripe_complete_btn'], 'Complete');
    });
  });

  group('Buyer error mapping logic for inactive Stripe', () {
    String mapCheckoutError({
      required Map<String, dynamic> data,
      required AppLocalizations l,
    }) {
      final err = (data['error'] as String?) ?? '';
      final code = data['code'] as String?;
      final isStripeNotActive = code == 'stripe_not_configured' ||
          err.contains('Stripe') ||
          err.contains('Ricollega') ||
          err.contains('configurazione') ||
          err.toLowerCase().contains('charges');

      if (isStripeNotActive) {
        return l['ticket_sales_not_active'];
      }
      return data['error'] ?? l['payment_init_failed'];
    }

    test('maps organizer Stripe errors to buyer friendly message in IT and EN', () {
      final lIt = AppLocalizations(const Locale('it'));
      final lEn = AppLocalizations(const Locale('en'));

      final legacyPayload = {
        'error': 'Ricollega il tuo account Stripe dalle Impostazioni',
        'code': 'stripe_not_configured',
      };
      expect(mapCheckoutError(data: legacyPayload, l: lIt), 'La vendita dei biglietti non è ancora attiva, riprova più tardi');
      expect(mapCheckoutError(data: legacyPayload, l: lEn), 'Ticket sales are not active yet, please try again later');

      final pendingPayload = {
        'error': 'Completa la configurazione del tuo account Stripe per vendere biglietti',
        'code': 'stripe_not_configured',
      };
      expect(mapCheckoutError(data: pendingPayload, l: lIt), 'La vendita dei biglietti non è ancora attiva, riprova più tardi');

      final genericError = {
        'error': 'Email non valida',
      };
      expect(mapCheckoutError(data: genericError, l: lIt), 'Email non valida');
    });
  });

  group('Event publication guard rules', () {
    bool canPublish(EventModel event, Organization? org) {
      if (!event.isPaid) return true;
      if (org == null || !org.hasActiveStripe) return false;
      return true;
    }

    test('Free event can always be published even without Stripe', () {
      final freeEvent = EventModel(
        id: 'evt_free',
        orgId: 'org_1',
        title: 'Free Event',
        date: DateTime.now().add(const Duration(days: 5)),
        isPaid: false,
      );
      final orgWithoutStripe = Organization(id: 'org_1', name: 'Org Without Stripe');

      expect(canPublish(freeEvent, null), isTrue);
      expect(canPublish(freeEvent, orgWithoutStripe), isTrue);
    });

    test('Paid event cannot be published if Stripe is not active', () {
      final paidEvent = EventModel(
        id: 'evt_paid',
        orgId: 'org_1',
        title: 'Paid Event',
        date: DateTime.now().add(const Duration(days: 5)),
        isPaid: true,
        price: 15.0,
      );
      final orgPending = Organization(
        id: 'org_1',
        name: 'Pending Org',
        paymentMode: 'standard',
        stripeChargesEnabled: false,
        stripeConnectStatus: 'pending',
      );
      final orgActive = Organization(
        id: 'org_1',
        name: 'Active Org',
        paymentMode: 'standard',
        stripeChargesEnabled: true,
        stripeConnectStatus: 'active',
      );

      expect(canPublish(paidEvent, null), isFalse);
      expect(canPublish(paidEvent, orgPending), isFalse);
      expect(canPublish(paidEvent, orgActive), isTrue);
    });
  });
}
