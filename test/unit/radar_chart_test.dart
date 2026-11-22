// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/
// EdgeCaseTest.kt (the radar parts of highlightsPastTheDataClearTheSelection and everyChartDrawsEveryShapeOfData) and
// HostileInputTest.kt (its "radar 1, 2 and 7 entries", "all zero", "all NaN y", "float extremes" and "tiny range" cases
// and the PieRadarChartBase calls of extremeViewport: drawn in everyRadarShapeOfDataDraws, and drawn and touched as in
// hostileDataDrawsAndTakesTouches in hostileRadarDataDrawsAndTakesTouches). The other cases are not ports of a Kotlin
// test: MPAndroidChart has no unit test for RadarChart, RadarChartRenderer, XAxisRendererRadarChart,
// YAxisRendererRadarChart or RadarHighlighter, so they pin those against the Kotlin code. Charts are 400 x 400 and get
// their size before their data, as Fixtures.lay does. Cases that send touches run in testWidgets, for the gesture
// binding's fake clock and timers; the hostile replay also gives the touch listener that clock.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/chart.dart';
import 'package:mp_flutter_chart/src/charts/radar_chart.dart';
import 'package:mp_flutter_chart/src/components/limit_line.dart';
import 'package:mp_flutter_chart/src/components/marker_image.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/radar_data.dart';
import 'package:mp_flutter_chart/src/data/radar_data_set.dart';
import 'package:mp_flutter_chart/src/data/radar_entry.dart';
import 'package:mp_flutter_chart/src/formatter/i_axis_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/highlight/radar_highlighter.dart';
import 'package:mp_flutter_chart/src/renderer/radar_chart_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/x_axis_renderer_radar_chart.dart';
import 'package:mp_flutter_chart/src/renderer/y_axis_renderer_radar_chart.dart';
import 'package:mp_flutter_chart/src/utils/color_template.dart';
import 'package:mp_flutter_chart/src/utils/float_math.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

import '../recording/recording_canvas.dart';
import '../support/pie_radar_gestures.dart';

/// Kotlin's `Float.MAX_VALUE`.
const double _floatMax = 3.4028234663852886e38;

/// Kotlin's `Float.MIN_VALUE`, the smallest positive Float.
const double _floatMin = 1.401298464324817e-45;

/// One data set per list of values, labelled by its index.
RadarData _data(List<List<double>> sets) => RadarData([
  for (var i = 0; i < sets.length; i++)
    RadarDataSet([for (final v in sets[i]) RadarEntry(v)], 'set $i'),
]);

/// A 400 x 400 radar chart holding [sets].
RadarChart _radar(List<List<double>> sets) {
  final chart = RadarChart()..onSizeChanged(400, 400);
  chart.data = _data(sets);
  return chart;
}

/// Draws [chart] onto a RecordingCanvas and onto a real canvas, Kotlin's drawBoth (window and bitmap). The real canvas
/// asserts that no offset or rectangle it gets is NaN. Returns the RecordingCanvas.
RecordingCanvas _drawBoth(Chart chart) {
  final recording = RecordingCanvas();
  chart.onDraw(recording);
  final recorder = ui.PictureRecorder();
  chart.onDraw(ui.Canvas(recorder));
  recorder.endRecording().dispose();
  return recording;
}

/// Whether [v] is finite as a Float. A path clamps a coordinate beyond the Float range to it.
bool _isFloat(double v) => v.abs() < _floatMax;

/// No shape whose geometry is not finite as a Float reaches the canvas. A path with a point that is not a
/// number or infinite gets the empty bounds at the origin, where no path of a laid-out radar lies (a chart that is not
/// laid out draws everything at the origin, so that check needs [laidOut]); a larger double is clamped to the Float
/// range.
void _expectFiniteGeometry(
  RecordingCanvas canvas,
  String label, {
  required bool laidOut,
}) {
  for (final p in canvas.paths) {
    final b = p.bounds;
    expect(
      _isFloat(b.left) &&
          _isFloat(b.top) &&
          _isFloat(b.right) &&
          _isFloat(b.bottom),
      isTrue,
      reason: '$label: a path with bounds $b',
    );
    if (laidOut) {
      expect(
        p.bounds,
        isNot(ui.Rect.zero),
        reason: '$label: a path with a point that is not a number',
      );
    }
  }
  for (final l in canvas.lines) {
    expect(
      _isFloat(l.p1.dx) &&
          _isFloat(l.p1.dy) &&
          _isFloat(l.p2.dx) &&
          _isFloat(l.p2.dy),
      isTrue,
      reason: '$label: a line from ${l.p1} to ${l.p2}',
    );
  }
  for (final p in canvas.paragraphs) {
    expect(
      _isFloat(p.offset.dx) && _isFloat(p.offset.dy),
      isTrue,
      reason: '$label: text at ${p.offset}',
    );
  }
  for (final c in canvas.circles) {
    expect(
      _isFloat(c.x) && _isFloat(c.y) && _isFloat(c.radius),
      isTrue,
      reason: '$label: a circle at (${c.x}, ${c.y}) r ${c.radius}',
    );
  }
}

/// Records every x axis label and the position it is drawn at.
class _LabelRecorder extends XAxisRendererRadarChart {
  _LabelRecorder(super.viewPortHandler, super.xAxis, super.chart);

  final List<(String, double, double)> labels = [];

  @override
  void drawLabel(
    ui.Canvas c,
    String formattedLabel,
    double x,
    double y,
    MPPointF anchor,
    double angleDegrees,
  ) {
    labels.add((formattedLabel, x, y));
    expect(anchor.x, 0.5);
    expect(anchor.y, 0.25);
    super.drawLabel(c, formattedLabel, x, y, anchor, angleDegrees);
  }
}

double _distance(MPPointF a, double x, double y) =>
    math.sqrt(math.pow(x - a.x, 2) + math.pow(y - a.y, 2));

/// Draws [chart], a radar of one data set with five entries, and checks its web: no
/// line reaches beyond the radius, and the rings, one per y axis entry, lie at [fractions] of the radius, in order.
void _expectRingsAt(RadarChart chart, List<double> fractions) {
  final canvas = RecordingCanvas();
  chart.onDraw(canvas);
  final c = chart.centerOffsets;
  final radius = chart.radius;

  for (final l in canvas.lines) {
    expect(_distance(c, l.p1.dx, l.p1.dy), lessThan(radius + 1e-3));
    expect(_distance(c, l.p2.dx, l.p2.dy), lessThan(radius + 1e-3));
  }

  // The rings are 0.75 dp wide (theWebHasOneSpokePerEntryAndOneRingPerLabel), one line per y axis entry and data
  // entry, ring by ring.
  final rings = canvas.lines.where((l) => l.strokeWidth == 0.75).toList();
  expect(rings, hasLength(fractions.length * 5));
  for (var j = 0; j < fractions.length; j++) {
    for (final l in rings.sublist(j * 5, j * 5 + 5)) {
      final r = radius * fractions[j];
      expect(
        _distance(c, l.p1.dx, l.p1.dy),
        closeTo(r, 1e-3),
        reason: 'ring $j',
      );
      expect(
        _distance(c, l.p2.dx, l.p2.dy),
        closeTo(r, 1e-3),
        reason: 'ring $j',
      );
    }
  }
}

