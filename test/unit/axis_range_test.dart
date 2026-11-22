// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/AxisRangeTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';

void main() {
  test('xAxisRangeAddsSpaceUnlessCustomLimitsAreSet', () {
    final axis = XAxis();
    axis.spaceMin = 1;
    axis.spaceMax = 2;
    axis.calculate(10, 20);
    expect(axis.axisMinimum, closeTo(9, 0.001));
    expect(axis.axisMaximum, closeTo(22, 0.001));
    expect(axis.axisRange, closeTo(13, 0.001));

    axis.axisMinimum = 0;
    expect(axis.isAxisMinCustom, isTrue);
    axis.calculate(10, 20);
    expect(axis.axisMinimum, closeTo(0, 0.001));
    expect(axis.axisMaximum, closeTo(22, 0.001));

    axis.resetAxisMinimum();
    expect(axis.isAxisMinCustom, isFalse);
    axis.spaceMin = 0;
    axis.spaceMax = 0;
    axis.calculate(5, 5);
    expect(axis.axisMinimum, closeTo(4, 0.001));
    expect(axis.axisMaximum, closeTo(6, 0.001));

    // A value this large does not change when 1 is added to it, so the padding has to scale with it.
    axis.calculate(7244926976, 7244926976);
    expect(axis.axisRange > 0, isTrue);
  });

  test('labelCountSurvivesAMinimumAboveTheMaximum', () {
    final axis = YAxis();
    axis.axisMinLabels = 30;
    axis.labelCount = 10;
    expect(axis.labelCount, 25);
  });

  test('yAxisRangeAddsPercentageSpace', () {
    final axis = YAxis();
    axis.calculate(0, 100);
    expect(axis.axisMinimum, closeTo(-10, 0.001));
    expect(axis.axisMaximum, closeTo(110, 0.001));

    axis.spaceTop = 0;
    axis.spaceBottom = 50;
    axis.calculate(0, 100);
    expect(axis.axisMinimum, closeTo(-50, 0.001));
    expect(axis.axisMaximum, closeTo(100, 0.001));

    axis.axisMaximum = 40;
    axis.calculate(0, 100);
    expect(axis.axisMaximum, closeTo(40, 0.001));
    expect(axis.axisMinimum, closeTo(-50, 0.001));
  });
}
