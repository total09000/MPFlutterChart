// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for HorizontalBarChart. Checks what
// charts/HorizontalBarChart.kt changes in BarChart (Review Focus #4): the swapped viewport handler, transformers,
// renderers and highlighter, the offsets with the axes swapped, the horizontal bar bounds, the marker position, the
// touch lookup with (y, x), the visible x range read along the height, the visible range setters that scale the other
// axis, and the empty state outline.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/bar_chart.dart';
import 'package:mp_flutter_chart/src/charts/horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/components/i_marker.dart';
import 'package:mp_flutter_chart/src/components/legend.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/matrix.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/highlight/horizontal_bar_highlighter.dart';
import 'package:mp_flutter_chart/src/listener/bar_line_chart_touch_listener.dart';
import 'package:mp_flutter_chart/src/renderer/horizontal_bar_chart_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/x_axis_renderer_horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/renderer/y_axis_renderer_horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/utils/horizontal_view_port_handler.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/transformer_horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

import 'support/strict_canvas.dart';

/// Exposes the protected members of [HorizontalBarChart].
class _TestHorizontalBarChart extends HorizontalBarChart {
  Float32List markerPosition(Highlight high) => getMarkerPosition(high);

  void drawOutline(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) =>
      drawNoDataIcon(canvas, bounds, paint);
}

/// Keeps the rounded rectangles in [keptRRects], because the Phase 0 RecordingCanvas only counts `drawRRect`.
/// Not named `rrects`: lane D's RecordingCanvas declares that as its own record list, and this class must compile
/// against both versions.
class _RRectCanvas extends StrictCanvas {
  final List<ui.RRect> keptRRects = [];

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    keptRRects.add(rrect);
    super.drawRRect(rrect, paint);
  }
}

/// Records where the chart draws it.
class _PositionMarker implements IMarker {
  final List<ui.Offset> positions = [];

  @override
  final MPPointF offset = MPPointF();

  @override
  MPPointF getOffsetForDrawingAtPoint(double posX, double posY) => offset;

  @override
  void refreshContent(Entry e, Highlight highlight) {}

  @override
  void draw(ui.Canvas canvas, double posX, double posY) =>
      positions.add(ui.Offset(posX, posY));
}

/// Five plain bars at x 0..4 with the values 1..5.
BarDataSet _plainSet([String label = 'plain']) => BarDataSet([
  for (var i = 0; i < 5; i++) BarEntry(x: i.toDouble(), y: i + 1.0),
], label);

/// A 400 x 300 horizontal bar chart without a host showing [data]; [setup] runs before the data is set.
_TestHorizontalBarChart _chart(
  BarData data, [
  void Function(_TestHorizontalBarChart chart)? setup,
]) {
  final chart = _TestHorizontalBarChart();
  setup?.call(chart);
  return chart
    ..data = data
    ..onSizeChanged(400, 300);
}

void _expectRect(MutableRect actual, MutableRect expected) {
  expect(actual.left, closeTo(expected.left, 1e-4), reason: 'left');
  expect(actual.top, closeTo(expected.top, 1e-4), reason: 'top');
  expect(actual.right, closeTo(expected.right, 1e-4), reason: 'right');
  expect(actual.bottom, closeTo(expected.bottom, 1e-4), reason: 'bottom');
}

