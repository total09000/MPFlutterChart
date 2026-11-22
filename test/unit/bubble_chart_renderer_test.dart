// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for BubbleChartRenderer (its Kotlin
// RendererEdgeCaseTest part runs in renderer_edge_case_test.dart). Locks what renderer/BubbleChartRenderer.kt draws on
// a recording canvas: one filled circle per bubble in the entry color, whose diameter is the reference
// size (the smaller of one x unit and the content height) scaled by the square root of size / maxSize, or by the size
// itself with normalizing off; the culling of bubbles that lie wholly outside the content rect; the size labels
// centered on the bubbles, faded with the animation; the highlight ring in a darker shade of the entry color; and the
// lowOf / highOf / hasSizes / sizeOf answers the point reduction reads.
// Review Focus #5: sizes of 0 (maxSize 0 included), negative, NaN and infinite, with normalizing on and off, and a
// content rect of size 0, draw on a StrictCanvas without a NaN circle.
//
// The fake prepares real transformers on a 400 x 300 chart with offsets 20 / 10 / 20 / 10, so the content rect is
// 20..380 x 10..290; x 0..10 → 20..380 px (36 px per x) and y 0..28 → 290..10 px (10 px per y). The reference size
// is therefore 36 px, the smaller of one x unit and the 280 px content height. Dp equal px.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/animation/chart_animator.dart';
import 'package:mp_flutter_chart/src/data/bubble_data.dart';
import 'package:mp_flutter_chart/src/data/bubble_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_entry.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_bubble_data_set.dart';
import 'package:mp_flutter_chart/src/renderer/bubble_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import '../recording/recording_canvas.dart';
import 'support/counting_icon.dart';
import 'support/fake_providers.dart';
import 'support/paint_recording_canvas.dart';
import 'support/strict_canvas.dart';

const _c0 = ui.Color(0xFF111111);
const _c1 = ui.Color(0xFF222222);
const _c2 = ui.Color(0xFF333333);

/// One value label the renderer drew: the value, its baseline position and its color.
typedef _Label = ({double value, double x, double y, ui.Color color});

/// Exposes [getShapeSize] and records the value labels of [BubbleChartRenderer].
class _TestBubbleRenderer extends BubbleChartRenderer {
  _TestBubbleRenderer(FakeBubbleChart chart, [ChartAnimator? animator])
    : super(chart, animator ?? ChartAnimator(), chart.handler);

  final List<_Label> labels = [];

  double shapeSize(
    double entrySize,
    double maxSize,
    double reference,
    bool normalizeSize,
  ) => getShapeSize(entrySize, maxSize, reference, normalizeSize);

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
    labels.add((value: value, x: x, y: y, color: color));
    super.drawValue(c, formatter, value, entry, dataSetIndex, x, y, color);
  }
}

/// A fake over x 0..10 and y 0..28 on the 400 x 300 chart. [lowestVisibleX] / [highestVisibleX] only widen the
/// entries the renderer walks, not the transformer.
FakeBubbleChart _chart(
  List<IBubbleDataSet> sets, {
  double lowestVisibleX = 0,
  double highestVisibleX = 10,
  int maxVisibleCount = 100,
  ViewPortHandler? handler,
}) {
  const xMin = 0.0, xMax = 10.0, yMin = 0.0, yMax = 28.0;
  final viewPort =
      handler ??
      (ViewPortHandler()
        ..setChartDimens(400, 300)
        ..restrainViewPort(20, 10, 20, 10));
  Transformer transformer() => Transformer(viewPort)
    ..prepareMatrixValuePx(xMin, xMax - xMin, yMax - yMin, yMin)
    ..prepareMatrixOffset(false);
  return FakeBubbleChart(
    BubbleData(sets),
    handler: viewPort,
    left: transformer(),
    right: transformer(),
    lowestVisibleX: lowestVisibleX,
    highestVisibleX: highestVisibleX,
    xChartMin: xMin,
    xChartMax: xMax,
    yChartMin: yMin,
    yChartMax: yMax,
    maxVisibleCount: maxVisibleCount,
  );
}

/// The pixel x of the value [x].
double _px(double x) => 20 + x * 36;

/// The pixel y of the value [y].
double _py(double y) => 290 - y * 10;

BubbleEntry _bubble(double x, double y, double size, {ChartDrawable? icon}) =>
    BubbleEntry(x: x, y: y, size: size, icon: icon);

