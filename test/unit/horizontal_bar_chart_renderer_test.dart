// Tests for renderer/HorizontalBarChartRenderer.kt on a recording canvas; MPAndroidChart has no unit
// test for it. Locks the swapped bar, shadow and highlight geometry, the rounding of the outermost (right) stack
// section, the value label positions to the side of the bars and the vertical culling, and that NaN and infinite
// values draw no NaN geometry (Review Focus #1).
//
// The fake prepares horizontal-bar transformers the way HorizontalBarChart.prepareValuePxMatrix does (the bar values
// along the transformer's x, the x values along its y) on a 400 x 300 chart with offsets 20 / 10 / 20 / 10, so the
// content rect is 20..380 x 10..290; by default y 0..10 → 20..380 px (36 px per y) and x −0.5..4.5 → 290..10 px
// (56 px per x).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/buffer/bar_buffer.dart';
import 'package:mp_flutter_chart/src/buffer/horizontal_bar_buffer.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/renderer/horizontal_bar_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/fill.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/transformer_horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';
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

/// One value label the renderer drew: its text and its baseline position.
typedef _Label = ({String text, double x, double y});

/// Records the value labels and exposes the protected members of [HorizontalBarChartRenderer].
class _TestHorizontalBarRenderer extends HorizontalBarChartRenderer {
  _TestHorizontalBarRenderer(FakeBarChart chart, [ChartAnimator? animator])
    : super(chart, animator ?? ChartAnimator(), chart.handler);

  final List<_Label> labels = [];

  List<BarBuffer> get buffers => barBuffers;

  Float32List get radii => barShapeRadii;

  double get pixels => xAxisPixels;

  /// Half the height of "10" in the value paint, which centers a label on its bar.
  double get halfTextHeight => Utils.calcTextHeight(paintValues, '10') / 2;

  /// The width of [text] in the value paint, as the renderer measures it.
  double textWidth(String text) =>
      Utils.calcTextWidth(paintValues, text).toDouble();

  @override
  void drawValueText(
    ui.Canvas c,
    String valueText,
    double x,
    double y,
    ui.Color color,
  ) {
    labels.add((text: valueText, x: x, y: y));
    super.drawValueText(c, valueText, x, y, color);
  }
}

/// An empty [Fill] that records the gradient direction it is asked to fill with.
class _DirectionFill extends Fill {
  final List<FillDirection> directions = [];

  @override
  void fillRect(
    ui.Canvas c,
    ChartPaint paint,
    double left,
    double top,
    double right,
    double bottom,
    FillDirection gradientDirection,
  ) {
    directions.add(gradientDirection);
    super.fillRect(c, paint, left, top, right, bottom, gradientDirection);
  }
}

FakeBarChart _chart(
  List<BarDataSet> sets, {
  double xMin = -0.5,
  double xMax = 4.5,
  double yMin = 0,
  double yMax = 10,
  bool inverted = false,
}) {
  final handler = ViewPortHandler()
    ..setChartDimens(400, 300)
    ..restrainViewPort(20, 10, 20, 10);
  TransformerHorizontalBarChart transformer() =>
      TransformerHorizontalBarChart(handler)
        ..prepareMatrixValuePx(yMin, yMax - yMin, xMax - xMin, xMin)
        ..prepareMatrixOffset(inverted);
  return FakeBarChart(
    BarData(sets),
    handler: handler,
    left: transformer(),
    right: transformer(),
    isInverted: inverted,
    lowestVisibleX: xMin,
    highestVisibleX: xMax,
    xChartMin: xMin,
    xChartMax: xMax,
    yChartMin: yMin,
    yChartMax: yMax,
  );
}

/// The pixel x of the bar value [y] on a chart showing [yMin]..[yMax] left to right.
double _px(double y, {double yMin = 0, double yMax = 10}) =>
    _contentLeft + (y - yMin) * (_contentRight - _contentLeft) / (yMax - yMin);

/// The pixel y of the x value [x] on a chart showing [xMin]..[xMax] bottom to top.
double _py(double x, {double xMin = -0.5, double xMax = 4.5}) =>
    _contentBottom -
    (x - xMin) * (_contentBottom - _contentTop) / (xMax - xMin);