/// Every shape of data a radar chart must draw and take touches with: EdgeCaseTest.shapesOfValues, each making a data
/// set of all values and one of the first value only, the radar cases of HostileInputTest, and the two shapes that
/// [_hostileSettings] makes hostile.
Map<String, RadarData? Function()> _hostileShapes() {
  final shapesOfValues = <String, List<double>>{
    'no values': [],
    'one value': [3],
    'equal values': [2, 2, 2],
    'zeros': [0, 0, 0],
    'negative values': [-5, 3, -1],
    'a NaN': [1, double.nan, 2],
    'an infinity': [1, double.infinity, 2],
  };
  return {
    'null data': () => null,
    'no data sets': () => RadarData(),
    for (final MapEntry(key: name, value: values) in shapesOfValues.entries)
      name: () => RadarData([
        RadarDataSet([for (final v in values) RadarEntry(v)], 'a'),
        RadarDataSet([for (final v in values.take(1)) RadarEntry(v)], 'b'),
      ]),
    'radar 1, 2 and 7 entries': () => RadarData([
      RadarDataSet([RadarEntry(3)], 'one'),
      RadarDataSet([RadarEntry(1), RadarEntry(2)], 'two'),
      RadarDataSet([
        for (var i = 0; i < 7; i++) RadarEntry(i.toDouble()),
      ], 'seven'),
    ]),
    'all equal': () => _data([
      [4, 4, 4, 4, 4],
    ]),
    'all zero': () => _data([
      [0, 0, 0, 0, 0],
    ]),
    'all NaN': () => _data([
      [double.nan, double.nan, double.nan],
    ]),
    'float extremes': () => _data([
      [_floatMax, -_floatMax, _floatMin],
    ]),
    'huge and close': () => _data([
      [1e20, 1.00000001e20, 1e20],
    ]),
    // HostileInputTest "tiny range": the label interval rounds to 0, so the axis range is 0 and the factor infinite.
    'tiny range': () => _data([
      [_floatMin, 2 * _floatMin],
    ]),
    'a corner radius that is not a number': () => _data([
      [1, 2, 3, 4, 5],
    ]),
    'beyond a tiny fixed axis': () => _data([
      [1e30, 1e30, 1e30, 1e30, 1e30],
    ]),
  };
}

/// Hostile settings rather than values: a NaN corner radius makes every rounded corner NaN, and values far beyond a
/// tiny fixed axis range put the (sharp) corners and the highlight beyond the Float range.
final _hostileSettings = <String, void Function(RadarChart, RadarDataSet)>{
  'a corner radius that is not a number': (chart, first) =>
      first.cornerRadius = double.nan,
  'beyond a tiny fixed axis': (chart, first) {
    first.cornerRadius = 0;
    chart.yAxis.axisMinimum = 0;
    chart.yAxis.axisMaximum = 1e-30;
    chart.notifyDataSetChanged();
  },
};

/// Sets [data], made for [shape] of [_hostileShapes], on [chart] with every part of the renderer in use: the fill,
/// rounded corners and the highlight ring of the first data set, the [_hostileSettings] of [shape], a limit line, a
/// marker and a highlight of entry 0.
void _setHostileData(RadarChart chart, String shape, RadarData? data) {
  chart.data = data;
  final first = data?.getDataSetByIndex(0);
  if (first is RadarDataSet) {
    first
      ..isDrawFilledEnabled = true
      ..cornerRadius = 6
      ..isDrawHighlightCircleEnabled = true;
    _hostileSettings[shape]?.call(chart, first);
  }
  chart.yAxis.addLimitLine(LimitLine(1));
  chart.marker = MarkerImage(
    PainterDrawable((canvas, size) {}, width: 10, height: 10),
  );
  chart.highlightValue(0, 0);
}

