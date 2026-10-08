import 'package:flutter_test/flutter_test.dart';
import 'package:second_practice/models/pricing_quote.dart';

void main() {
  test(
    'price includes service, urgency and all preparation before discount',
    () {
      final quote = PricingQuote.calculate(
        base: 1000,
        urgencyLevel: 3,
        preparationMinutes: 45,
        discountPercent: 10,
      );
      expect(quote.urgency, 500);
      expect(quote.preparation, 450);
      expect(quote.discount, 195);
      expect(quote.total, 1755);
    },
  );
  test('normal urgency and zero preparation do not add fees', () {
    expect(
      PricingQuote.calculate(
        base: 501,
        urgencyLevel: 1,
        preparationMinutes: 0,
      ).total,
      501,
    );
  });
  test('money is rounded to whole rubles at each charge', () {
    final quote = PricingQuote.calculate(
      base: 503,
      urgencyLevel: 2,
      preparationMinutes: 1,
      discountPercent: 30,
    );
    expect(quote.urgency, 101);
    expect(quote.discount, 184);
    expect(quote.total, 430);
    expect(PricingQuote.fromJson(quote.toJson()).total, 430);
  });
  test('discount limits and urgency cannot be bypassed', () {
    for (final discount in [-1, 31]) {
      expect(
        () => PricingQuote.calculate(
          base: 1000,
          urgencyLevel: 1,
          preparationMinutes: 0,
          discountPercent: discount,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => PricingQuote.calculate(
        base: 1000,
        urgencyLevel: 4,
        preparationMinutes: 0,
      ),
      throwsArgumentError,
    );
  });
}