/// A bubble of size 4 at (2, 10) and one of size 1 at (5, 5), in the colors [_c0] and [_c1].
BubbleDataSet _twoBubbles() =>
    BubbleDataSet([_bubble(2, 10, 4), _bubble(5, 5, 1)], 'bubbles')
      ..colors = [_c0, _c1];

/// Whether [circle] has a NaN in its geometry.
bool _hasNaN(CircleDraw circle) =>
    circle.x.isNaN || circle.y.isNaN || circle.radius.isNaN;

/// Android's highlight color for [color]: `Color.RGBToHSV`, the value halved, `Color.HSVToColor` with the alpha of
/// [color] (Skia's SkRGBToHSV / SkHSVToColor, worked out in Float arithmetic).
const _androidHighlight = <int, int>{
  0xFFFF0000: 0xFF800000,
  0x8000FF00: 0x80008000,
  0xFF405980: 0xFF202D40,
  0xFFC0FF8C: 0xFF608046,
  0x40FFFFFF: 0x40808080,
  0xFF000000: 0xFF000000,
  // Flutter gives 20295B and 805D39 for these two: the rounding differs by 1.
  0xFF3F51B5: 0xFF1F285B,
  0xFFFFBB73: 0xFF805E39,
};

void main() {
  group('getShapeSize', () {
    final renderer = _TestBubbleRenderer(_chart([]));

    test('normalized: the reference scaled by the square root of size / '
        'maxSize', () {
      expect(renderer.shapeSize(4, 4, 36, true), 36);
      expect(renderer.shapeSize(1, 4, 36, true), 18);
      expect(renderer.shapeSize(0, 4, 36, true), 0);
    });

    test('normalized with a maxSize of 0: the whole reference, whatever the '
        'size', () {
      expect(renderer.shapeSize(0, 0, 36, true), 36);
      expect(renderer.shapeSize(-5, 0, 36, true), 36);
    });

    test('normalized with a negative or NaN size: NaN', () {
      expect(renderer.shapeSize(-5, 4, 36, true), isNaN);
      expect(renderer.shapeSize(double.nan, 4, 36, true), isNaN);
    });

    test('not normalized: the reference times the size', () {
      expect(renderer.shapeSize(4, 4, 36, false), 144);
      expect(renderer.shapeSize(1, 4, 36, false), 36);
      expect(renderer.shapeSize(-5, 4, 36, false), -180);
      expect(renderer.shapeSize(1, 0, 36, false), 36);
    });
  });

  group('drawData', () {
    test('normalized sizes 4 and 1 give diameters of 36 and 18 px, 2 to 1, '
        'filled in the entry colors', () {
      final canvas = PaintRecordingCanvas();
      _TestBubbleRenderer(_chart([_twoBubbles()])).drawData(canvas);

      expect(canvas.circles, hasLength(2));
      final big = canvas.circles[0], small = canvas.circles[1];
      expect([big.x, big.y, big.radius], [_px(2), _py(10), 18]);
      expect([small.x, small.y, small.radius], [_px(5), _py(5), 9]);
      expect(big.radius / small.radius, 2);
      expect(
        [big.color.toARGB32(), small.color.toARGB32()],
        [_c0.toARGB32(), _c1.toARGB32()],
      );
      expect([big.style, small.style], everyElement(ui.PaintingStyle.fill));
    });

    test('without normalizing the diameters are the reference times the size, '
        '4 to 1', () {
      final canvas = RecordingCanvas();
      final set = _twoBubbles()..isNormalizeSizeEnabled = false;
      _TestBubbleRenderer(_chart([set])).drawData(canvas);

      expect([for (final c in canvas.circles) c.radius], [72, 18]);
    });

    test('the reference is the content height when one x unit is wider', () {
      final handler = ViewPortHandler()
        ..setChartDimens(400, 300)
        ..restrainViewPort(20, 10, 20, 10);
      // x 0..1 over 360 px: one x unit is wider than the 280 px content height.
      final transformer = Transformer(handler)
        ..prepareMatrixValuePx(0, 1, 28, 0)
        ..prepareMatrixOffset(false);
      final chart = FakeBubbleChart(
        BubbleData([
          BubbleDataSet([_bubble(0.5, 14, 4)], 'bubbles'),
        ]),
        handler: handler,
        left: transformer,
        right: transformer,
        highestVisibleX: 1,
      );
      final canvas = RecordingCanvas();
      BubbleChartRenderer(chart, ChartAnimator(), handler).drawData(canvas);

      expect(canvas.circles.single.radius, 140);
    });

    test('phaseY scales the y values, not the sizes', () {
      final canvas = RecordingCanvas();
      final animator = ChartAnimator()..phaseY = 0.5;
      _TestBubbleRenderer(_chart([_twoBubbles()]), animator).drawData(canvas);

      expect(
        [for (final c in canvas.circles) (c.y, c.radius)],
        [(_py(5), 18), (_py(2.5), 9)],
      );
    });

    test('phaseX reveals the entries one by one', () {
      final canvas = RecordingCanvas();
      final animator = ChartAnimator()..phaseX = 0.5;
      _TestBubbleRenderer(_chart([_twoBubbles()]), animator).drawData(canvas);

      expect(canvas.circles.single.x, _px(2));
    });

    test('a bubble that lies wholly outside the content rect is skipped, one '
        'that reaches into it is drawn', () {
      // Every bubble has size 4, a radius of 18 px.
      final set = BubbleDataSet([
        _bubble(-1, 14, 4), // right edge at 2 px: skipped
        _bubble(-0.25, 14, 4), // right edge at 29 px: drawn
        _bubble(2, 30, 4), // bottom edge at 8 px: skipped
        _bubble(3, 29, 4), // bottom edge at 18 px: drawn
        _bubble(4, -2.9, 4), // top edge at 301 px: skipped
        _bubble(5, -1.7, 4), // top edge at 289 px: drawn
        _bubble(10.25, 14, 4), // left edge at 371 px: drawn
        _bubble(11, 14, 4), // left edge at 398 px: the walk stops
      ], 'bubbles');
      final canvas = StrictCanvas();
      _TestBubbleRenderer(
        _chart([set], lowestVisibleX: -2, highestVisibleX: 12),
      ).drawData(canvas);

      expect(
        [for (final c in canvas.circles) c.x],
        [_px(-0.25), _px(3), _px(5), _px(10.25)],
      );
    });

    test('an empty set and no data draw nothing', () {
      for (final chart in [
        _chart([BubbleDataSet(<BubbleEntry>[], 'empty')]),
        _chart([])..bubbleData = null,
      ]) {
        final canvas = StrictCanvas();
        final renderer = _TestBubbleRenderer(chart);
        renderer.drawData(canvas);
        renderer.drawValues(canvas);
        renderer.drawHighlighted(canvas, [Highlight(2, 10, 0)]);
        expect(canvas.calls, isEmpty);
      }
    });

    test('an invisible set draws no bubbles and no labels, but its highlight '
        'ring, as in Kotlin', () {
      final canvas = StrictCanvas();
      final renderer = _TestBubbleRenderer(
        _chart([_twoBubbles()..isVisible = false]),
      );
      renderer.drawData(canvas);
      renderer.drawValues(canvas);
      expect(canvas.calls, isEmpty);

      // drawHighlighted checks isHighlightEnabled only.
      renderer.drawHighlighted(canvas, [Highlight(2, 10, 0)]);
      expect(canvas.circles.single.style, ui.PaintingStyle.stroke);
    });
  });

  group('the point reduction hooks', () {
    test('hasSizes is true; sizeOf is the size of a bubble and 0 for any other '
        'entry', () {
      final renderer = _TestBubbleRenderer(_chart([_twoBubbles()]));
      expect(renderer.hasSizes, isTrue);
      expect(renderer.sizeOf(_bubble(0, 1, 7)), 7);
      expect(renderer.sizeOf(Entry(x: 0, y: 1)), 0);
    });

    test('lowOf / highOf are the y minus / plus half the bubble height in y '
        'units, as of the last draw', () {
      final renderer = _TestBubbleRenderer(_chart([_twoBubbles()]));
      final big = _bubble(2, 10, 4), small = _bubble(5, 5, 1);

      // Before a draw nothing is measured, so a bubble has no height.
      expect([renderer.lowOf(big), renderer.highOf(big)], [10, 10]);

      renderer.drawData(RecordingCanvas());

      // 18 and 9 px radii at 10 px per y unit.
      expect(renderer.lowOf(big), closeTo(8.2, 1e-4));
      expect(renderer.highOf(big), closeTo(11.8, 1e-4));
      expect(renderer.lowOf(small), closeTo(4.1, 1e-4));
      expect(renderer.highOf(small), closeTo(5.9, 1e-4));
      expect(renderer.lowOf(Entry(x: 0, y: 3)), 3);
      expect(renderer.highOf(Entry(x: 0, y: 3)), 3);
    });
  });

  group('drawValues', () {
    test('each label is the size, centered on its bubble half a line below the '
        'center, measured before the set text style is applied', () {
      final set = _twoBubbles()..valueTextSize = 30;
      final renderer = _TestBubbleRenderer(_chart([set]));
      final lineHeight = Utils.calcTextHeight(renderer.paintValues, '1');

      renderer.drawValues(RecordingCanvas());

      expect(renderer.labels, hasLength(2));
      expect(renderer.labels.map((l) => l.value), [4, 1]);
      expect(renderer.labels[0].x, _px(2));
      expect(renderer.labels[0].y, _py(10) + 0.5 * lineHeight);
      expect(renderer.labels[1].y, _py(5) + 0.5 * lineHeight);
      // The set's 30 dp text is taller than the default 9 dp the line height was measured with.
      expect(
        Utils.calcTextHeight(renderer.paintValues, '1'),
        greaterThan(lineHeight),
      );
    });

    test('the text color takes its alpha from the animation phase', () {
      final set = _twoBubbles()..valueTextColor = const ui.Color(0x80112233);

      final still = _TestBubbleRenderer(_chart([set]));
      still.drawValues(RecordingCanvas());
      // The phase replaces the alpha of the color; it does not scale it.
      expect(still.labels.first.color, const ui.Color(0xFF112233));

      final fadingY = _TestBubbleRenderer(
        _chart([set]),
        ChartAnimator()..phaseY = 0.5,
      );
      final lineHeight = Utils.calcTextHeight(fadingY.paintValues, '1');
      fadingY.drawValues(RecordingCanvas());
      // phaseX 1: the alpha follows phaseY, 255 * 0.5 rounded; the label moves with the bubble.
      expect(fadingY.labels.first.color, const ui.Color(0x80112233));
      expect(fadingY.labels.first.y, _py(5) + 0.5 * lineHeight);

      final fadingX = _TestBubbleRenderer(
        _chart([set]),
        ChartAnimator()..phaseX = 0.6,
      );
      fadingX.drawValues(RecordingCanvas());
      expect(fadingX.labels.single.color, const ui.Color(0x99112233));
    });

    test('a label is drawn only while the center of its bubble is inside the '
        'content rect', () {
      final set = BubbleDataSet([
        _bubble(-0.25, 14, 4), // center left of the content rect
        _bubble(
          3,
          29,
          4,
        ), // center above the content rect, though the bubble is drawn
        _bubble(5, 14, 4),
        _bubble(10.25, 14, 4), // center right of the content rect
      ], 'bubbles');
      final chart = _chart([set], lowestVisibleX: -2, highestVisibleX: 12);
      final canvas = RecordingCanvas();
      final renderer = _TestBubbleRenderer(chart);
      renderer.drawData(canvas);
      renderer.drawValues(canvas);

      expect(canvas.circles, hasLength(4));
      expect(renderer.labels.map((l) => l.x), [_px(5)]);
    });

    test('maxVisibleCount culls all labels', () {
      final renderer = _TestBubbleRenderer(
        _chart([_twoBubbles()], maxVisibleCount: 1),
      );
      renderer.drawValues(RecordingCanvas());
      expect(renderer.labels, isEmpty);
    });

    test('icons are drawn with the labels off, and not once icons are off', () {
      final icon = CountingIcon();
      final set = BubbleDataSet([_bubble(2, 10, 4, icon: icon)], 'bubbles')
        ..isDrawValuesEnabled = false;
      final renderer = _TestBubbleRenderer(_chart([set]));

      renderer.drawValues(RecordingCanvas());
      expect(renderer.labels, isEmpty);
      expect(icon.draws, 1);

      set.isDrawIconsEnabled = false;
      renderer.drawValues(RecordingCanvas());
      expect(icon.draws, 1);
    });
  });

  group('drawHighlighted', () {
    test('a ring of highlightCircleWidth around the bubble, in a darker shade '
        'of the entry color, at the drawn position', () {
      final set = _twoBubbles()..highlightCircleWidth = 3;
      final canvas = PaintRecordingCanvas();
      final high = Highlight(5, 5, 0);
      _TestBubbleRenderer(_chart([set])).drawHighlighted(canvas, [high]);

      final ring = canvas.circles.single;
      expect([ring.x, ring.y, ring.radius], [_px(5), _py(5), 9]);
      expect(ring.style, ui.PaintingStyle.stroke);
      expect(canvas.circlePaints.single.strokeWidth, 3);
      // The second entry's color, 0x222222, at half its HSV value.
      expect(ring.color.toARGB32(), 0xFF111111);
      expect([high.drawX, high.drawY], [_px(5), _py(5)]);
    });

    test('the ring color is the entry color with its HSV value halved and its '
        'alpha kept, as Android computes it', () {
      // Android works in Float and rounds with floor(x + 0.5), Flutter's HSVColor in double rounding halves away
      // from zero: a channel may differ by 1 (0xFF3F51B5 gives 1F285B on Android, 20295B here, as MIGRATION.md
      // says). Alpha is exact.
      final rings = <int, int>{};
      for (final MapEntry(key: original, value: android)
          in _androidHighlight.entries) {
        final set = BubbleDataSet([_bubble(2, 10, 4)], 'bubbles')
          ..color = ui.Color(original);
        final canvas = RecordingCanvas();
        _TestBubbleRenderer(
          _chart([set]),
        ).drawHighlighted(canvas, [Highlight(2, 10, 0)]);

        final ring = canvas.circles.single.color.toARGB32();
        rings[original] = ring;
        final reason = 'color ${original.toRadixString(16)}';
        expect(ring >>> 24, android >>> 24, reason: '$reason alpha');
        for (final shift in [16, 8, 0]) {
          expect(
            (ring >> shift) & 0xFF,
            closeTo((android >> shift) & 0xFF, 1),
            reason: '$reason channel at bit $shift',
          );
        }
      }
      expect(rings[0xFF3F51B5], 0xFF20295B);
    });

    test('phaseY moves the ring with the bubble', () {
      final canvas = RecordingCanvas();
      _TestBubbleRenderer(
        _chart([_twoBubbles()]),
        ChartAnimator()..phaseY = 0.5,
      ).drawHighlighted(canvas, [Highlight(2, 10, 0)]);

      final ring = canvas.circles.single;
      expect([ring.y, ring.radius], [_py(5), 18]);
    });

    test(
      'nothing is drawn for a y that is not the entry y, a set with '
      'highlighting off, a missing set or an entry phaseX has not revealed',
      () {
        final cases = <String, (FakeBubbleChart, ChartAnimator, Highlight)>{
          'other y': (
            _chart([_twoBubbles()]),
            ChartAnimator(),
            Highlight(2, 9, 0),
          ),
          'highlighting off': (
            _chart([_twoBubbles()..isHighlightEnabled = false]),
            ChartAnimator(),
            Highlight(2, 10, 0),
          ),
          'missing set': (
            _chart([_twoBubbles()]),
            ChartAnimator(),
            Highlight(2, 10, 3),
          ),
          'not revealed': (
            _chart([_twoBubbles()]),
            ChartAnimator()..phaseX = 0.5,
            Highlight(5, 5, 0),
          ),
        };
        for (final MapEntry(key: name, value: (chart, animator, high))
            in cases.entries) {
          final canvas = StrictCanvas();
          _TestBubbleRenderer(chart, animator).drawHighlighted(canvas, [high]);
          expect(canvas.calls, isEmpty, reason: name);
        }
      },
    );

    test('a bubble outside the content rect gets no ring, but its drawn '
        'position is set', () {
      final set = BubbleDataSet([_bubble(2, 30, 4)], 'bubbles');
      final canvas = StrictCanvas();
      final high = Highlight(2, 30, 0);
      _TestBubbleRenderer(_chart([set])).drawHighlighted(canvas, [high]);

      expect(canvas.calls, isEmpty);
      expect([high.drawX, high.drawY], [_px(2), _py(30)]);
    });
  });

  group('degenerate sizes and content rects (Review Focus #5)', () {
    // Two bubbles at (3, 14) and (6, 14), with the radii drawn with normalizing on and off. A NaN radius leaves the
    // bubble out, and so does a radius of 0 or less, for which Android's canvas draws nothing (T18 BU4); an infinite
    // one is handed to the canvas, which draws nothing for it.
    const cases = <String, (List<double>, List<double>, List<double>)>{
      'all sizes 0 (maxSize 0)': ([0, 0], [18, 18], []),
      'a size of 0 next to a positive one': ([4, 0], [18], [72]),
      'a negative size': ([4, -5], [18], [72]),
      'a NaN size': ([4, double.nan], [18], [72]),
      'an infinite size': ([4, double.infinity], [], [72, double.infinity]),
      'only negative sizes (maxSize 0)': ([-5, -1], [18, 18], []),
    };

    BubbleDataSet setOf(List<double> sizes, bool normalize) => BubbleDataSet([
      _bubble(3, 14, sizes[0]),
      _bubble(6, 14, sizes[1]),
    ], 'bubbles')..isNormalizeSizeEnabled = normalize;

    for (final MapEntry(key: name, value: (sizes, normalized, plain))
        in cases.entries) {
      for (final normalize in [true, false]) {
        test('$name, normalizing ${normalize ? 'on' : 'off'}', () {
          final set = setOf(sizes, normalize);
          final renderer = _TestBubbleRenderer(_chart([set]));
          final canvas = StrictCanvas();

          renderer.drawData(canvas);
          final data = [...canvas.circles];
          renderer.drawValues(canvas);
          renderer.drawHighlighted(canvas, [
            Highlight(3, 14, 0),
            Highlight(6, 14, 0),
          ]);
          final rings = canvas.circles.sublist(data.length);

          final expected = normalize ? normalized : plain;
          expect([for (final c in data) c.radius], expected);
          expect([for (final c in rings) c.radius], expected);
          expect(canvas.circles.where(_hasNaN), isEmpty);
          // The labels go by the center, which every bubble has inside the content rect.
          expect(renderer.labels, hasLength(2));
        });
      }
    }

    test('a content rect of size 0 draws no bubble and no ring: every radius '
        'is ±0 or NaN, which drawCircleP leaves out', () {
      for (final MapEntry(key: name, value: (sizes, _, _)) in cases.entries) {
        for (final normalize in [true, false]) {
          // The offsets take the whole 40 x 20 chart: the content rect is the point (20, 10).
          final handler = ViewPortHandler()
            ..setChartDimens(40, 20)
            ..restrainViewPort(20, 10, 20, 10);
          final set = setOf(sizes, normalize);
          final renderer = _TestBubbleRenderer(_chart([set], handler: handler));
          final canvas = StrictCanvas();

          renderer.drawData(canvas);
          renderer.drawValues(canvas);
          renderer.drawHighlighted(canvas, [
            Highlight(3, 14, 0),
            Highlight(6, 14, 0),
          ]);

          final where = '$name, normalizing $normalize';
          // Every radius is ±0 (a reference of 0 times the size factor) or NaN (0 x ∞, or a NaN size factor): no
          // bubble and no ring is drawn.
          expect(canvas.circles, isEmpty, reason: where);
          expect(renderer.lowOf(set.getEntryForIndex(0)), isNot(isNaN));
        }
      }
    });

    test('the unprepared transformers of the Kotlin fake: a content rect of '
        'size 0 and every value its own pixel', () {
      for (final normalize in [true, false]) {
        final set = setOf([4, -5], normalize);
        final chart = FakeBubbleChart(
          BubbleData([set]),
          lowestVisibleX: -10,
          highestVisibleX: 10,
        );
        final canvas = StrictCanvas();
        final renderer = BubbleChartRenderer(
          chart,
          ChartAnimator(),
          ViewPortHandler(),
        );
        renderer.drawData(canvas);
        renderer.drawValues(canvas);
        renderer.drawHighlighted(canvas, [Highlight(3, 14, 0)]);
        expect(canvas.circles.where(_hasNaN), isEmpty);
      }
    });

    test('NaN and infinite y draw no NaN circle', () {
      final set = BubbleDataSet([
        _bubble(2, double.nan, 4),
        _bubble(3, double.infinity, 4),
        _bubble(4, double.negativeInfinity, 4),
        _bubble(5, 14, 4),
      ], 'bubbles')..color = _c2;
      for (final phaseY in [1.0, 0.0]) {
        final renderer = _TestBubbleRenderer(
          _chart([set], lowestVisibleX: -10, highestVisibleX: 10),
          ChartAnimator()..phaseY = phaseY,
        );
        final canvas = StrictCanvas();
        renderer.drawData(canvas);
        renderer.drawValues(canvas);
        renderer.drawHighlighted(canvas, [
          for (final e in set.entries) Highlight(e.x, e.y, 0),
        ]);

        // Only the finite bubble and its ring.
        expect(canvas.circles, hasLength(2), reason: 'phaseY $phaseY');
        expect(
          canvas.circles.map((c) => c.x),
          everyElement(_px(5)),
          reason: 'phaseY $phaseY',
        );
      }
    });
  });
}