void main() {
  test('a new horizontal bar chart swaps in the horizontal viewport handler, '
      'transformers, renderers and highlighter before anything captures them', () {
    final chart = HorizontalBarChart();
    final handler = chart.viewPortHandler;
    final left = chart.getTransformer(AxisDependency.LEFT);
    final right = chart.getTransformer(AxisDependency.RIGHT);

    expect(handler, isA<HorizontalViewPortHandler>());
    expect(left, isA<TransformerHorizontalBarChart>());
    expect(right, isA<TransformerHorizontalBarChart>());
    expect(left, isNot(same(right)));

    expect(chart.renderer, isA<HorizontalBarChartRenderer>());
    expect(chart.highlighter, isA<HorizontalBarHighlighter>());

    expect(chart.rendererXAxis, isA<XAxisRendererHorizontalBarChart>());
    expect(chart.rendererXAxis.transformer, same(left));
    expect(chart.rendererLeftYAxis, isA<YAxisRendererHorizontalBarChart>());
    expect(chart.rendererLeftYAxis.transformer, same(left));
    expect(chart.rendererRightYAxis, isA<YAxisRendererHorizontalBarChart>());
    expect(chart.rendererRightYAxis.transformer, same(right));

    // BarLineChartBase.init builds the touch listener from the handler of the moment, so the handler has to be
    // replaced before super.init().
    final listener = chart.chartTouchListener as BarLineChartTouchListener;
    expect(identical(listener.matrix, handler.matrixTouch), isTrue);

    // BarChart.init still runs.
    expect(chart.xAxis.spaceMin, 0.5);
    expect(chart.xAxis.spaceMax, 0.5);
  });

  test('the legend renderer, which Chart.init builds, places the legend with '
      'the horizontal viewport handler', () {
    // Its handler is protected, so this looks at where it draws: a stale handler that never got a size would put
    // a legend at the bottom right above and left of the chart.
    final chart = _chart(BarData([_plainSet()..isDrawValuesEnabled = false]), (
      chart,
    ) {
      chart.xAxis.isEnabled = false;
      chart.axisLeft.isEnabled = false;
      chart.axisRight.isEnabled = false;
      chart.description.isEnabled = false;
      chart.legend.horizontalAlignment = LegendHorizontalAlignment.RIGHT;
    });
    final canvas = StrictCanvas();
    chart.onDraw(canvas);

    final label = canvas.paragraphs.single.offset;
    expect(label.dx, inInclusiveRange(200, 400));
    expect(label.dy, inInclusiveRange(150, 300));
  });

  test('the value axes run along the width and the x axis along the height', () {
    final rightSet = BarDataSet([
      BarEntry(x: 0, y: 50),
      BarEntry(x: 1, y: 100),
    ], 'right')..axisDependency = AxisDependency.RIGHT;
    final chart = _chart(BarData([_plainSet(), rightSet]));
    final vph = chart.viewPortHandler;
    final xAxis = chart.xAxis;

    for (final (axis, yAxis) in [
      (AxisDependency.LEFT, chart.axisLeft),
      (AxisDependency.RIGHT, chart.axisRight),
    ]) {
      final bottomLeft = chart.getPixelForValues(
        yAxis.axisMinimum,
        xAxis.axisMinimum,
        axis,
      );
      expect(bottomLeft.x, closeTo(vph.contentLeft, 1e-3), reason: '$axis');
      expect(bottomLeft.y, closeTo(vph.contentBottom, 1e-3), reason: '$axis');

      final topRight = chart.getPixelForValues(
        yAxis.axisMaximum,
        xAxis.axisMaximum,
        axis,
      );
      expect(topRight.x, closeTo(vph.contentRight, 1e-3), reason: '$axis');
      expect(topRight.y, closeTo(vph.contentTop, 1e-3), reason: '$axis');
    }
  });

  test('the x axis labels take their width on the left at BOTTOM, on the right '
      'at TOP and on both sides when BOTH_SIDED', () {
    final chart = _chart(BarData([_plainSet()]), (chart) {
      chart.minOffset = 0;
      chart.legend.isEnabled = false;
      chart.axisLeft.isEnabled = false;
      chart.axisRight.isEnabled = false;
    });
    final vph = chart.viewPortHandler;

    for (final (position, onLeft, onRight) in [
      (XAxisPosition.BOTTOM, true, false),
      (XAxisPosition.TOP, false, true),
      (XAxisPosition.BOTH_SIDED, true, true),
      (XAxisPosition.BOTTOM_INSIDE, false, false),
    ]) {
      chart.xAxis.position = position;
      chart.notifyDataSetChanged();
      final width = chart.xAxis.labelRotatedWidth.toDouble();
      expect(width, greaterThan(0));

      expect(
        vph.offsetLeft,
        closeTo(onLeft ? width : 0, 1e-4),
        reason: '$position left',
      );
      expect(
        vph.offsetRight,
        closeTo(onRight ? width : 0, 1e-4),
        reason: '$position right',
      );
      expect(vph.offsetTop, 0, reason: '$position top');
      expect(vph.offsetBottom, 0, reason: '$position bottom');
    }

    chart.xAxis
      ..position = XAxisPosition.BOTTOM
      ..isEnabled = false;
    chart.notifyDataSetChanged();
    expect(vph.offsetLeft, 0);
  });

  test('the left axis labels take their height at the top and the right axis '
      'labels at the bottom, plus the extra offsets and at least minOffset', () {
    final chart = _chart(BarData([_plainSet()]), (chart) {
      chart.minOffset = 0;
      chart.legend.isEnabled = false;
      chart.xAxis.isEnabled = false;
      chart
        ..extraLeftOffset = 1
        ..extraTopOffset = 2
        ..extraRightOffset = 3
        ..extraBottomOffset = 4;
    });
    final vph = chart.viewPortHandler;
    final leftHeight = chart.axisLeft.getRequiredHeightSpace(
      chart.rendererLeftYAxis.paintAxisLabels,
    );
    final rightHeight = chart.axisRight.getRequiredHeightSpace(
      chart.rendererRightYAxis.paintAxisLabels,
    );
    expect(leftHeight, greaterThan(0));
    expect(rightHeight, greaterThan(0));

    expect(vph.offsetLeft, closeTo(1, 1e-4));
    expect(vph.offsetTop, closeTo(leftHeight + 2, 1e-4));
    expect(vph.offsetRight, closeTo(3, 1e-4));
    expect(vph.offsetBottom, closeTo(rightHeight + 4, 1e-4));

    chart.axisRight.isEnabled = false;
    chart.minOffset = 15;
    chart.notifyDataSetChanged();
    expect(vph.offsetLeft, closeTo(15, 1e-4));
    expect(vph.offsetBottom, closeTo(15, 1e-4));
  });

  test('a horizontal legend at the bottom also reserves the right axis labels '
      'and one at the top the left axis labels, as Kotlin does', () {
    final chart = _chart(BarData([_plainSet()]), (chart) {
      chart.minOffset = 0;
      chart.xAxis.isEnabled = false;
    });
    final vph = chart.viewPortHandler;
    final legend = chart.legend;
    final leftHeight = chart.axisLeft.getRequiredHeightSpace(
      chart.rendererLeftYAxis.paintAxisLabels,
    );
    final rightHeight = chart.axisRight.getRequiredHeightSpace(
      chart.rendererRightYAxis.paintAxisLabels,
    );
    double legendHeight() =>
        [legend.neededHeight, 300 * legend.maxSizePercent].reduce(
          (a, b) => a < b ? a : b,
        ) +
        Utils.convertDpToPixel(legend.yOffset);

    // The default legend: horizontal, at the bottom.
    expect(legend.neededHeight, greaterThan(0));
    expect(vph.offsetTop, closeTo(leftHeight, 1e-4));
    expect(
      vph.offsetBottom,
      closeTo(legendHeight() + 2 * rightHeight, 1e-4),
    );

    legend.verticalAlignment = LegendVerticalAlignment.TOP;
    chart.notifyDataSetChanged();
    expect(vph.offsetTop, closeTo(legendHeight() + 2 * leftHeight, 1e-4));
    expect(vph.offsetBottom, closeTo(rightHeight, 1e-4));

    legend
      ..orientation = LegendOrientation.VERTICAL
      ..horizontalAlignment = LegendHorizontalAlignment.RIGHT;
    chart.notifyDataSetChanged();
    expect(
      vph.offsetRight,
      closeTo(
        legend.neededWidth + Utils.convertDpToPixel(legend.xOffset),
        1e-4,
      ),
    );
    expect(vph.offsetTop, closeTo(leftHeight, 1e-4));
    expect(vph.offsetBottom, closeTo(rightHeight, 1e-4));
  });

  test('bar bounds are the pixel rectangle from 0 to y along the width, half a '
      'bar width either side of x along the height', () {
    final left = _plainSet('left');
    final negative = BarEntry(x: 5, y: -2);
    left.addEntry(negative);
    final right = BarDataSet([
      BarEntry(x: 0, y: 50),
      BarEntry(x: 1, y: 100),
    ], 'right')..axisDependency = AxisDependency.RIGHT;
    final data = BarData([left, right]);
    final chart = _chart(data);
    final half = data.barWidth / 2;

    /// The pixel rectangle from the value [fromY] at the entry x [topX] to the value [toY] at the entry x
    /// [bottomX]: the transformer takes the value first.
    MutableRect pixels(
      double fromY,
      double topX,
      double toY,
      double bottomX,
      AxisDependency axis,
    ) {
      final topLeft = chart.getPixelForValues(fromY, topX, axis);
      final bottomRight = chart.getPixelForValues(toY, bottomX, axis);
      return MutableRect(topLeft.x, topLeft.y, bottomRight.x, bottomRight.y);
    }

    final positive = left.getEntryForIndex(2);
    _expectRect(
      chart.getBarBounds(positive),
      pixels(0, 2 + half, 3, 2 - half, AxisDependency.LEFT),
    );
    _expectRect(
      chart.getBarBounds(negative),
      pixels(-2, 5 + half, 0, 5 - half, AxisDependency.LEFT),
    );
    _expectRect(
      chart.getBarBounds(right.getEntryForIndex(1)),
      pixels(0, 1 + half, 100, 1 - half, AxisDependency.RIGHT),
    );

    final output = MutableRect();
    expect(chart.getBarBounds(positive, output), same(output));
    _expectRect(output, pixels(0, 2 + half, 3, 2 - half, AxisDependency.LEFT));
  });

  test(
    'an entry that is not in the data has bounds of Float.MIN_VALUE on every side',
    () {
      final chart = _chart(BarData([_plainSet()]));
      List<double> sides(MutableRect r) => [r.left, r.top, r.right, r.bottom];
      const min = Utils.FLOAT_EPSILON;

      expect(sides(chart.getBarBounds(BarEntry(x: 2, y: 7))), [
        min,
        min,
        min,
        min,
      ]);
      expect(
        sides(HorizontalBarChart().getBarBounds(BarEntry(x: 0, y: 1))),
        [min, min, min, min],
        reason: 'a chart without data',
      );
    },
  );

  test('the marker of a highlighted bar sits at its tip, vertically centered '
      '(MPAndroidChart 3.x, not v4.0.1)', () {
    final set = _plainSet();
    final marker = _PositionMarker();
    final chart = _chart(BarData([set]))..marker = marker;
    chart.highlightValue(2, 0, callListener: false);
    final high = chart.highlighted.single;

    chart.onDraw(StrictCanvas());

    final bounds = chart.getBarBounds(set.getEntryForIndex(2));
    final position = chart.markerPosition(high);
    expect(position[0], closeTo(bounds.right, 1e-3));
    expect(position[1], closeTo(bounds.centerY(), 1e-3));

    expect(marker.positions, hasLength(1));
    expect(marker.positions.single.dx, closeTo(bounds.right, 1e-3));
    expect(marker.positions.single.dy, closeTo(bounds.centerY(), 1e-3));
  });

  test('the marker position is the draw position with x and y swapped', () {
    final chart = _TestHorizontalBarChart();
    final position = chart.markerPosition(Highlight(0, 0, 0)..setDraw(10, 20));
    expect(position, [20, 10]);
  });

  test('the position of an entry is the pixel of its (y, x)', () {
    final set = _plainSet();
    final chart = _chart(BarData([set]));
    final e = set.getEntryForIndex(3);

    final position = chart.getPosition(e, AxisDependency.LEFT)!;
    final expected = chart.getPixelForValues(e.y, e.x, AxisDependency.LEFT);
    expect(position.x, closeTo(expected.x, 1e-3));
    expect(position.y, closeTo(expected.y, 1e-3));

    // That is the tip of the bar, at its vertical center.
    final bounds = chart.getBarBounds(e);
    expect(position.x, closeTo(bounds.right, 1e-3));
    expect(position.y, closeTo(bounds.centerY(), 1e-3));

    expect(chart.getPosition(null, AxisDependency.LEFT), isNull);
  });

  test('a touch highlights the bar of the touched row, wherever along the row, '
      'and the whole stack with full bar highlighting', () {
    final chart = _chart(BarData([_plainSet()]));

    // Bar x = 2 is 3 long; the touch past its tip still selects it.
    for (final value in [1.5, 4.9]) {
      final touch = chart.getPixelForValues(value, 2, AxisDependency.LEFT);
      final h = chart.getHighlightByTouchPoint(touch.x, touch.y)!;
      expect(h.x, 2, reason: 'value $value');
      expect(h.y, 3, reason: 'value $value');
      expect(h.dataSetIndex, 0);
    }

    final stacked = _chart(
      BarData([
        BarDataSet([
          BarEntry.stacked(x: 0, stackValues: [1, 2]),
          BarEntry.stacked(x: 1, stackValues: [3, 4]),
        ], 'stack'),
      ]),
    );
    // The value 2 lies in the second section (1..3) of the bar at x = 0.
    final touch = stacked.getPixelForValues(2, 0, AxisDependency.LEFT);
    expect(stacked.getHighlightByTouchPoint(touch.x, touch.y)!.stackIndex, 1);

    stacked.isHighlightFullBarEnabled = true;
    final full = stacked.getHighlightByTouchPoint(touch.x, touch.y)!;
    expect(full.x, 0);
    expect(full.stackIndex, -1);

    expect(HorizontalBarChart().getHighlightByTouchPoint(100, 100), isNull);
  });

  test('the visible x range is read along the height: the x axis bounds fully '
      'zoomed out, half the range at a vertical zoom of 2', () {
    final chart = _chart(BarData([_plainSet()]));
    final xAxis = chart.xAxis;

    expect(chart.lowestVisibleX, closeTo(xAxis.axisMinimum, 1e-4));
    expect(chart.highestVisibleX, closeTo(xAxis.axisMaximum, 1e-4));

    final matrix = Matrix()..set(chart.viewPortHandler.matrixTouch);
    matrix.postScale(1, 2, 0, 0);
    chart.viewPortHandler.refresh(matrix, chart, false);

    expect(chart.lowestVisibleX, greaterThanOrEqualTo(xAxis.axisMinimum));
    expect(chart.highestVisibleX, lessThanOrEqualTo(xAxis.axisMaximum));
    expect(
      chart.highestVisibleX - chart.lowestVisibleX,
      closeTo(xAxis.axisRange / 2, 1e-4),
    );
    expect(chart.visibleXRange, closeTo(xAxis.axisRange / 2, 1e-4));
  });

  test('the visible x range limits the vertical scale and the visible y range '
      'the horizontal scale', () {
    final rightSet = BarDataSet([
      BarEntry(x: 0, y: 50),
    ], 'right')..axisDependency = AxisDependency.RIGHT;
    final data = BarData([_plainSet(), rightSet]);
    final xRange = _chart(data).xAxis.axisRange;
    expect(xRange, closeTo(5, 1e-4));

    var chart = _chart(data);
    var vph = chart.viewPortHandler;
    final defaultMax = vph.maxScaleX;
    chart.setVisibleXRangeMaximum(xRange / 2);
    expect(vph.minScaleY, closeTo(2, 1e-4));
    expect(vph.minScaleX, 1);
    chart.setVisibleXRangeMinimum(xRange / 5);
    expect(vph.maxScaleY, closeTo(5, 1e-4));
    expect(vph.maxScaleX, defaultMax);
    // A range that is not above 0 does nothing.
    chart.setVisibleXRangeMaximum(0);
    expect(vph.minScaleY, closeTo(2, 1e-4));

    chart = _chart(data);
    vph = chart.viewPortHandler;
    chart.setVisibleXRange(xRange / 4, xRange / 2);
    expect(vph.minScaleY, closeTo(2, 1e-4));
    expect(vph.maxScaleY, closeTo(4, 1e-4));
    expect(vph.minScaleX, 1);
    expect(vph.maxScaleX, defaultMax);

    chart = _chart(data);
    vph = chart.viewPortHandler;
    final leftRange = chart.axisLeft.axisRange;
    final rightRange = chart.axisRight.axisRange;
    expect(leftRange, isNot(closeTo(rightRange, 1e-4)));
    chart.setVisibleYRangeMaximum(leftRange / 2, AxisDependency.LEFT);
    expect(vph.minScaleX, closeTo(2, 1e-4));
    expect(vph.minScaleY, 1);
    chart.setVisibleYRangeMinimum(rightRange / 5, AxisDependency.RIGHT);
    expect(vph.maxScaleX, closeTo(5, 1e-4));
    expect(vph.maxScaleY, defaultMax);

    chart = _chart(data);
    vph = chart.viewPortHandler;
    chart.setVisibleYRange(
      rightRange / 4,
      rightRange / 2,
      AxisDependency.RIGHT,
    );
    expect(vph.minScaleX, closeTo(2, 1e-4));
    expect(vph.maxScaleX, closeTo(4, 1e-4));
    expect(vph.minScaleY, 1);
    expect(vph.maxScaleY, defaultMax);
  });

  test('setViewPortOffsets holds only until the next calculateOffsets, which '
      'recomputes the content rect, as in Kotlin; BarChart keeps it', () {
    // Kotlin's HorizontalBarChart.calculateOffsets has no customViewPortEnabled check, unlike BarLineChartBase's.
    final chart = _chart(BarData([_plainSet()]));
    final handler = chart.viewPortHandler;
    final automatic = MutableRect(
      handler.contentLeft,
      handler.contentTop,
      handler.contentRight,
      handler.contentBottom,
    );
    expect(automatic.left, isNot(closeTo(30, 1e-4)));

    // Without a host the offsets apply at once.
    chart.setViewPortOffsets(30, 40, 50, 60);
    _expectRect(handler.contentRect, MutableRect(30, 40, 350, 240));

    chart.notifyDataSetChanged();
    _expectRect(handler.contentRect, automatic);

    final bars = BarChart()
      ..data = BarData([_plainSet()])
      ..onSizeChanged(400, 300);
    bars.setViewPortOffsets(30, 40, 50, 60);
    bars.notifyDataSetChanged();
    _expectRect(
      bars.viewPortHandler.contentRect,
      MutableRect(30, 40, 350, 240),
    );
  });

  test('a touch lookup without data returns null, and logs that while '
      'logging is enabled', () {
    final chart = HorizontalBarChart()..onSizeChanged(400, 300);
    final logged = <String?>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logged.add(message);
    try {
      expect(chart.getHighlightByTouchPoint(100, 100), isNull);
      expect(logged, isEmpty);

      chart.isLogEnabled = true;
      expect(chart.getHighlightByTouchPoint(100, 100), isNull);
    } finally {
      debugPrint = previous;
    }
    expect(logged, ["MPAndroidChart: Can't select by touch. No data set."]);
  });

  test('the empty state outline is three bars from the left edge, 0.55, 1 and '
      '0.75 of the width long, top to bottom', () {
    final chart = _TestHorizontalBarChart();
    final canvas = _RRectCanvas();
    final paint = ChartPaint()..style = PaintStyle.STROKE;

    chart.drawOutline(canvas, MutableRect(10, 20, 100, 65), paint);

    expect(paint.style, PaintStyle.FILL);
    // 45 high: bars 10 high with gaps of 7.5, corner radius 10 / 3.5.
    expect(canvas.keptRRects, hasLength(3));
    final widths = [0.55, 1.0, 0.75];
    for (var i = 0; i < 3; i++) {
      final rrect = canvas.keptRRects[i];
      final top = 20 + i * 17.5;
      expect(rrect.left, closeTo(10, 1e-4), reason: 'bar $i left');
      expect(rrect.top, closeTo(top, 1e-4), reason: 'bar $i top');
      expect(
        rrect.right,
        closeTo(10 + 90 * widths[i], 1e-4),
        reason: 'bar $i right',
      );
      expect(rrect.bottom, closeTo(top + 10, 1e-4), reason: 'bar $i bottom');
      expect(rrect.tlRadiusX, closeTo(10 / 3.5, 1e-4), reason: 'bar $i radius');
      expect(rrect.tlRadiusY, closeTo(10 / 3.5, 1e-4), reason: 'bar $i radius');
    }

    // Drawn by the empty state of a chart without data.
    final empty = HorizontalBarChart()..onSizeChanged(400, 300);
    final emptyCanvas = _RRectCanvas();
    empty.onDraw(emptyCanvas);
    expect(emptyCanvas.keptRRects, hasLength(3));
    final lefts = emptyCanvas.keptRRects.map((r) => r.left).toSet();
    expect(lefts, hasLength(1));
    expect(
      emptyCanvas.keptRRects[0].top,
      lessThan(emptyCanvas.keptRRects[1].top),
    );
    expect(
      emptyCanvas.keptRRects[1].top,
      lessThan(emptyCanvas.keptRRects[2].top),
    );
  });
}
