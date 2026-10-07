import 'package:flutter_test/flutter_test.dart';
import 'package:second_practice/validation/validators.dart';

void main() {
  test('required text rejects empty and whitespace values', () {
    for (final value in [null, '', '   ']) {
      expect(Validators.text(value), isNotNull);
    }
    expect(Validators.text('Услуга'), isNull);
  });
  test('text length is checked after trimming', () {
    expect(Validators.text(' ab ', min: 3), isNotNull);
    expect(Validators.text(' abc ', min: 3, max: 3), isNull);
    expect(Validators.text('abcd', max: 3), isNotNull);
  });
  test('email requires a domain and rejects spaces', () {
    expect(Validators.email('client@alibi.example'), isNull);
    for (final value in ['client', 'client@alibi', 'a b@alibi.example']) {
      expect(Validators.email(value), isNotNull);
    }
  });
  test('integer accepts boundaries and rejects fractions', () {
    expect(Validators.integer('0', min: 0, max: 3), isNull);
    expect(Validators.integer('3', min: 0, max: 3), isNull);
    for (final value in ['-1', '4', '1.5', 'abc']) {
      expect(Validators.integer(value, min: 0, max: 3), isNotNull);
    }
  });
  test('date distinguishes leap years and normalized invalid dates', () {
    expect(Validators.date('2024-02-29'), isNull);
    for (final value in [
      '2025-02-29',
      '2026-04-31',
      '1899-01-01',
      '01.01.2026',
    ]) {
      expect(Validators.date(value), isNotNull);
    }
  });
  test('phone requires enough digits and rejects letters', () {
    expect(Validators.phone('+7 900 123-45-67'), isNull);
    expect(Validators.phone('+7 123'), isNotNull);
    expect(Validators.phone('+7 900 abc-45-67'), isNotNull);
  });
  test('identifier requires the correct prefix and digit count', () {
    expect(Validators.identifier('ALI-0001', 'ALI'), isNull);
    expect(Validators.identifier('CARD-0001', 'ALI'), isNotNull);
    expect(Validators.identifier('ALI-001', 'ALI'), isNotNull);
  });
  test('selection accepts only available linked records', () {
    expect(Validators.selection(1, [1, 2]), isNull);
    expect(Validators.selection(null, [1, 2]), isNotNull);
    expect(Validators.selection(3, [1, 2]), isNotNull);
  });
  test('multiple selection rejects empty and missing linked records', () {
    expect(Validators.multiple([1, 2], [1, 2]), isNull);
    expect(Validators.multiple([], [1, 2]), isNotNull);
    expect(Validators.multiple([1, 3], [1, 2]), isNotNull);
  });
}
