// Tests for renderer/BarChartRenderer.kt on a recording canvas; no Kotlin unit-test counterpart beyond
// BarRendererTest.kt (ported in bar_renderer_test.dart). Locks the bar, shadow, border, rounded and stacked geometry,
// the value label positions and the highlight rectangle, and Review Focus #1 to #3: NaN and infinite values, stacks
// that grow without a notify and highlights that point past the data.
//
// The fake prepares real transformers on a 400 x 300 chart with offsets 20 / 10 / 20 / 10, so the content rect is
// 20..380 x 10..290; by default x −0.5..4.5 → 20..380 px (72 px per x) and y 0..10 → 290..10 px (28 px per y).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/buffer/bar_buffer.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_bar_data_set.dart';
import 'package:mp_flutter_chart/src/renderer/bar_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/fill.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
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

/// One value label the renderer drew: the value, its stack index (−1 for a plain bar) and its baseline position.
typedef _Label = ({double value, int stackIndex, double x, double y});

/// Records the value labels and exposes the protected members of [BarChartRenderer].
class _TestBarRenderer extends BarChartRenderer {
  _TestBarRenderer(FakeBarChart chart, [ChartAnimator? animator])
    : super(chart, animator ?? ChartAnimator(), chart.handler);

  final List<_Label> labels = [];

  List<BarBuffer> get buffers => barBuffers;

  Float32List get radii => barShapeRadii;

  BarCorners corners(IBarDataSet dataSet, int pos, int sections) =>
      barCorners(dataSet, pos, sections);

  void barShape(
    ui.Canvas c,
    IBarDataSet dataSet,
    List<double> ltrb,
    BarCorners corners,
    void Function() draw,
  ) => drawBarShape(
    c,
    dataSet,
    ltrb[0],
    ltrb[1],
    ltrb[2],
    ltrb[3],
    corners,
    draw,
  );

  double get textHeight => Utils.calcTextHeight(paintValues, '8').toDouble();

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
    labels.add((value: value, stackIndex: -1, x: x, y: y));
    super.drawValue(c, formatter, value, entry, dataSetIndex, x, y, color);
  }

  @override
  void drawStackedValue(
    ui.Canvas c,
    IValueFormatter formatter,
    double value,
    int stackIndex,
    Entry entry,
    int dataSetIndex,
    double x,
    double y,
    ui.Color color,
  ) {
    labels.add((value: value, stackIndex: stackIndex, x: x, y: y));
    super.drawStackedValue(
      c,
      formatter,
      value,
      stackIndex,
      entry,
      dataSetIndex,
      x,
      y,
      color,
    );
  }
}

FakeBarChart _chart(
  List<BarDataSet> sets, {
  double xMin = -0.5,
  double xMax = 4.5,
  double yMin = 0,
  double yMax = 10,
}) {
  final handler = ViewPortHandler()
    ..setChartDimens(400, 300)
    ..restrainViewPort(20, 10, 20, 10);
  Transformer transformer() => Transformer(handler)
    ..prepareMatrixValuePx(xMin, xMax - xMin, yMax - yMin, yMin)
    ..prepareMatrixOffset(false);
  return FakeBarChart(
    BarData(sets),
    handler: handler,
    left: transformer(),
    right: transformer(),
    lowestVisibleX: xMin,
    highestVisibleX: xMax,
    xChartMin: xMin,
    xChartMax: xMax,
    yChartMin: yMin,
    yChartMax: yMax,
  );
}

/// The pixel x of the value [x] on a chart showing [xMin]..[xMax].
double _px(double x, {double xMin = -0.5, double xMax = 4.5}) =>
    _contentLeft + (x - xMin) * (_contentRight - _contentLeft) / (xMax - xMin);

/// The pixel y of the value [y] on a chart showing [yMin]..[yMax].
double _py(double y, {double yMin = 0, double yMax = 10}) =>
    _contentBottom -
    (y - yMin) * (_contentBottom - _contentTop) / (yMax - yMin);

