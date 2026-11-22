// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for PieRadarChartBase. Checks the rotation
// angle, the angle and distance helpers, the offsets and the touch gate of the round chart base on a minimal subclass.
// The spin cases follow MPChartDeviceTest's AnimationTest.animationsReachTheirFinalStateAndEndOnce (its spin part)
// and EdgeCaseTest.negativeAnimationDurationsAreAccepted. Cases that send touches or drive frames run in testWidgets,
// for the gesture binding's clock, fake timers and the frame scheduler.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/pie_radar_chart_base.dart';
import 'package:mp_flutter_chart/src/components/legend.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/highlight/i_highlighter.dart';
import 'package:mp_flutter_chart/src/listener/pie_radar_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/renderer/data_renderer.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';
import 'package:mp_flutter_chart/src/widgets/chart_touch_event.dart';

import '../support/pie_radar_gestures.dart';

/// Draws nothing.
class _NoopRenderer extends DataRenderer {
  _NoopRenderer(super.animator, super.viewPortHandler);

  @override
  void initBuffers() {}

  @override
  void drawData(ui.Canvas c) {}

  @override
  void drawValues(ui.Canvas c) {}

  @override
  void drawExtras(ui.Canvas c) {}

  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {}
}

/// The smallest round chart: a radius of [radiusPx] (100 px unless a test sets it), four equal quarters starting at
/// [rotationAngle], a renderer that draws nothing and a highlighter that always answers the second entry. [baseOffset]
/// and [legendOffset] are the required offsets in px, 0 unless a test sets them.
class _RoundChart extends PieRadarChartBase<PieData> {
  double baseOffset = 0;
  double legendOffset = 0;
  double radiusPx = 100;

  @override
  void init() {
    super.init();
    renderer = _NoopRenderer(animator, viewPortHandler);
    highlighter = IHighlighter.fromFunction((x, y) => Highlight(1, 1, 0));
  }

  @override
  double get radius => radiusPx;

  @override
  int getIndexForAngle(double angle) =>
      Utils.getNormalizedAngle(angle - rotationAngle) ~/ 90;

  @override
  double get requiredLegendOffset => legendOffset;

  @override
  double get requiredBaseOffset => baseOffset;
}

/// Four slices.
PieData _data() => PieData(
  PieDataSet([
    for (final v in [1.0, 2.0, 3.0, 4.0]) PieEntry(v),
  ], 'quarters'),
);

/// A 400 x 300 round chart with four slices, without a host.
_RoundChart _chart({bool legend = true}) {
  final chart = _RoundChart();
  chart.legend.isEnabled = legend;
  chart
    ..onSizeChanged(400, 300)
    ..data = _data();
  return chart;
}

