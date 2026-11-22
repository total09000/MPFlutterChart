// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/EmptyStateLayoutTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/empty_state_layout.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';

EmptyStateLayout _layout(
  PaintAlign align, {
  double iconHeight = 24,
  double gap = 10,
}) => EmptyStateLayout(400, 300, 30, iconHeight, gap, 90, 16, align);

void main() {
  test('theBlockIsCenteredVerticallyAndPlacedByTheAlignment', () {
    final center = _layout(PaintAlign.CENTER);
    expect(center.top, (300 - 24 - 10 - 16) / 2);
    expect(center.textTop, center.top + 24 + 10);
    expect(center.centerX, 200);
    expect(center.textX, 200);

    final left = _layout(PaintAlign.LEFT);
    expect(left.centerX, 45);
    expect(left.textX, 0);

    final right = _layout(PaintAlign.RIGHT);
    expect(right.centerX, 355);
    expect(right.textX, 400);

    final textOnly = _layout(PaintAlign.CENTER, iconHeight: 0, gap: 0);
    expect(textOnly.textTop, (300 - 16) / 2);
  });

  test('theLoadingPulseBreathesBetween30And100Percent', () {
    final samples = [
      for (var it = 0; it < LOADING_PULSE_MILLIS; it += 10) loadingPulse(it),
    ];
    expect(samples.reduce((a, b) => a < b ? a : b), closeTo(0.3, 0.01));
    expect(samples.reduce((a, b) => a > b ? a : b), closeTo(1, 0.01));
    expect(
      loadingPulse(123),
      closeTo(loadingPulse(123 + LOADING_PULSE_MILLIS), 0.0001),
    );
    expect(samples.every((it) => it >= 0.3 && it <= 1), isTrue);
  });
}