/// Where `Utils.drawImage` translates to for a [CountingIcon] given the pixel position ([x], [y]): Kotlin's `toInt()`
/// of each, minus half the 4 px icon.
ui.Offset _iconAt(double x, double y) =>
    ui.Offset(x.truncate() - 2.0, y.truncate() - 2.0);

/// Five plain bars at x 0..4 with height `x + 1`, all in [color].
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

/// A [StrictCanvas] that keeps the bounds every clip path had when it was applied; the renderer reuses one path.
class _ClipBoundsCanvas extends StrictCanvas {
  final List<ui.Rect> clipBounds = [];

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    clipBounds.add(path.getBounds());
    super.clipPath(path, doAntiAlias: doAntiAlias);
  }
}

void main() {
  group('drawData', () {
    test('five plain bars are five rects from x ± barWidth / 2 down to the '
        'content bottom', () {
      final chart = _chart([_fiveBars()]);
      final canvas = StrictCanvas();
      _TestBarRenderer(chart).drawData(canvas);

      final bars = _rectsIn(canvas, _red);
      expect(bars, hasLength(5));
      expect(canvas.rects, hasLength(5));
      for (var k = 0; k < 5; k++) {
        _expectRect(
          bars[k].rect,
          _px(k - 0.425),
          _py(k + 1.0),
          _px(k + 0.425),
          _contentBottom,
        );
      }
      expect(canvas.getSaveCount(), 1);
    });

    test('bar shadows span the content height behind each bar', () {
      final set = _fiveBars();
      final chart = _chart([set])..isDrawBarShadowEnabled = true;
      final canvas = StrictCanvas();
      _TestBarRenderer(chart).drawData(canvas);

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
          _px(k - 0.425),
          _contentTop,
          _px(k + 0.425),
          _contentBottom,
        );
      }
    });

    test('a border draws each bar once more in the border color', () {
      // RecordingCanvas keeps no paint style, so the border shows as one more rect per bar in its color (ruling R-A2).
      final set = _fiveBars()
        ..barBorderWidth = 2
        ..barBorderColor = _blue;
      final canvas = StrictCanvas();
      _TestBarRenderer(_chart([set])).drawData(canvas);

      final bars = _rectsIn(canvas, _red);
      final borders = _rectsIn(canvas, _blue);
      expect(bars, hasLength(5));
      expect(borders, hasLength(5));
      for (var k = 0; k < 5; k++) {
        expect(borders[k].rect, bars[k].rect);
      }
    });

    test('rounded bars are clipped one by one to a rounded rect of their '
        'bounds', () {
      // Kotlin clips to a round rect path and draws a plain rect inside the clip; it draws no round rect.
      final set = _fiveBars()..barCornerRadius = 4;
      final canvas = _ClipBoundsCanvas();
      final renderer = _TestBarRenderer(_chart([set]));
      renderer.drawData(canvas);

      final bars = _rectsIn(canvas, _red);
      expect(bars, hasLength(5));
      expect(canvas.clipBounds, hasLength(5));
      expect(canvas.drawRRectCalls, 0);
      for (var k = 0; k < 5; k++) {
        final bounds = canvas.clipBounds[k];
        expect(bounds.left, closeTo(bars[k].rect.left, 1e-3));
        expect(bounds.top, closeTo(bars[k].rect.top, 1e-3));
        expect(bounds.right, closeTo(bars[k].rect.right, 1e-3));
        expect(bounds.bottom, closeTo(bars[k].rect.bottom, 1e-3));
      }
      expect(renderer.radii.toList(), List.filled(8, 4.0));
      expect(canvas.getSaveCount(), 1);
    });

    test('a stacked bar rounds only its outermost section, at the top', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [2, 3]),
      ], 'stack')..barCornerRadius = 4;
      final canvas = StrictCanvas();
      final renderer = _TestBarRenderer(_chart([set]));
      renderer.drawData(canvas);

      expect(canvas.rects, hasLength(2));
      expect(canvas.clipPaths, hasLength(1));
      expect(renderer.radii.toList(), [4, 4, 4, 4, 0, 0, 0, 0]);
    });

    test('barCorners', () {
      final renderer = _TestBarRenderer(_chart([_fiveBars()]));
      final plain = _fiveBars();
      final stacked = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [1, 2, 3]),
        BarEntry.stacked(x: 1, stackValues: [1, 2]),
      ], 'stack');
      expect(renderer.corners(plain, 3, 1), BarCorners.ALL);
      expect(renderer.corners(stacked, 0, 3), BarCorners.NONE);
      expect(renderer.corners(stacked, 2, 3), BarCorners.TOP);
      // The second entry carries two of the three sections the set makes room for.
      expect(renderer.corners(stacked, 4, 2), BarCorners.TOP);
      expect(renderer.corners(stacked, 5, 2), BarCorners.NONE);
      stacked.isStackSectionsRounded = true;
      expect(renderer.corners(stacked, 0, 3), BarCorners.ALL);
    });

    test('a stacked bar draws one rect per stack value in the color of its '
        'place', () {
      final set = BarDataSet([
        for (var k = 0; k < 5; k++)
          BarEntry.stacked(x: k.toDouble(), stackValues: [2, 3]),
      ], 'stack')..colors = [_red, _green];
      final canvas = StrictCanvas();
      _TestBarRenderer(_chart([set])).drawData(canvas);

      expect(canvas.rects, hasLength(10));
      for (var k = 0; k < 5; k++) {
        final low = canvas.rects[2 * k];
        final high = canvas.rects[2 * k + 1];
        expect(low.color.toARGB32(), _red.toARGB32());
        expect(high.color.toARGB32(), _green.toARGB32());
        _expectRect(low.rect, _px(k - 0.425), _py(2), _px(k + 0.425), _py(0));
        _expectRect(high.rect, _px(k - 0.425), _py(5), _px(k + 0.425), _py(2));
      }
    });

    test('stack colors follow the place of the bar in the data set, not in '
        'the buffer', () {
      // Scrolled to x 1.5..4.5: the feed starts at entry 1, which is off screen, so the first drawn rect is the
      // third of the buffer and the fifth of the data set.
      final set = BarDataSet([
        for (var k = 0; k < 5; k++)
          BarEntry.stacked(x: k.toDouble(), stackValues: [2, 3]),
      ], 'stack')..colors = [_red, _green, _blue];
      final canvas = StrictCanvas();
      _TestBarRenderer(_chart([set], xMin: 1.5)).drawData(canvas);

      expect(canvas.rects.map((r) => r.color.toARGB32()).toList(), [
        for (var pos = 4; pos < 10; pos++) set.getColor(pos).toARGB32(),
      ]);
      expect(
        canvas.rects.first.rect.left,
        closeTo(_px(1.575, xMin: 1.5), 1e-4),
      );
    });

    test('a custom fill paints each bar through its Fill', () {
      final set = _fiveBars()..fills = [Fill.ofColor(_green)];
      final canvas = StrictCanvas();
      _TestBarRenderer(_chart([set])).drawData(canvas);

      expect(canvas.rects, isEmpty);
      expect(canvas.colors, List.filled(5, _green));
      expect(canvas.clipRects, hasLength(5));
      _expectRect(
        canvas.clipRects[2],
        _px(1.575),
        _py(3),
        _px(2.425),
        _contentBottom,
      );
    });

    test('an empty or invisible set draws nothing', () {
      final empty = BarDataSet([], 'empty');
      final hidden = _fiveBars()..isVisible = false;
      final canvas = StrictCanvas();
      _TestBarRenderer(_chart([empty, hidden])).drawData(canvas);
      expect(canvas.calls, isEmpty);
    });

    test('initBuffers keeps the buffers while they fit the data', () {
      final chart = _chart([_fiveBars()]);
      final renderer = _TestBarRenderer(chart)..initBuffers();
      final first = renderer.buffers.single;
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
      expect(renderer.buffers.single.size, 3 * 4 * 2);
      expect(renderer.buffers.single.containsStacks, isTrue);
    });

    test('a stack that grows without a notify keeps the colors of its first '
        'sections', () {
      final stacked = BarEntry.stacked(x: 0, stackValues: [1, 2]);
      final set = BarDataSet([stacked], 'stack')..colors = [_red, _green];
      final renderer = _TestBarRenderer(_chart([set]));
      renderer.drawData(StrictCanvas());

      stacked.stackValues = [1, 2, 3];
      final canvas = StrictCanvas();
      renderer.drawData(canvas);

      // The set still makes room for two sections until it is notified.
      expect(canvas.rects.map((r) => r.color.toARGB32()).toList(), [
        _red.toARGB32(),
        _green.toARGB32(),
      ]);
      _expectRect(
        canvas.rects[1].rect,
        _px(-0.425),
        _py(3),
        _px(0.425),
        _py(1),
      );
    });
  });

  group('drawValues', () {
    test('a positive value sits 4.5 dp above its bar and a negative one '
        'its text height plus 4.5 dp below it', () {
      final set = BarDataSet([
        BarEntry(x: 1, y: 5),
        BarEntry(x: 2, y: -3),
      ], 'bars');
      final renderer = _TestBarRenderer(_chart([set], yMin: -10, yMax: 10));
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      final offset = Utils.convertDpToPixel(4.5);
      expect(renderer.labels, hasLength(2));
      final (above, below) = (renderer.labels[0], renderer.labels[1]);
      expect(above.value, 5);
      expect(above.x, closeTo(_px(1), 1e-4));
      expect(above.y, closeTo(_py(5, yMin: -10, yMax: 10) - offset, 1e-4));
      expect(below.value, -3);
      expect(
        below.y,
        closeTo(
          _py(-3, yMin: -10, yMax: 10) + renderer.textHeight + offset,
          1e-4,
        ),
      );
      expect(canvas.paragraphs, hasLength(2));
    });

    test('values drawn inside the bars sit below the top of a positive bar '
        'and above the bottom of a negative one', () {
      final set = BarDataSet([
        BarEntry(x: 1, y: 5),
        BarEntry(x: 2, y: -3),
      ], 'bars');
      final chart = _chart([set], yMin: -10, yMax: 10)
        ..isDrawValueAboveBarEnabled = false;
      final renderer = _TestBarRenderer(chart);
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      final offset = Utils.convertDpToPixel(4.5);
      expect(
        renderer.labels[0].y,
        closeTo(
          _py(5, yMin: -10, yMax: 10) + renderer.textHeight + offset,
          1e-4,
        ),
      );
      expect(
        renderer.labels[1].y,
        closeTo(_py(-3, yMin: -10, yMax: 10) - offset, 1e-4),
      );
    });

    test('a stacked bar gets one label per stack value, above its section', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 2, stackValues: [2, 3]),
      ], 'stack');
      final renderer = _TestBarRenderer(_chart([set]));
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      final offset = Utils.convertDpToPixel(4.5);
      expect(renderer.labels, hasLength(2));
      expect(
        [for (final l in renderer.labels) (l.value, l.stackIndex)],
        [(2.0, 0), (3.0, 1)],
      );
      expect(renderer.labels[0].x, closeTo(_px(2), 1e-4));
      expect(renderer.labels[0].y, closeTo(_py(2) - offset, 1e-4));
      expect(renderer.labels[1].y, closeTo(_py(5) - offset, 1e-4));
    });

    test('icons are drawn at the label anchor moved by the icons offset, '
        'also with the labels off, and not once icons are off', () {
      final icon = CountingIcon();
      final set = BarDataSet([
        BarEntry(x: 1, y: 5, icon: icon),
        BarEntry(x: 2, y: -3, icon: icon),
      ], 'bars')..iconsOffset = MPPointF(2, -3);
      final renderer = _TestBarRenderer(_chart([set], yMin: -10, yMax: 10));
      final canvas = TranslationRecordingCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      expect(icon.draws, 2);
      // Kotlin's (x + iconsOffset.x).toInt() and (y + iconsOffset.y).toInt() at the label's anchor, 4.5 dp above a
      // positive bar and the text height plus 4.5 dp below a negative one; drawImage centers the icon there.
      expect(renderer.labels, hasLength(2));
      expect(canvas.translations, [
        for (final l in renderer.labels) _iconAt(l.x + 2, l.y - 3),
      ]);

      set.isDrawValuesEnabled = false;
      renderer.drawValues(StrictCanvas());
      expect(icon.draws, 4);
      expect(renderer.labels, hasLength(2));

      set.isDrawIconsEnabled = false;
      renderer.drawValues(StrictCanvas());
      expect(icon.draws, 4);
    });

    test(
      'a stacked bar draws its icon once per stack value, at each label, and '
      'a plain entry in a stacked set once',
      () {
        final stackedIcon = CountingIcon();
        final plainIcon = CountingIcon();
        final set = BarDataSet([
          BarEntry.stacked(x: 1, stackValues: [2, 3], icon: stackedIcon),
          BarEntry(x: 3, y: 4, icon: plainIcon),
        ], 'stack');
        final renderer = _TestBarRenderer(_chart([set]));
        final canvas = TranslationRecordingCanvas();
        renderer
          ..drawData(canvas)
          ..drawValues(canvas);

        expect(stackedIcon.draws, 2);
        expect(plainIcon.draws, 1);
        expect(
          [for (final l in renderer.labels) (l.value, l.stackIndex)],
          [(2.0, 0), (3.0, 1), (4.0, -1)],
        );
        expect(canvas.translations, [
          for (final l in renderer.labels) _iconAt(l.x, l.y),
        ]);

        set.isDrawIconsEnabled = false;
        renderer.drawValues(StrictCanvas());
        expect(stackedIcon.draws, 2);
        expect(plainIcon.draws, 1);
      },
    );
  });

  group('drawHighlighted', () {
    test('a highlight covers its bar in the highlight color at alpha 120 and '
        'marks its top center', () {
      final set = _fiveBars();
      final renderer = _TestBarRenderer(_chart([set]));
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
      _expectRect(
        highlight.rect,
        _px(1.575),
        _py(3),
        _px(2.425),
        _contentBottom,
      );
      expect(high.drawX, closeTo(_px(2), 1e-4));
      expect(high.drawY, closeTo(_py(3), 1e-4));
    });

    test('a stacked highlight covers its section, or the whole bar with full '
        'bar highlighting', () {
      final set = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [-2, 3]),
      ], 'stack');
      final chart = _chart([set], yMin: -10, yMax: 10);
      final renderer = _TestBarRenderer(chart);
      double py(double y) => _py(y, yMin: -10, yMax: 10);

      var canvas = StrictCanvas();
      renderer.drawHighlighted(canvas, [Highlight.stacked(0, 0, 0)]);
      _expectRect(
        canvas.rects.single.rect,
        _px(-0.425),
        py(0),
        _px(0.425),
        py(-2),
      );

      chart.isHighlightFullBarEnabled = true;
      canvas = StrictCanvas();
      renderer.drawHighlighted(canvas, [Highlight.stacked(0, 0, 0)]);
      _expectRect(
        canvas.rects.single.rect,
        _px(-0.425),
        py(3),
        _px(0.425),
        py(-2),
      );
    });

    test('a highlight that points past the data draws nothing', () {
      final stacked = BarDataSet([
        BarEntry.stacked(x: 0, stackValues: [1, 2]),
      ], 'stack');
      final disabled = _fiveBars()..isHighlightEnabled = false;
      final renderer = _TestBarRenderer(_chart([stacked, disabled]));
      final canvas = StrictCanvas();
      renderer.drawData(canvas);
      final drawn = canvas.calls.length;

      renderer.drawHighlighted(canvas, [
        Highlight(0, 3, 0)..stackIndex = 5,
        Highlight(0, 3, 0)..stackIndex = 2,
        Highlight(1, 2, 7),
        Highlight(1, 2, -1),
        Highlight(1, 2, 1),
      ]);
      expect(canvas.calls.length, drawn);
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

    for (final rounded in [false, true]) {
      for (final gradient in [false, true]) {
        test('are drawn without NaN geometry (rounded: $rounded, gradient '
            'fill: $gradient)', () {
          final sets = hostileSets();
          for (final set in sets) {
            set
              ..barCornerRadius = rounded ? 4 : 0
              ..barBorderWidth = 1
              ..barBorderColor = const ui.Color(0xFF123456)
              ..fills = gradient ? [Fill.ofColors(_red, _blue)] : null;
          }
          final chart = _chart(sets)..isDrawBarShadowEnabled = true;
          final renderer = _TestBarRenderer(chart);
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

    test('drawBarShape leaves out a bar with a NaN in any one edge, rounded or '
        'not, and draws one with infinite edges', () {
      final renderer = _TestBarRenderer(_chart([_fiveBars()]));
      for (final radius in [0.0, 4.0]) {
        final set = _fiveBars()..barCornerRadius = radius;
        for (var edge = 0; edge < 4; edge++) {
          final ltrb = [20.0, 10.0, 60.0, 290.0]..[edge] = double.nan;
          final canvas = StrictCanvas();
          var draws = 0;
          renderer.barShape(canvas, set, ltrb, BarCorners.ALL, () => draws++);
          expect(draws, 0, reason: 'radius $radius, edge $edge');
          expect(canvas.calls, isEmpty, reason: 'radius $radius, edge $edge');
        }

        var draws = 0;
        renderer.barShape(
          StrictCanvas(),
          set,
          [20, double.negativeInfinity, 60, double.infinity],
          BarCorners.ALL,
          () => draws++,
        );
        expect(draws, 1, reason: 'radius $radius, infinite edges');
      }
    });

    test('the NaN section of a stack is left out and the others drawn', () {
      final canvas = StrictCanvas();
      _TestBarRenderer(_chart(hostileSets())).drawData(canvas);

      expect(_rectsIn(canvas, _green), hasLength(1));
      expect(_rectsIn(canvas, _blue), isEmpty);
      // A NaN bar is fed as an empty bar at 0, as in Kotlin; the infinite ones reach past the content.
      final plain = _rectsIn(canvas, _red);
      expect(plain, hasLength(3));
      expect(plain[0].rect.height, 0);
      expect(plain[1].rect.top, double.negativeInfinity);
      expect(plain[2].rect.bottom, double.infinity);
    });

    test('an infinite bar at y phase 0 becomes NaN and is left out', () {
      final set = BarDataSet([
        BarEntry(x: 0, y: double.infinity),
        BarEntry(x: 1, y: 2),
      ], 'plain')..barCornerRadius = 4;
      final animator = ChartAnimator()..phaseY = 0;
      final renderer = _TestBarRenderer(_chart([set]), animator);
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawHighlighted(canvas, [Highlight(0, double.nan, 0)])
        ..drawValues(canvas);

      expect(canvas.rects, hasLength(1));
    });

    test('the label of a −∞ bar at y phase 0 is left out, as its bottom is '
        'NaN', () {
      // The feed multiplies the bottom by the phase (−∞ × 0 = NaN) while the top stays 0 and in bounds, so the
      // negative label is anchored at a NaN y; animateY starts at phase 0.
      final set = BarDataSet([
        BarEntry(x: 0, y: double.negativeInfinity),
        BarEntry(x: 1, y: 2),
      ], 'plain');
      final animator = ChartAnimator()..phaseY = 0;
      final renderer = _TestBarRenderer(_chart([set]), animator);
      final canvas = StrictCanvas();
      renderer
        ..drawData(canvas)
        ..drawValues(canvas);

      expect(renderer.labels, hasLength(2));
      expect(renderer.labels[0].y, isNaN);
      expect(canvas.paragraphs, hasLength(1));
    });
  });
}
