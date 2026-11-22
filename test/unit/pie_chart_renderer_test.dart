// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/
// PieRendererTest.kt (aLabelWithLineBreaksIsDrawnAsLinesCenteredOnTheSingleLineSpot, split into its label and legend
// halves). The other cases are not ports of a Kotlin test: they pin what PieChartRenderer draws (slices, rings, the
// layer of decision D8, value lines, center text) on the RecordingCanvas, which stands in for the device tests'
// RecordingCanvas. The RecordingCanvas does not record text: drawn text shows as paragraphs with their
// offset. Their recorded width is the layout width, which is infinite for the unbounded labels of ChartCanvas.drawText,
// so the label positions are compared through the offsets and the line widths TextMeasure gives.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/pie_chart.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';
import 'package:mp_flutter_chart/src/renderer/pie_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

import '../recording/recording_canvas.dart';

const ui.Color _red = ui.Color(0xFFFF0000);
const ui.Color _green = ui.Color(0xFF00FF00);
const ui.Color _blue = ui.Color(0xFF0000FF);
const ui.Color _yellow = ui.Color(0xFFFFFF00);

/// PieRendererTest.pie: a 400 x 400 pie chart without legend and description, holding [entries]. [configure] runs
/// before the data is set.
PieChart _pie(
  List<PieEntry> entries, {
  void Function(PieChart chart, PieDataSet set)? configure,
  double size = 400,
}) {
  final chart = PieChart()..onSizeChanged(size, size);
  chart.legend.isEnabled = false;
  chart.description.isEnabled = false;
  final set = PieDataSet(entries, 'pie');
  configure?.call(chart, set);
  chart.data = PieData(set);
  return chart;
}

List<PieEntry> _ones(int n) => [for (var i = 0; i < n; i++) PieEntry(1)];

RecordingCanvas _draw(PieChart chart) {
  final canvas = RecordingCanvas();
  chart.onDraw(canvas);
  return canvas;
}

PieChartRenderer _renderer(PieChart chart) =>
    chart.renderer as PieChartRenderer;

int _count(RecordingCanvas canvas, String call) =>
    canvas.calls.where((c) => c == call).length;

void _expectRect(ui.Rect actual, ui.Rect expected, [double tolerance = 1e-4]) {
  expect(actual.left, closeTo(expected.left, tolerance));
  expect(actual.top, closeTo(expected.top, tolerance));
  expect(actual.right, closeTo(expected.right, tolerance));
  expect(actual.bottom, closeTo(expected.bottom, tolerance));
}

ui.Rect _circle(PieChart chart, double radius) {
  final c = chart.centerCircleBox;
  return ui.Rect.fromCircle(center: ui.Offset(c.x, c.y), radius: radius);
}