/// Where `Utils.drawImage` translates to for a [CountingIcon] given the pixel position ([x], [y]): Kotlin's `toInt()`
/// of each, minus half the 4 px icon.
ui.Offset _iconAt(double x, double y) =>
    ui.Offset(x.truncate() - 2.0, y.truncate() - 2.0);

/// Five plain bars at x 0..4 with the value `x + 1`, all in [color].
BarDataSet _fiveBars({ui.Color color = _red}) => BarDataSet([
  for (var k = 0; k < 5; k++) BarEntry(x: k.toDouble(), y: k + 1.0),
], 'bars')..color = color;

void _expectRect(
  ui.Rect actual,
  double left,
  double top,
  double right,
  double bottom,
) {
  expect(actual.left, closeTo(left, 1e-4), reason: 'left of $actual');
  expect(actual.top, closeTo(top, 1e-4), reason: 'top of $actual');
  expect(actual.right, closeTo(right, 1e-4), reason: 'right of $actual');
  expect(actual.bottom, closeTo(bottom, 1e-4), reason: 'bottom of $actual');
}

/// The rects drawn in [color]. Colors are compared as ARGB: `ui.Paint` keeps its color in floats of its own.
List<RectDraw> _rectsIn(RecordingCanvas canvas, ui.Color color) => [
  for (final r in canvas.rects)
    if (r.color.toARGB32() == color.toARGB32()) r,
];

