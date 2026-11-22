// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/LargeValueFormatterTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/formatter/large_value_formatter.dart';

void main() {
  test('formatsSmallAndVeryLargeNumbers', () {
    final formatter = LargeValueFormatter();
    final axis = XAxis();
    expect(formatter.getFormattedValue(856, axis), '856');
    expect(formatter.getFormattedValue(5821, axis), '5.8k');
    expect(formatter.getFormattedValue(101800, axis), '102k');
    expect(formatter.getFormattedValue(0.5, axis), '0.5');
    expect(formatter.getFormattedValue(-5821, axis), '-5.8k');
    expect(formatter.getFormattedValue(1e18, axis), endsWith('t'));
  });

  test('formatsWithSuffixes', () {
    final formatter = LargeValueFormatter();
    final axis = XAxis();

    expect(formatter.getFormattedValue(5, axis), '5');
    expect(formatter.getFormattedValue(5.5, axis), '5.5');
    expect(formatter.getFormattedValue(50, axis), '50');
    expect(formatter.getFormattedValue(50.5, axis), '50.5');
    expect(formatter.getFormattedValue(500, axis), '500');
    expect(formatter.getFormattedValue(1100, axis), '1.1k');
    expect(formatter.getFormattedValue(10000, axis), '10k');
    expect(formatter.getFormattedValue(10500, axis), '10.5k');
    expect(formatter.getFormattedValue(100000, axis), '100k');
    expect(formatter.getFormattedValue(1000000, axis), '1m');
    expect(formatter.getFormattedValue(1500000, axis), '1.5m');
    expect(formatter.getFormattedValue(9500000, axis), '9.5m');
    expect(formatter.getFormattedValue(22200000, axis), '22.2m');
    expect(formatter.getFormattedValue(222000000, axis), '222m');
    expect(formatter.getFormattedValue(1000000000, axis), '1b');
    expect(formatter.getFormattedValue(9900000000, axis), '9.9b');
    expect(formatter.getFormattedValue(99000000000, axis), '99b');
    expect(formatter.getFormattedValue(99500000000, axis), '99.5b');
    expect(formatter.getFormattedValue(999000000000, axis), '999b');
    expect(formatter.getFormattedValue(1000000000000, axis), '1t');

    formatter.suffix = ['', 'k', 'm', 'b', 't', 'q'];
    expect(formatter.getFormattedValue(1000000000000000, axis), '1q');
    expect(formatter.getFormattedValue(1100000000000000, axis), '1.1q');
    expect(formatter.getFormattedValue(10000000000000000, axis), '10q');
    expect(formatter.getFormattedValue(13300000000000000, axis), '13.3q');
    expect(formatter.getFormattedValue(100000000000000000, axis), '100q');
  });
}
