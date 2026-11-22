// Tests for renderer/LineChartRenderer.kt on a RecordingCanvas; no Kotlin unit-test counterpart (the
// device tests' LineRendererTest checks the same draw calls on Android).
//
// The fake chart prepares real transformers: content rect 0..100 x 0..100; x 0..10 → 0..100 px (10 px per x);
// y 0..100 → 100..0 px (1 px per y).
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/formatter/default_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/line_data_provider.dart';
import 'package:mp_flutter_chart/src/renderer/line_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import '../recording/recording_canvas.dart';

class _FakeChart extends LineDataProvider {
  _FakeChart(this.lineData, this.handler) {
    _transformer
      ..prepareMatrixValuePx(0, 10, 100, 0)
      ..prepareMatrixOffset(false);
  }

  final ViewPortHandler handler;
  late final Transformer _transformer = Transformer(handler);

  @override
  LineData? lineData;

  @override
  LineData? get data => lineData;

  @override
  Transformer getTransformer(AxisDependency axis) => _transformer;

  @override
  bool isInverted(AxisDependency axis) => false;

  @override
  YAxis getAxis(AxisDependency axis) => YAxis(axis);

  @override
  double get lowestVisibleX => 0;

  @override
  double get highestVisibleX => 10;

  @override
  double get xChartMin => 0;

  @override
  double get xChartMax => 10;

  @override
  double get xRange => 10;

  @override
  double get yChartMin => 0;

  @override
  double get yChartMax => 100;

  @override
  double get maxHighlightDistance => 500;

  @override
  MPPointF get centerOfView => MPPointF.getInstance(0, 0);

  @override
  MPPointF get centerOffsets => MPPointF.getInstance(0, 0);

  @override
  MutableRect get contentRect => handler.contentRect;

  @override
  IValueFormatter get defaultValueFormatter => DefaultValueFormatter(0);

  @override
  int get maxVisibleCount => 100;
}

LineDataSet _set(List<List<double>> xy) =>
    LineDataSet([for (final p in xy) Entry(x: p[0], y: p[1])], 'line');

const _threePoints = [
  [0.0, 10.0],
  [5.0, 50.0],
  [10.0, 90.0],
];

LineChartRenderer _renderer(LineDataSet set) {
  final handler = ViewPortHandler()..setChartDimens(100, 100);
  final chart = _FakeChart(LineData([set]), handler);
  return LineChartRenderer(chart, ChartAnimator(), handler);
}