void main() {
  group('drawData', () {
    test('five plain bars run from the content left (y 0) to the right, '
        'x ± barWidth / 2 high', () {
      final canvas = StrictCanvas();
      _TestHorizontalBarRenderer(_chart([_fiveBars()])).drawData(canvas);

      final bars = _rectsIn(canvas, _red);
      expect(bars, hasLength(5));
      expect(canvas.rects, hasLength(5));
      for (var k = 0; k < 5; k++) {
        _expectRect(
          bars[k].rect,
          _contentLeft,
          _py(k + 0.425),
          _px(k + 1.0),
          _py(k - 0.425),
        );
        expect(bars[k].rect.top, lessThan(bars[k].rect.bottom));
        if (k > 0) {
          expect(bars[k].rect.right, greaterThan(bars[k - 1].rect.right));
        }
      }
      expect(canvas.getSaveCount(), 1);
    });

    test('xAxisPixels is the content height, along which the x values run', () {
      final renderer = _TestHorizontalBarRenderer(_chart([_fiveBars()]));
      expect(renderer.pixels, _contentBottom - _contentTop);
    });

    test('bar shadows span the content width behind each bar', () {
      final set = _fiveBars();
      final chart = _chart([set])..isDrawBarShadowEnabled = true;
      final canvas = StrictCanvas();
      _TestHorizontalBarRenderer(chart).drawData(canvas);

      final shadows = _rectsIn(canvas, set.barShadowColor);
      expect(shadows, hasLength(5));
      expect(_rectsIn(canvas, _red), hasLength(5));
      // All shadows come first, then the bars.
      expect(
        canvas.rects.take(5).map((r) => r.color.toARGB32()),
        everyElement(set.barShadowColor.toARGB32()),
      );
      for (var k = 0; k < 5; k++) {
        _expectRect(
          shadows[k].rect,
          _contentLeft,
          _py(k + 0.425),
          _contentRight,
          _py(k - 0.425),
        );
      }
    });

    test('a border draws each bar once more in the border color', () {
      final set = _fiveBars()
        ..barBorderWidth = 2
        ..barBorderColor = _blue;
      final canvas = StrictCanvas();
      _TestHorizontalBarRenderer(_chart([set])).drawData(canvas);

      final bars = _rectsIn(canvas, _red);
      final borders = _rectsIn(canvas, _blue);
      expect(bars, hasLength(5));
      expect(borders, hasLength(5));
      for (var k = 0; k < 5; k++) {
        expect(borders[k].rect, bars[k].rect);
      }
    });

    test('a stacked bar rounds only its outermost section, on the right', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [2, 3]),
      ], 'stack')..barCornerRadius = 4;
      final canvas = StrictCanvas();
      final renderer = _TestHorizontalBarRenderer(_chart([set]));
      renderer.drawData(canvas);

      expect(canvas.rects, hasLength(2));
      // Only the outer section is clipped, to a rect rounded at its top right and bottom right corners.
      expect(canvas.clipPaths, hasLength(1));
      expect(renderer.radii.toList(), [0, 0, 4, 4, 4, 4, 0, 0]);
      _expectRect(
        canvas.rects[0].rect,
        _px(0),
        _py(0.425),
        _px(2),
        _py(-0.425),
      );
      _expectRect(
        canvas.rects[1].rect,
        _px(2),
        _py(0.425),
        _px(5),
        _py(-0.425),
      );
      final clip = canvas.clipPaths.single.getBounds();
      expect(clip.left, closeTo(_px(2), 1e-3));
      expect(clip.right, closeTo(_px(5), 1e-3));
      expect(canvas.getSaveCount(), 1);
    });

    test('a stacked bar draws one rect per stack value in the color of its '
        'place', () {
      final set = BarDataSet([
        for (var k = 0; k < 5; k++)
          BarEntry.stacked(x: k.toDouble(), stackValues: [2, 3]),
      ], 'stack')..colors = [_red, _green];
      final canvas = StrictCanvas();
      _TestHorizontalBarRenderer(_chart([set])).drawData(canvas);

      expect(canvas.rects, hasLength(10));
      for (var k = 0; k < 5; k++) {
        final inner = canvas.rects[2 * k];
        final outer = canvas.rects[2 * k + 1];
        expect(inner.color.toARGB32(), _red.toARGB32());
        expect(outer.color.toARGB32(), _green.toARGB32());
        _expectRect(inner.rect, _px(0), _py(k + 0.425), _px(2), _py(k - 0.425));
        _expectRect(outer.rect, _px(2), _py(k + 0.425), _px(5), _py(k - 0.425));
      }
    });

    test('bars below the content bottom are skipped and those above the '
        'content top end the pass', () {
      // The visible range reaches one entry past each edge, so x 1.5..4.5 feeds the bar at x 1 (below the content)
      // and x −0.5..2.5 the bar at x 3 (above it).
      var canvas = StrictCanvas();
      _TestHorizontalBarRenderer(
        _chart([_fiveBars()], xMin: 1.5),
      ).drawData(canvas);
      expect(canvas.rects, hasLength(3));
      expect(canvas.rects.first.rect.top, closeTo(_py(2.425, xMin: 1.5), 1e-4));

      canvas = StrictCanvas();
      _TestHorizontalBarRenderer(
        _chart([_fiveBars()], xMax: 2.5),
      ).drawData(canvas);
      expect(canvas.rects, hasLength(3));
      expect(
        canvas.rects.last.rect.bottom,
        closeTo(_py(1.575, xMax: 2.5), 1e-4),
      );
    });

    test('a custom fill paints each bar through its Fill', () {
      final set = _fiveBars()..fills = [Fill.ofColor(_green)];
      final canvas = StrictCanvas();
      _TestHorizontalBarRenderer(_chart([set])).drawData(canvas);

      expect(canvas.rects, isEmpty);
      expect(canvas.colors, List.filled(5, _green));
      expect(canvas.clipRects, hasLength(5));
      _expectRect(
        canvas.clipRects[2],
        _contentLeft,
        _py(2.425),
        _px(3),
        _py(1.575),
      );
    });

    test(
      'custom fills run to the right, or to the left on an inverted axis',
      () {
        for (final inverted in [false, true]) {
          final fill = _DirectionFill();
          final set = _fiveBars()..fills = [fill];
          _TestHorizontalBarRenderer(
            _chart([set], inverted: inverted),
          ).drawData(StrictCanvas());
          expect(
            fill.directions,
            List.filled(5, inverted ? FillDirection.LEFT : FillDirection.RIGHT),
            reason: 'inverted: $inverted',
          );
        }
      },
    );

    test('initBuffers creates horizontal bar buffers and keeps them while '
        'they fit the data', () {
      final chart = _chart([_fiveBars()]);
      final renderer = _TestHorizontalBarRenderer(chart)..initBuffers();
      final first = renderer.buffers.single;
      expect(first, isA<HorizontalBarBuffer>());
      expect(first.size, 5 * 4);

      renderer.initBuffers();
      expect(renderer.buffers.single, same(first));

      chart.barData = BarData([
        BarDataSet([
          BarEntry.stacked(x: 0, stackValues: [1, 2]),
          BarEntry.stacked(x: 1, stackValues: [1, 2]),
          BarEntry.stacked(x: 2, stackValues: [1, 2]),
        ], 'stack'),
      ]);
      renderer.drawData(StrictCanvas());
      expect(renderer.buffers.single, isNot(same(first)));
      expect(renderer.buffers.single, isA<HorizontalBarBuffer>());
      expect(renderer.buffers.single.size, 3 * 4 * 2);
      expect(renderer.buffers.single.containsStacks, isTrue);
    });
  });

  group('drawValues', () {
    test('a positive value sits 5 dp right of its bar and a negative one '
        '5 dp plus its width left of it, both centered on the bar', () {
      final set = BarDataSet([
        BarEntry(x: 1, y: 5),
        BarEntry(x: 2, y: -3),
      ], 'bars');
      final renderer = _TestHorizontalBarRenderer(
        _chart([set], yMin: -10, yMax: 10),
      );
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);
      double px(double y) => _px(y, yMin: -10, yMax: 10);

      final offset = Utils.convertDpToPixel(5);
      expect(renderer.labels, hasLength(2));
      final (right, left) = (renderer.labels[0], renderer.labels[1]);
      expect(right.x, closeTo(px(5) + offset, 1e-4));
      expect(right.y, closeTo(_py(1) + renderer.halfTextHeight, 1e-4));
      expect(
        left.x,
        closeTo(px(-3) - offset - renderer.textWidth(left.text), 1e-4),
      );
      expect(left.y, closeTo(_py(2) + renderer.halfTextHeight, 1e-4));
      expect(canvas.paragraphs, hasLength(2));
    });

    test('values drawn inside the bars sit inside the tip of a positive bar '
        'and the base of a negative one', () {
      final set = BarDataSet([
        BarEntry(x: 1, y: 5),
        BarEntry(x: 2, y: -3),
      ], 'bars');
      final chart = _chart([set], yMin: -10, yMax: 10)
        ..isDrawValueAboveBarEnabled = false;
      final renderer = _TestHorizontalBarRenderer(chart);
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);
      double px(double y) => _px(y, yMin: -10, yMax: 10);

      final offset = Utils.convertDpToPixel(5);
      final (right, left) = (renderer.labels[0], renderer.labels[1]);
      expect(
        right.x,
        closeTo(px(5) - offset - renderer.textWidth(right.text), 1e-4),
      );
      // Kotlin: the 5 dp offset minus the bar width, from the right end of the negative bar, which is its base.
      expect(left.x, closeTo(px(-3) + offset, 1e-4));
    });

    test('an inverted axis mirrors the offsets: the label goes the other way '
        'from the right end of the bar', () {
      // Kotlin's formula: the offsets are negated and moved by the text width, from buffer index 2. With the axis
      // inverted that is the pixel of 0 for a positive bar, which then spans from its value to 0.
      final set = BarDataSet([BarEntry(x: 1, y: 5)], 'bars');
      final renderer = _TestHorizontalBarRenderer(
        _chart([set], yMin: -10, yMax: 10, inverted: true),
      );
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      final bar = canvas.rects.single.rect;
      expect(bar.right, closeTo(200, 1e-4));
      expect(bar.left, closeTo(110, 1e-4));
      final label = renderer.labels.single;
      expect(
        label.x,
        closeTo(
          bar.right -
              Utils.convertDpToPixel(5) -
              renderer.textWidth(label.text),
          1e-4,
        ),
      );
    });

    test('a stacked bar gets one label per stack value, right of its section '
        'and centered on the bar', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 2, stackValues: [2, 3]),
      ], 'stack');
      final renderer = _TestHorizontalBarRenderer(_chart([set]));
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      final offset = Utils.convertDpToPixel(5);
      expect(renderer.labels, hasLength(2));
      expect(renderer.labels[0].x, closeTo(_px(2) + offset, 1e-4));
      expect(renderer.labels[1].x, closeTo(_px(5) + offset, 1e-4));
      for (final label in renderer.labels) {
        expect(label.y, closeTo(_py(2) + renderer.halfTextHeight, 1e-4));
      }
    });

    test('a plain entry in a stacked set is labelled at the top of its bar', () {
      // Kotlin anchors the label of an entry without stack values at buffer index 1, the top edge, not the center.
      final set = BarDataSet([
        BarEntry.stacked(x: 1, stackValues: [2, 3]),
        BarEntry(x: 3, y: 4),
      ], 'stack');
      final renderer = _TestHorizontalBarRenderer(_chart([set]));
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      expect(renderer.labels, hasLength(3));
      final plain = renderer.labels.last;
      expect(plain.x, closeTo(_px(4) + Utils.convertDpToPixel(5), 1e-4));
      expect(plain.y, closeTo(_py(3.425) + renderer.halfTextHeight, 1e-4));
    });

    test('icons are drawn at the label anchor, vertically centered on the '
        'bar and moved by the icons offset, also with the labels off', () {
      final icon = CountingIcon();
      final set = BarDataSet([
        BarEntry(x: 1, y: 5, icon: icon),
        BarEntry(x: 2, y: -3, icon: icon),
      ], 'bars')..iconsOffset = MPPointF(2, -3);
      final renderer = _TestHorizontalBarRenderer(
        _chart([set], yMin: -10, yMax: 10),
      );
      final canvas = TranslationRecordingCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      expect(icon.draws, 2);
      // Kotlin: the label's x and the bar's vertical center (the label's baseline less half the text height), each
      // plus the icons offset, then toInt(); drawImage centers the icon there.
      expect(renderer.labels, hasLength(2));
      expect(canvas.translations, [
        for (final l in renderer.labels)
          _iconAt(l.x + 2, l.y - renderer.halfTextHeight - 3),
      ]);

      set.isDrawValuesEnabled = false;
      renderer.drawValues(StrictCanvas());
      expect(icon.draws, 4);
      expect(renderer.labels, hasLength(2));

      set.isDrawIconsEnabled = false;
      renderer.drawValues(StrictCanvas());
      expect(icon.draws, 4);
    });

    test('a stacked bar draws its icon once per stack value, a plain entry in '
        'a stacked set once, at the top of its bar like its label', () {
      final stackedIcon = CountingIcon();
      final plainIcon = CountingIcon();
      final set = BarDataSet([
        BarEntry.stacked(x: 1, stackValues: [2, 3], icon: stackedIcon),
        BarEntry(x: 3, y: 4, icon: plainIcon),
      ], 'stack');
      final renderer = _TestHorizontalBarRenderer(_chart([set]));
      final canvas = TranslationRecordingCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      expect(stackedIcon.draws, 2);
      expect(plainIcon.draws, 1);
      expect(renderer.labels, hasLength(3));
      expect(canvas.translations, [
        for (final l in renderer.labels)
          _iconAt(l.x, l.y - renderer.halfTextHeight),
      ]);
      expect(
        canvas.translations.last.dy,
        _py(3.425).truncate() - 2.0,
        reason: 'the top edge of the plain bar, buffer index 1',
      );

      set.isDrawIconsEnabled = false;
      renderer.drawValues(StrictCanvas());
      expect(stackedIcon.draws, 2);
      expect(plainIcon.draws, 1);
    });

    test('labels are left aligned in the value paint', () {
      final set = BarDataSet([BarEntry(x: 1, y: 5)], 'bars');
      final renderer = _TestHorizontalBarRenderer(_chart([set]));
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      // A left aligned text starts at its anchor.
      expect(
        canvas.paragraphs.single.offset.dx,
        closeTo(renderer.labels.single.x, 1e-4),
      );
    });
  });

  group('drawHighlighted', () {
    test('a highlight spans from the pixel of 0 to the pixel of the value, '
        'x ± barWidth / 2 high, and records the draw position of '
        'MPAndroidChart 3.x', () {
      final set = _fiveBars();
      final renderer = _TestHorizontalBarRenderer(_chart([set]));
      final canvas = StrictCanvas();
      renderer.drawData(canvas);
      final drawn = canvas.rects.length;

      final high = Highlight(2, 3, 0);
      renderer.drawHighlighted(canvas, [high]);

      final highlight = canvas.rects.skip(drawn).single;
      expect(
        highlight.color.toARGB32(),
        const ui.Color.fromARGB(120, 0, 0, 0).toARGB32(),
      );
      _expectRect(highlight.rect, _px(0), _py(2.425), _px(3), _py(1.575));
      // Deliberate deviation from v4.0.1, which lost this override: as in MPAndroidChart 3.x, drawX is the vertical
      // center and drawY the right edge, which HorizontalBarChart.getMarkerPosition swaps back into the bar's tip.
      expect(high.drawX, closeTo(_py(2), 1e-4));
      expect(high.drawY, closeTo(_px(3), 1e-4));
    });

    test('the y animation phase scales the highlight horizontally', () {
      final animator = ChartAnimator()..phaseY = 0.5;
      final renderer = _TestHorizontalBarRenderer(
        _chart([_fiveBars()]),
        animator,
      );
      final canvas = StrictCanvas();
      renderer.drawHighlighted(canvas, [Highlight(3, 4, 0)]);

      _expectRect(
        canvas.rects.single.rect,
        _px(0),
        _py(3.425),
        _px(2),
        _py(2.575),
      );
    });

    test('a stacked highlight covers its section, or the whole bar with full '
        'bar highlighting', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [-2, 3]),
      ], 'stack');
      final chart = _chart([set], yMin: -10, yMax: 10);
      final renderer = _TestHorizontalBarRenderer(chart);
      double px(double y) => _px(y, yMin: -10, yMax: 10);

      var canvas = StrictCanvas();
      renderer.drawHighlighted(canvas, [Highlight.stacked(0, 0, 0)]);
      _expectRect(
        canvas.rects.single.rect,
        px(-2),
        _py(0.425),
        px(0),
        _py(-0.425),
      );

      chart.isHighlightFullBarEnabled = true;
      canvas = StrictCanvas();
      renderer.drawHighlighted(canvas, [Highlight.stacked(0, 0, 0)]);
      _expectRect(
        canvas.rects.single.rect,
        px(-2),
        _py(0.425),
        px(3),
        _py(-0.425),
      );
    });
  });

  group('NaN and infinite values', () {
    /// A plain set with NaN, +∞ and −∞ bars and a stacked set whose second section is NaN.
    List<BarDataSet> hostileSets() => [
      BarDataSet([
        BarEntry(x: 0, y: double.nan),
        BarEntry(x: 1, y: double.infinity),
        BarEntry(x: 2, y: double.negativeInfinity),
      ], 'plain')..color = _red,
      BarDataSet([
        BarEntry.stacked(x: 3, stackValues: [1, double.nan]),
      ], 'stacked')..colors = [_green, _blue],
    ];

    List<Highlight> everyHighlight() => [
      for (var x = 0; x < 3; x++) Highlight(x.toDouble(), double.nan, 0),
      Highlight.stacked(3, 1, 0),
      Highlight.stacked(3, 1, 1),
    ];

    for (final phaseY in [1.0, 0.0]) {
      for (final rounded in [false, true]) {
        for (final inverted in [false, true]) {
          test('are drawn without NaN geometry (y phase: $phaseY, rounded: '
              '$rounded, inverted: $inverted)', () {
            final sets = hostileSets();
            for (final set in sets) {
              set
                ..barCornerRadius = rounded ? 4 : 0
                ..barBorderWidth = 1
                ..barBorderColor = const ui.Color(0xFF123456);
            }
            final chart = _chart(sets, inverted: inverted)
              ..isDrawBarShadowEnabled = true;
            final animator = ChartAnimator()..phaseY = phaseY;
            final renderer = _TestHorizontalBarRenderer(chart, animator);
            final canvas = StrictCanvas();

            renderer
              ..drawData(canvas)
              ..drawHighlighted(canvas, everyHighlight())
              ..drawValues(canvas);

            chart.isHighlightFullBarEnabled = true;
            renderer.drawHighlighted(canvas, everyHighlight());
            expect(canvas.getSaveCount(), 1);
          });
        }
      }
    }

    /// The x row a label was drawn for: its baseline less half the text height is the center of a stack section or
    /// the top edge of a plain entry in a stacked set, either of which rounds to the x value on [xMin]..[xMax].
    int row(
      _TestHorizontalBarRenderer renderer,
      _Label label, {
      double xMin = -0.5,
      double xMax = 4.5,
    }) =>
        ((_contentBottom - (label.y - renderer.halfTextHeight)) /
                    ((_contentBottom - _contentTop) / (xMax - xMin)) +
                xMin)
            .round();

    for (final inverted in [false, true]) {
      test('at y phase 0 the ±∞ bars, whose tips become NaN, get no label; the '
          'NaN bar (empty, at 0) and the finite bar keep theirs (inverted: '
          '$inverted)', () {
        final set = BarDataSet([
          BarEntry(x: 0, y: double.nan),
          BarEntry(x: 1, y: double.infinity),
          BarEntry(x: 2, y: double.negativeInfinity),
          BarEntry(x: 3, y: 2),
        ], 'plain');
        List<int> labelledRows(double phaseY) {
          final renderer = _TestHorizontalBarRenderer(
            _chart([set], inverted: inverted),
            ChartAnimator()..phaseY = phaseY,
          );
          final canvas = StrictCanvas();
          renderer
            ..drawData(canvas)
            ..drawValues(canvas);
          expect(canvas.paragraphs, hasLength(renderer.labels.length));
          return [for (final l in renderer.labels) row(renderer, l)];
        }

        // At phase 1 the infinite bars reach past the content and are labelled out at ±∞.
        expect(labelledRows(1), [0, 1, 2, 3]);
        // Kotlin's phase quirk, kept by ruling and pinned in the buffer tests: with the axis inverted a negative
        // plain bar is not scaled by the phase, so the −∞ bar keeps its infinite tip and its label.
        expect(labelledRows(0), inverted ? [0, 2, 3] : [0, 3]);
      });

      test('±∞ stack sections and NaN or ±∞ plain entries in a stacked set draw '
          'no NaN geometry and are labelled only where their tip is finite and '
          'in view (inverted: $inverted)', () {
        const inf = double.infinity;
        final set = BarDataSet([
          BarEntry.stacked(x: 0, stackValues: [inf, 2]),
          BarEntry.stacked(x: 1, stackValues: [-inf, 1]),
          BarEntry.stacked(x: 2, stackValues: [1, 2]),
          BarEntry(x: 3, y: double.nan),
          BarEntry(x: 4, y: inf),
          BarEntry(x: 5, y: -inf),
        ], 'stacked')..colors = [_green, _blue];
        final highlights = [
          for (var x = 0; x < 3; x++)
            for (var stackIndex = 0; stackIndex < 2; stackIndex++)
              Highlight.stacked(x.toDouble(), 0, stackIndex),
          for (var x = 3; x < 6; x++) Highlight(x.toDouble(), double.nan, 0),
        ];

        List<int> labelledRows(double phaseY) {
          final chart = _chart([set], xMax: 5.5, inverted: inverted)
            ..isDrawBarShadowEnabled = true;
          final renderer = _TestHorizontalBarRenderer(
            chart,
            ChartAnimator()..phaseY = phaseY,
          );
          final canvas = StrictCanvas();
          renderer
            ..drawData(canvas)
            ..drawHighlighted(canvas, highlights)
            ..drawValues(canvas);
          chart.isHighlightFullBarEnabled = true;
          renderer.drawHighlighted(canvas, highlights);
          expect(canvas.getSaveCount(), 1);
          return [for (final l in renderer.labels) row(renderer, l, xMax: 5.5)];
        }

        // Phase 1: the ±∞ sections lie past the content and are culled, the second section of x 1 and both of x 2
        // are labelled; the plain entries are culled by their whole bar, which is in view, so all three are
        // labelled.
        expect(labelledRows(1), [1, 2, 2, 3, 4, 5]);
        // Phase 0: every section with an infinite end is NaN and culled, the finite ones sit at 0; of the plain
        // entries the NaN one, an empty bar at 0, keeps a tip in view, and with the axis inverted the −∞ one too,
        // which the phase does not scale (Kotlin's quirk, as above).
        expect(labelledRows(0), inverted ? [1, 2, 2, 3, 5] : [1, 2, 2, 3]);
      });
    }

    test('the NaN section of a stack is left out and the others drawn', () {
      final canvas = StrictCanvas();
      _TestHorizontalBarRenderer(_chart(hostileSets())).drawData(canvas);

      expect(_rectsIn(canvas, _green), hasLength(1));
      expect(_rectsIn(canvas, _blue), isEmpty);
      // A NaN bar is fed as an empty bar at 0, as in Kotlin; the infinite ones reach past the content.
      final plain = _rectsIn(canvas, _red);
      expect(plain, hasLength(3));
      expect(plain[0].rect.width, 0);
      expect(plain[1].rect.right, double.infinity);
      expect(plain[2].rect.left, double.negativeInfinity);
    });
  });
}
