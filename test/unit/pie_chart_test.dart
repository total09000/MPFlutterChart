// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/
// EdgeCaseTest.kt (pieAnglesStayFinite, highlightsPastTheDataClearTheSelection and the pie parts of
// gesturesKeepTheChartFinite and everyChartDrawsEveryShapeOfData), HostileInputTest.kt (the two pie cases and the
// PieRadarChartBase calls of hostileDataDrawsAndTakesTouches / extremeViewport) and EmptyStateTest.kt (the pie and
// radar parts of everyChartTypeDrawsItsOwnOutline, and aCustomIconIsDrawnInsteadOfTheOutline). The other cases are not
// ports of a Kotlin test: they pin PieChart's slice angles, index lookup, marker position, PieHighlighter, the pie hole
// check of PieRadarChartTouchListener and the renderer's skipping of geometry that is not finite under hostile settings
// against the Kotlin code. Charts are 400 x 300 and get their size before their data, as Fixtures.lay does. Cases that
// send touches run in testWidgets, for the gesture binding's fake clock and timers; the hostile replay also gives the
// touch listener that clock.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/scheduler.dart' show TickerProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/chart.dart';
import 'package:mp_flutter_chart/src/charts/chart_host.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/charts/pie_chart.dart';
import 'package:mp_flutter_chart/src/charts/radar_chart.dart';
import 'package:mp_flutter_chart/src/components/marker_image.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/highlight/pie_highlighter.dart';
import 'package:mp_flutter_chart/src/listener/chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/listener/pie_radar_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/renderer/pie_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';
import 'package:mp_flutter_chart/src/widgets/chart_touch_event.dart';

import '../recording/recording_canvas.dart';
import '../support/pie_radar_gestures.dart';

/// Kotlin's `Float.MAX_VALUE`.
const double _floatMax = 3.4028234663852886e38;

/// Records the scroll requests of the touch listener, like the fixture of the same name in
/// pie_radar_chart_touch_listener_test.dart.
class _FakeHost implements ChartHost {
  @override
  TickerProvider? get vsync => null;

  int scrollDisables = 0;

  @override
  void markNeedsPaint() {}

  @override
  void postFrame(void Function() job) => job();

  @override
  void disableScroll() => scrollDisables++;

  @override
  void enableScroll() {}
}

/// Exposes the protected marker position.
class _MarkerPie extends PieChart {
  Float32List markerPosition(Highlight high) => getMarkerPosition(high);
}

/// Draws the rounded slice ends, which neither PieChart.onDraw nor Kotlin's draw pass calls, from drawExtras, as the
/// documentation of drawRoundedSlices suggests for a subclass.
class _RoundedSlicesRenderer extends PieChartRenderer {
  _RoundedSlicesRenderer(super.chart, super.animator, super.viewPortHandler);

  @override
  void drawExtras(ui.Canvas c) {
    drawRoundedSlices(c);
    super.drawExtras(c);
  }
}

/// EmptyStateTest's CountingDrawable: counts its draws and keeps the bounds of the last one. Like an Android Drawable
/// it has no intrinsic size (-1).
class _CountingDrawable extends ChartDrawable {
  int draws = 0;
  MutableRect? bounds;

  @override
  int get intrinsicWidth => -1;

  @override
  int get intrinsicHeight => -1;

  @override
  void draw(ui.Canvas canvas, MutableRect bounds) {
    draws++;
    this.bounds = MutableRect(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    );
  }
}

PieData _data(List<double> values, [String label = '']) =>
    PieData(PieDataSet([for (final v in values) PieEntry(v)], label));

/// A 400 x 300 pie chart holding [values].
PieChart _pie(List<double> values) {
  final chart = PieChart()..onSizeChanged(400, 300);
  chart.data = _data(values);
  return chart;
}

/// Draws [chart] onto a RecordingCanvas and onto a real canvas, Kotlin's drawBoth (window and bitmap). Returns the
/// RecordingCanvas.
RecordingCanvas _drawBoth(Chart chart) {
  final recording = RecordingCanvas();
  chart.onDraw(recording);
  final recorder = ui.PictureRecorder();
  chart.onDraw(ui.Canvas(recorder));
  recorder.endRecording().dispose();
  return recording;
}

