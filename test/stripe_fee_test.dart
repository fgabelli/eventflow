import 'package:flutter_test/flutter_test.dart';
import 'package:eventflow/core/constants/app_constants.dart';

void main() {
  group('StripeFeeHelper Unit Tests', () {
    test('estimateStripeFeeCents for 20.00 EUR (2000 cents)', () {
      // 2000 * 0.015 = 30 + 25 = 55 cents
      final feeCents = StripeFeeHelper.estimateStripeFeeCents(2000);
      expect(feeCents, equals(55));
    });

    test('estimateStripeFeeCents for 10.00 EUR (1000 cents)', () {
      // 1000 * 0.015 = 15 + 25 = 40 cents
      final feeCents = StripeFeeHelper.estimateStripeFeeCents(1000);
      expect(feeCents, equals(40));
    });

    test('estimateStripeFeeCents for 50.00 EUR (5000 cents)', () {
      // 5000 * 0.015 = 75 + 25 = 100 cents (1.00 EUR)
      final feeCents = StripeFeeHelper.estimateStripeFeeCents(5000);
      expect(feeCents, equals(100));
    });

    test('estimateStripeFeeEur and estimateNetEur for 20 EUR', () {
      final feeEur = StripeFeeHelper.estimateStripeFeeEur(20.0);
      final netEur = StripeFeeHelper.estimateNetEur(20.0);
      expect(feeEur, equals(0.55));
      expect(netEur, closeTo(19.45, 0.001));
    });

    test('estimateStripeFeeCents handles 0 and negative values safely', () {
      expect(StripeFeeHelper.estimateStripeFeeCents(0), equals(0));
      expect(StripeFeeHelper.estimateStripeFeeCents(-100), equals(0));
      expect(StripeFeeHelper.estimateStripeFeeEur(0), equals(0.0));
      expect(StripeFeeHelper.estimateNetEur(0), equals(0.0));
    });
  });
}
