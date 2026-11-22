// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/UtilsTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

void main() {
  test('formatNumber', () {
    expect(Utils.formatNumber(0, 2, true), '0');
    expect(Utils.formatNumber(1234.5, 1, false), '1234,5');
    expect(Utils.formatNumber(12345.5, 2, true), '12.345,50');
    expect(Utils.formatNumber(1234567, 0, true, ' '), '1 234 567');
    expect(Utils.formatNumber(-0.75, 2, false), '-0,75');
    expect(Utils.formatNumber(1.5, 10, false), '1,500000000');
    expect(Utils.formatNumber(double.nan, 2, false), 'NaN');
    expect(Utils.formatNumber(double.infinity, 2, false), 'Infinity');
    expect(Utils.formatNumber(2, -1, false), '2');
  });

  test('numericHelpers', () {
    expect(Utils.roundToNextSignificant(1234.0), closeTo(1000, 0.001));
    expect(Utils.roundToNextSignificant(0.0468), closeTo(0.05, 0.0001));
    expect(Utils.roundToNextSignificant(0.0), 0);
    expect(Utils.getDecimals(12.3), 1);
    expect(Utils.getDecimals(0.0468), 4);
    expect(Utils.getNormalizedAngle(390), closeTo(30, 0.001));
    expect(Utils.getNormalizedAngle(-10), closeTo(350, 0.001));
    expect(Utils.getNormalizedAngle(-1e-6), inInclusiveRange(0, 359.99));
    expect(Utils.getNormalizedAngle(-3e10), inInclusiveRange(0, 359.99));
    expect(Utils.getNormalizedAngle(double.negativeInfinity).isNaN, isTrue);
    expect(Utils.getDecimals(1e-40), 0);
  });

  // Not in the Kotlin test: Flutter works in logical pixels, so dp conversion is the identity (Task 5 brief).
  test('convertDpToPixel and convertPixelsToDp are the identity', () {
    expect(Utils.convertDpToPixel(12), 12);
    expect(Utils.convertPixelsToDp(12), 12);
  });
}
