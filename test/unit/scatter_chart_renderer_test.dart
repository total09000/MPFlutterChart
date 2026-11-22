// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for ScatterChartRenderer. Locks what
// renderer/ScatterChartRenderer.kt draws on a recording canvas: one shape per entry inside the content
// rectangle, at its pixel and in the color of its index; the value labels one shape size above the points; the
// highlight lines; and Review Focus #1: an entry with a NaN x or y fails the bounds checks before it reaches a shape,
// which matters for the triangle, whose NaN path neither drawPathP nor StrictCanvas would catch.
//
// The fake prepares real transformers on a 400 x 300 chart with offsets 20 / 10 / 20 / 10, so the content rect is
// 20..380 x 10..290; x −0.5..4.5 → 20..380 px (72 px per x) and y 0..10 → 290..10 px (28 px per y). The shapes are
// 10 dp, which is 10 px here.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/charts/scatter_shape.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/scatter_data.dart';
import 'package:mp_flutter_chart/src/data/scatter_data_set.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_scatter_data_set.dart';
import 'package:mp_flutter_chart/src/renderer/scatter/i_shape_renderer.dart';
import 'package:mp_flutter_chart/src/renderer/scatter_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import '../recording/recording_canvas.dart';
import 'support/counting_icon.dart';
import 'support/fake_providers.dart';
import 'support/strict_canvas.dart';

const _contentLeft = 20.0;
const _contentTop = 10.0;
const _contentRight = 380.0;
const _contentBottom = 290.0;

const _red = ui.Color(0xFFFF0000);
const _green = ui.Color(0xFF00FF00);
const _blue = ui.Color(0xFF0000FF);

/// One value label the renderer drew: the value and its baseline position.
typedef _Label = ({double value, double x, double y});

/// Records the value labels of [ScatterChartRenderer].
class _TestScatterRenderer extends ScatterChartRenderer {
  _TestScatterRenderer(FakeScatterChart chart, [ChartAnimator? animator])
    : super(chart, animator ?? ChartAnimator(), chart.handler);

  final List<_Label> labels = [];

  @override
  void drawValue(
    ui.Canvas c,
    IValueFormatter formatter,
    double value,
    Entry entry,
    int dataSetIndex,
    double x,
    double y,
    ui.Color color,
  ) {
    labels.add((value: value, x: x, y: y));
    super.drawValue(c, formatter, value, entry, dataSetIndex, x, y, color);
  }
}

FakeScatterChart _chart(
  List<IScatterDataSet> sets, {
  int maxVisibleCount = 100,
}) {
  const xMin = -0.5, xMax = 4.5, yMin = 0.0, yMax = 10.0;
  final handler = ViewPortHandler()
    ..setChartDimens(400, 300)
    ..restrainViewPort(20, 10, 20, 10);
  Transformer transformer() => Transformer(handler)
    ..prepareMatrixValuePx(xMin, xMax - xMin, yMax - yMin, yMin)
    ..prepareMatrixOffset(false);
  return FakeScatterChart(
    ScatterData(sets),
    handler: handler,
    left: transformer(),
    right: transformer(),
    lowestVisibleX: xMin,
    highestVisibleX: xMax,
    xChartMin: xMin,
    xChartMax: xMax,
    yChartMin: yMin,
    yChartMax: yMax,
    maxVisibleCount: maxVisibleCount,
  );
}

/// The pixel x of the value [x].
double _px(double x) =>
    _contentLeft + (x + 0.5) * (_contentRight - _contentLeft) / 5;

/// The pixel y of the value [y].
double _py(double y) =>
    _contentBottom - y * (_contentBottom - _contentTop) / 10;

/// A set of 10 dp [shape]s at [points], given as (x, y).
ScatterDataSet _set(
  List<(double, double)> points, {
  ScatterShape shape = ScatterShape.CIRCLE,
}) => ScatterDataSet([for (final (x, y) in points) Entry(x: x, y: y)], 'points')
  ..setScatterShape(shape)
  ..scatterShapeSize = 10;

/// Three points at x 1, 2 and 3.
ScatterDataSet _threePoints() => _set([(1, 2), (2, 5), (3, 8)]);