void main() {
  test('rotationAngleIsNormalizedAndKeepsTheRawValue', () {
    final chart = _chart();
    // Kotlin's default: 270, the top of the chart.
    expect(chart.rotationAngle, 270);
    expect(chart.rawRotationAngle, 270);

    chart.rotationAngle = -90;
    expect(chart.rotationAngle, closeTo(270, 1e-4));
    expect(chart.rawRotationAngle, -90);

    chart.rotationAngle = 725;
    expect(chart.rotationAngle, closeTo(5, 1e-4));
    expect(chart.rawRotationAngle, 725);
  });

  test('getAngleForPointGoesClockwiseFromThreeOClock', () {
    final chart = _chart();
    final c = chart.centerOffsets;

    // Kotlin's code, not its KDoc (which says 360): 3 o'clock is 0. The center itself is 90.
    expect(chart.getAngleForPoint(c.x, c.y), 90);
    expect(chart.getAngleForPoint(c.x + 10, c.y), closeTo(0, 1e-4));
    expect(chart.getAngleForPoint(c.x, c.y + 10), closeTo(90, 1e-4));
    expect(chart.getAngleForPoint(c.x - 10, c.y), closeTo(180, 1e-4));
    expect(chart.getAngleForPoint(c.x, c.y - 10), closeTo(270, 1e-4));
    // Between them: 45 degrees below 3 o'clock.
    expect(chart.getAngleForPoint(c.x + 10, c.y + 10), closeTo(45, 1e-4));
  });

  test('getPositionWritesIntoTheGivenPoint', () {
    final chart = _chart();
    final c = chart.centerOffsets;

    final p = chart.getPosition(c, 10, 90);
    expect(p.x, closeTo(c.x, 1e-4));
    expect(p.y, closeTo(c.y + 10, 1e-4));

    // The given point is written and returned.
    final out = MPPointF(-1, -1);
    final written = chart.getPosition(c, 10, 180, out);
    expect(identical(written, out), isTrue);
    expect(out.x, closeTo(c.x - 10, 1e-4));
    expect(out.y, closeTo(c.y, 1e-4));

    expect(chart.distanceToCenter(c.x + 3, c.y + 4), closeTo(5, 1e-4));
    expect(chart.distanceToCenter(c.x - 3, c.y - 4), closeTo(5, 1e-4));
  });

  test('diameterSubtractsTheExtraOffsets', () {
    final chart = _chart(legend: false);
    final content = chart.viewPortHandler.contentRect;
    expect(content.width(), 400);
    expect(content.height(), 300);
    expect(chart.diameter, 300);

    // The extra offsets are subtracted from the current content rectangle, without recalculating the offsets.
    chart.extraLeftOffset = 10;
    expect(
      chart.diameter,
      math.min(content.width() - Utils.convertDpToPixel(10), content.height()),
    );

    // Where they decide the result: 400 - 10 - 150 = 240 wide, then 300 - 20 - 70 = 210 high.
    chart.extraRightOffset = 150;
    expect(chart.diameter, closeTo(240, 1e-4));
    chart.extraTopOffset = 20;
    chart.extraBottomOffset = 70;
    expect(chart.diameter, closeTo(210, 1e-4));
    expect(content.width(), 400);
  });

  testWidgets('onTouchEventGoesToTheListenerOnlyWhileTouchIsEnabled', (
    tester,
  ) async {
    final chart = _chart()..isTouchEnabled = false;
    final c = chart.centerOffsets;
    expect(chart.chartTouchListener, isA<PieRadarChartTouchListener>());

    // Not passed on: View.onTouchEvent of a view without click listeners consumes nothing.
    expect(
      chart.onTouchEvent(
        event(ChartTouchAction.down, 0, [ui.Offset(c.x + 50, c.y)]),
      ),
      isFalse,
    );
    expect(
      chart.onTouchEvent(
        event(ChartTouchAction.move, 16, [ui.Offset(c.x, c.y + 50)]),
      ),
      isFalse,
    );
    expect(chart.rotationAngle, 270);
    expect(
      chart.onTouchEvent(
        event(ChartTouchAction.up, 32, [ui.Offset(c.x, c.y + 50)]),
      ),
      isFalse,
    );

    chart.isTouchEnabled = true;
    expect(
      chart.onTouchEvent(
        event(ChartTouchAction.down, 1000, [ui.Offset(c.x + 50, c.y)]),
      ),
      isTrue,
    );
    // Past 8 dp: the rotation starts; the next move rotates by the angle covered, from 0 (3 o'clock) to 180
    // (9 o'clock): 270 + 180 = 450, normalized 90.
    chart.onTouchEvent(
      event(ChartTouchAction.move, 1016, [ui.Offset(c.x + 50, c.y + 10)]),
    );
    expect(chart.rotationAngle, 270);
    chart.onTouchEvent(
      event(ChartTouchAction.move, 1032, [ui.Offset(c.x - 50, c.y)]),
    );
    expect(chart.rotationAngle, closeTo(90, 1e-4));
    chart.onTouchEvent(
      event(ChartTouchAction.up, 1048, [ui.Offset(c.x - 50, c.y)]),
    );
  });

  test('maxVisibleCountIsTheEntryCountAndTheYRangeIsZero', () {
    final empty = _RoundChart();
    expect(empty.maxVisibleCount, 0);
    expect(empty.yChartMin, 0);
    expect(empty.yChartMax, 0);

    final chart = _chart();
    expect(chart.maxVisibleCount, 4);
    // The y range of the data is 1 .. 4, but a round chart has no y axis.
    expect(chart.yChartMin, 0);
    expect(chart.yChartMax, 0);
  });

  group('spinEndsAtTheTargetAndCallsOnEndOnce', () {
    test('without a vsync the spin ends at once', () {
      // AnimationTest.animationsReachTheirFinalStateAndEndOnce: spin(200, 0, 90) ends at 90 and calls onEnd once.
      final chart = _chart();
      var ends = 0;
      chart.spin(200, 0, 450, onEnd: () => ends++);
      expect(chart.rotationAngle, closeTo(Utils.getNormalizedAngle(450), 1e-4));
      expect(chart.rotationAngle, closeTo(90, 1e-4));
      expect(chart.rawRotationAngle, 450);
      expect(ends, 1);
      expect(chart.isAnimating, isFalse);

      // Without onEnd.
      chart.spin(200, 0, 30);
      expect(chart.rotationAngle, closeTo(30, 1e-4));
    });

    test('a negative duration is accepted', () {
      // EdgeCaseTest.negativeAnimationDurationsAreAccepted: animateXY(-1, -1) and spin(-1, 0, 90). Both end at once at
      // their final state.
      final chart = _chart();
      var ends = 0;
      chart.animateXY(-1, -1, onEnd: () => ends++);
      expect(chart.isAnimating, isFalse);
      expect(chart.animator.phaseX, 1);
      expect(chart.animator.phaseY, 1);
      expect(ends, 1);
      chart.spin(-1, 0, 90, onEnd: () => ends++);
      expect(chart.rotationAngle, closeTo(90, 1e-4));
      expect(chart.isAnimating, isFalse);
      expect(ends, 2);

      // Kotlin's case is a pie without data.
      final empty = _RoundChart()..onSizeChanged(400, 300);
      empty.animateXY(-1, -1);
      empty.spin(-1, 0, 90);
      expect(empty.isAnimating, isFalse);
      expect(empty.rotationAngle, closeTo(90, 1e-4));
    });

    testWidgets('with a vsync the spin moves through the frames', (
      tester,
    ) async {
      final chart = _chart();
      chart.animator.vsync = const TestVSync();
      var ends = 0;

      chart.spin(100, 0, 90, onEnd: () => ends++);
      // The start angle is applied at once.
      expect(chart.rotationAngle, 0);
      expect(chart.isAnimating, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(chart.rotationAngle, greaterThan(0));
      expect(chart.rotationAngle, lessThan(90));
      expect(chart.rotationAngle, closeTo(45, 1e-4));
      expect(ends, 0);

      await tester.pump(const Duration(milliseconds: 51));
      expect(chart.rotationAngle, closeTo(90, 1e-4));
      expect(ends, 1);
      expect(chart.isAnimating, isFalse);

      await tester.pump(const Duration(milliseconds: 100));
      expect(ends, 1);
    });

    testWidgets('a new spin cancels the running one, whose onEnd runs once', (
      tester,
    ) async {
      final chart = _chart();
      chart.animator.vsync = const TestVSync();
      var first = 0;
      var second = 0;

      chart.spin(100, 0, 90, onEnd: () => first++);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(chart.rotationAngle, closeTo(27, 1e-4));

      chart.spin(100, 180, 270, onEnd: () => second++);
      expect(first, 1);
      expect(second, 0);
      expect(chart.rotationAngle, 180);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 101));
      expect(chart.rotationAngle, closeTo(270, 1e-4));
      expect(first, 1);
      expect(second, 1);
      expect(chart.isAnimating, isFalse);
    });
  });

  group('calculateOffsetsLeavesMinOffsetAroundTheChart', () {
    test('without a legend', () {
      final chart = _chart(legend: false);
      final content = chart.viewPortHandler.contentRect;

      // Kotlin's calculateOffsets with the legend off: legendLeft/Top/Right/Bottom = 0 + the extra offsets (0);
      // minOffsetSides = minOffsetTopBottom = convertDpToPixel(minOffset) = 0; offsetLeft = max(0, 0),
      // offsetTop = max(0, 0), offsetRight = max(0, 0), offsetBottom = max(0, max(requiredVerticalBaseOffset = 0, 0)).
      chart.calculateOffsets();
      expect(
        [content.left, content.top, content.right, content.bottom],
        [0, 0, 400, 300],
      );

      // minOffset = 20 dp: every offset is max(convertDpToPixel(20), 0) = 20.
      chart.minOffset = 20;
      chart.calculateOffsets();
      final inset = Utils.convertDpToPixel(20);
      expect(
        [content.left, content.top, content.right, content.bottom],
        [inset, inset, 400 - inset, 300 - inset],
      );

      // With the legend off Kotlin adds the base offsets only through offsetBottom =
      // max(minOffsetTopBottom, max(requiredVerticalBaseOffset, legendBottom)): 7 px below, nothing elsewhere.
      chart.minOffset = 0;
      chart.baseOffset = 7;
      chart.calculateOffsets();
      expect(
        [content.left, content.top, content.right, content.bottom],
        [0, 0, 400, 293],
      );
    });

    test('with the default legend below the chart', () {
      final chart = _chart()
        ..baseOffset = 7
        ..legendOffset = 3;
      final legend = chart.legend;
      expect(legend.orientation, LegendOrientation.HORIZONTAL);
      expect(legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
      expect(legend.neededHeight, greaterThan(0));
      final content = chart.viewPortHandler.contentRect;

      // HORIZONTAL and BOTTOM: legendBottom = min(neededHeight + requiredLegendOffset, chartHeight * 0.95); then
      // legendLeft/Right += requiredBaseOffset, legendTop/Bottom += requiredVerticalBaseOffset (= base).
      chart.calculateOffsets();
      final bottom = math.min(legend.neededHeight + 3, 300 * 0.95) + 7;
      expect(content.left, closeTo(7, 1e-4));
      expect(content.top, closeTo(7, 1e-4));
      expect(content.right, closeTo(400 - 7, 1e-4));
      expect(content.bottom, closeTo(300 - bottom, 1e-4));

      // minOffset wins where it is larger than the legend offsets.
      chart.minOffset = 20;
      chart.calculateOffsets();
      final inset = Utils.convertDpToPixel(20);
      expect(content.left, closeTo(inset, 1e-4));
      expect(content.top, closeTo(inset, 1e-4));
      expect(content.right, closeTo(400 - inset, 1e-4));
      expect(content.bottom, closeTo(300 - math.max(inset, bottom), 1e-4));
    });

    test('with a vertical legend centered on the right', () {
      final chart = _chart();
      chart.legend
        ..orientation = LegendOrientation.VERTICAL
        ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
        ..verticalAlignment = LegendVerticalAlignment.CENTER;
      chart.notifyDataSetChanged();
      final legend = chart.legend;
      final content = chart.viewPortHandler.contentRect;

      // VERTICAL, RIGHT and CENTER: legendRight = min(neededWidth, chartWidth * 0.95) + convertDpToPixel(13).
      final right =
          math.min(legend.neededWidth, 400 * 0.95) + Utils.convertDpToPixel(13);
      expect(content.left, 0);
      expect(content.top, 0);
      expect(content.right, closeTo(400 - right, 1e-4));
      expect(content.bottom, 300);
    });

    test('with a vertical legend in a top corner', () {
      // VERTICAL, LEFT or RIGHT and not CENTER: Kotlin moves the content away from the legend only when the legend's
      // inner bottom corner, (width - legendWidth + 15, legendHeight + 15) on the right or (legendWidth - 15,
      // legendHeight + 15) on the left, lies inside the chart's circle: by 5 dp plus how far inside it lies. (The
      // other case, a corner at or below the center of a chart taller than it is wide after the legend, needs a legend
      // half the chart high.) The distances are measured from the content center, the chart center here: the chart
      // starts without a legend, so its content is the whole chart when notifyDataSetChanged calculates the offsets.
      for (final alignment in [
        LegendHorizontalAlignment.RIGHT,
        LegendHorizontalAlignment.LEFT,
      ]) {
        for (final radius in [100.0, 250.0]) {
          final chart = _chart(legend: false)..radiusPx = radius;
          final content = chart.viewPortHandler.contentRect;
          expect(
            [content.left, content.top, content.right, content.bottom],
            [0, 0, 400, 300],
          );
          chart.legend
            ..isEnabled = true
            ..orientation = LegendOrientation.VERTICAL
            ..horizontalAlignment = alignment
            ..verticalAlignment = LegendVerticalAlignment.TOP;
          chart.notifyDataSetChanged();
          final legend = chart.legend;
          expect(legend.neededWidth, greaterThan(0));

          final legendWidth =
              math.min(legend.neededWidth, 400 * legend.maxSizePercent) +
              Utils.convertDpToPixel(8);
          final legendHeight = legend.neededHeight + legend.textHeightMax;
          final bottomX = alignment == LegendHorizontalAlignment.RIGHT
              ? 400 - legendWidth + 15
              : legendWidth - 15;
          final bottomY = legendHeight + 15;
          final distLegend = math.sqrt(
            math.pow(bottomX - 200, 2) + math.pow(bottomY - 150, 2),
          );
          // The reference point is on the chart's circle, so its distance from the center is the radius.
          final offset = distLegend < radius
              ? Utils.convertDpToPixel(5) + radius - distLegend
              : 0.0;
          final label = '$alignment, radius $radius';
          // The small radius leaves the corner outside; the large one takes it in.
          expect(offset > 0, radius > 100, reason: label);
          final left = alignment == LegendHorizontalAlignment.LEFT ? offset : 0;
          final right = alignment == LegendHorizontalAlignment.RIGHT
              ? offset
              : 0;
          expect(content.left, closeTo(left, 1e-3), reason: label);
          expect(content.top, 0, reason: label);
          expect(content.right, closeTo(400 - right, 1e-3), reason: label);
          expect(content.bottom, 300, reason: label);
        }
      }
    });

    test('with a vertical legend centered below the chart', () {
      // VERTICAL and CENTER: legendTop or legendBottom = min(neededHeight, chartHeight * 0.95); a CENTER vertical
      // alignment leaves the content as it is.
      for (final vertical in LegendVerticalAlignment.values) {
        final chart = _chart();
        chart.legend
          ..orientation = LegendOrientation.VERTICAL
          ..horizontalAlignment = LegendHorizontalAlignment.CENTER
          ..verticalAlignment = vertical;
        chart.notifyDataSetChanged();
        final legend = chart.legend;
        final content = chart.viewPortHandler.contentRect;
        final height = math.min(
          legend.neededHeight,
          300 * legend.maxSizePercent,
        );
        expect(height, greaterThan(0));
        expect(content.left, 0, reason: '$vertical');
        expect(content.right, 400, reason: '$vertical');
        expect(
          content.top,
          closeTo(vertical == LegendVerticalAlignment.TOP ? height : 0, 1e-4),
          reason: '$vertical',
        );
        expect(
          content.bottom,
          closeTo(
            vertical == LegendVerticalAlignment.BOTTOM ? 300 - height : 300,
            1e-4,
          ),
          reason: '$vertical',
        );
      }
    });
  });
}