void main() {
  group('PieChartRenderer', () {
    test('eachVisibleSliceIsOneFilledPath', () {
      final chart = _pie(
        _ones(3),
        configure: (chart, set) {
          set.colors = [_red, _green, _blue];
          set.isDrawValuesEnabled = false;
          // No hole: the hole circle and the transparent ring are not drawn, every path is a slice.
          chart.isDrawHoleEnabled = false;
        },
      );
      final set = chart.data!.dataSet!;

      var canvas = _draw(chart);
      expect(canvas.paths, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(canvas.paths[i].style, ui.PaintingStyle.fill);
        expect(canvas.paths[i].color, set.getColor(i));
        expect(canvas.paths[i].fillType, ui.PathFillType.nonZero);
      }

      // An empty slice is skipped.
      chart.data = PieData(
        PieDataSet([PieEntry(1), PieEntry(0), PieEntry(1)], 'pie')
          ..colors = [_red, _green, _blue]
          ..isDrawValuesEnabled = false,
      );
      canvas = _draw(chart);
      expect(canvas.paths.map((p) => p.color), [_red, _blue]);

      chart.data!.dataSet!.isVisible = false;
      canvas = _draw(chart);
      expect(canvas.paths, isEmpty);
    });

    test('zeroSizedPieKeepsTheCanvasBalanced', () {
      final chart = PieChart()..onSizeChanged(0, 0);
      chart.legend.isEnabled = false;
      chart.description.isEnabled = false;
      chart.isTransparentCircleClippedToSlices = true;
      chart.data = PieData(PieDataSet(_ones(3), 'pie'));
      chart.highlightValue(1, 0);

      final canvas = RecordingCanvas();
      final before = canvas.getSaveCount();
      chart.onDraw(canvas);
      expect(canvas.calls, isNot(contains('saveLayer')));
      expect(canvas.paths, isEmpty);
      expect(canvas.circles, isEmpty);
      expect(canvas.getSaveCount(), before);

      // A chart that never got a size draws no slices either.
      final unsized = PieChart()..data = PieData(PieDataSet(_ones(3), 'pie'));
      unsized.isTransparentCircleClippedToSlices = true;
      final c2 = RecordingCanvas();
      unsized.onDraw(c2);
      expect(c2.calls, isNot(contains('saveLayer')));
      expect(c2.paths, isEmpty);
      expect(c2.getSaveCount(), 1);
    });

    test('aLayerOpensOnlyForAClippedTransparentCircle', () {
      final chart = _pie(
        _ones(3),
        configure: (chart, set) => set.colors = [_red, _green, _blue],
      );

      var canvas = _draw(chart);
      expect(_count(canvas, 'saveLayer'), 0);
      expect(canvas.getSaveCount(), 1);

      chart.isTransparentCircleClippedToSlices = true;
      expect(chart.transparentCircleRadius, greaterThan(chart.holeRadius));
      canvas = _draw(chart);
      expect(_count(canvas, 'saveLayer'), 1);
      expect(canvas.getSaveCount(), 1);
      // The layer holds the slices, the hole and the ring; the center text is drawn after it is closed.
      final layer = canvas.calls.indexOf('saveLayer');
      final closed = canvas.calls.indexOf('restoreToCount', layer);
      expect(closed, greaterThan(layer));
      expect(canvas.calls.indexOf('drawPath'), greaterThan(layer));
      expect(canvas.calls.lastIndexOf('drawPath'), lessThan(closed));
      expect(canvas.calls.indexOf('drawCircle'), greaterThan(layer));
      expect(canvas.calls.indexOf('clipPath'), greaterThan(closed));

      // Drawing again opens one layer again.
      canvas = _draw(chart);
      expect(_count(canvas, 'saveLayer'), 1);
      expect(canvas.getSaveCount(), 1);

      chart.isDrawHoleEnabled = false;
      canvas = _draw(chart);
      expect(_count(canvas, 'saveLayer'), 0);

      chart.isDrawHoleEnabled = true;
      chart.transparentCircleRadius = 40;
      canvas = _draw(chart);
      expect(_count(canvas, 'saveLayer'), 0);

      chart.transparentCircleRadius = 55;
      chart.transparentCircleAlpha = 0;
      canvas = _draw(chart);
      expect(_count(canvas, 'saveLayer'), 0);
    });

    test('theHoleAndTheTransparentCircleAreRings', () {
      final chart = _pie(
        _ones(3),
        configure: (chart, set) => set.colors = [_red, _green, _blue],
      );
      final r = chart.radius;
      final ringColor = const ui.Color(0xFFFFFFFF).withAlpha(105);
      expect(chart.transparentCircleColor, ringColor);
      expect(chart.transparentCircleAlpha, 105);

      var canvas = _draw(chart);
      // ui.Paint keeps its color in 32-bit floats, so a translucent color is compared as ARGB.
      final ring = canvas.paths
          .where((p) => p.color.toARGB32() == ringColor.toARGB32())
          .single;
      expect(ring.fillType, ui.PathFillType.evenOdd);
      expect(ring.style, ui.PaintingStyle.fill);
      _expectRect(ring.bounds, _circle(chart, r * 0.55));

      final hole = canvas.circles.single;
      expect(hole.color, chart.holeColor);
      expect(hole.color, const ui.Color(0xFFFFFFFF));
      expect(hole.radius, closeTo(r * 0.5, 1e-4));
      final c = chart.centerCircleBox;
      expect(hole.x, closeTo(c.x, 1e-4));
      expect(hole.y, closeTo(c.y, 1e-4));

      // transparentCircleColor keeps the alpha.
      chart.transparentCircleColor = _red;
      expect(chart.transparentCircleColor, _red.withAlpha(105));

      chart.holeColor = const ui.Color(0x00000000);
      canvas = _draw(chart);
      expect(canvas.circles, isEmpty);
    });

    test('aSingleSliceWithAHoleIsARing', () {
      final chart = _pie(
        [PieEntry(5)],
        configure: (chart, set) {
          set.colors = [_red];
          set.isDrawValuesEnabled = false;
        },
      );
      final canvas = _draw(chart);
      final slice = canvas.paths.where((p) => p.color == _red).single;
      expect(slice.fillType, ui.PathFillType.evenOdd);
      _expectRect(slice.bounds, chart.circleBox.toRect());

      // Without the hole it is a plain disc.
      chart.isDrawHoleEnabled = false;
      final disc = _draw(chart).paths.where((p) => p.color == _red).single;
      expect(disc.fillType, ui.PathFillType.nonZero);
      _expectRect(disc.bounds, chart.circleBox.toRect());
    });

    test('aHighlightedSliceGrowsBySelectionShift', () {
      final chart = _pie(
        _ones(4),
        configure: (chart, set) {
          set.colors = [_red, _green, _blue, _yellow];
          set.isDrawValuesEnabled = false;
        },
      );
      final set = chart.data!.dataSet! as PieDataSet;
      final shift = Utils.convertDpToPixel(set.selectionShift);
      expect(shift, 9);

      // Slice 0 spans 270 to 360: the top right quarter between the hole and the rim.
      final normal = _draw(chart).paths.where((p) => p.color == _red).single;
      chart.highlightValue(0, 0);
      final highlighted = _draw(
        chart,
      ).paths.where((p) => p.color == _red).single;

      expect(highlighted.bounds.top, closeTo(normal.bounds.top - shift, 0.5));
      expect(
        highlighted.bounds.right,
        closeTo(normal.bounds.right + shift, 0.5),
      );
      // The inner edge stays on the hole.
      expect(highlighted.bounds.left, closeTo(normal.bounds.left, 0.5));
      expect(highlighted.bounds.bottom, closeTo(normal.bounds.bottom, 0.5));

      // In the data set's highlight color when it has one.
      set.highlightColor = _green;
      final colored = _draw(chart).paths.where((p) => p.color == _green);
      expect(colored, hasLength(2));
      expect(_draw(chart).paths.where((p) => p.color == _red), isEmpty);

      // A single highlighted slice is the whole ring grown by the shift.
      final single = _pie(
        [PieEntry(1)],
        configure: (chart, set) {
          set.colors = [_red];
          set.isDrawValuesEnabled = false;
        },
      );
      single.highlightValue(0, 0);
      final grown = _draw(single).paths.where((p) => p.color == _red).single;
      expect(grown.fillType, ui.PathFillType.evenOdd);
      _expectRect(grown.bounds, single.circleBox.toRect().inflate(shift), 0.5);
    });

    test('valuesOutsideTheSliceGetValueLines', () {
      final chart = _pie(
        _ones(3),
        configure: (chart, set) {
          set.colors = [_red, _green, _blue];
          set.yValuePosition = ValuePosition.OUTSIDE_SLICE;
        },
      );
      final set = chart.data!.dataSet! as PieDataSet;
      expect(set.valueLineColor, const ui.Color(0xFF000000));

      // Kotlin draws each value line in two parts: out from the slice, then sideways to the label.
      var canvas = _draw(chart);
      final lines = canvas.lines.where((l) => l.color == set.valueLineColor);
      expect(lines, hasLength(6));
      expect(canvas.lines, hasLength(6));
      for (final line in lines) {
        expect(line.strokeWidth, Utils.convertDpToPixel(set.valueLineWidth));
      }
      // The second part of each line is horizontal and starts where the first part ends.
      for (var i = 0; i < 6; i += 2) {
        expect(canvas.lines[i + 1].p1, canvas.lines[i].p2);
        expect(canvas.lines[i + 1].p1.dy, canvas.lines[i + 1].p2.dy);
      }

      // In the slice color.
      set.isUseValueColorForLineEnabled = true;
      canvas = _draw(chart);
      expect(canvas.lines.map((l) => l.color), [
        _red,
        _red,
        _green,
        _green,
        _blue,
        _blue,
      ]);

      set.yValuePosition = ValuePosition.INSIDE_SLICE;
      canvas = _draw(chart);
      expect(canvas.lines, isEmpty);
    });

    test('aLabelWithLineBreaksIsDrawnAsLinesCenteredOnTheSingleLineSpot', () {
      void labelOnly(PieChart chart, PieDataSet set) {
        set.isDrawValuesEnabled = false;
        chart.isDrawCenterTextEnabled = false;
      }

      final singleChart = _pie([
        PieEntry(1, label: 'Single'),
      ], configure: labelOnly);
      final single = _draw(singleChart).paragraphs.single;
      final twoLines = _pie([
        PieEntry(1, label: 'Top\nBottom'),
      ], configure: labelOnly);
      final lines = _draw(twoLines).paragraphs;

      final style = _renderer(twoLines).paintEntryLabels.textStyle;
      final singleStyle = _renderer(singleChart).paintEntryLabels.textStyle;
      expect(lines, hasLength(2));

      // Centered labels: the left edge is half the measured line width left of the label spot.
      double width(String text, TextStyle style) =>
          TextMeasure.layout(text, style).width;
      final singleCenter = single.offset.dx + width('Single', singleStyle) / 2;
      expect(
        lines[0].offset.dx + width('Top', style) / 2,
        closeTo(singleCenter, 0.01),
      );
      expect(
        lines[1].offset.dx + width('Bottom', style) / 2,
        closeTo(singleCenter, 0.01),
      );
      expect(
        (lines[0].offset.dy + lines[1].offset.dy) / 2,
        closeTo(single.offset.dy, 0.01),
      );
      // One font spacing apart.
      expect(
        lines[1].offset.dy - lines[0].offset.dy,
        closeTo(_renderer(twoLines).paintEntryLabels.getFontSpacing(), 1e-4),
      );
    });

    test('theLegendJoinsTheLabelLines', () {
      final twoLines = _pie([PieEntry(1, label: 'Top\nBottom')]);
      expect(twoLines.legend.entries.first.label, 'Top Bottom');
    });

    test('centerTextIsClippedToTheHole', () {
      final chart = _pie(
        _ones(3),
        configure: (chart, set) {
          set.isDrawValuesEnabled = false;
          chart.centerText = 'Total';
        },
      );
      final renderer = _renderer(chart);
      final r = chart.radius;

      var canvas = _draw(chart);
      expect(canvas.clipPaths, hasLength(1));
      _expectRect(canvas.clipPaths.single.getBounds(), _circle(chart, r * 0.5));
      final text = canvas.paragraphs.single;
      // Laid out as wide as the hole (centerTextRadiusPercent 100) and centered in it.
      expect(text.width, math.max((2 * r * 0.5).ceilToDouble(), 1));
      expect(canvas.getSaveCount(), 1);
      final layouts = renderer.centerTextLayoutCount;
      expect(layouts, 1);

      // An unchanged text is not laid out again.
      canvas = _draw(chart);
      expect(canvas.paragraphs, hasLength(1));
      expect(renderer.centerTextLayoutCount, layouts);

      // A new text, new bounds or a new style is.
      chart.centerText = 'Sum';
      _draw(chart);
      expect(renderer.centerTextLayoutCount, layouts + 1);
      chart.centerTextRadiusPercent = 50;
      _draw(chart);
      expect(renderer.centerTextLayoutCount, layouts + 2);
      chart.centerTextSize = 20;
      _draw(chart);
      expect(renderer.centerTextLayoutCount, layouts + 3);
      _draw(chart);
      expect(renderer.centerTextLayoutCount, layouts + 3);

      // Disabled: no clip and no text.
      chart.isDrawCenterTextEnabled = false;
      canvas = _draw(chart);
      expect(canvas.clipPaths, isEmpty);
      expect(canvas.paragraphs, isEmpty);
    });

    test('aCenterTextThatIsNotDrawnIsNotLaidOut', () {
      final chart = _pie(
        _ones(3),
        configure: (chart, set) {
          set.isDrawValuesEnabled = false;
          chart.centerText = 'Total';
        },
      );
      final renderer = _renderer(chart);

      // A center text offset that is not finite leaves the text box not finite, so the text is not
      // drawn, and not laid out either: its bounds never equal the last ones, which would lay it out on every frame.
      for (final v in [double.nan, double.infinity, double.negativeInfinity]) {
        for (final (x, y) in [(v, 0.0), (0.0, v)]) {
          chart.setCenterTextOffset(x, y);
          final layouts = renderer.centerTextLayoutCount;
          for (var i = 0; i < 3; i++) {
            final canvas = _draw(chart);
            expect(canvas.paragraphs, isEmpty, reason: 'offset ($x, $y)');
            expect(canvas.clipPaths, isEmpty, reason: 'offset ($x, $y)');
          }
          expect(
            renderer.centerTextLayoutCount,
            layouts,
            reason: 'offset ($x, $y)',
          );
        }
      }

      // Back at a finite offset the text is laid out once and drawn.
      chart.setCenterTextOffset(0, 0);
      final layouts = renderer.centerTextLayoutCount;
      expect(_draw(chart).paragraphs, hasLength(1));
      expect(_draw(chart).paragraphs, hasLength(1));
      expect(renderer.centerTextLayoutCount, layouts + 1);
    });

    test('detachingReleasesTheCenterTextLayout', () {
      final chart = _pie(
        _ones(3),
        configure: (chart, set) {
          set.isDrawValuesEnabled = false;
          chart.centerText = 'Total';
        },
      );
      final renderer = _renderer(chart);

      _draw(chart);
      final layouts = renderer.centerTextLayoutCount;
      expect(layouts, 1);

      // Where Kotlin's PieChart.onDetachedFromWindow released the renderer's bitmap, the renderer disposes its cached
      // TextPainter, so the next draw lays the text out again.
      chart.onDetachedFromWindow();
      expect(_draw(chart).paragraphs, hasLength(1));
      expect(renderer.centerTextLayoutCount, layouts + 1);
      _draw(chart);
      expect(renderer.centerTextLayoutCount, layouts + 1);

      // Detaching twice, or before anything was drawn, is harmless.
      chart.onDetachedFromWindow();
      chart.onDetachedFromWindow();
      expect(_draw(chart).paragraphs, hasLength(1));
      expect(renderer.centerTextLayoutCount, layouts + 2);
      PieChart().onDetachedFromWindow();
    });
  });
}
