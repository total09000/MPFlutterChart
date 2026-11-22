// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for CandleStickChartRenderer. Locks what
// renderer/CandleStickChartRenderer.kt draws on a recording canvas: with candle bars a shadow (two lines
// from high and low to the body) and a body from open to close, stroked or filled per direction, or a line when open
// equals close; without them a high-low line and open and close ticks; the colors per direction with their
// COLOR_NONE fallbacks; the value labels 5 dp above the high; the highlight lines through the middle of high and low.
// Review Focus #1: NaN and infinite high, low, open and close draw without NaN geometry at a y phase of 1 and of 0.
//
// The fake prepares real transformers on a 400 x 300 chart with offsets 20 / 10 / 20 / 10, so the content rect is
// 20..380 x 10..290; x −0.5..4.5 → 20..380 px (72 px per x) and y 0..28 → 290..10 px (10 px per y). Dp equal px.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/data/candle_data.dart';
import 'package:mp_flutter_chart/src/data/candle_data_set.dart';
import 'package:mp_flutter_chart/src/data/candle_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_candle_data_set.dart';
import 'package:mp_flutter_chart/src/renderer/candle_stick_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import '../recording/recording_canvas.dart';
import 'support/counting_icon.dart';
import 'support/fake_providers.dart';
import 'support/paint_recording_canvas.dart';
import 'support/strict_canvas.dart';

const _contentLeft = 20.0;
const _contentRight = 380.0;
const _contentBottom = 290.0;

const _increasing = ui.Color(0xFF00FF00);
const _decreasing = ui.Color(0xFFFF0000);
const _neutral = ui.Color(0xFF0000FF);
const _shadow = ui.Color(0xFF808080);
const _c0 = ui.Color(0xFF111111);
const _c1 = ui.Color(0xFF222222);
const _c2 = ui.Color(0xFF333333);

/// One value label the renderer drew: the value and its baseline position.
typedef _Label = ({double value, double x, double y});

