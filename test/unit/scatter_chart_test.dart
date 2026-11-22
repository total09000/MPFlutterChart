// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/ScatterBoundsTest.kt
//
// The device test runs on the recording canvas instead of a bitmap, on a chart laid out at the
// 1080 x 1200 of the device fixtures; `_CountingScatterSet` subclasses `ScatterDataSet` where Kotlin delegates the
// whole `IScatterDataSet` to a wrapped set, and is styled like `Fixtures.scatterSet` itself. The other tests are not
// ports, since MPAndroidChart v4.0.1 has no unit test for ScatterChart: they check what charts/ScatterChart.kt adds
// to BarLineChartBase (its renderer and x axis spacing, the scatter data and the empty state outline) and that NaN
// entries draw through the whole chart.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/scatter_chart.dart';
import 'package:mp_flutter_chart/src/charts/scatter_shape.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/scatter_data.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/i_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter_chart_renderer.dart';

import 'support/fixtures.dart';
import 'support/strict_canvas.dart';

/// Exposes the protected members of [ScatterChart].
class _TestScatterChart extends ScatterChart {
  void drawOutline(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) =>
      drawNoDataIcon(canvas, bounds, paint);
}

/// Counts calls to [getEntryForIndex], the fetch the renderer makes once per entry it draws.
class _CountingScatterSet extends ScatterDataSet {
  _CountingScatterSet(super.entries, super.label);

  int _fetches = 0;

  int get fetches => _fetches;

  @override
  Entry getEntryForIndex(int index) {
    _fetches++;
    return super.getEntryForIndex(index);
  }
}

void main() {
  test(
    'a new scatter chart draws with the scatter renderer and pads the x axis by half a unit',
    () {
      final chart = ScatterChart();

      expect(chart.renderer, isA<ScatterChartRenderer>());
      expect(chart.xAxis.spaceMin, 0.5);
      expect(chart.xAxis.spaceMax, 0.5);
      expect(chart.scatterData, isNull);

      final data = ScatterData([
        ScatterDataSet([Entry(x: 0, y: 1)], 'points'),
      ]);
      chart.data = data;
      expect(chart.scatterData, same(data));
    },
  );

  test('the empty state outline is four filled circles of a seventh of the '
      'height', () {
    final chart = _TestScatterChart();
    final canvas = StrictCanvas();
    final paint = ChartPaint()..style = PaintStyle.STROKE;

    chart.drawOutline(canvas, MutableRect(10, 20, 100, 90), paint);

    expect(paint.style, PaintStyle.FILL);
    // 90 wide and 70 high from (10, 20).
    final centers = [(0.15, 0.75), (0.4, 0.35), (0.62, 0.6), (0.85, 0.2)];
    expect(canvas.circles, hasLength(4));
    for (var i = 0; i < 4; i++) {
      final (fx, fy) = centers[i];
      final circle = canvas.circles[i];
      expect(circle.x, closeTo(10 + 90 * fx, 1e-4), reason: 'circle $i x');
      expect(circle.y, closeTo(20 + 70 * fy, 1e-4), reason: 'circle $i y');
      expect(circle.radius, closeTo(10, 1e-4), reason: 'circle $i radius');
      expect(circle.style, ui.PaintingStyle.fill, reason: 'circle $i style');
    }

    // Drawn by the empty state of a chart without data.
    final empty = ScatterChart()..onSizeChanged(400, 300);
    final emptyCanvas = StrictCanvas();
    empty.onDraw(emptyCanvas);
    expect(emptyCanvas.circles, hasLength(4));
  });

  test('entries with a NaN x or y draw through the chart without NaN '
      'geometry', () {
    for (final shape in [ScatterShape.TRIANGLE, ScatterShape.CIRCLE]) {
      // StrictCanvas lets a NaN triangle path through and drawCircleP / drawText leave NaN circles and labels out,
      // so the canvas cannot tell whether a NaN entry got to its shape or label. The shape renderer and the value
      // formatter can: they record every position and value they are given, then draw as usual.
      final shapes = <ui.Offset>[];
      final labels = <double>[];
      final real = ScatterDataSet.getRendererForShape(shape);
      final set =
          ScatterDataSet([
              Entry(x: 0, y: 2),
              Entry(x: 1, y: double.nan),
              Entry(x: 2, y: 5),
              Entry(x: double.nan, y: 4),
            ], 'points')
            ..shapeRenderer = IShapeRenderer.fromFunction((
              c,
              dataSet,
              viewPortHandler,
              posX,
              posY,
              renderPaint,
            ) {
              shapes.add(ui.Offset(posX, posY));
              real.renderShape(
                c,
                dataSet,
                viewPortHandler,
                posX,
                posY,
                renderPaint,
              );
            })
            ..valueFormatter = IValueFormatter.fromFunction((
              value,
              entry,
              dataSetIndex,
              viewPortHandler,
            ) {
              labels.add(value);
              return '$value';
            });
      final chart = ScatterChart()
        ..data = ScatterData([set])
        ..onSizeChanged(400, 300);

      for (final highlighted in [false, true]) {
        if (highlighted) chart.highlightValue(1, 0);
        shapes.clear();
        labels.clear();

        chart.onDraw(StrictCanvas());

        final where = '$shape, highlighted: $highlighted';
        expect(shapes, hasLength(2), reason: 'shapes drawn ($where)');
        for (final position in shapes) {
          expect(
            position.isFinite,
            isTrue,
            reason: 'shape at $position ($where)',
          );
        }
        expect(labels, [2, 5], reason: 'labels drawn ($where)');
      }
    }
  });

  group('ScatterBoundsTest', () {
    test('onlyFetchesTheEntriesOnScreen', () {
      const total = 100000;
      // Fixtures.scatterSet styles a set it builds itself; the counting subclass gets the same styling here.
      final countingSet = _CountingScatterSet(lineEntries(total), 'scatter')
        ..setScatterShape(ScatterShape.CIRCLE)
        ..scatterShapeSize = 3;
      quiet(countingSet);
      final chart = lay(ScatterChart());
      chart.data = ScatterData([countingSet]);
      final canvas = StrictCanvas();

      resetViewport(chart);
      zoomToVisiblePoints(chart, total, 300);
      panBy(chart, -300000);

      chart.onDraw(canvas);

      expect(
        countingSet.fetches,
        lessThan(total ~/ 10),
        reason: 'fetched ${countingSet.fetches} of $total entries',
      );
      // The 300 or so entries on screen are drawn, so they are fetched (302 fetches here); the bound of 100 only rules
      // out a draw that fetches next to nothing.
      expect(
        countingSet.fetches,
        greaterThanOrEqualTo(100),
        reason: 'fetched ${countingSet.fetches} of $total entries',
      );
    });
  });
}
