import 'package:flutter_test/flutter_test.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';

void main() {
  group('Promotions & Vouchers Unit Tests', () {
    test('PromotionModel serialization and getters', () {
      final now = DateTime.now();
      final expDate = now.add(const Duration(days: 30));

      final promo = PromotionModel(
        id: 'promo_123',
        orgId: 'org_abc',
        title: 'Offerta 2x1 Palestra FitCenter',
        partnerName: 'Palestra FitCenter',
        codePrefix: 'FIT',
        currentSequence: 25,
        totalVouchers: 25,
        claimedCount: 5,
        redeemedCount: 2,
        expirationDate: expDate,
        offerType: OfferType.twoForOne,
        paymentMethod: PromotionPaymentMethod.atVenue,
        status: PromotionStatus.active,
      );

      expect(promo.isExpired, isFalse);
      expect(promo.isActive, isTrue);
      expect(promo.isTwoForOne, isTrue);
      expect(promo.availableCount, equals(20));
      expect(promo.codePrefix, equals('FIT'));

      final firestoreMap = promo.toFirestore();
      expect(firestoreMap['title'], equals('Offerta 2x1 Palestra FitCenter'));
      expect(firestoreMap['partnerName'], equals('Palestra FitCenter'));
      expect(firestoreMap['codePrefix'], equals('FIT'));
      expect(firestoreMap['offerType'], equals('twoForOne'));
      expect(firestoreMap['paymentMethod'], equals('atVenue'));
    });

    test('VoucherModel sequence code formatting and status flow', () {
      final prefix = 'SPA';
      const quantity = 10;
      final vouchers = <VoucherModel>[];

      for (int i = 1; i <= quantity; i++) {
        final codeNumber = i.toString().padLeft(4, '0');
        final code = '$prefix-$codeNumber';
        vouchers.add(
          VoucherModel(
            id: 'org_123_$code',
            promoId: 'promo_123',
            orgId: 'org_123',
            code: code,
            sequenceNumber: i,
            status: VoucherStatus.available,
          ),
        );
      }

      expect(vouchers.length, equals(10));
      expect(vouchers.first.code, equals('SPA-0001'));
      expect(vouchers.last.code, equals('SPA-0010'));
      expect(vouchers.first.isAvailable, isTrue);

      // Simulate customer claim
      final claimedVoucher = vouchers.first.copyWith(
        status: VoucherStatus.claimed,
        claimedAt: DateTime.now(),
        claimedFirstName: 'Mario',
        claimedLastName: 'Rossi',
        claimedEmail: 'mario.rossi@example.com',
        claimedPhone: '+393331234567',
        paymentStatus: VoucherPaymentStatus.pending,
      );

      expect(claimedVoucher.isClaimed, isTrue);
      expect(claimedVoucher.claimedFullName, equals('Mario Rossi'));
      expect(claimedVoucher.claimedEmail, equals('mario.rossi@example.com'));

      // Simulate venue redemption
      final redeemedVoucher = claimedVoucher.copyWith(
        status: VoucherStatus.redeemed,
        redeemedAt: DateTime.now(),
        redeemedByUserId: 'receptionist_1',
        paymentStatus: VoucherPaymentStatus.paidAtVenue,
      );

      expect(redeemedVoucher.isRedeemed, isTrue);
      expect(redeemedVoucher.paymentStatus, equals(VoucherPaymentStatus.paidAtVenue));
    });

    test('SubscriptionPlan promotion limits', () {
      expect(SubscriptionPlan.free.maxActivePromotions, equals(1));
      expect(SubscriptionPlan.free.maxVouchersPerPromotion, equals(25));
      expect(SubscriptionPlan.free.canOnlinePromotionPayment, isFalse);

      expect(SubscriptionPlan.pro.maxActivePromotions, equals(5));
      expect(SubscriptionPlan.pro.maxVouchersPerPromotion, equals(250));
      expect(SubscriptionPlan.pro.canOnlinePromotionPayment, isTrue);

      expect(SubscriptionPlan.business.isUnlimitedPromotions, isTrue);
      expect(SubscriptionPlan.business.isUnlimitedVouchers, isTrue);
      expect(SubscriptionPlan.business.canOnlinePromotionPayment, isTrue);
    });
  });
}