void main() {
  group('RadarChart', () {
    test('defaultsMatchKotlin', () {
      final chart = RadarChart();

      expect(chart.webLineWidth, 1.5);
      expect(chart.webLineWidthInner, 0.75);
      // Color.rgb(122, 122, 122).
      expect(chart.webColor, const ui.Color.fromARGB(255, 122, 122, 122));
      expect(chart.webColorInner, const ui.Color.fromARGB(255, 122, 122, 122));
      expect(chart.webAlpha, 150);
      expect(chart.isDrawWebEnabled, isTrue);
      expect(chart.skipWebLineCount, 0);
      // Kotlin's setter: max(0, value).
      chart.skipWebLineCount = -3;
      expect(chart.skipWebLineCount, 0);
      chart.skipWebLineCount = 2;
      expect(chart.skipWebLineCount, 2);

      expect(chart.yAxis.axisDependency, AxisDependency.LEFT);
      expect(chart.yAxis.labelXOffset, 10);
      expect(chart.rotationAngle, 270);

      expect(chart.renderer, isA<RadarChartRenderer>());
      expect(chart.yAxisRenderer, isA<YAxisRendererRadarChart>());
      expect(chart.xAxisRenderer, isA<XAxisRendererRadarChart>());
      expect(chart.highlighter, isA<RadarHighlighter>());
      expect(
        (chart.renderer as RadarChartRenderer).webPaint.style,
        PaintStyle.STROKE,
      );

      // Without data the slice angle divides by one entry.
      expect(chart.sliceAngle, 360);

      // Decision D3 for the highlight circle of a radar data set.
      final set = RadarDataSet([RadarEntry(1)], '');
      expect(set.highlightCircleFillColor, const ui.Color(0xFFFFFFFF));
      expect(set.highlightCircleStrokeColor, ColorTemplate.COLOR_NONE);
      expect(set.highlightCircleStrokeAlpha, 76);
    });

    test('sliceAngleAndFactor', () {
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);

      expect(chart.sliceAngle, 72);

      final content = chart.viewPortHandler.contentRect;
      expect(chart.radius, math.min(content.width() / 2, content.height() / 2));
      expect(chart.factor, chart.radius / chart.yAxis.axisRange);
      expect(chart.yRange, chart.yAxis.axisRange);
      expect(chart.yChartMin, chart.yAxis.axisMinimum);
      expect(chart.yChartMax, chart.yAxis.axisMaximum);

      // computeAxes ran from notifyDataSetChanged: the y axis range is its first and last label value.
      final y = chart.yAxis;
      expect(y.entryCount, greaterThan(1));
      expect(y.axisMinimum, y.entries[0]);
      expect(y.axisMaximum, y.entries[y.entryCount - 1]);

      // calcMinMax: the x axis spans the entry count of the largest data set.
      expect(chart.xAxis.axisMinimum, 0);
      expect(chart.xAxis.axisMaximum, 5);
    });

    test('offsetsMakeRoomForTheLabels', () {
      // PieRadarChartBase.calculateOffsets, the RadarChart branch: without a legend the sides keep room for a label
      // width and the top and bottom for half a width plus a height, while the x axis draws labels.
      final chart = RadarChart()..onSizeChanged(400, 400);
      chart.legend.isEnabled = false;
      chart.data = _data([
        [1, 2, 3, 4, 5],
      ]);
      final vph = chart.viewPortHandler;
      final x = chart.xAxis;
      expect(x.labelRotatedWidth, greaterThan(1));
      expect(vph.offsetLeft, x.labelRotatedWidth);
      expect(vph.offsetRight, x.labelRotatedWidth);
      expect(vph.offsetTop, x.labelRotatedWidth / 2 + x.labelRotatedHeight);
      expect(vph.offsetBottom, x.labelRotatedWidth / 2 + x.labelRotatedHeight);

      // Without labels only the bottom keeps the 10 dp of requiredVerticalBaseOffset.
      x.isDrawLabelsEnabled = false;
      chart.notifyDataSetChanged();
      expect(vph.offsetLeft, 0);
      expect(vph.offsetRight, 0);
      expect(vph.offsetTop, 0);
      expect(vph.offsetBottom, 10);
    });

    test('getIndexForAngleSnapsToTheNearestSpoke', () {
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);
      expect(chart.rotationAngle, 270);

      // Kotlin: a = getNormalizedAngle(angle - 270); the reference angles are 72 (i + 1) - 36, that is 36, 108, 180,
      // 252 and 324, and the first one above a gives the index.
      expect(chart.getIndexForAngle(270), 0); // a = 0
      expect(chart.getIndexForAngle(300), 0); // a = 30 < 36
      expect(chart.getIndexForAngle(310), 1); // a = 40: 36 < 40 < 108
      expect(chart.getIndexForAngle(50), 2); // a = 140: 108 < 140 < 180
      // a = 340 is above every reference angle, so the index stays 0, the spoke at a = 0 (never -1).
      expect(chart.getIndexForAngle(250), 0);

      // Without data the loop does not run.
      expect(RadarChart().getIndexForAngle(123), 0);
    });

    test('computeAxisValuesMatchesKotlin', () {
      final chart = RadarChart();
      final axis = chart.yAxis;
      final renderer = chart.yAxisRenderer;
      expect(axis.labelCount, 6);

      // computeAxis without a transformer goes straight to computeAxisValues(0, 100). Kotlin, by hand:
      // range 100, rawInterval 100 / 6 = 16.67, roundToNextSignificant gives 20 (2 / 0.1f); the magnitude is
      // roundToNextSignificant(10^1) = 10 and the significant digit 2, so the interval stays 20. first = 0, last =
      // nextUp(floor(100 / 20) * 20) = nextUp(100); the loop counts f = 0, 20, 40, 60, 80, 100 (n = 6) and the radar
      // version adds one more label (n++ = 7). The entries are 0, 20, ..., 120, and the axis range becomes the first
      // and last of them: 0 .. 120.
      renderer.computeAxis(0, 100, false);
      expect(axis.entryCount, 7);
      expect(axis.entries.sublist(0, 7), [0, 20, 40, 60, 80, 100, 120]);
      expect(axis.decimals, 0);
      expect(axis.axisMinimum, 0);
      expect(axis.axisMaximum, 120);
      expect(axis.axisRange, 120);

      // Centered labels (entryCount is 7 from the last call): n starts at 1 and first moves back one interval to
      // -20; the loop counts -20 .. 100 (n = 8) and n++ gives 9 entries -20 .. 140. The centered entries are offset by
      // (entries[1] - entries[0]) / 2 = 10.
      axis.isCenterAxisLabelsEnabled = true;
      renderer.computeAxis(0, 100, false);
      expect(axis.entryCount, 9);
      expect(axis.entries.sublist(0, 9), [
        -20,
        0,
        20,
        40,
        60,
        80,
        100,
        120,
        140,
      ]);
      expect(axis.centeredEntries.sublist(0, 9), [
        -10,
        10,
        30,
        50,
        70,
        90,
        110,
        130,
        150,
      ]);
      expect(axis.axisMinimum, -20);
      expect(axis.axisMaximum, 140);
      axis.isCenterAxisLabelsEnabled = false;

      // Forced labels: step = 100f / 4f = 25, five entries from min, and the range is their first and last.
      axis.isForceLabelsEnabled = true;
      axis.labelCount = 5;
      renderer.computeAxis(0, 100, false);
      expect(axis.entryCount, 5);
      expect(axis.entries.sublist(0, 5), [0, 25, 50, 75, 100]);
      expect(axis.axisMinimum, 0);
      expect(axis.axisMaximum, 100);

      // An empty range: no entries, and the axis range is left as it was.
      axis.isForceLabelsEnabled = false;
      axis.labelCount = 6;
      renderer.computeAxis(5, 5, false);
      expect(axis.entries, isEmpty);
      expect(axis.entryCount, 0);
      expect(axis.axisMaximum, 100);
    });

    test('aCustomMaximumIsKept', () {
      // Regression for charter §7 item 1 (deliberate deviation), with RadarChartActivity's y axis:
      // labelCount 5 and a fixed 0 .. 80. By hand: range 80, rawInterval 80 / 5 = 16, roundToNextSignificant gives 20
      // (2 / 0.1f); the magnitude is 10 and the significant digit 2, so the interval stays 20. first = 0, last =
      // nextUp(floor(80 / 20) * 20) = nextUp(80); the loop counts f = 0, 20, 40, 60, 80 (n = 5). Kotlin's n++ adds
      // 100 and writes it back into the custom maximum, so every notifyDataSetChanged grows it (100, 120, 140, ...).
      // The port adds no entry for a custom maximum and keeps 80.
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);
      final y = chart.yAxis
        ..axisMinimum = 0
        ..axisMaximum = 80
        ..labelCount = 5;

      void expectKept(String when) {
        expect(y.isAxisMaxCustom, isTrue, reason: when);
        expect(y.axisMaximum, 80, reason: when);
        expect(y.axisMinimum, 0, reason: when);
        expect(y.axisRange, 80, reason: when);
        expect(y.entryCount, 5, reason: when);
        expect(y.entries.sublist(0, 5), [0, 20, 40, 60, 80], reason: when);
        expect(chart.yChartMax, 80, reason: when);
        expect(chart.yRange, 80, reason: when);
      }

      chart.notifyDataSetChanged();
      chart.notifyDataSetChanged();
      expectKept('after two notifyDataSetChanged calls');

      // Chart.kt:1037: a size change calls notifyDataSetChanged.
      chart.onSizeChanged(300, 360);
      expectKept('after a size change');
    });

    test('theWebEndsAtACustomMaximum', () {
      // On the fixed 0 .. 80 axis of aCustomMaximumIsKept the rings are the labels 0, 20, ..., 80, at
      // 0, 1/4, ..., 4/4 of the radius, so the outer ring lies on the radius and no web line reaches beyond it.
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);
      chart.yAxis
        ..axisMinimum = 0
        ..axisMaximum = 80
        ..labelCount = 5;
      chart.notifyDataSetChanged();
      chart.notifyDataSetChanged();

      _expectRingsAt(chart, [0, 0.25, 0.5, 0.75, 1]);
    });

    test('aCustomMaximumWithCenteredLabelsIsKept', () {
      // With a custom maximum no entry lies beyond `last`, the counting loop's own bound, so centering's
      // extra entry at the end is left out as well as Kotlin's n++.
      final chart = RadarChart();
      final renderer = chart.yAxisRenderer;
      final axis = chart.yAxis
        ..axisMaximum = 80
        ..labelCount = 5;
      // Centering reads as off while the axis has no entries, so a first pass gives it the five of
      // aCustomMaximumIsKept.
      renderer.computeAxis(0, 80, false);
      expect(axis.entryCount, 5);
      axis.isCenterAxisLabelsEnabled = true;

      // By hand: the interval is 20 (aCustomMaximumIsKept); n starts at 1 and first moves back one interval to -20;
      // the loop counts -20 .. 80 up to last = nextUp(80), and only those six entries are kept. The minimum is not
      // custom, so it is the first entry, as in Kotlin.
      renderer.computeAxis(0, 80, false);
      expect(axis.entryCount, 6);
      expect(axis.entries.sublist(0, 6), [-20, 0, 20, 40, 60, 80]);
      expect(axis.centeredEntries.sublist(0, 6), [-10, 10, 30, 50, 70, 90]);
      expect(axis.axisMaximum, 80);
      expect(axis.axisMinimum, -20);
      expect(axis.axisRange, 100);
      expect(axis.isAxisMaxCustom, isTrue);

      // Drawn: the minimum comes from the data, 1 - 10 % of (5 - 1) = 0.6. rawInterval 79.4 / 5 rounds to 20, first =
      // ceil(0.6 / 20) * 20 - 20 = 0, and the loop counts 0 .. 80: the rings lie at j / 4 of the radius.
      final radar = _radar([
        [1, 2, 3, 4, 5],
      ]);
      final y = radar.yAxis
        ..axisMaximum = 80
        ..labelCount = 5
        ..isCenterAxisLabelsEnabled = true;
      radar.notifyDataSetChanged();
      radar.notifyDataSetChanged();
      expect(y.entries.sublist(0, y.entryCount), [0, 20, 40, 60, 80]);
      expect(y.axisMinimum, 0);
      expect(y.axisMaximum, 80);
      _expectRingsAt(radar, [0, 0.25, 0.5, 0.75, 1]);
    });

    test('customLimitsWithForcedLabelsAreKept', () {
      final chart = RadarChart();
      final axis = chart.yAxis
        ..axisMinimum = 0
        ..axisMaximum = 1
        ..labelCount = 11
        ..isForceLabelsEnabled = true;

      // Rulings R-C20 and R-C28 with forced labels: step = 1f / 10f = 0.1f and the entries are Float sums from 0, as
      // in Kotlin, so the last one is 1.0000001. Kotlin applies it as the maximum; the custom maximum 1 is kept
      // exactly.
      chart.yAxisRenderer.computeAxis(0, 1, false);
      expect(axis.entryCount, 11);
      expect(axis.entries.sublist(0, 11), [
        0,
        0.10000000149011612,
        0.20000000298023224,
        0.30000001192092896,
        0.4000000059604645,
        0.5,
        0.6000000238418579,
        0.7000000476837158,
        0.8000000715255737,
        0.9000000953674316,
        1.0000001192092896,
      ]);
      expect(axis.axisMaximum, 1);
      expect(axis.axisMinimum, 0);
      expect(axis.axisRange, 1);

      // Not even an equal Float is written back: the entries are 0.1f and 0.7f, the limits stay the doubles 0.1 and
      // 0.7.
      axis
        ..axisMinimum = 0.1
        ..axisMaximum = 0.7
        ..labelCount = 2;
      chart.yAxisRenderer.computeAxis(0.1, 0.7, false);
      expect(axis.entryCount, 2);
      expect(axis.entries.sublist(0, 2), [
        toKotlinFloat(0.1),
        toKotlinFloat(0.7),
      ]);
      expect(axis.axisMinimum, 0.1);
      expect(axis.axisMaximum, 0.7);
      expect(axis.axisRange, 0.7 - 0.1);
    });

    test('customLimitsWithNoLabelInRangeLeaveNoEntries', () {
      // Rulings R-C20 and R-C28 when no label fits, by hand: labelCount 6 on a fixed 1 .. 9 with granularity 10. Range
      // 8, rawInterval 8 / 6 = 1.33 rounds to 1 and the granularity raises it to 10 (magnitude 10, digit 1). first =
      // ceil(1 / 10) * 10 = 10 and last = nextUp(floor(9 / 10) * 10) = nextUp(0), so the loop counts nothing (n = 0).
      // Kotlin's n++ makes the single entry 10 and the range 10 .. 10; here there is no entry, and the range runs from
      // the custom minimum to the custom maximum.
      RadarChart fixed(double max, {bool centered = false}) {
        final chart = _radar([
          [1, 2, 3, 4, 5],
        ]);
        chart.yAxis
          ..axisMinimum = 1
          ..axisMaximum = max
          ..granularity = 10
          ..isCenterAxisLabelsEnabled = centered;
        expect(chart.yAxis.labelCount, 6);
        chart.notifyDataSetChanged();
        return chart;
      }

      void expectNoEntries(RadarChart chart, String label) {
        final y = chart.yAxis;
        expect(y.entryCount, 0, reason: label);
        expect(y.isAxisMinCustom && y.isAxisMaxCustom, isTrue, reason: label);
        expect(y.axisMinimum, 1, reason: label);
        expect(y.axisMaximum, 9, reason: label);
        expect(y.axisRange, 8, reason: label);

        // The web is the five spokes only, and nothing else draws a line.
        final canvas = _drawBoth(chart);
        expect(canvas.lines, hasLength(5), reason: label);
        _expectFiniteGeometry(canvas, label, laidOut: true);
      }

      expectNoEntries(fixed(9), 'not centered');

      // Centered: first = 10 - 10 = 0, the loop counts 0 (n = 2 with centering's start). The custom maximum keeps only
      // 0, which lies below the custom minimum: no entry is left either.
      expectNoEntries(fixed(9, centered: true), 'centered');

      // Centered on 1 .. 19: rawInterval 18 / 6 = 3 is raised to 10, first = 0, last = nextUp(10), and the loop counts
      // 0 and 10. Without 0, below the minimum, one entry is left; its centered entry is half the interval above it.
      final one = fixed(19, centered: true).yAxis;
      expect(one.entryCount, 1);
      expect(one.entries[0], 10);
      expect(one.centeredEntries[0], 15);
      expect(one.axisMinimum, 1);
      expect(one.axisMaximum, 19);
      expect(one.axisRange, 18);

      // Only the maximum fixed: without an entry the range starts at the given minimum.
      final bare = RadarChart();
      final axis = bare.yAxis
        ..axisMaximum = 9
        ..granularity = 10;
      bare.yAxisRenderer.computeAxis(1, 9, false);
      expect(axis.entryCount, 0);
      expect(axis.isAxisMinCustom, isFalse);
      expect(axis.axisMinimum, 1);
      expect(axis.axisMaximum, 9);
      expect(axis.axisRange, 8);
    });

    test('aCustomMinimumIsKept', () {
      // A custom minimum is kept as set and never written back, and no entry lies below it. Kotlin writes
      // the first entry back into the field that holds a custom minimum. With centered labels that entry is one
      // interval below the first label, so the minimum falls on every notifyDataSetChanged (a fixed 0 .. 80 with five
      // labels becomes -20 .. 120, -30 .. 180, -40 .. 240, as the maximum grows too); without centering a minimum
      // between two labels jumps up to the first one (5 to 20).
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);
      final y = chart.yAxis
        ..axisMinimum = 0
        ..axisMaximum = 80
        ..labelCount = 5
        ..isCenterAxisLabelsEnabled = true;

      // Centered on a fixed 0 .. 80, by hand: interval 20, first = 0 - 20 = -20, and the loop counts -20 .. 80. The
      // shifted first entry lies below the minimum and is left out, which leaves 0 .. 80.
      for (var pass = 1; pass <= 3; pass++) {
        chart.notifyDataSetChanged();
        final when = 'centered, pass $pass';
        expect(y.isAxisMinCustom, isTrue, reason: when);
        expect(y.axisMinimum, 0, reason: when);
        expect(y.axisMaximum, 80, reason: when);
        expect(y.axisRange, 80, reason: when);
        expect(y.entries.sublist(0, y.entryCount), [
          0,
          20,
          40,
          60,
          80,
        ], reason: when);
        expect(y.centeredEntries.sublist(0, y.entryCount), [
          10,
          30,
          50,
          70,
          90,
        ], reason: when);
      }
      _expectRingsAt(chart, [0, 0.25, 0.5, 0.75, 1]);

      // Centered with only the minimum fixed: the maximum comes from the data, 5 + 10 % of (5 - 1) = 5.4. rawInterval
      // 5.4 / 5 = 1.08 rounds to 1, first = 0 - 1 = -1 and last = nextUp(5); the loop counts -1 .. 5, and centering's
      // extra entry and Kotlin's n++ add 6 and 7. Without the shifted first entry that leaves 0 .. 7.
      y.resetAxisMaximum();
      for (var pass = 1; pass <= 2; pass++) {
        chart.notifyDataSetChanged();
        final when = 'centered, computed maximum, pass $pass';
        expect(y.axisMinimum, 0, reason: when);
        expect(y.axisMaximum, 7, reason: when);
        expect(y.entries.sublist(0, y.entryCount), [
          0,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
        ], reason: when);
      }
      _expectRingsAt(chart, [for (var j = 0; j < 8; j++) j / 7]);

      // Not centered on a fixed 5 .. 80: rawInterval 75 / 5 = 15 rounds to 20, first = ceil(5 / 20) * 20 = 20, and the
      // loop counts 20 .. 80. The entries start at the first label above the minimum, which stays 5 (Kotlin: 20).
      y
        ..isCenterAxisLabelsEnabled = false
        ..axisMinimum = 5
        ..axisMaximum = 80;
      for (var pass = 1; pass <= 2; pass++) {
        chart.notifyDataSetChanged();
        final when = 'not centered, pass $pass';
        expect(y.axisMinimum, 5, reason: when);
        expect(y.axisMaximum, 80, reason: when);
        expect(y.axisRange, 75, reason: when);
        expect(y.entries.sublist(0, y.entryCount), [
          20,
          40,
          60,
          80,
        ], reason: when);
      }
      // The rings lie at (20 - 5) / 75, ..., (80 - 5) / 75 of the radius: none at the center, the outer one on it.
      _expectRingsAt(chart, [15 / 75, 35 / 75, 55 / 75, 1]);
    });

    test(
      'computeAxisValuesTerminatesForHugeCloseValues',
      () {
        final chart = RadarChart();
        final axis = chart.yAxis;
        final renderer = chart.yAxisRenderer;

        // Both bounds are rounded to Float first, and 1e20 + 65536 is the same Float as 1e20 (its ulp
        // there is 2^43), so the range is 0 and no entries are computed, as in Kotlin.
        renderer.computeAxis(1e20, 1e20 + 65536, false);
        expect(axis.entryCount, 0);
        expect(axis.entries.every((e) => e.isFinite), isTrue);

        // Two neighbouring Floats and a label count of two billion: the interval, 4000, is below half the double ulp
        // at 1e20 (16384), so f + interval == f and Kotlin's `while (f <= last)` never ends. The R28 guard stops
        // counting at the first label; n++ adds the radar's extra one.
        final low = toKotlinFloat(1e20);
        final high = low + 8796093022208.0; // + 2^43, the next Float
        expect(toKotlinFloat(high), high);
        axis.axisMaxLabels = 2147483647;
        axis.labelCount = 2000000000;
        renderer.computeAxis(low, high, false);
        expect(axis.entryCount, 2);
        expect(
          axis.entries.sublist(0, axis.entryCount).every((e) => e.isFinite),
          isTrue,
        );
        expect(axis.axisRange.isFinite, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test('theWebHasOneSpokePerEntryAndOneRingPerLabel', () {
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);

      // The spokes are 1.5 dp wide, the rings 0.75 dp; both in the web color at the web alpha.
      List<LineDraw> spokes(RecordingCanvas c) =>
          c.lines.where((l) => l.strokeWidth == 1.5).toList();
      List<LineDraw> rings(RecordingCanvas c) =>
          c.lines.where((l) => l.strokeWidth == 0.75).toList();
      RecordingCanvas draw(RadarChart chart) {
        final canvas = RecordingCanvas();
        chart.onDraw(canvas);
        return canvas;
      }

      var canvas = draw(chart);
      final labels = chart.yAxis.entryCount;
      expect(labels, greaterThan(1));
      expect(spokes(canvas), hasLength(5));
      // Kotlin's drawWeb draws one line per y axis entry and per entry of the data (radarData.entryCount).
      expect(rings(canvas), hasLength(labels * 5));
      expect(canvas.lines, hasLength(5 + labels * 5));
      for (final l in canvas.lines) {
        expect(l.color.toARGB32(), 0x967A7A7A);
      }

      // The first spoke runs from the center to the rim at the rotation angle, 270 (up).
      final c = chart.centerOffsets;
      final first = spokes(canvas).first;
      expect(first.p1.dx, closeTo(c.x, 1e-4));
      expect(first.p1.dy, closeTo(c.y, 1e-4));
      expect(first.p2.dx, closeTo(c.x, 1e-3));
      expect(first.p2.dy, closeTo(c.y - chart.radius, 1e-3));

      // skipWebLineCount leaves out spokes: i += 1 + skip.
      chart.skipWebLineCount = 1; // 0, 2, 4
      expect(spokes(draw(chart)), hasLength(3));
      chart.skipWebLineCount = 2; // 0, 3
      canvas = draw(chart);
      expect(spokes(canvas), hasLength(2));
      expect(rings(canvas), hasLength(labels * 5));
      chart.skipWebLineCount = 0;

      // With two data sets the rings are drawn once per entry of both, so every ring twice.
      final two = _radar([
        [1, 2, 3, 4, 5],
        [5, 4, 3, 2, 1],
      ]);
      canvas = draw(two);
      expect(spokes(canvas), hasLength(5));
      expect(rings(canvas), hasLength(two.yAxis.entryCount * 10));

      chart.isDrawWebEnabled = false;
      expect(draw(chart).lines, isEmpty);
    });

    test('filledSurfaceUsesTheFillColorAndCornerRadiusStaysInside', () {
      RadarChart make(double cornerRadius) {
        final chart = RadarChart()..onSizeChanged(400, 400);
        chart.yAxis.axisMinimum = 0;
        chart.data = RadarData([
          RadarDataSet([for (var i = 0; i < 5; i++) RadarEntry(10)], 'filled')
            ..isDrawFilledEnabled = true
            ..fillColor = const ui.Color(0xFF00AA00)
            ..cornerRadius = cornerRadius,
        ]);
        return chart;
      }

      final sharp = make(0);
      var canvas = RecordingCanvas();
      sharp.renderer.drawData(canvas);
      // drawFilledPathColor: the polygon clips a drawColor in the fill color at the fill alpha (85).
      expect(canvas.clipPaths, hasLength(1));
      expect(canvas.colors, [const ui.Color.fromARGB(85, 0, 0xAA, 0)]);
      // The fill is not opaque, so the outline is drawn as well.
      expect(canvas.paths, hasLength(1));
      expect(canvas.paths.single.style, ui.PaintingStyle.stroke);
      final sharpBounds = canvas.paths.single.bounds;
      expect(sharpBounds.isFinite, isTrue);
      expect(sharpBounds.isEmpty, isFalse);

      // A point just inside the top corner is inside the sharp polygon.
      final c = sharp.centerOffsets;
      final justInside = ui.Offset(c.x, c.y - 10 * sharp.factor + 1);
      expect(canvas.clipPaths.single.contains(justInside), isTrue);

      final round = make(12);
      canvas = RecordingCanvas();
      round.renderer.drawData(canvas);
      expect(canvas.clipPaths, hasLength(1));
      expect(canvas.paths, hasLength(1));
      final roundBounds = canvas.paths.single.bounds;
      expect(roundBounds.isFinite, isTrue);
      expect(roundBounds.left, greaterThanOrEqualTo(sharpBounds.left - 1e-3));
      expect(roundBounds.top, greaterThanOrEqualTo(sharpBounds.top - 1e-3));
      expect(roundBounds.right, lessThanOrEqualTo(sharpBounds.right + 1e-3));
      expect(roundBounds.bottom, lessThanOrEqualTo(sharpBounds.bottom + 1e-3));
      // The rounded corner is cut back 12 dp along both edges, so the same point is outside.
      expect(canvas.clipPaths.single.contains(justInside), isFalse);

      // An opaque fill draws no outline.
      final set = round.data!.getDataSetByIndex(0)! as RadarDataSet;
      set.fillAlpha = 255;
      canvas = RecordingCanvas();
      round.renderer.drawData(canvas);
      expect(canvas.clipPaths, hasLength(1));
      expect(canvas.paths, isEmpty);
    });

    test('highlightDrawsLinesAndAnOptionalRing', () {
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);
      final renderer = chart.renderer as RadarChartRenderer;
      final set = chart.data!.getDataSetByIndex(0)! as RadarDataSet;

      chart.highlightValue(2, 0);
      expect(chart.highlighted, hasLength(1));
      var canvas = RecordingCanvas();
      renderer.drawHighlighted(canvas, chart.highlighted);

      // The vertical and the horizontal highlight line through the corner of entry 2, and no ring.
      final corner = chart.getPosition(
        chart.centerOffsets,
        (3 - chart.yChartMin) * chart.factor,
        chart.sliceAngle * 2 + chart.rotationAngle,
      );
      final high = chart.highlighted.single;
      expect(high.drawX, closeTo(corner.x, 1e-3));
      expect(high.drawY, closeTo(corner.y, 1e-3));
      expect(canvas.paths, hasLength(2));
      expect(canvas.circles, isEmpty);
      expect(canvas.paths[0].bounds.left, closeTo(corner.x, 1e-3));
      expect(canvas.paths[1].bounds.top, closeTo(corner.y, 1e-3));
      for (final p in canvas.paths) {
        expect(p.color.toARGB32(), set.highlightColor.toARGB32());
      }

      set.isDrawHighlightCircleEnabled = true;
      canvas = RecordingCanvas();
      renderer.drawHighlighted(canvas, chart.highlighted);
      // The ring is two concentric circles filled even-odd, in the fill color (white), 4 dp outside.
      final ring = canvas.paths
          .where((p) => p.fillType == ui.PathFillType.evenOdd)
          .single;
      expect(ring.style, ui.PaintingStyle.fill);
      expect(ring.color.toARGB32(), 0xFFFFFFFF);
      expect(ring.bounds.width, closeTo(8, 1e-3));
      expect(ring.bounds.center.dx, closeTo(corner.x, 1e-3));
      expect(ring.bounds.center.dy, closeTo(corner.y, 1e-3));
      // Kotlin replaces the stroke color COLOR_NONE with the data set color, at the stroke alpha 76.
      final stroke = canvas.circles.single;
      expect(stroke.style, ui.PaintingStyle.stroke);
      expect(stroke.radius, 4);
      expect(stroke.color.toARGB32(), set.getColor(0).withAlpha(76).toARGB32());
      expect(canvas.getSaveCount(), 1);

      // Without a fill color only the stroke is drawn.
      set.highlightCircleFillColor = ColorTemplate.COLOR_NONE;
      canvas = RecordingCanvas();
      renderer.drawHighlighted(canvas, chart.highlighted);
      expect(
        canvas.paths.where((p) => p.fillType == ui.PathFillType.evenOdd),
        isEmpty,
      );
      expect(canvas.circles, hasLength(1));

      // drawHighlightCircle itself draws no stroke for COLOR_NONE ...
      canvas = RecordingCanvas();
      renderer.drawHighlightCircle(
        canvas,
        MPPointF(100, 100),
        3,
        4,
        const ui.Color(0xFFFFFFFF),
        ColorTemplate.COLOR_NONE,
        2,
      );
      expect(canvas.circles, isEmpty);
      expect(canvas.paths.single.fillType, ui.PathFillType.evenOdd);
      expect(canvas.getSaveCount(), 1);

      // ... and an inner radius of 0 fills a full disc, stroked when a stroke color is given.
      canvas = RecordingCanvas();
      renderer.drawHighlightCircle(
        canvas,
        MPPointF(100, 100),
        0,
        4,
        const ui.Color(0xFFFFFFFF),
        const ui.Color(0xFF000000),
        2,
      );
      expect(canvas.paths.single.bounds, ui.Rect.fromLTRB(96, 96, 104, 104));
      expect(canvas.circles.single.color.toARGB32(), 0xFF000000);

      // A highlight of an entry the data set does not have draws nothing.
      canvas = RecordingCanvas();
      renderer.drawHighlighted(canvas, [Highlight.stacked(7, 0, -1)]);
      expect(canvas.calls, isEmpty);
    });

    test('valuesAreDrawnAboveTheirCorners', () {
      // RadarChartRenderer.drawValues: each value text is centered on its corner, getPosition(center, (y - yChartMin)
      // * factor, sliceAngle * j + rotationAngle), with its baseline 5 dp above it. A corner that is not finite gets
      // no text, and a data set with its values off gets none.
      List<ui.Offset> expected(RadarChart chart) {
        final renderer = chart.renderer as RadarChartRenderer;
        final set = chart.data!.getDataSetByIndex(0)!;
        final style = renderer.paintValues.textStyle;
        final offsets = <ui.Offset>[];
        for (var j = 0; j < set.entryCount; j++) {
          final entry = set.getEntryForIndex(j);
          final corner = chart.getPosition(
            chart.centerOffsets,
            (entry.y - chart.yChartMin) * chart.factor,
            chart.sliceAngle * j + chart.rotationAngle,
          );
          if (!corner.x.isFinite || !corner.y.isFinite) continue;
          final painter = TextMeasure.layout(
            set.valueFormatter.getFormattedValue(
              entry.y,
              entry,
              0,
              chart.viewPortHandler,
            ),
            style,
          );
          offsets.add(
            ui.Offset(
              corner.x - painter.width / 2,
              corner.y -
                  Utils.convertDpToPixel(5) -
                  painter.computeDistanceToActualBaseline(
                    ui.TextBaseline.alphabetic,
                  ),
            ),
          );
        }
        return offsets;
      }

      RecordingCanvas values(RadarChart chart) {
        final canvas = RecordingCanvas();
        chart.renderer.drawValues(canvas);
        return canvas;
      }

      for (final (label, sets, count) in <(String, List<double>, int)>[
        ('five values', [1, 3, 2, 4, 5], 5),
        ('a NaN', [1, double.nan, 2], 2),
        ('an infinity', [1, double.infinity, 2], 2),
      ]) {
        final chart = _radar([sets])..rotationAngle = 30;
        final drawn = values(chart).paragraphs;
        final want = expected(chart);
        expect(drawn, hasLength(count), reason: label);
        expect(want, hasLength(count), reason: label);
        for (var k = 0; k < count; k++) {
          expect(
            drawn[k].offset,
            offsetMoreOrLessEquals(want[k], epsilon: 1e-3),
            reason: '$label, text $k',
          );
        }
      }

      final off = _radar([
        [1, 3, 2],
      ]);
      off.data!.getDataSetByIndex(0)!.isDrawValuesEnabled = false;
      expect(values(off).paragraphs, isEmpty);
    });

    test('radarHighlighterPicksTheClosestSetAtTheSpoke', () {
      final chart = RadarChart()..onSizeChanged(400, 400);
      // With the axis starting at 0 the distance from the center divided by the factor is the value itself, which
      // RadarHighlighter compares the entry values with.
      chart.yAxis.axisMinimum = 0;
      chart.data = _data([
        [2, 5, 5, 5, 5],
        [8, 5, 5, 5, 5],
      ]);
      expect(chart.yChartMin, 0);
      final c = chart.centerOffsets;

      // Points on spoke 0, which points up at the rotation angle.
      MPPointF onSpoke(double value) =>
          chart.getPosition(c, value * chart.factor, chart.rotationAngle);

      final near8 = onSpoke(7.6);
      var high = chart.getHighlightByTouchPoint(near8.x, near8.y)!;
      expect(high.dataSetIndex, 1);
      expect(high.x, 0);
      expect(high.y, 8);
      // The pixel position of the entry, not of the touch.
      final at8 = onSpoke(8);
      expect(high.xPx, closeTo(at8.x, 1e-3));
      expect(high.yPx, closeTo(at8.y, 1e-3));
      expect(high.axis, AxisDependency.LEFT);

      final near2 = onSpoke(2.5);
      high = chart.getHighlightByTouchPoint(near2.x, near2.y)!;
      expect(high.dataSetIndex, 0);
      expect(high.y, 2);

      // Beyond the radius nothing is highlighted.
      final outside = chart.getPosition(c, chart.radius + 5, 270);
      expect(chart.getHighlightByTouchPoint(outside.x, outside.y), isNull);
    });

    test('highlightsPastTheDataAreHarmless', () {
      final radar = RadarChart()..onSizeChanged(400, 400);
      radar.data = RadarData([
        RadarDataSet([for (var i = 0; i < 6; i++) RadarEntry(1)], 'long'),
        RadarDataSet([for (var i = 0; i < 2; i++) RadarEntry(2)], 'short'),
      ]);
      // Kotlin's Highlight(5f, 1, -1): x 5 in the data set 1, which has only two entries.
      radar.highlightValues([Highlight.stacked(5, 1, -1)]);
      final canvas = _drawBoth(radar);
      _expectFiniteGeometry(canvas, 'past the data', laidOut: true);

      final c = radar.centerOffsets;
      for (var angle = 0; angle < 360; angle += 15) {
        final rad = angle * math.pi / 180;
        final high = radar.getHighlightByTouchPoint(
          c.x + 100 * math.cos(rad),
          c.y + 100 * math.sin(rad),
        );
        // The short set only answers at its own two spokes.
        if (high != null && high.dataSetIndex == 1) {
          expect(high.x, lessThan(2));
        }
      }
    });

    test('everyRadarShapeOfDataDraws', () {
      // Laid-out shapes whose data-set outlines Kotlin still strokes, with their count, so that a skip of a shape
      // Kotlin draws fails. RadarChartRenderer.drawDataSet calls c.drawPath(surface, renderPaint) once per visible
      // data set unless its fill is opaque (fillAlpha 255; the filled first set keeps the default 85). It drops only a
      // corner whose x is NaN and builds the closed polygon from the corners left, also from one or two, so Android
      // strokes an outline for every data set with a corner left, as long as all of them are finite: 'a NaN' strokes
      // [1, 2] (its NaN corner dropped) and [1]; 'radar 1, 2 and 7 entries' its three sets of 1, 2 and 7 corners;
      // 'equal values' [2, 2, 2] and [2], whose y range of 0 the axis pads. The data sets of a shape share the default
      // color and line width, which no other stroked path of the chart has (the limit line and the highlight lines
      // have their own).
      const outlines = {
        'a NaN': 2,
        'radar 1, 2 and 7 entries': 3,
        'equal values': 2,
      };
      // A renamed shape fails here instead of leaving its count or its settings unused.
      expect(_hostileShapes().keys, containsAll(outlines.keys));
      expect(_hostileShapes().keys, containsAll(_hostileSettings.keys));
      for (final MapEntry(key: shape, value: make)
          in _hostileShapes().entries) {
        for (final laidOut in [true, false]) {
          final chart = RadarChart();
          if (laidOut) chart.onSizeChanged(400, 400);
          final label = '$shape (${laidOut ? 'laid out' : 'not laid out'})';
          try {
            _setHostileData(chart, shape, make());
            final canvas = _drawBoth(chart);
            _expectFiniteGeometry(canvas, label, laidOut: laidOut);
            final expected = outlines[shape];
            if (laidOut && expected != null) {
              final set = chart.data!.getDataSetByIndex(0)!;
              expect(
                canvas.paths.where(
                  (p) =>
                      p.style == ui.PaintingStyle.stroke &&
                      p.color.toARGB32() == set.color.toARGB32() &&
                      p.strokeWidth == Utils.convertDpToPixel(set.lineWidth),
                ),
                hasLength(expected),
                reason: '$label: the data-set outlines Kotlin strokes',
              );
            }

            for (final (name, call) in <(String, void Function())>[
              ('rotation 1e30', () => chart.rotationAngle = 1e30),
              ('rotation NaN', () => chart.rotationAngle = double.nan),
              ('spin', () => chart.spin(200, 0, 1e9)),
            ]) {
              call();
              _expectFiniteGeometry(
                _drawBoth(chart),
                '$label, $name',
                laidOut: laidOut,
              );
            }
          } catch (e, s) {
            fail('RadarChart with $label: $e\n$s');
          }
        }
      }
    });

    testWidgets('hostileRadarDataDrawsAndTakesTouches', (tester) async {
      // HostileInputTest.hostileDataDrawsAndTakesTouches and the PieRadarChartBase calls of extremeViewport: draw,
      // touch, highlight entry 0 and draw again, then for each hostile call draw and touch, every drawing finite.
      // _setHostileData highlights entry 0 before the first draw as well, which Kotlin does not. The
      // touch listener runs on the test binding's fake clock (useFakeClock), so every run sees the same fling velocity
      // and deceleration step.
      final logs = <(String, String?)>[];
      var shown = '';
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add((shown, message));
      try {
        var t = 0;
        for (final MapEntry(key: shape, value: make)
            in _hostileShapes().entries) {
          for (final laidOut in [true, false]) {
            final chart = RadarChart();
            if (laidOut) chart.onSizeChanged(400, 400);
            useFakeClock(tester, chart);
            final label = '$shape (${laidOut ? 'laid out' : 'not laid out'})';
            shown = shape;
            try {
              _setHostileData(chart, shape, make());
              void draw(String step) => _expectFiniteGeometry(
                _drawBoth(chart),
                '$label, $step',
                laidOut: laidOut,
              );
              // The rotation stays finite where Kotlin's does: everywhere but after `rotationAngle = NaN`, which
              // Kotlin keeps through the touches as well (a rotating touch measures its start angle from the NaN
              // rotation, and the fling adds to it), until the spin sets an angle again.
              void expectRotation(String step, {bool nan = false}) => expect(
                nan ? chart.rotationAngle.isNaN : chart.rotationAngle.isFinite,
                isTrue,
                reason: '$label, $step: rotation ${chart.rotationAngle}',
              );

              draw('first draw');
              t = touch(chart, t);
              expectRotation('touches');
              // HostileInputTest.kt:103: chart.highlightValue(firstX(chart), 0), and firstX is 0 for radar entries.
              chart.highlightValue(0, 0);
              draw('after touches');

              for (final (name, call) in <(String, void Function())>[
                ('rotation 1e30', () => chart.rotationAngle = 1e30),
                ('rotation NaN', () => chart.rotationAngle = double.nan),
                ('spin', () => chart.spin(200, 0, 1e9)),
              ]) {
                call();
                final nan = name == 'rotation NaN';
                expectRotation(name, nan: nan);
                draw(name);
                t = touch(chart, t);
                expectRotation('$name, touches', nan: nan);
              }
              draw('last draw');
            } catch (e, s) {
              fail('RadarChart with $label: $e\n$s');
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
    });

    test('xAxisLabelsSitAroundTheWeb', () {
      const names = ['A', 'B', 'C', 'D', 'E'];
      final chart = RadarChart()..onSizeChanged(400, 400);
      chart.xAxis.valueFormatter = IAxisValueFormatter.fromFunction(
        (value, axis) => names[value.toInt() % names.length],
      );
      final recorder = _LabelRecorder(
        chart.viewPortHandler,
        chart.xAxis,
        chart,
      );
      chart.xAxisRenderer = recorder;
      chart.data = _data([
        [1, 2, 3, 4, 5],
      ]);

      chart.onDraw(RecordingCanvas());
      expect(recorder.labels.map((l) => l.$1), names);

      // Each label is anchored half its rotated width beyond the web, at the angle of its spoke, raised by half its
      // rotated height.
      final c = chart.centerOffsets;
      final xAxis = chart.xAxis;
      final distance =
          chart.yRange * chart.factor + xAxis.labelRotatedWidth / 2;
      for (var i = 0; i < names.length; i++) {
        final (_, x, y) = recorder.labels[i];
        final p = chart.getPosition(
          c,
          distance,
          chart.sliceAngle * i + chart.rotationAngle,
        );
        expect(x, closeTo(p.x, 1e-3));
        expect(y, closeTo(p.y - xAxis.labelRotatedHeight / 2, 1e-3));
        expect(_distance(c, p.x, p.y), greaterThan(chart.radius));
      }

      // The offsets keep the five texts inside the chart (the text of a label is at most labelRotatedWidth wide and
      // labelRotatedHeight high), outside the content rectangle where the web is drawn.
      final canvas = RecordingCanvas();
      chart.xAxisRenderer.renderAxisLabels(canvas);
      expect(canvas.paragraphs, hasLength(5));
      for (final p in canvas.paragraphs) {
        expect(p.offset.dx, greaterThanOrEqualTo(0));
        expect(p.offset.dx + xAxis.labelRotatedWidth, lessThanOrEqualTo(400));
        expect(p.offset.dy, greaterThanOrEqualTo(0));
        expect(p.offset.dy + xAxis.labelRotatedHeight, lessThanOrEqualTo(400));
      }

      // No labels without the axis or its labels; limit lines are not drawn on the x axis.
      xAxis.isDrawLabelsEnabled = false;
      final none = RecordingCanvas();
      chart.xAxisRenderer.renderAxisLabels(none);
      expect(none.calls, isEmpty);
      xAxis.addLimitLine(LimitLine(2));
      chart.xAxisRenderer.renderLimitLines(none);
      expect(none.calls, isEmpty);
    });

    test('yAxisLabelsRunAlongTheFirstSpoke', () {
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);
      final y = chart.yAxis;

      var canvas = RecordingCanvas();
      chart.yAxisRenderer.renderAxisLabels(canvas);
      expect(canvas.paragraphs, hasLength(y.entryCount));
      // Up the spoke at the rotation angle (270): the first label lowest, at the center height.
      final ys = [for (final p in canvas.paragraphs) p.offset.dy];
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], lessThan(ys[i - 1]));
      }

      y.isDrawTopYLabelEntryEnabled = false;
      canvas = RecordingCanvas();
      chart.yAxisRenderer.renderAxisLabels(canvas);
      expect(canvas.paragraphs, hasLength(y.entryCount - 1));
      y.isDrawBottomYLabelEntryEnabled = false;
      canvas = RecordingCanvas();
      chart.yAxisRenderer.renderAxisLabels(canvas);
      expect(canvas.paragraphs, hasLength(y.entryCount - 2));
    });

    test('limitLinesAreClosedPolygonsAroundTheWeb', () {
      final chart = _radar([
        [1, 2, 3, 4, 5],
      ]);
      final limit = LimitLine(3)..lineColor = const ui.Color(0xFF0000FF);
      chart.yAxis.addLimitLine(limit);
      chart.yAxis.addLimitLine(LimitLine(4)..isEnabled = false);

      final canvas = RecordingCanvas();
      chart.yAxisRenderer.renderLimitLines(canvas);
      final polygon = canvas.paths.single;
      expect(polygon.color.toARGB32(), 0xFF0000FF);
      expect(polygon.style, ui.PaintingStyle.stroke);
      // The top corner sits on spoke 0 at the radius of the limit.
      final r = (3 - chart.yChartMin) * chart.factor;
      expect(polygon.bounds.top, closeTo(chart.centerOffsets.y - r, 1e-3));
      // No label is drawn.
      expect(canvas.paragraphs, isEmpty);
    });
  });
}