void main() {
  group('drawData', () {
    test('a CIRCLE set draws one circle per entry, centered on its pixel, '
        'in the color of its index', () {
      final set = _threePoints()..colors = [_red, _green, _blue];
      final canvas = RecordingCanvas();

      _TestScatterRenderer(_chart([set])).drawData(canvas);

      // Without a hole a circle is a ring of half the size stroked around a quarter of it.
      expect(canvas.circles, hasLength(3));
      final expected = [
        (1.0, 2.0, _red),
        (2.0, 5.0, _green),
        (3.0, 8.0, _blue),
      ];
      for (var k = 0; k < 3; k++) {
        final (x, y, color) = expected[k];
        final circle = canvas.circles[k];
        expect(circle.x, closeTo(_px(x), 1e-4), reason: 'circle $k x');
        expect(circle.y, closeTo(_py(y), 1e-4), reason: 'circle $k y');
        expect(circle.radius, closeTo(2.5, 1e-4), reason: 'circle $k radius');
        expect(circle.color, color, reason: 'circle $k color');
      }
    });

    test('each entry goes to the shape renderer of its set with the viewport '
        'handler and its pixel', () {
      final drawn = <(IScatterDataSet, ViewPortHandler, double, double)>[];
      final set = _threePoints()
        ..shapeRenderer = IShapeRenderer.fromFunction(
          (c, dataSet, viewPortHandler, posX, posY, renderPaint) =>
              drawn.add((dataSet, viewPortHandler, posX, posY)),
        );
      final chart = _chart([set]);

      _TestScatterRenderer(chart).drawData(RecordingCanvas());

      expect(drawn, hasLength(3));
      for (final (k, x, y) in [(0, 1.0, 2.0), (1, 2.0, 5.0), (2, 3.0, 8.0)]) {
        final (dataSet, viewPortHandler, posX, posY) = drawn[k];
        expect(dataSet, same(set));
        expect(viewPortHandler, same(chart.handler));
        expect(posX, closeTo(_px(x), 1e-4), reason: 'entry $k x');
        expect(posY, closeTo(_py(y), 1e-4), reason: 'entry $k y');
      }
    });

    test('an invisible set, an empty set and no data draw nothing', () {
      final hidden = _threePoints()..isVisible = false;
      final empty = _set([]);
      final canvas = RecordingCanvas();

      _TestScatterRenderer(_chart([hidden, empty])).drawData(canvas);
      _TestScatterRenderer(FakeScatterChart(null)).drawData(canvas);

      expect(canvas.calls, isEmpty);
    });

    test('entries left of, above or right of the content rectangle are not '
        'drawn', () {
      // x −2 is at −88 px, y 12 at −46 px and x 6 at 488 px.
      final set = _set([(-2, 5), (0, 12), (1, 5), (6, 5)]);
      final canvas = RecordingCanvas();

      _TestScatterRenderer(_chart([set])).drawData(canvas);

      expect(canvas.circles, hasLength(1));
      expect(canvas.circles.single.x, closeTo(_px(1), 1e-4));
      expect(canvas.circles.single.y, closeTo(_py(5), 1e-4));
    });

    test('the y phase scales the values and the x phase reveals the entries '
        'from the left', () {
      final animator = ChartAnimator()
        ..phaseX = 0.5
        ..phaseY = 0.5;
      final canvas = RecordingCanvas();

      _TestScatterRenderer(_chart([_threePoints()]), animator).drawData(canvas);

      // XBounds: entries 0 to 2, so a range of 2 * 0.5 = 1 past the first.
      expect(canvas.circles, hasLength(2));
      expect(canvas.circles[0].y, closeTo(_py(1), 1e-4));
      expect(canvas.circles[1].y, closeTo(_py(2.5), 1e-4));
    });
  });

  group('drawValues', () {
    test('each label is the y value with its baseline one shape size above '
        'the point', () {
      final canvas = RecordingCanvas();
      final renderer = _TestScatterRenderer(_chart([_threePoints()]));

      renderer.drawValues(canvas);

      expect(canvas.drawParagraphCalls, 3);
      expect(renderer.labels, hasLength(3));
      for (final (k, x, y) in [(0, 1.0, 2.0), (1, 2.0, 5.0), (2, 3.0, 8.0)]) {
        final label = renderer.labels[k];
        expect(label.value, y, reason: 'label $k value');
        expect(label.x, closeTo(_px(x), 1e-4), reason: 'label $k x');
        expect(label.y, closeTo(_py(y) - 10, 1e-4), reason: 'label $k y');
      }
    });

    test('no labels while more entries are in view than maxVisibleCount', () {
      final crowded = _TestScatterRenderer(
        _chart([_threePoints()], maxVisibleCount: 2),
      );
      crowded.drawValues(RecordingCanvas());
      expect(crowded.labels, isEmpty);

      final fits = _TestScatterRenderer(
        _chart([_threePoints()], maxVisibleCount: 3),
      );
      fits.drawValues(RecordingCanvas());
      expect(fits.labels, hasLength(3));
    });

    test('icons are drawn when enabled, even with the labels off', () {
      final icon = CountingIcon();
      final set = _set([(1, 2), (2, 5), (3, 8)])
        ..isDrawValuesEnabled = false
        ..isDrawIconsEnabled = true;
      for (final e in set.entries) {
        e.icon = icon;
      }
      final renderer = _TestScatterRenderer(_chart([set]));

      renderer.drawValues(RecordingCanvas());

      expect(renderer.labels, isEmpty);
      expect(icon.draws, 3);

      set.isDrawIconsEnabled = false;
      renderer.drawValues(RecordingCanvas());
      expect(icon.draws, 3);
    });
  });

  group('drawHighlighted', () {
    test('a highlight draws the highlight lines through the pixel of the '
        'closest entry and records that pixel', () {
      const highlightColor = ui.Color(0xFF123456);
      final set = _threePoints()..highlightColor = highlightColor;
      final canvas = RecordingCanvas();
      final high = Highlight(1, 2, 0);
      final between = Highlight(2.4, 5, 0);

      _TestScatterRenderer(
        _chart([set]),
      ).drawHighlighted(canvas, [high, between]);

      expect(high.drawX, closeTo(_px(1), 1e-4));
      expect(high.drawY, closeTo(_py(2), 1e-4));
      expect(between.drawX, closeTo(_px(2), 1e-4));
      expect(between.drawY, closeTo(_py(5), 1e-4));

      // A vertical line over the content height and a horizontal one over the content width, per highlight.
      expect(canvas.drawPathCalls, 4);
      final vertical = canvas.paths[0].bounds;
      expect(vertical.left, closeTo(_px(1), 1e-4));
      expect(vertical.right, closeTo(_px(1), 1e-4));
      expect(vertical.top, closeTo(_contentTop, 1e-4));
      expect(vertical.bottom, closeTo(_contentBottom, 1e-4));
      final horizontal = canvas.paths[1].bounds;
      expect(horizontal.left, closeTo(_contentLeft, 1e-4));
      expect(horizontal.right, closeTo(_contentRight, 1e-4));
      expect(horizontal.top, closeTo(_py(2), 1e-4));
      expect(horizontal.bottom, closeTo(_py(2), 1e-4));
      for (final path in canvas.paths) {
        expect(path.color.toARGB32(), highlightColor.toARGB32());
      }
    });

    test('a highlight is skipped when its set does not highlight, when its set '
        'is missing and when the x phase has not revealed its entry', () {
      final noHighlight = _threePoints()..isHighlightEnabled = false;
      final canvas = RecordingCanvas();
      _TestScatterRenderer(
        _chart([noHighlight]),
      ).drawHighlighted(canvas, [Highlight(1, 2, 0)]);
      _TestScatterRenderer(
        _chart([_threePoints()]),
      ).drawHighlighted(canvas, [Highlight(1, 2, 3)]);
      expect(canvas.calls, isEmpty);

      // Entry 2 of 3 is past 3 * 0.5; entry 0 is not.
      final animator = ChartAnimator()..phaseX = 0.5;
      final hidden = Highlight(3, 8, 0);
      _TestScatterRenderer(
        _chart([_threePoints()]),
        animator,
      ).drawHighlighted(canvas, [hidden, Highlight(1, 2, 0)]);
      expect(canvas.drawPathCalls, 2);
      expect(hidden.drawX, 0);
      expect(hidden.drawY, 0);
    });
  });

  group('an x or y that is not a number', () {
    // A NaN y maps to a NaN pixel y and a NaN x to a NaN pixel x, which fail isInBoundsY / isInBoundsLeft.
    List<(double, double)> points() => [
      (0, 2),
      (1, double.nan),
      (2, 5),
      (double.nan, 4),
    ];

    for (final shape in [ScatterShape.TRIANGLE, ScatterShape.CIRCLE]) {
      test('$shape draws the other entries and their labels and no shape for '
          'the NaN ones', () {
        final canvas = StrictCanvas();
        final renderer = _TestScatterRenderer(
          _chart([_set(points(), shape: shape)]),
        );

        renderer.drawData(canvas);
        renderer.drawValues(canvas);

        final shapes = shape == ScatterShape.CIRCLE
            ? [
                for (final c in canvas.circles)
                  ui.Rect.fromCircle(
                    center: ui.Offset(c.x, c.y),
                    radius: c.radius,
                  ),
              ]
            : [for (final p in canvas.paths) p.bounds];
        expect(shapes, hasLength(2));
        for (final (k, x, y) in [(0, 0.0, 2.0), (1, 2.0, 5.0)]) {
          expect(shapes[k].isFinite, isTrue, reason: 'shape $k');
          expect(shapes[k].center.dx, closeTo(_px(x), 1e-4));
          expect(shapes[k].center.dy, closeTo(_py(y), 1e-4));
        }
        expect(renderer.labels.map((it) => it.value), [2, 5]);
        expect(canvas.getSaveCount(), 1);
      });
    }

    test('highlights on a set with NaN entries draw without throwing', () {
      final canvas = StrictCanvas();
      final nanX = Highlight(double.nan, 4, 0);

      _TestScatterRenderer(
        _chart([_set(points(), shape: ScatterShape.TRIANGLE)]),
      ).drawHighlighted(canvas, [
        Highlight(0, 2, 0),
        Highlight(1, double.nan, 0),
        nanX,
      ]);

      // A NaN x finds no entry; the NaN y entry gets its lines like in Kotlin, the horizontal one with a NaN y
      // that Skia leaves out.
      expect(nanX.drawX, 0);
      expect(canvas.drawPathCalls, 4);
      expect(canvas.getSaveCount(), 1);
    });
  });
}