/// A slice, ring or line whose geometry is not finite is not drawn, so nothing that is not a number
/// reaches a path or the canvas. With slice angles that are not numbers, the only slice left is a full circle
/// ([fullCircles], a single slice), whose outline does not depend on the angles, as in Kotlin; the transparent ring
/// around the hole does not depend on them either. No value line or text is drawn at a position that is not a number.
void _expectNoNonFiniteSlices(
  PieChart chart,
  RecordingCanvas canvas,
  String label, {
  int fullCircles = 0,
}) {
  final ring = chart.transparentCircleColor.toARGB32();
  expect(
    canvas.paths.where((p) => p.color.toARGB32() != ring),
    hasLength(fullCircles),
    reason: '$label: a slice with angles that are not numbers is drawn',
  );
  expect(canvas.lines, isEmpty, reason: '$label: a value line is drawn');
  for (final p in canvas.paragraphs) {
    expect(p.offset.isFinite, isTrue, reason: '$label: text at ${p.offset}');
  }
  for (final c in canvas.circles) {
    expect(
      c.x.isFinite && c.y.isFinite && c.radius.isFinite,
      isTrue,
      reason: '$label: a circle at (${c.x}, ${c.y}) r ${c.radius}',
    );
  }
}

/// No path holds a point that is not a number. Skia gives such a path the empty bounds at the origin,
/// where no path of a laid-out pie lies.
void _expectFinitePaths(RecordingCanvas canvas, String label) {
  for (final p in canvas.paths) {
    expect(
      p.bounds,
      isNot(ui.Rect.zero),
      reason: '$label: a path with a point that is not a number',
    );
  }
}

/// Nothing that is not finite reaches the canvas: no path with a point that is not a number (see
/// [_expectFinitePaths]), no circle, clip, line or text at a position that is not finite.
void _expectFiniteGeometry(RecordingCanvas canvas, String label) {
  _expectFinitePaths(canvas, label);
  for (final c in canvas.circles) {
    expect(
      c.x.isFinite && c.y.isFinite && c.radius.isFinite,
      isTrue,
      reason: '$label: a circle at (${c.x}, ${c.y}) r ${c.radius}',
    );
  }
  for (final p in canvas.clipPaths) {
    final b = p.getBounds();
    expect(
      b.isFinite && b != ui.Rect.zero,
      isTrue,
      reason: '$label: a clip with bounds $b',
    );
  }
  for (final l in canvas.lines) {
    expect(
      l.p1.isFinite && l.p2.isFinite,
      isTrue,
      reason: '$label: a line from ${l.p1} to ${l.p2}',
    );
  }
  for (final p in canvas.paragraphs) {
    expect(p.offset.isFinite, isTrue, reason: '$label: text at ${p.offset}');
  }
}