void main() {
  group('LINEAR', () {
    test('drawData draws the three points as one drawLines call', () {
      final set = _set(_threePoints);
      final canvas = RecordingCanvas();
      _renderer(set).drawData(canvas);

      expect(canvas.drawRawPointsCalls, 1);
      expect(canvas.drawPathCalls, 0);
      expect(canvas.drawImageCalls, 0);
      final draw = canvas.rawPoints.single;
      expect(draw.mode, ui.PointMode.lines);
      // The first segment starts and ends at the first entry, as in Kotlin.
      expect(draw.points.toList(), [
        0, 90, 0, 90, //
        0, 90, 50, 50, //
        50, 50, 100, 10, //
      ]);
      expect(draw.color.toARGB32(), set.color.toARGB32());
    });

    test(
      'drawExtras draws a circle and its hole at each of the three points',
      () {
        final set = _set(_threePoints);
        final canvas = RecordingCanvas();
        _renderer(set).drawExtras(canvas);

        final outer = canvas.circles
            .where((c) => c.radius == set.circleRadius)
            .toList();
        final holes = canvas.circles
            .where((c) => c.radius == set.circleHoleRadius)
            .toList();
        expect(outer.length, 3);
        expect(holes.length, 3);
        expect(
          [for (final c in outer) (c.x, c.y)],
          [(0, 90), (50, 50), (100, 10)],
        );
        expect(outer.first.color.toARGB32(), set.getCircleColor(0).toARGB32());
        expect(holes.first.color.toARGB32(), set.circleHoleColor.toARGB32());
        expect(canvas.drawImageCalls, 0);
      },
    );

    test('without a hole only the circles are drawn', () {
      final set = _set(_threePoints)..isDrawCircleHoleEnabled = false;
      final canvas = RecordingCanvas();
      _renderer(set).drawExtras(canvas);
      expect(canvas.drawCircleCalls, 3);
    });

    test('a transparent hole is drawn as one even-odd path per circle', () {
      final set = _set(_threePoints)
        ..circleHoleColor = const ui.Color(0x00112233);
      final canvas = RecordingCanvas();
      _renderer(set).drawExtras(canvas);
      expect(canvas.drawCircleCalls, 0);
      expect(canvas.drawPathCalls, 3);
      for (final path in canvas.paths) {
        expect(path.fillType, ui.PathFillType.evenOdd);
        expect(path.bounds.width, closeTo(set.circleRadius * 2, 1e-3));
      }
    });

    test('a data set without circle colors draws no circles', () {
      final set = _set(_threePoints)..resetCircleColors();
      final canvas = RecordingCanvas();
      _renderer(set).drawExtras(canvas);
      expect(canvas.drawCircleCalls, 0);
      expect(canvas.drawPathCalls, 0);
    });

    test(
      'a filled set clips to the fill path and fills it with the fill color',
      () {
        final set = _set(_threePoints)..isDrawFilledEnabled = true;
        final canvas = RecordingCanvas();
        _renderer(set).drawData(canvas);
        expect(canvas.clipPaths.length, 1);
        expect(canvas.drawColorCalls, 1);
        expect(
          canvas.colors.single.toARGB32(),
          set.fillColor.withAlpha(set.fillAlpha).toARGB32(),
        );
        expect(canvas.getSaveCount(), 1);
      },
    );

    test('several colors draw one drawLines call per segment', () {
      final set = _set(_threePoints)
        ..colors = [const ui.Color(0xFFFF0000), const ui.Color(0xFF00FF00)];
      final canvas = RecordingCanvas();
      _renderer(set).drawData(canvas);
      expect(canvas.drawRawPointsCalls, 2);
      expect(canvas.rawPoints.map((d) => d.color.toARGB32()).toList(), [
        0xFFFF0000,
        0xFF00FF00,
      ]);
    });
  });

  group('without an offscreen bitmap', () {
    for (final mode in [
      LineDataSetMode.CUBIC_BEZIER,
      LineDataSetMode.HORIZONTAL_BEZIER,
    ]) {
      test('$mode draws one path straight onto the canvas', () {
        final set = _set(_threePoints)..mode = mode;
        final canvas = RecordingCanvas();
        _renderer(set).drawData(canvas);
        expect(canvas.drawImageCalls, 0);
        expect(canvas.drawPictureCalls, 0);
        expect(canvas.drawPathCalls, 1);
        expect(canvas.paths.single.style, ui.PaintingStyle.stroke);
        expect(canvas.paths.single.bounds.left, closeTo(0, 1e-3));
        expect(canvas.paths.single.bounds.right, closeTo(100, 1e-3));
      });

      test('$mode with a fill clips to the fill and fills it', () {
        final set = _set(_threePoints)
          ..mode = mode
          ..isDrawFilledEnabled = true;
        final canvas = RecordingCanvas();
        _renderer(set).drawData(canvas);
        expect(canvas.drawImageCalls, 0);
        expect(canvas.clipPaths.length, 1);
        expect(canvas.drawColorCalls, 1);
        expect(canvas.drawPathCalls, 1);
      });
    }

    test('a dashed linear line is dashed onto the canvas', () {
      final set = _set(_threePoints)..enableDashedLine(4, 2, 0);
      final canvas = RecordingCanvas();
      _renderer(set).drawData(canvas);
      expect(canvas.drawImageCalls, 0);
      expect(canvas.drawRawPointsCalls, 0);
      expect(canvas.drawPathCalls, 1);
    });
  });

  // Kotlin composites its offscreen bitmap (bezier fills and lines, dashed linear lines) after all data sets, so
  // those stack above every linear fill and plain linear line whatever the data set order.
  group('stacking of the offscreen pieces', () {
    const fillCalls = {'drawColor', 'drawRawPoints', 'drawPath'};
    List<String> draws(RecordingCanvas c) =>
        c.calls.where(fillCalls.contains).toList();
    int rgb(ui.Color color) => color.toARGB32() & 0xFFFFFF;

    LineChartRenderer renderer(
      List<LineDataSet> sets, [
      ViewPortHandler? handler,
    ]) {
      handler ??= ViewPortHandler()..setChartDimens(100, 100);
      return LineChartRenderer(
        _FakeChart(LineData(sets), handler),
        ChartAnimator(),
        handler,
      );
    }

    test('a cubic set before a linear set is drawn after it', () {
      final a = _set(_threePoints)
        ..mode = LineDataSetMode.CUBIC_BEZIER
        ..isDrawFilledEnabled = true
        ..fillColor = const ui.Color(0xFFFF0000)
        ..color = const ui.Color(0xFFAA0000);
      final b = _set(_threePoints)
        ..isDrawFilledEnabled = true
        ..fillColor = const ui.Color(0xFF0000FF)
        ..color = const ui.Color(0xFF0000AA);
      final canvas = RecordingCanvas();
      renderer([a, b]).drawData(canvas);

      // B's fill and line, then A's fill and line.
      expect(draws(canvas), [
        'drawColor',
        'drawRawPoints',
        'drawColor',
        'drawPath',
      ]);
      expect(canvas.colors.map(rgb).toList(), [0x0000FF, 0xFF0000]);
      expect(rgb(canvas.rawPoints.single.color), 0x0000AA);
      expect(rgb(canvas.paths.single.color), 0xAA0000);
      expect(canvas.getSaveCount(), 1);
    });

    test('a linear set before a cubic set keeps the data set order', () {
      final a = _set(_threePoints)..isDrawFilledEnabled = true;
      final b = _set(_threePoints)
        ..mode = LineDataSetMode.HORIZONTAL_BEZIER
        ..isDrawFilledEnabled = true;
      final canvas = RecordingCanvas();
      renderer([a, b]).drawData(canvas);
      expect(draws(canvas), [
        'drawColor',
        'drawRawPoints',
        'drawColor',
        'drawPath',
      ]);
    });

    test('a dashed linear set fills in order but its line goes on top', () {
      // Kotlin draws the fill of a dashed set onto the chart canvas and only its line onto the bitmap.
      final dashed = _set(_threePoints)
        ..enableDashedLine(4, 2, 0)
        ..isDrawFilledEnabled = true
        ..fillColor = const ui.Color(0xFF00FF00)
        ..color = const ui.Color(0xFF00AA00);
      final plain = _set(_threePoints)..color = const ui.Color(0xFF0000AA);
      final canvas = RecordingCanvas();
      renderer([dashed, plain]).drawData(canvas);

      expect(draws(canvas), ['drawColor', 'drawRawPoints', 'drawPath']);
      expect(rgb(canvas.colors.single), 0x00FF00);
      expect(rgb(canvas.rawPoints.single.color), 0x0000AA);
      expect(rgb(canvas.paths.single.color), 0x00AA00);
      expect(canvas.paths.single.style, ui.PaintingStyle.stroke);
    });

    test('a chart without size draws nothing when a bezier set is visible', () {
      // Kotlin cannot create the bitmap of a chart without size and returns before drawing any data set.
      final handler = ViewPortHandler();
      final cubic = _set(_threePoints)..mode = LineDataSetMode.CUBIC_BEZIER;
      final linear = _set(_threePoints);
      final canvas = RecordingCanvas();
      renderer([linear, cubic], handler).drawData(canvas);
      expect(canvas.calls, isEmpty);

      // A hidden bezier set needs no bitmap: the linear set is drawn.
      cubic.isVisible = false;
      renderer([linear, cubic], handler).drawData(canvas);
      expect(canvas.drawRawPointsCalls, 1);
    });
  });

  group('a y value that is not a number', () {
    final nanPoints = [
      [0.0, 10.0],
      [5.0, double.nan],
      [10.0, 90.0],
    ];

    for (final mode in LineDataSetMode.values) {
      test(
        '$mode draws data, values, circles and highlights without throwing',
        () {
          final set = _set(nanPoints)
            ..mode = mode
            ..isDrawFilledEnabled = true;
          final renderer = _renderer(set);
          final canvas = RecordingCanvas();
          renderer.drawData(canvas);
          renderer.drawValues(canvas);
          renderer.drawExtras(canvas);
          renderer.drawHighlighted(canvas, [Highlight(5, double.nan, 0)]);
          expect(canvas.getSaveCount(), 1);
        },
      );
    }

    test('LINEAR leaves a gap: only the drawable segments are drawn', () {
      final set = _set(nanPoints);
      final canvas = RecordingCanvas();
      _renderer(set).drawData(canvas);
      // Segment 0 (first entry to itself) is drawable; segments 1 and 2 touch the NaN entry.
      expect(canvas.drawRawPointsCalls, 1);
      expect(canvas.rawPoints.single.points.toList(), [0, 90, 0, 90]);
    });

    test('drawValues skips the entry without a value', () {
      final set = _set(nanPoints);
      final canvas = RecordingCanvas();
      _renderer(set).drawValues(canvas);
      expect(canvas.drawParagraphCalls, 2);
    });
  });

  test('drawValues draws one label per visible entry, above the circle', () {
    final set = _set(_threePoints);
    final canvas = RecordingCanvas();
    _renderer(set).drawValues(canvas);
    expect(canvas.drawParagraphCalls, 3);
  });

  test('drawHighlighted records the pixel position and draws both lines', () {
    final set = _set(_threePoints);
    final canvas = RecordingCanvas();
    final high = Highlight(5, 50, 0);
    _renderer(set).drawHighlighted(canvas, [high]);
    expect(high.drawX, closeTo(50, 1e-4));
    expect(high.drawY, closeTo(50, 1e-4));
    expect(canvas.drawPathCalls, 2);
  });

  test(
    'drawHighlighted draws the highlight circle when the set enables it',
    () {
      final set = _set(_threePoints)..isDrawHighlightCircleEnabled = true;
      final canvas = RecordingCanvas();
      _renderer(set).drawHighlighted(canvas, [Highlight(5, 50, 0)]);
      expect(canvas.drawCircleCalls, 3);
    },
  );

  test(
    'drawHighlighted draws no highlight circle for a radius of 0 or less, as Android draws none, and still the lines',
    () {
      // drawHighlightCircle calls drawCircleP with the radius and 1.9 times it; Android's canvas returns early for a
      // radius of 0 or less, and so does drawCircleP (T18 BU4), where Impeller would stroke a dot.
      for (final radius in [0.0, -2.0]) {
        final set = _set(_threePoints)
          ..isDrawHighlightCircleEnabled = true
          ..highlightCircleRadius = radius;
        final canvas = RecordingCanvas();
        _renderer(set).drawHighlighted(canvas, [Highlight(5, 50, 0)]);
        expect(canvas.drawCircleCalls, 0, reason: 'radius $radius');
        expect(canvas.drawPathCalls, 2, reason: 'radius $radius');
      }
    },
  );
}
