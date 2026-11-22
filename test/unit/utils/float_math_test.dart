// Tests for the Kotlin Float emulation helpers (lib/src/utils/float_math.dart); no Kotlin counterpart.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/utils/float_math.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

void main() {
  test('toKotlinFloat rounds to the nearest Float', () {
    expect(toKotlinFloat(0.1), 0.10000000149011612);
    expect(toKotlinFloat(1.5), 1.5);
    expect(toKotlinFloat(1e-50), 0);
    expect(toKotlinFloat(1e39), double.infinity);
    expect(toKotlinFloat(-1e39), double.negativeInfinity);
    expect(toKotlinFloat(double.nan), isNaN);
  });

  test('kotlinFloatToInt truncates and saturates like Float.toInt()', () {
    expect(kotlinFloatToInt(2.9), 2);
    expect(kotlinFloatToInt(-2.9), -2);
    expect(kotlinFloatToInt(double.nan), 0);
    expect(kotlinFloatToInt(double.infinity), 2147483647);
    expect(kotlinFloatToInt(double.negativeInfinity), -2147483648);
    expect(kotlinFloatToInt(3e9), 2147483647);
    expect(kotlinFloatToInt(-3e9), -2147483648);
  });

  test(
    'kotlinFloatOverflow keeps in-range values and overflows like a Float beyond the Float range',
    () {
      expect(kotlinFloatOverflow(0.1), 0.1);
      expect(kotlinFloatOverflow(-7244926976.5), -7244926976.5);
      expect(kotlinFloatOverflow(kotlinFloatMaxValue), kotlinFloatMaxValue);
      expect(kotlinFloatOverflow(2 * kotlinFloatMaxValue), double.infinity);
      expect(
        kotlinFloatOverflow(-2 * kotlinFloatMaxValue),
        double.negativeInfinity,
      );
      // Within half a Float ulp above Float.MAX_VALUE the value rounds back to Float.MAX_VALUE.
      expect(
        kotlinFloatOverflow(kotlinFloatMaxValue * (1 + 1e-9)),
        kotlinFloatMaxValue,
      );
      expect(kotlinFloatOverflow(double.infinity), double.infinity);
      expect(kotlinFloatOverflow(double.nan), isNaN);
    },
  );
  test('kotlinLog10 is exact at powers of ten like Math.log10', () {
    for (var n = -20; n <= 22; n++) {
      final x = double.parse('1e$n');
      expect(kotlinLog10(x), n.toDouble(), reason: '1e$n');
    }
    expect(kotlinLog10(2), closeTo(0.3010299956639812, 1e-15));
    expect(kotlinLog10(0), double.negativeInfinity);
    expect(kotlinLog10(-1), isNaN);
    expect(kotlinLog10(double.nan), isNaN);
    expect(kotlinLog10(double.infinity), double.infinity);
  });

  group('device px grid', () {
    tearDown(() => Utils.devicePixelRatio = 1.0);

    test('at 1.0 the helpers round whole logical px', () {
      expect(floorToDevicePx(2.7), 2);
      expect(ceilToDevicePx(2.2), 3);
      expect(truncateToDevicePx(-2.7), -2);
      expect(roundToDevicePx(2.5), 3);
      expect(roundToDevicePx(-2.5), -2);
    });

    test('at 2.625 they round on the device grid', () {
      Utils.devicePixelRatio = 2.625;
      // 7.207 logical px is 18.92 device px.
      expect(floorToDevicePx(7.207) * 2.625, closeTo(18, 1e-9));
      expect(ceilToDevicePx(7.207) * 2.625, closeTo(19, 1e-9));
      expect(truncateToDevicePx(-7.207) * 2.625, closeTo(-18, 1e-9));
      expect(roundToDevicePx(7.207) * 2.625, closeTo(19, 1e-9));
      expect(roundToDevicePx(-1 / 2.625 * 0.5) * 2.625, closeTo(0, 1e-9));
    });

    test('a value already on the grid stays on it', () {
      Utils.devicePixelRatio = 2.625;
      for (var n = -50; n <= 50; n++) {
        final v = n / 2.625;
        expect(floorToDevicePx(v) * 2.625, closeTo(n, 1e-9), reason: '$n');
        expect(ceilToDevicePx(v) * 2.625, closeTo(n, 1e-9), reason: '$n');
        expect(truncateToDevicePx(v) * 2.625, closeTo(n, 1e-9), reason: '$n');
        expect(roundToDevicePx(v) * 2.625, closeTo(n, 1e-9), reason: '$n');
      }
    });

    test('NaN and saturation follow Float.toInt() and Math.round', () {
      Utils.devicePixelRatio = 2;
      expect(truncateToDevicePx(double.nan), 0);
      expect(truncateToDevicePx(double.infinity), 2147483647 / 2);
      expect(truncateToDevicePx(double.negativeInfinity), -2147483648 / 2);
      expect(() => roundToDevicePx(double.nan), throwsArgumentError);
      expect(roundToDevicePx(double.infinity), 2147483647 / 2);
      expect(floorToDevicePx(double.nan), isNaN);
      expect(ceilToDevicePx(double.infinity), double.infinity);
    });
  });
}