/// Records the value labels of [CandleStickChartRenderer].
class _TestCandleRenderer extends CandleStickChartRenderer {
  _TestCandleRenderer(FakeCandleChart chart, [ChartAnimator? animator])
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

/// A fake over x [xMin]..[xMax] and y 0..28 on the 400 x 300 chart.
FakeCandleChart _chart(
  List<ICandleDataSet> sets, {
  double xMin = -0.5,
  double xMax = 4.5,
  int maxVisibleCount = 100,
}) {
  const yMin = 0.0, yMax = 28.0;
  final handler = ViewPortHandler()
    ..setChartDimens(400, 300)
    ..restrainViewPort(20, 10, 20, 10);
  Transformer transformer() => Transformer(handler)
    ..prepareMatrixValuePx(xMin, xMax - xMin, yMax - yMin, yMin)
    ..prepareMatrixOffset(false);
  return FakeCandleChart(
    CandleData(sets),
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

/// The pixel x of the value [x] on the default x range −0.5..4.5.
double _px(double x) =>
    _contentLeft + (x + 0.5) * (_contentRight - _contentLeft) / 5;

/// The pixel y of the value [y].
double _py(double y) => _contentBottom - y * 10;

CandleEntry _candle(
  double x,
  double high,
  double low,
  double open,
  double close, {
  ChartDrawable? icon,
}) => CandleEntry(
  x: x,
  high: high,
  low: low,
  open: open,
  close: close,
  icon: icon,
);

/// An increasing candle at x 1, a decreasing one at x 2 and a neutral one at x 3, in the three direction colors and
/// the shadow color.
CandleDataSet _threeCandles() =>
    CandleDataSet([
        _candle(1, 20, 4, 8, 16),
        _candle(2, 24, 6, 18, 10),
        _candle(3, 14, 2, 9, 9),
      ], 'candles')
      ..increasingColor = _increasing
      ..decreasingColor = _decreasing
      ..neutralColor = _neutral
      ..shadowColor = _shadow;

/// The four sides of [rect] as a list, left, top, right, bottom.
List<double> _ltrb(ui.Rect rect) => [
  rect.left,
  rect.top,
  rect.right,
  rect.bottom,
];

/// Matches a list of doubles element by element within 1e-3.
Matcher _closeToAll(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (e, a) => (e - a).abs() < 1e-3,
  'within 1e-3 of',
);

void main() {
  group('drawData with candle bars', () {
    test('an increasing body is a stroked rect in increasingColor from close '
        'to open, a decreasing one a filled rect in decreasingColor from open '
        'to close, a neutral one a line in neutralColor', () {
      final canvas = PaintRecordingCanvas();

      _TestCandleRenderer(_chart([_threeCandles()])).drawData(canvas);

      // barSpace 0.1: each body spans x − 0.4 .. x + 0.4.
      expect(canvas.rects, hasLength(2));
      final increasing = canvas.rects[0];
      expect(
        _ltrb(increasing.rect),
        _closeToAll([_px(0.6), _py(16), _px(1.4), _py(8)]),
      );
      expect(increasing.color.toARGB32(), _increasing.toARGB32());
      expect(canvas.rectPaints[0].style, ui.PaintingStyle.stroke);
      // The body is stroked with the shadow width, 1.5 dp.
      expect(canvas.rectPaints[0].strokeWidth, closeTo(1.5, 1e-6));

      final decreasing = canvas.rects[1];
      expect(
        _ltrb(decreasing.rect),
        _closeToAll([_px(1.6), _py(18), _px(2.4), _py(10)]),
      );
      expect(decreasing.color.toARGB32(), _decreasing.toARGB32());
      expect(canvas.rectPaints[1].style, ui.PaintingStyle.fill);

      final neutral = canvas.lines.single;
      expect([
        neutral.p1.dx,
        neutral.p1.dy,
        neutral.p2.dx,
        neutral.p2.dy,
      ], _closeToAll([_px(2.6), _py(9), _px(3.4), _py(9)]));
      expect(neutral.color.toARGB32(), _neutral.toARGB32());
    });

    test('each shadow is one drawLines call of two lines, from the high to the '
        'top of the body and from the low to its bottom, in shadowColor', () {
      final canvas = RecordingCanvas();

      _TestCandleRenderer(_chart([_threeCandles()])).drawData(canvas);

      expect(canvas.rawPoints, hasLength(3));
      final expected = [
        [_px(1), _py(20), _px(1), _py(16), _px(1), _py(4), _px(1), _py(8)],
        [_px(2), _py(24), _px(2), _py(18), _px(2), _py(6), _px(2), _py(10)],
        [_px(3), _py(14), _px(3), _py(9), _px(3), _py(2), _px(3), _py(9)],
      ];
      for (var i = 0; i < 3; i++) {
        final shadow = canvas.rawPoints[i];
        expect(shadow.mode, ui.PointMode.lines, reason: 'shadow $i mode');
        expect(shadow.points, _closeToAll(expected[i]), reason: 'shadow $i');
        expect(
          shadow.color.toARGB32(),
          _shadow.toARGB32(),
          reason: 'shadow $i color',
        );
      }
      // The shadows are drawn before the body of their candle.
      expect(canvas.calls.indexOf('drawRawPoints'), 0);
      expect(canvas.calls[1], 'drawRect');
    });

    test('with shadowColorSameAsCandle the shadow takes the color of its '
        'direction', () {
      final canvas = RecordingCanvas();
      final set = _threeCandles()..shadowColorSameAsCandle = true;

      _TestCandleRenderer(_chart([set])).drawData(canvas);

      expect(
        [for (final s in canvas.rawPoints) s.color.toARGB32()],
        [_increasing.toARGB32(), _decreasing.toARGB32(), _neutral.toARGB32()],
      );
    });

    test('a COLOR_NONE body or shadow color falls back to the entry color', () {
      final set = CandleDataSet([
        _candle(1, 20, 4, 8, 16),
        _candle(2, 24, 6, 18, 10),
        _candle(3, 14, 2, 9, 9),
      ], 'candles')..colors = [_c0, _c1, _c2];
      final entryColors = [_c0.toARGB32(), _c1.toARGB32(), _c2.toARGB32()];

      final canvas = RecordingCanvas();
      _TestCandleRenderer(_chart([set])).drawData(canvas);
      expect([
        for (final s in canvas.rawPoints) s.color.toARGB32(),
      ], entryColors);
      expect(
        [for (final r in canvas.rects) r.color.toARGB32()],
        [_c0.toARGB32(), _c1.toARGB32()],
      );
      expect(canvas.lines.single.color.toARGB32(), _c2.toARGB32());

      set.shadowColorSameAsCandle = true;
      final sameAsCandle = RecordingCanvas();
      _TestCandleRenderer(_chart([set])).drawData(sameAsCandle);
      expect([
        for (final s in sameAsCandle.rawPoints) s.color.toARGB32(),
      ], entryColors);
    });

    test('the body is 1 − 2 × barSpace of an x step wide', () {
      for (final (barSpace, width) in [
        (0.1, 57.6),
        (0.25, 36.0),
        (0.0, 72.0),
      ]) {
        final canvas = RecordingCanvas();
        final set = _threeCandles()..barSpace = barSpace;

        _TestCandleRenderer(_chart([set])).drawData(canvas);

        for (final rect in canvas.rects) {
          expect(rect.rect.width, closeTo(width, 1e-3), reason: '$barSpace');
        }
        final line = canvas.lines.single;
        expect(line.p2.dx - line.p1.dx, closeTo(width, 1e-3));
      }
    });

    test('the paint styles of the two directions are the data set\'s', () {
      final canvas = PaintRecordingCanvas();
      final set = _threeCandles()
        ..increasingPaintStyle = PaintStyle.FILL
        ..decreasingPaintStyle = PaintStyle.STROKE;

      _TestCandleRenderer(_chart([set])).drawData(canvas);

      expect(
        [for (final p in canvas.rectPaints) p.style],
        [ui.PaintingStyle.fill, ui.PaintingStyle.stroke],
      );
    });
  });

  group('drawData without candle bars', () {
    test('each candle is a high-low line, an open tick to the left and a close '
        'tick to the right, in the color of its direction and the shadow '
        'width', () {
      final canvas = RecordingCanvas();
      final set = _threeCandles()
        ..showCandleBar = false
        ..shadowWidth = 3;

      _TestCandleRenderer(_chart([set])).drawData(canvas);

      expect(canvas.rects, isEmpty);
      expect(canvas.rawPoints, isEmpty);
      expect(canvas.lines, hasLength(9));
      final candles = [
        (1.0, 20.0, 4.0, 8.0, 16.0, _increasing),
        (2.0, 24.0, 6.0, 18.0, 10.0, _decreasing),
        (3.0, 14.0, 2.0, 9.0, 9.0, _neutral),
      ];
      for (var i = 0; i < 3; i++) {
        final (x, high, low, open, close, color) = candles[i];
        final range = canvas.lines[3 * i];
        final openTick = canvas.lines[3 * i + 1];
        final closeTick = canvas.lines[3 * i + 2];
        expect(
          [range.p1.dx, range.p1.dy, range.p2.dx, range.p2.dy],
          _closeToAll([_px(x), _py(high), _px(x), _py(low)]),
          reason: 'range $i',
        );
        expect(
          [openTick.p1.dx, openTick.p1.dy, openTick.p2.dx, openTick.p2.dy],
          _closeToAll([_px(x - 0.4), _py(open), _px(x), _py(open)]),
          reason: 'open $i',
        );
        expect(
          [closeTick.p1.dx, closeTick.p1.dy, closeTick.p2.dx, closeTick.p2.dy],
          _closeToAll([_px(x + 0.4), _py(close), _px(x), _py(close)]),
          reason: 'close $i',
        );
        for (final line in [range, openTick, closeTick]) {
          expect(line.color.toARGB32(), color.toARGB32(), reason: 'color $i');
          expect(line.strokeWidth, closeTo(3, 1e-6), reason: 'width $i');
        }
      }
    });

    test('a COLOR_NONE direction color falls back to the entry color for the '
        'range line and both ticks', () {
      final set =
          CandleDataSet([
              _candle(1, 20, 4, 8, 16),
              _candle(2, 24, 6, 18, 10),
              _candle(3, 14, 2, 9, 9),
            ], 'candles')
            ..colors = [_c0, _c1, _c2]
            ..showCandleBar = false;

      final canvas = RecordingCanvas();
      _TestCandleRenderer(_chart([set])).drawData(canvas);

      expect(
        [for (final l in canvas.lines) l.color.toARGB32()],
        [
          for (final c in [_c0, _c1, _c2]) ...List.filled(3, c.toARGB32()),
        ],
      );
    });
  });

  group('drawData phases and empty data', () {
    test('phaseY scales every value, phaseX reveals the first candles', () {
      final canvas = RecordingCanvas();
      final animator = ChartAnimator()..phaseY = 0.5;

      _TestCandleRenderer(_chart([_threeCandles()]), animator).drawData(canvas);

      expect(
        _ltrb(canvas.rects[0].rect),
        _closeToAll([_px(0.6), _py(8), _px(1.4), _py(4)]),
      );
      expect(
        canvas.rawPoints[0].points,
        _closeToAll([
          _px(1), _py(10), _px(1), _py(8), _px(1), _py(2), _px(1), _py(4), //
        ]),
      );

      final revealed = RecordingCanvas();
      _TestCandleRenderer(
        _chart([_threeCandles()]),
        ChartAnimator()..phaseX = 0.5,
      ).drawData(revealed);
      expect(revealed.rawPoints, hasLength(2));
    });

    test('an invisible set, an empty set and no data draw nothing', () {
      final canvas = RecordingCanvas();
      _TestCandleRenderer(
        _chart([_threeCandles()..isVisible = false]),
      ).drawData(canvas);
      _TestCandleRenderer(
        _chart([CandleDataSet(<CandleEntry>[], 'empty')]),
      ).drawData(canvas);
      final noData = _chart([])..candleData = null;
      _TestCandleRenderer(noData)
        ..drawData(canvas)
        ..drawValues(canvas)
        ..drawHighlighted(canvas, [Highlight(1, 12, 0)]);
      expect(canvas.calls, isEmpty);
    });

    test('lowOf and highOf read the low and the high', () {
      final renderer = _TestCandleRenderer(_chart([_threeCandles()]));
      final candle = _candle(0, 20, 4, 8, 16);
      expect(renderer.lowOf(candle), 4);
      expect(renderer.highOf(candle), 20);
    });
  });

  group('drawValues', () {
    test('each label is the high, 5 dp above it', () {
      final canvas = RecordingCanvas();
      final renderer = _TestCandleRenderer(_chart([_threeCandles()]));

      renderer.drawValues(canvas);

      expect(renderer.labels, hasLength(3));
      final expected = [(20.0, 1.0), (24.0, 2.0), (14.0, 3.0)];
      for (var i = 0; i < 3; i++) {
        final (high, x) = expected[i];
        final label = renderer.labels[i];
        expect(label.value, high, reason: 'label $i value');
        expect(label.x, closeTo(_px(x), 1e-3), reason: 'label $i x');
        expect(label.y, closeTo(_py(high) - 5, 1e-3), reason: 'label $i y');
      }
      expect(canvas.paragraphs, hasLength(3));
    });

    test('a high above the content rect gets no label, and more candles in '
        'view than maxVisibleCount get none at all', () {
      final set = CandleDataSet([
        _candle(0, 30, 4, 8, 16),
        _candle(1, 20, 4, 8, 16),
        _candle(2, 24, 6, 18, 10),
      ], 'candles');
      final renderer = _TestCandleRenderer(_chart([set]));
      renderer.drawValues(RecordingCanvas());
      expect([for (final l in renderer.labels) l.value], [20, 24]);

      final crowded = _TestCandleRenderer(_chart([set], maxVisibleCount: 2));
      crowded.drawValues(RecordingCanvas());
      expect(crowded.labels, isEmpty);
    });

    test('icons are drawn while icons are enabled, even without labels', () {
      final icon = CountingIcon();
      final set = CandleDataSet([
        _candle(1, 20, 4, 8, 16, icon: icon),
        _candle(2, 24, 6, 18, 10, icon: icon),
      ], 'candles')..isDrawValuesEnabled = false;
      final renderer = _TestCandleRenderer(_chart([set]));

      renderer.drawValues(RecordingCanvas());
      expect(renderer.labels, isEmpty);
      expect(icon.draws, 2);

      set.isDrawIconsEnabled = false;
      renderer.drawValues(RecordingCanvas());
      expect(icon.draws, 2);
    });
  });

  group('drawHighlighted', () {
    test('the highlight lines cross at the middle of high and low times '
        'phaseY', () {
      final set = _threeCandles();
      final canvas = RecordingCanvas();
      final high = Highlight(2, 15, 0);

      _TestCandleRenderer(_chart([set])).drawHighlighted(canvas, [high]);

      expect(high.drawX, closeTo(_px(2), 1e-3));
      expect(high.drawY, closeTo(_py(15), 1e-3));
      expect(canvas.paths, hasLength(2));
      final vertical = canvas.paths[0].bounds;
      expect(vertical.left, closeTo(_px(2), 1e-3));
      expect(vertical.top, closeTo(10, 1e-3));
      expect(vertical.bottom, closeTo(_contentBottom, 1e-3));
      final horizontal = canvas.paths[1].bounds;
      expect(horizontal.top, closeTo(_py(15), 1e-3));
      expect(horizontal.left, closeTo(_contentLeft, 1e-3));
      expect(horizontal.right, closeTo(_contentRight, 1e-3));

      final halfway = Highlight(2, 15, 0);
      _TestCandleRenderer(
        _chart([set]),
        ChartAnimator()..phaseY = 0.5,
      ).drawHighlighted(RecordingCanvas(), [halfway]);
      expect(halfway.drawY, closeTo(_py(7.5), 1e-3));
    });

    test('the highlight follows high and low, not the y set at '
        'construction', () {
      final set = _threeCandles();
      final candle = set.getEntryForIndex(1)..high = 30;
      expect(candle.y, 15);
      final high = Highlight(2, 15, 0);

      _TestCandleRenderer(
        _chart([set]),
      ).drawHighlighted(RecordingCanvas(), [high]);

      expect(high.drawY, closeTo(_py(18), 1e-3));
    });

    test('nothing is drawn for a set without highlighting, a missing set or a '
        'candle the x phase has not revealed', () {
      final canvas = RecordingCanvas();
      final noHighlight = _threeCandles()..isHighlightEnabled = false;
      _TestCandleRenderer(
        _chart([noHighlight]),
      ).drawHighlighted(canvas, [Highlight(1, 12, 0)]);
      _TestCandleRenderer(
        _chart([_threeCandles()]),
      ).drawHighlighted(canvas, [Highlight(1, 12, 3)]);
      final hidden = Highlight(3, 8, 0);
      _TestCandleRenderer(
        _chart([_threeCandles()]),
        ChartAnimator()..phaseX = 0.5,
      ).drawHighlighted(canvas, [hidden]);
      expect(canvas.calls, isEmpty);
      expect(hidden.drawX, 0);
    });
  });

  group('NaN and infinite values (Review Focus #1)', () {
    const nan = double.nan, inf = double.infinity;
    // One finite increasing candle, then each of high, low, open and close in turn NaN, +∞ and −∞.
    List<CandleEntry> hostile() {
      final values = <List<double>>[
        [20, 4, 8, 16],
        [nan, 4, 8, 16], [inf, 4, 8, 16], [-inf, 4, 8, 16], //
        [20, nan, 8, 16], [20, inf, 8, 16], [20, -inf, 8, 16], //
        [20, 4, nan, 16], [20, 4, inf, 16], [20, 4, -inf, 16], //
        [20, 4, 8, nan], [20, 4, 8, inf], [20, 4, 8, -inf], //
      ];
      return [
        for (var i = 0; i < values.length; i++)
          _candle(
            i.toDouble(),
            values[i][0],
            values[i][1],
            values[i][2],
            values[i][3],
          ),
      ];
    }

    // Per (showCandleBar, phaseY): the rects, lines and shadows drawn.
    //  - Bodies: a NaN open or close fails both comparisons and becomes a neutral line, which has a NaN end; an
    //    infinite one is a rect with an infinite edge, which Flutter draws. At phaseY 0 an infinite value turns into
    //    0 × ∞ = NaN.
    //  - Shadows go to drawRawPoints, which takes NaN without asserting; Skia leaves such lines out.
    //  - Without candle bars each line is left out when one of its values is NaN, or infinite at phaseY 0.
    final cases = [
      (showCandleBar: true, phaseY: 1.0, rects: 11, lines: 0, shadows: 13),
      (showCandleBar: true, phaseY: 0.0, rects: 7, lines: 0, shadows: 13),
      (showCandleBar: false, phaseY: 1.0, rects: 0, lines: 35, shadows: 0),
      (showCandleBar: false, phaseY: 0.0, rects: 0, lines: 27, shadows: 0),
    ];

    for (final c in cases) {
      test('draw without NaN geometry (showCandleBar ${c.showCandleBar}, '
          'phaseY ${c.phaseY})', () {
        final set = CandleDataSet(hostile(), 'hostile')
          ..showCandleBar = c.showCandleBar;
        final chart = _chart([set], xMin: -0.5, xMax: 12.5);
        final renderer = _TestCandleRenderer(
          chart,
          ChartAnimator()..phaseY = c.phaseY,
        );

        final data = StrictCanvas();
        renderer.drawData(data);
        expect(data.rects, hasLength(c.rects), reason: 'rects');
        expect(data.lines, hasLength(c.lines), reason: 'lines');
        expect(data.rawPoints, hasLength(c.shadows), reason: 'shadows');

        // The candles with a NaN or infinite high have their label position above, below or outside the content
        // rect and get no label; the other ten do.
        final values = StrictCanvas();
        renderer.drawValues(values);
        expect(values.paragraphs, hasLength(10), reason: 'labels');
        expect(renderer.labels.map((l) => l.value), everyElement(20));

        // The highlight lines are paths; a NaN in them reaches Skia, which skips it (ruling A11).
        final highlights = [
          for (var i = 0; i < 13; i++) Highlight(i.toDouble(), 12, 0),
        ];
        final highlighted = StrictCanvas();
        renderer.drawHighlighted(highlighted, highlights);
        expect(highlighted.paths, hasLength(26), reason: 'highlight lines');
        expect(
          highlights[0].drawY,
          closeTo(_contentBottom - 12 * 10 * c.phaseY, 1e-3),
        );
      });
    }

    test('a NaN bar space, which the clamp lets through, leaves out the '
        'bodies and the ticks but keeps the shadows and the range lines', () {
      for (final showCandleBar in [true, false]) {
        final set = _threeCandles()
          ..barSpace = double.nan
          ..showCandleBar = showCandleBar;
        final canvas = StrictCanvas();
        _TestCandleRenderer(_chart([set])).drawData(canvas);

        final reason = 'showCandleBar $showCandleBar';
        expect(canvas.rects, isEmpty, reason: reason);
        if (showCandleBar) {
          // The neutral candle's body is a line, which has NaN ends too.
          expect(canvas.lines, isEmpty, reason: reason);
          expect(canvas.rawPoints, hasLength(3), reason: reason);
        } else {
          expect(canvas.lines, hasLength(3), reason: reason);
          for (final (i, line) in canvas.lines.indexed) {
            expect(line.p1.dx, closeTo(_px(i + 1.0), 1e-3), reason: reason);
            expect(line.p2.dx, closeTo(_px(i + 1.0), 1e-3), reason: reason);
          }
        }
      }
    });
  });
}
