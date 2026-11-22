// Tests for the java.text.DecimalFormat shim DecimalFormat; no Kotlin counterpart.
// Expected strings were produced by java.text.DecimalFormat on JDK 17 (Ruling R6: HALF_EVEN on the exact binary value).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/decimal_format.dart';

void main() {
  group('DecimalFormat (brief cases)', () {
    test('###,###,###,##0.0', () {
      expect(DecimalFormat('###,###,###,##0.0').format(1234.56), '1,234.6');
      expect(DecimalFormat('###,###,###,##0.0').format(0), '0.0');
    });

    test('###,###,###,##0 groups a negative int', () {
      expect(DecimalFormat('###,###,###,##0').format(-1234567), '-1,234,567');
    });

    test('#.## rounds 1.005 HALF_EVEN on the binary value (below the tie) and drops trailing zeros', () {
      expect(DecimalFormat('#.##').format(1.005), '1');
    });
  });

  group('DecimalFormat HALF_EVEN', () {
    test('exact binary ties round to even', () {
      expect(DecimalFormat('#.##').format(0.125), '0.12');
      expect(DecimalFormat('#.##').format(0.375), '0.38');
      expect(DecimalFormat('#').format(2.5), '2');
      expect(DecimalFormat('#').format(3.5), '4');
      expect(DecimalFormat('#').format(0.5), '0');
      expect(DecimalFormat('###,###,###,##0').format(1.5), '2');
      expect(DecimalFormat('###,###,###,##0').format(-2.5), '-2');
      expect(DecimalFormat('###,###,###,##0.000').format(-1.0625), '-1.062');
      expect(DecimalFormat('###,###,###,##0.00').format(1.125), '1.12');
      expect(DecimalFormat('###,###,##0.0').format(12.25), '12.2');
    });

    test('decimal ties that are not binary ties round by the binary value', () {
      expect(DecimalFormat('###,###,##0.#').format(0.15), '0.1'); // 0.1499999…
      expect(DecimalFormat('###,###,##0.#').format(0.05), '0.1'); // 0.0500000…3
      expect(DecimalFormat('###,###,###,##0.00').format(0.005), '0.01');
      expect(DecimalFormat('###,###,###,##0.00').format(2.675), '2.67');
      expect(DecimalFormat('###,###,##0.0').format(12.35), '12.3');
      expect(DecimalFormat('#.#').format(0.95), '0.9');
      expect(DecimalFormat('#.#').format(9.95), '9.9');
      expect(DecimalFormat('###,###,###,##0.000').format(1.0005), '1.000');
    });

    test('rounding carries into the integer part and new groups', () {
      expect(DecimalFormat('###,###,##0.#').format(999.95), '1,000');
      expect(DecimalFormat('#,##0.0').format(-999.96), '-1,000.0');
      expect(DecimalFormat('#').format(0.6), '1');
      expect(DecimalFormat('###,###,###,##0').format(123456789012345.6), '123,456,789,012,346');
    });

    test('a value just above a decimal tie rounds up by its binary value (see MIGRATION.md)', () {
      // 0.0005 is stored as 0.000500000000000000010…, so HALF_EVEN on the exact binary value rounds up. The JDK
      // prints '0.000' here and Android's ICU (HALF_EVEN on the shortest decimal) also differs on such inputs;
      // the port deliberately keeps the exact-binary rule.
      expect(DecimalFormat('###,###,###,##0.000').format(0.0005), '0.001');
    });

    test('values far below the last fraction digit become zero', () {
      expect(DecimalFormat('#.##').format(0.001), '0');
      expect(DecimalFormat('#.#').format(0.04), '0');
      expect(DecimalFormat('###,###,###,##0.0').format(1e-7), '0.0');
      expect(DecimalFormat('###,###,###,##0.0').format(1e-20), '0.0');
      expect(DecimalFormat('###,###,###,##0.0').format(5e-324), '0.0');
    });
  });

  group('DecimalFormat pattern family', () {
    test('a pattern without 0 but with a decimal point prints one integer digit', () {
      expect(DecimalFormat('#.##').format(0.46), '0.46');
      expect(DecimalFormat('#.#').format(-0.46), '-0.5');
      expect(DecimalFormat('###,###,##0.#').format(0.5), '0.5');
    });

    test('min and max fraction digits', () {
      expect(DecimalFormat('###,###,###,##0.0').format(1234.0), '1,234.0');
      expect(DecimalFormat('###,###,###,##0.0').format(5), '5.0');
      expect(DecimalFormat('###,###,###,##0.0000000000').format(0.1), '0.1000000000');
      expect(DecimalFormat('#,##0.###').format(1234567.1235), '1,234,567.123');
      expect(DecimalFormat('###,###,##0.#').format(1234567.85), '1,234,567.9');
    });

    test('grouping size comes from the last group; no comma means no grouping', () {
      expect(DecimalFormat('#,##0').format(1234567.0), '1,234,567');
      expect(DecimalFormat('#,##,###').format(1234567), '1,234,567');
      expect(DecimalFormat('#').format(-1234567), '-1234567');
      expect(DecimalFormat('#.#').format(-1234567), '-1234567');
    });

    test('ints format exactly (Java format(long))', () {
      // Ints beyond 2^53 are not exact JavaScript numbers (and such a literal does not compile for the web).
      if (!kIsWeb) {
        expect(
          DecimalFormat('###,###,###,##0').format(int.parse('123456789012345678')),
          '123,456,789,012,345,678',
        );
        expect(DecimalFormat('#').format(int.parse('-9223372036854775808')), '-9223372036854775808');
      }
      expect(DecimalFormat('#').format(0), '0');
    });

    test('large doubles print their shortest digits followed by zeros', () {
      expect(DecimalFormat('###,###,###,##0').format(1e16), '10,000,000,000,000,000');
      expect(DecimalFormat('###,###,###,##0').format(1e20), '100,000,000,000,000,000,000');
      expect(DecimalFormat('###,###,###,##0').format(1e21), '1,000,000,000,000,000,000,000');
      expect(
        DecimalFormat('###,###,###,##0').format(123456789012345678901234567890.0),
        '123,456,789,012,345,680,000,000,000,000',
      );
      final max = DecimalFormat('###,###,###,##0.0').format(1.7976931348623157e308);
      expect(max, startsWith('179,769,313,486,231,570,000,'));
      expect(max, endsWith(',000.0'));
      expect(max.replaceAll(',', '').length, 309 + 2);
    });

    test('Float values widened to double keep their binary value', () {
      // Kotlin formatters pass Float values: 12.34f == 12.34000015258789, 1234.4f == 1234.4000244140625.
      expect(DecimalFormat('###,###,###,##0.0').format(12.34000015258789), '12.3');
      expect(DecimalFormat('###,###,###,##0.00').format(1234.4000244140625), '1,234.40');
    });

    test('unsupported patterns throw', () {
      expect(() => DecimalFormat('0.0%'), throwsArgumentError);
      expect(() => DecimalFormat('0.0.0'), throwsArgumentError);
    });

    test('patterns Java rejects as malformed throw', () {
      expect(() => DecimalFormat('#.#0'), throwsArgumentError);
      expect(() => DecimalFormat('0.#0'), throwsArgumentError);
      expect(() => DecimalFormat('#0#.#'), throwsArgumentError);
      expect(() => DecimalFormat('0#'), throwsArgumentError);
      expect(() => DecimalFormat('##0.0#0'), throwsArgumentError);
      expect(() => DecimalFormat('#,##0,'), throwsArgumentError);
    });

    test('minimumFractionDigits and maximumFractionDigits follow the pattern (Java getters)', () {
      final percent = DecimalFormat('###,###,##0.0');
      expect(percent.minimumFractionDigits, 1);
      expect(percent.maximumFractionDigits, 1);
      final plain = DecimalFormat('###,###,##0.#');
      expect(plain.minimumFractionDigits, 0);
      expect(plain.maximumFractionDigits, 1);
      expect(DecimalFormat('###,###,###,##0').maximumFractionDigits, 0);
      expect(DecimalFormat('#.##').minimumFractionDigits, 0);
      expect(DecimalFormat('#.##').maximumFractionDigits, 2);
      expect(DecimalFormat('.##').minimumFractionDigits, 1);
      expect(DecimalFormat('0.00#').minimumFractionDigits, 2);
      expect(DecimalFormat('0.00#').maximumFractionDigits, 3);
    });
  });

  group('DecimalFormat signs and special values', () {
    test('negative values that round to zero keep the minus sign, like Java', () {
      expect(DecimalFormat('#.#').format(-0.01), '-0');
      expect(DecimalFormat('###,###,##0').format(-0.4), '-0');
      expect(DecimalFormat('###,###,##0.0').format(-0.04), '-0.0');
      expect(DecimalFormat('0.00').format(-0.001), '-0.00');
      expect(DecimalFormat('#').format(-0.5), '-0');
    });

    test('negative zero prints -0, positive zero prints 0', () {
      expect(DecimalFormat('#.#').format(-0.0), '-0');
      expect(DecimalFormat('#.#').format(0.0), '0');
    });

    test('NaN and infinities', () {
      expect(DecimalFormat('###,###,##0.#').format(double.nan), 'NaN');
      expect(DecimalFormat('###,###,##0.#').format(double.infinity), '∞');
      expect(DecimalFormat('###,###,##0.#').format(double.negativeInfinity), '-∞');
    });
  });
}