void main() {
  group('PieChart', () {
    test('pieAnglesStayFinite', () {
      final chart = PieChart()..onSizeChanged(400, 300);

      chart.data = _data([0, 0]);
      expect(chart.drawAngles.every((a) => a == 0), isTrue);

      chart.data = _data([-1, 3]);
      expect(chart.absoluteAngles.last, closeTo(360, 0.01));

      chart.minAngleForSlices = 90;
      chart.data = _data([1, 1, 1, 1]);
      expect(chart.drawAngles.every((a) => a == 90), isTrue);

      final c = chart.centerOffsets;
      expect(chart.getAngleForPoint(c.x, c.y).isFinite, isTrue);
    });

    test('anglesAreFloatArraysThatStartWithOneSlot', () {
      // Kotlin's FloatArray(1) before any data.
      final chart = PieChart();
      expect(chart.drawAngles, isA<Float32List>());
      expect(chart.drawAngles, [0]);
      expect(chart.absoluteAngles, isA<Float32List>());
      expect(chart.absoluteAngles, [0]);

      chart
        ..onSizeChanged(400, 300)
        ..data = _data([1, 2, 3, 4]);
      expect(chart.drawAngles, isA<Float32List>());
      expect(chart.drawAngles, [36, 72, 108, 144]);
      expect(chart.absoluteAngles, [36, 108, 216, 360]);

      // calcAngles keeps the arrays when the entry count stays.
      final drawAngles = chart.drawAngles;
      chart.data = _data([1, 1, 1, 1]);
      expect(identical(chart.drawAngles, drawAngles), isTrue);
      expect(chart.drawAngles, [90, 90, 90, 90]);
    });

    test('maxAngleMakesAHalfPie', () {
      final chart = PieChart()..onSizeChanged(400, 300);
      chart.maxAngle = 180;
      chart.data = _data([1, 1]);
      expect(chart.absoluteAngles, [90, 180]);

      // Kotlin's coerceIn(90f, 360f).
      chart.maxAngle = 10;
      expect(chart.maxAngle, 90);
      chart.maxAngle = 1000;
      expect(chart.maxAngle, 360);
      chart.maxAngle = double.nan;
      expect(chart.maxAngle.isNaN, isTrue);
    });

    test('minAngleForSlicesTakesRoomFromTheBigSlices', () {
      final chart = PieChart()..onSizeChanged(400, 300);
      chart.minAngleForSlices = 30;
      chart.data = _data([1, 100]);
      // calcAngles: 1 / 101 * 360 = 3.56 is below 30, so it takes 30 and offset = 26.44; the big slice keeps
      // 356.44 with diff = 326.44 above the minimum. shrink = offset / diff, and the big slice gives up
      // (356.44 - 30) * shrink = 26.44 degrees: 330.
      expect(chart.drawAngles[0], closeTo(30, 1e-4));
      expect(chart.drawAngles[1], closeTo(330, 1e-3));
      expect(chart.drawAngles[0] + chart.drawAngles[1], closeTo(360, 1e-3));
      expect(chart.absoluteAngles.last, closeTo(360, 1e-3));

      // Kotlin's coerceIn(0f, maxAngle / 2f).
      chart.minAngleForSlices = 500;
      expect(chart.minAngleForSlices, 180);
      chart.minAngleForSlices = -1;
      expect(chart.minAngleForSlices, 0);

      // Not applied when the slices cannot all have it: 4 * 100 > 360.
      chart.minAngleForSlices = 100;
      chart.data = _data([1, 1, 1, 7]);
      expect(chart.drawAngles, [36, 36, 36, 252]);
    });

    test('getIndexForAngleFindsTheSliceUnderTheAngle', () {
      final chart = _pie([1, 1, 1, 1]);
      expect(chart.rotationAngle, 270);
      expect(chart.getIndexForAngle(280), 0);
      expect(chart.getIndexForAngle(10), 1);
      expect(chart.getIndexForAngle(100), 2);
      expect(chart.getIndexForAngle(190), 3);

      chart.rotationAngle = 0;
      expect(chart.getIndexForAngle(10), 0);

      // A half pie: nothing lies under the other half.
      chart.maxAngle = 180;
      chart.notifyDataSetChanged();
      expect(chart.getIndexForAngle(200), -1);
    });

    test('needsHighlightFollowsTheSelection', () {
      final chart = _pie([1, 2, 3, 4]);
      expect(
        [for (var i = 0; i < 4; i++) chart.needsHighlight(i)],
        [false, false, false, false],
      );

      chart.highlightValue(2, 0);
      expect(
        [for (var i = 0; i < 4; i++) chart.needsHighlight(i)],
        [false, false, true, false],
      );

      // Kotlin's high.x.toInt() truncates.
      chart.highlightValues([Highlight(1.7, double.nan, 0)]);
      expect(chart.needsHighlight(1), isTrue);
      expect(chart.needsHighlight(2), isFalse);

      chart.highlightValueOf(null);
      expect(chart.needsHighlight(1), isFalse);
    });

    test('getDataSetIndexForIndex', () {
      final chart = PieChart()..onSizeChanged(400, 300);
      expect(chart.getDataSetIndexForIndex(0), -1);

      // Every PieEntry has x 0 and getEntryForXValue rounds to the closest entry, so any index finds the set.
      chart.data = _data([1, 2, 3]);
      expect(chart.getDataSetIndexForIndex(0), 0);
      expect(chart.getDataSetIndexForIndex(2), 0);
      expect(chart.getDataSetIndexForIndex(7), 0);

      chart.data = _data([]);
      expect(chart.getDataSetIndexForIndex(0), -1);
    });

    test('markerPositionIsInTheMiddleOfTheSlice', () {
      final chart = _MarkerPie()..onSizeChanged(400, 300);
      chart.data = _data([1, 1, 1, 1]);
      final center = chart.centerCircleBox;
      final r = chart.radius;

      // With the hole: halfway between the hole edge and the rim. Slice 0 spans 270 to 360, its middle is 315.
      chart.highlightValue(0, 0);
      var pos = chart.markerPosition(chart.highlighted.single);
      var dist = r - (r - r / 100 * chart.holeRadius) / 2;
      expect(
        pos[0],
        closeTo(center.x + dist * math.cos(315 * Utils.DEG2RAD), 1e-3),
      );
      expect(
        pos[1],
        closeTo(center.y + dist * math.sin(315 * Utils.DEG2RAD), 1e-3),
      );
      expect(pos.every((v) => v.isFinite), isTrue);

      // Without the hole: 3.6 tenths of the radius in from the rim. Slice 2 spans 90 to 180, its middle is 135.
      chart.isDrawHoleEnabled = false;
      chart.highlightValue(2, 0);
      pos = chart.markerPosition(chart.highlighted.single);
      dist = r - r / 10 * 3.6;
      expect(
        pos[0],
        closeTo(center.x + dist * math.cos(135 * Utils.DEG2RAD), 1e-3),
      );
      expect(
        pos[1],
        closeTo(center.y + dist * math.sin(135 * Utils.DEG2RAD), 1e-3),
      );

      // An index outside the slices has no position.
      pos = chart.markerPosition(Highlight(9, 1, 0));
      expect(pos[0].isNaN && pos[1].isNaN, isTrue);
      pos = chart.markerPosition(Highlight(double.nan, 1, 0));
      expect(pos.every((v) => v.isFinite), isTrue);
    });

    test('highlightsPastTheDataClearTheSelection', () {
      final pie = PieChart()..onSizeChanged(400, 300);
      pie.marker = MarkerImage(
        PainterDrawable((canvas, size) {}, width: 10, height: 10),
      );
      pie.data = _data([1, 1, 1, 1, 1]);
      pie.highlightValue(4, 0);
      pie.data = _data([1, 1]);
      _drawBoth(pie);
      pie.highlightValue(9, 0);
      expect(pie.valuesToHighlight(), isFalse);
    });

    test('pieHighlighterReturnsTheSliceUnderTheTouch', () {
      final chart = _pie([1, 2, 3, 4]);
      expect(chart.highlighter, isA<PieHighlighter>());
      expect(chart.renderer, isA<PieChartRenderer>());
      final c = chart.centerOffsets;
      final r = chart.radius;

      // Slice 1 spans 270 + 36 to 270 + 108 degrees; its middle is 342.
      final p = chart.getPosition(c, r * 0.75, 342);
      final high = chart.highlighter.getHighlight(p.x, p.y)!;
      expect(high.x, 1);
      expect(high.y, 2);
      expect(high.dataSetIndex, 0);
      expect(high.xPx, p.x);
      expect(high.yPx, p.y);
      expect(high.axis, AxisDependency.LEFT);

      // Kotlin's highlighter does not look at the hole.
      final inHole = chart.getPosition(c, r * 0.2, 342);
      expect(chart.highlighter.getHighlight(inHole.x, inHole.y)?.x, 1);

      final outside = chart.getPosition(c, r * 1.1, 342);
      expect(chart.highlighter.getHighlight(outside.x, outside.y), isNull);

      // Half way through the y animation the slices span half their angles, so the angle is doubled first:
      // 342 / 0.5 = 684, 684 - 270 = 414, normalized 54: slice 1 (36 until 108).
      chart.animator.phaseY = 0.5;
      final q = chart.getPosition(c, r * 0.75, 342);
      expect(chart.highlighter.getHighlight(q.x, q.y)?.x, 1);
      final s = chart.getPosition(c, r * 0.75, 171);
      // 171 / 0.5 = 342, 342 - 270 = 72: slice 1 too, though slice 1 of the full pie does not lie at 171.
      expect(chart.highlighter.getHighlight(s.x, s.y)?.x, 1);
    });

    testWidgets('aDownInTheHoleOrACornerNeverRotates', (tester) async {
      final host = _FakeHost();
      final chart = _pie([1, 1, 1])..host = host;
      final listener = chart.chartTouchListener as PieRadarChartTouchListener;
      final c = chart.centerOffsets;
      final x = c.x + chart.radius * 0.3;

      void drag(int t) {
        send(chart, ChartTouchAction.down, t, x, c.y);
        for (var i = 1; i <= 10; i++) {
          send(chart, ChartTouchAction.move, t + 16 * i, x, c.y + 4.0 * i);
        }
      }

      expect(chart.isDrawHoleEnabled, isTrue);
      drag(0);
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollDisables, 0);
      expect(chart.rotationAngle, 270);
      send(chart, ChartTouchAction.up, 200, x, c.y + 40);

      // A corner is outside the radius.
      send(chart, ChartTouchAction.down, 1000, 2, 2);
      for (var i = 1; i <= 10; i++) {
        send(chart, ChartTouchAction.move, 1000 + 16 * i, 2 + 4.0 * i, 2);
      }
      expect(listener.touchMode, ChartTouchListener.NONE);
      expect(host.scrollDisables, 0);
      send(chart, ChartTouchAction.up, 1200, 42, 2);

      // Without the hole the same spot is on the chart.
      chart.isDrawHoleEnabled = false;
      drag(2000);
      expect(listener.touchMode, ChartTouchListener.ROTATE);
      expect(host.scrollDisables, 1);
      send(chart, ChartTouchAction.up, 2200, x, c.y + 40);
      listener.stopDeceleration();
    });

    testWidgets('gesturesKeepTheRotationFinite', (tester) async {
      final pie = PieChart()..onSizeChanged(400, 300);
      pie.isDrawHoleEnabled = false;
      pie.data = _data([1, 1, 1]);
      final c = pie.centerOffsets;
      send(pie, ChartTouchAction.down, 0, c.x, c.y);
      send(pie, ChartTouchAction.move, 16, c.x + 100, c.y + 100);
      send(pie, ChartTouchAction.move, 32, c.x + 150, c.y);
      send(pie, ChartTouchAction.up, 48, c.x + 150, c.y);
      expect(pie.rotationAngle.isFinite, isTrue);
      (pie.chartTouchListener as PieRadarChartTouchListener).stopDeceleration();
    });

    testWidgets('hostilePieDataDrawsAndTakesTouches', (tester) async {
      // HostileInputTest.hostileDataDrawsAndTakesTouches and the PieRadarChartBase calls of extremeViewport: draw,
      // touch, highlight entry 0 and draw again, then for each hostile call draw and touch, every drawing finite.
      // The touch listener runs on the test binding's fake clock (useFakeClock), so every run sees the
      // same fling velocity and deceleration step.
      final shapes = <String, PieData? Function()>{
        'null data': () => null,
        'no data sets': () => PieData(),
        'no values': () => _data([]),
        'one value': () => _data([3]),
        'equal values': () => _data([2, 2, 2]),
        'zeros': () => _data([0, 0, 0]),
        'negative values': () => _data([-5, 3, -1]),
        'a NaN': () => _data([1, double.nan, 2]),
        'an infinity': () => _data([1, double.infinity, 2]),
        'pie all negative with labels': () => PieData(
          PieDataSet([PieEntry(-3, label: 'a'), PieEntry(-1, label: 'b')], 'p'),
        ),
        'pie one huge one tiny': () => PieData(
          PieDataSet([
            PieEntry(_floatMax, label: 'a'),
            PieEntry(_floatMax, label: 'b'),
            PieEntry(1e-30, label: 'c'),
          ], 'p'),
        ),
      };

      final logs = <(String, String?)>[];
      var shown = '';
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add((shown, message));
      try {
        var t = 0;
        for (final MapEntry(key: shape, value: make) in shapes.entries) {
          for (final laidOut in [true, false]) {
            final chart = PieChart();
            if (laidOut) chart.onSizeChanged(400, 300);
            useFakeClock(tester, chart);
            final label = '$shape (${laidOut ? 'laid out' : 'not laid out'})';
            shown = shape;
            try {
              final data = make();
              chart.data = data;
              // HostileInputTest.put draws the values of the first set.
              data?.dataSet?.isDrawValuesEnabled = true;
              chart.marker = MarkerImage(
                PainterDrawable((canvas, size) {}, width: 10, height: 10),
              );
              // Not in Kotlin, which highlights only after the touches: the first draw has a highlight too.
              chart.highlightValue(0, 0);
              RecordingCanvas draw(String step) {
                final canvas = _drawBoth(chart);
                if (laidOut) _expectFinitePaths(canvas, '$label, $step');
                return canvas;
              }

              final first = draw('first draw');
              // A NaN value makes the sum and so every slice angle NaN.
              if (shape == 'a NaN' && laidOut) {
                _expectNoNonFiniteSlices(chart, first, label);
              }
              t = touch(chart, t);
              // HostileInputTest.kt:103: chart.highlightValue(firstX(chart), 0), and firstX is 0 for pie entries.
              chart.highlightValue(0, 0);
              draw('after touches');

              for (final (name, call) in <(String, void Function())>[
                ('rotation 1e30', () => chart.rotationAngle = 1e30),
                ('rotation NaN', () => chart.rotationAngle = double.nan),
                ('spin', () => chart.spin(200, 0, 1e9)),
              ]) {
                call();
                final canvas = draw(name);
                // A NaN rotation makes every slice start angle NaN; only the full circle of a single slice is left.
                if (name == 'rotation NaN') {
                  _expectNoNonFiniteSlices(
                    chart,
                    canvas,
                    '$label, $name',
                    fullCircles: shape == 'one value' && laidOut ? 1 : 0,
                  );
                }
                t = touch(chart, t);
              }
              draw('last draw');
            } catch (e, s) {
              fail('PieChart with $label: $e\n$s');
            }
          }
        }
      } finally {
        debugPrint = previous;
      }

      // The only log is Kotlin's for a tap on a chart without data.
      expect(logs, isNotEmpty);
      for (final (shape, message) in logs) {
        expect(shape, 'null data', reason: message);
        expect(message, "MPAndroidChart: Can't select by touch. No data set.");
      }

      // The sum is a double, so two Float.MAX_VALUE slices are two half circles (Kotlin's Float sum
      // overflows to infinity and every angle is 0).
      final huge = PieChart()..onSizeChanged(400, 300);
      huge.data = shapes['pie one huge one tiny']!();
      expect(huge.absoluteAngles.every((a) => a.isFinite), isTrue);
      expect(huge.drawAngles[0], closeTo(180, 1e-3));
      expect(huge.drawAngles[1], closeTo(180, 1e-3));
      expect(huge.drawAngles[2], closeTo(0, 1e-3));

      // The gesture detector's timers run out.
      await tester.pump(const Duration(seconds: 2));
    });

    test('hostilePieSettingsDrawOnlyFiniteGeometry', () {
      // Hostile settings rather than values, which reach the guards of drawHole, drawRoundedSlices and drawCenterText,
      // with the number of slices still drawn: a NaN hole radius leaves no hole (Kotlin's
      // `innerRadius > 0f` is false, so the slices are wedges to the center) and no center text; a transparent circle
      // radius that is not a number is never larger than the hole, so no ring is drawn, and an infinite one is, which
      // makes the ring infinite; NaN slice angles leave the rounded ends nowhere; a center text offset that is not
      // finite leaves the text box nowhere. Slice 0 is highlighted, so drawDataSet leaves it to drawHighlighted.
      final settings = <String, (List<double>, void Function(PieChart), int)>{
        'a hole radius that is not a number': (
          [1, 2, 3],
          (chart) => chart.holeRadius = double.nan,
          3,
        ),
        'a transparent circle radius that is not a number': (
          [1, 2, 3],
          (chart) => chart.transparentCircleRadius = double.nan,
          3,
        ),
        'an infinite transparent circle radius': (
          [1, 2, 3],
          (chart) => chart.transparentCircleRadius = double.infinity,
          3,
        ),
        'rounded slices with a NaN value': (
          [1, double.nan, 2],
          (chart) => chart.isDrawRoundedSlicesEnabled = true,
          0,
        ),
        'a center text offset that is not a number': (
          [1, 2, 3],
          (chart) => chart.setCenterTextOffset(double.nan, 0),
          3,
        ),
        'an infinite center text offset': (
          [1, 2, 3],
          (chart) => chart.setCenterTextOffset(0, double.infinity),
          3,
        ),
      };

      PieChart make(List<double> values, void Function(PieChart) hostile) {
        final chart = PieChart()..onSizeChanged(400, 300);
        chart.renderer = _RoundedSlicesRenderer(
          chart,
          chart.animator,
          chart.viewPortHandler,
        );
        chart.centerText = 'Total';
        chart.data = _data(values);
        chart.data!.dataSet!.isDrawValuesEnabled = true;
        hostile(chart);
        chart.notifyDataSetChanged();
        chart.highlightValue(0, 0);
        return chart;
      }

      int slicePaths(PieChart chart, RecordingCanvas canvas) {
        final color = chart.data!.dataSet!.getColor(0).toARGB32();
        return canvas.paths.where((p) => p.color.toARGB32() == color).length;
      }

      // With finite values the subclass reaches drawRoundedSlices: three rounded ends and the hole.
      final rounded = make([
        1,
        2,
        3,
      ], (c) => c.isDrawRoundedSlicesEnabled = true);
      final finite = _drawBoth(rounded);
      expect(finite.circles, hasLength(4));
      _expectFiniteGeometry(finite, 'finite rounded slices');

      for (final MapEntry(key: name, value: (values, hostile, slices))
          in settings.entries) {
        try {
          final chart = make(values, hostile);
          final canvas = _drawBoth(chart);
          _expectFiniteGeometry(canvas, name);
          expect(slicePaths(chart, canvas), slices, reason: '$name: slices');
        } catch (e, s) {
          fail('PieChart with $name: $e\n$s');
        }
      }
    });

    test('aCustomIconIsDrawnInsteadOfTheOutline', () {
      // EmptyStateTest.aCustomIconIsDrawnInsteadOfTheOutline: P0's Chart.drawEmptyState draws noDataIcon.
      final icon = _CountingDrawable();
      final chart = PieChart()..onSizeChanged(400, 300);
      chart.noDataIcon = icon;
      final canvas = RecordingCanvas();
      chart.onDraw(canvas);
      expect(icon.draws, 1);
      final bounds = icon.bounds!;
      expect(
        bounds.width() > 0 && bounds.height() > 0,
        isTrue,
        reason: 'icon bounds $bounds',
      );
      // Instead of the outline: no ring is stroked.
      expect(canvas.circles, isEmpty);
    });

    test('everyPieDrawsItsOwnOutline', () {
      RecordingCanvas outline(Chart chart) {
        chart.noDataText = '';
        chart.onSizeChanged(400, 300);
        final canvas = RecordingCanvas();
        chart.onDraw(canvas);
        return canvas;
      }

      final outlines = {
        'line': outline(LineChart()),
        'pie': outline(PieChart()),
        'radar': outline(RadarChart()),
      };
      for (final MapEntry(key: name, value: canvas) in outlines.entries) {
        expect(
          canvas.circles.isNotEmpty || canvas.paths.isNotEmpty,
          isTrue,
          reason: '$name draws no outline',
        );
      }
      String shape(RecordingCanvas c) => [
        ...c.calls,
        for (final circle in c.circles) 'circle ${circle.radius}',
        for (final path in c.paths) 'path ${path.bounds}',
      ].join(',');
      expect(
        outlines.values.map(shape).toSet(),
        hasLength(outlines.length),
        reason: 'the outline shapes should differ',
      );

      // The pie outline is a ring: a circle stroked a fifth of the icon height wide (24 dp high).
      final ring = outlines['pie']!.circles.single;
      expect(ring.style, ui.PaintingStyle.stroke);
      final height = Utils.convertDpToPixel(24);
      expect(ring.radius, closeTo((height - height / 5) / 2, 1e-4));

      // The radar outline is two hexagons stroked a twelfth of the icon height wide, the inner one half the size of the
      // outer one, which spans the icon height less the stroke width from corner to corner.
      final radar = outlines['radar']!;
      expect(radar.circles, isEmpty);
      expect(radar.paths, hasLength(2));
      final strokeWidth = height / 12;
      final outer = (height - strokeWidth) / 2;
      for (final hexagon in radar.paths) {
        expect(hexagon.style, ui.PaintingStyle.stroke);
        expect(hexagon.strokeWidth, closeTo(strokeWidth, 1e-4));
      }
      expect(radar.paths[0].bounds.height, closeTo(2 * outer, 1e-3));
      expect(radar.paths[1].bounds.height, closeTo(outer, 1e-3));
      // Corners up and down: the width is the height times cos 30°.
      expect(
        radar.paths[0].bounds.width,
        closeTo(2 * outer * math.cos(math.pi / 6), 1e-3),
      );
    });
  });
}
