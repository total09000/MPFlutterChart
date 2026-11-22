// Tests for renderer/XAxisRendererHorizontalBarChart.kt and YAxisRendererHorizontalBarChart.kt on a recording
// canvas; MPAndroidChart has no unit test for them. Locks the swapped axes: the x axis runs vertically (labels left
// or right of the content, horizontal grid and limit lines, the axis line along a side) and the y axes run
// horizontally (labels above or below the content, vertical grid, zero and limit lines, the axis line along the top
// or bottom), and the visible range each takes when zoomed.
//
// The renderers are built directly on a 400 x 300 viewport with offsets 20 / 10 / 20 / 10 (content rect 20..380 x
// 10..290) and transformers prepared as HorizontalBarChart.prepareValuePxMatrix does: y 0..10 → 20..380 px (36 px
// per y) along the transformer's x, x 0..4 → 290..10 px (70 px per x) along its y.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextBaseline;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/bar_chart.dart';
import 'package:mp_flutter_chart/src/components/limit_line.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';
import 'package:mp_flutter_chart/src/renderer/x_axis_renderer_horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/renderer/y_axis_renderer_horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/utils/float_math.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/transformer_horizontal_bar_chart.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import '../recording/recording_canvas.dart';
import 'support/strict_canvas.dart';

const _contentLeft = 20.0;
const _contentTop = 10.0;
const _contentRight = 380.0;
const _contentBottom = 290.0;

ViewPortHandler _handler() => ViewPortHandler()
  ..setChartDimens(400, 300)
  ..restrainViewPort(20, 10, 20, 10);

/// y [yMin]..[yMin] + 10 along the transformer's x and x 0..4 along its y.
TransformerHorizontalBarChart _transformer(
  ViewPortHandler handler, {
  double yMin = 0,
  bool inverted = false,
}) => TransformerHorizontalBarChart(handler)
  ..prepareMatrixValuePx(yMin, 10, 4, 0)
  ..prepareMatrixOffset(inverted);

/// The pixel x of the y value [y] on a y axis starting at [yMin].
double _px(double y, {double yMin = 0}) => _contentLeft + 36 * (y - yMin);

/// The pixel y of the x value [x].
double _py(double x) => _contentBottom - 70 * x;

/// The anchor (x, baseline y) `ChartCanvas.drawText` was given for paragraph [p] of [text] in [paint] aligned [align].
(double, double) _textAnchor(
  ParagraphDraw p,
  ChartPaint paint,
  String text,
  PaintAlign align,
) {
  final painter = TextMeasure.layout(text, paint.textStyle);
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final x = switch (align) {
    PaintAlign.LEFT => p.offset.dx,
    PaintAlign.CENTER => p.offset.dx + painter.width / 2,
    PaintAlign.RIGHT => p.offset.dx + painter.width,
  };
  return (x, p.offset.dy + baseline);
}

/// Zooms [handler] by [scaleX] / [scaleY] around the content origin, within its limits.
void _zoom(ViewPortHandler handler, double scaleX, double scaleY) {
  handler.matrixTouch.postScale(scaleX, scaleY);
  handler.limitTransAndScale(handler.matrixTouch, handler.contentRect);
}

/// The entries of [axis] as a list.
List<double> _entries(XAxis axis) => [
  for (var i = 0; i < axis.entryCount; i++) axis.entries[i],
];

/// One x axis label: its text, position and anchor.
typedef _AxisLabel = ({
  String text,
  double x,
  double y,
  double anchorX,
  double anchorY,
});

/// Records the labels and exposes the protected members of [XAxisRendererHorizontalBarChart].
class _TestXRenderer extends XAxisRendererHorizontalBarChart {
  _TestXRenderer(ViewPortHandler handler, XAxis axis, Transformer transformer)
    : super(handler, axis, transformer, BarChart());

  final List<_AxisLabel> labels = [];

  /// The range each [computeAxisValues] call was given, as (min, max).
  final List<(double, double)> computedRanges = [];

  double minimum(double range) => minimumInterval(range);

  ChartPaint get limitPaint => limitLinePaint;

  @override
  void computeAxisValues(double min, double max) {
    computedRanges.add((min, max));
    super.computeAxisValues(min, max);
  }

  @override
  void drawLabel(
    ui.Canvas c,
    String formattedLabel,
    double x,
    double y,
    MPPointF anchor,
    double angleDegrees,
  ) {
    labels.add((
      text: formattedLabel,
      x: x,
      y: y,
      anchorX: anchor.x,
      anchorY: anchor.y,
    ));
    super.drawLabel(c, formattedLabel, x, y, anchor, angleDegrees);
  }
}

/// Records the label lines and exposes the protected members of [YAxisRendererHorizontalBarChart].
class _TestYRenderer extends YAxisRendererHorizontalBarChart {
  _TestYRenderer(super.handler, super.axis, super.transformer);

  final List<({double fixedPosition, double offset})> labelLines = [];

  Float32List positions() => getTransformedPositions();

  ChartPaint get limitPaint => limitLinePaint;

  @override
  void drawYLabels(
    ui.Canvas c,
    double fixedPosition,
    Float32List positions,
    double offset,
  ) {
    labelLines.add((fixedPosition: fixedPosition, offset: offset));
    super.drawYLabels(c, fixedPosition, positions, offset);
  }
}

void main() {
  setUp(TextMeasure.clearCache);

  group('XAxisRendererHorizontalBarChart', () {
    // A granularity of 1 keeps the labels on whole x values.
    _TestXRenderer renderer(XAxis axis, [ViewPortHandler? handler]) {
      final h = handler ?? _handler();
      axis.granularity = 1;
      return _TestXRenderer(h, axis, _transformer(h));
    }

    test('computeAxis labels the full range when not zoomed vertically, with '
        'no minimum interval', () {
      final axis = XAxis();
      final r = renderer(axis)..computeAxis(0, 4, false);
      expect(_entries(axis), [0, 1, 2, 3, 4]);
      expect(axis.labelRotatedWidth, greaterThan(0));
      expect(r.minimum(100), 0);
    });

    test('computeAxis takes the visible range from the bottom and top edge '
        'when zoomed vertically', () {
      // The vertical XAxisRenderer only looks at horizontal zoom and would label 0..4 here.
      final handler = _handler();
      _zoom(handler, 1, 2);
      final axis = XAxis();
      renderer(axis, handler).computeAxis(0, 4, false);
      expect(_entries(axis), [0, 1, 2]);
    });

    test('computeAxis with inverted true takes the minimum from the top edge '
        'and the maximum from the bottom edge', () {
      // The zoomed range is x 0..2: 0 at the content bottom, 2 at the top. The charts pass false for the x axis;
      // only a direct call reaches this branch, which swaps the edges as in Kotlin.
      final handler = _handler();
      _zoom(handler, 1, 2);
      final axis = XAxis();
      final r = renderer(axis, handler);

      r.computeAxis(0, 4, false);
      r.computeAxis(0, 4, true);
      expect(r.computedRanges, hasLength(2));
      final (min, max) = r.computedRanges[0];
      expect(min, closeTo(0, 1e-4));
      expect(max, closeTo(2, 1e-4));
      expect(r.computedRanges[1], (max, min));
      // A range from 2 down to 0 gives no labels.
      expect(_entries(axis), isEmpty);

      // Not zoomed, both branches label the given range.
      final unzoomed = renderer(XAxis())..computeAxis(0, 4, true);
      expect(unzoomed.computedRanges.single, (0.0, 4.0));
    });

    test('labels sit at the pixel y of their x value, right aligned left of '
        'the content for BOTTOM', () {
      final axis = XAxis()..position = XAxisPosition.BOTTOM;
      final r = renderer(axis)..computeAxis(0, 4, false);
      final canvas = StrictCanvas();
      r.renderAxisLabels(canvas);

      expect(r.labels, hasLength(5));
      expect(canvas.paragraphs, hasLength(5));
      for (var i = 0; i < 5; i++) {
        final label = r.labels[i];
        expect(label.text, '$i');
        expect(label.x, _contentLeft - Utils.convertDpToPixel(5));
        expect(label.y, closeTo(_py(i.toDouble()), 1e-4));
        expect((label.anchorX, label.anchorY), (1.0, 0.5));
        // Right aligned: the text bounds end at the label x.
        final bounds = r.paintAxisLabels.getTextBounds(label.text);
        expect(
          canvas.paragraphs[i].offset.dx,
          closeTo(label.x - bounds.left - bounds.width(), 1e-3),
        );
      }
    });

    test('each position puts the labels on its side of the content', () {
      final xOffset = Utils.convertDpToPixel(5);
      final expected = {
        XAxisPosition.TOP: [(_contentRight + xOffset, 0.0)],
        XAxisPosition.TOP_INSIDE: [(_contentRight - xOffset, 1.0)],
        XAxisPosition.BOTTOM: [(_contentLeft - xOffset, 1.0)],
        XAxisPosition.BOTTOM_INSIDE: [(_contentLeft + xOffset, 1.0)],
        XAxisPosition.BOTH_SIDED: [
          (_contentRight + xOffset, 0.0),
          (_contentLeft - xOffset, 1.0),
        ],
      };
      for (final MapEntry(key: position, value: sides) in expected.entries) {
        final axis = XAxis()..position = position;
        final r = renderer(axis)..computeAxis(0, 4, false);
        r.renderAxisLabels(StrictCanvas());

        expect(r.labels, hasLength(5 * sides.length), reason: '$position');
        for (var s = 0; s < sides.length; s++) {
          for (final label in r.labels.skip(5 * s).take(5)) {
            expect(
              (label.x, label.anchorX, label.anchorY),
              (sides[s].$1, sides[s].$2, 0.5),
              reason: '$position',
            );
          }
        }
      }
    });

    test('labels outside the content height are left out', () {
      final axis = XAxis()
        ..position = XAxisPosition.BOTTOM
        ..labelCount = 12;
      final r = renderer(axis)..computeAxis(-4, 8, false);
      expect(axis.entryCount, 13);
      r.renderAxisLabels(StrictCanvas());
      expect([for (final l in r.labels) l.text], ['0', '1', '2', '3', '4']);
    });

    test('computeSize adds 3.5 x offsets to the label widths', () {
      for (final angle in [0.0, 90.0]) {
        final axis = XAxis()..labelRotationAngle = angle;
        final r = renderer(axis)..computeAxis(0, 4, false);

        final size = Utils.calcTextSize(r.paintAxisLabels, axis.longestLabel);
        final rotated = Utils.getSizeOfRotatedRectangleByDegrees(
          size.width,
          size.height,
          angle,
        );
        final extra = Utils.convertDpToPixel(5) * 3.5;
        expect(axis.labelWidth, kotlinFloatToInt(size.width + extra));
        expect(axis.labelHeight, size.height.round());
        expect(axis.labelRotatedWidth, kotlinFloatToInt(rotated.width + extra));
        expect(axis.labelRotatedHeight, rotated.height.round());
      }
    });

    test('the axis line runs down the left edge for the BOTTOM positions and '
        'the right edge for the TOP positions', () {
      final left = (
        const ui.Offset(_contentLeft, _contentTop),
        const ui.Offset(_contentLeft, _contentBottom),
      );
      final right = (
        const ui.Offset(_contentRight, _contentTop),
        const ui.Offset(_contentRight, _contentBottom),
      );
      final expected = {
        XAxisPosition.TOP: [right],
        XAxisPosition.TOP_INSIDE: [right],
        XAxisPosition.BOTTOM: [left],
        XAxisPosition.BOTTOM_INSIDE: [left],
        XAxisPosition.BOTH_SIDED: [right, left],
      };
      for (final MapEntry(key: position, value: lines) in expected.entries) {
        final axis = XAxis()..position = position;
        final canvas = StrictCanvas();
        renderer(axis).renderAxisLine(canvas);
        expect(
          [for (final l in canvas.lines) (l.p1, l.p2)],
          lines,
          reason: '$position',
        );
      }

      final disabled = XAxis()..isDrawAxisLineEnabled = false;
      final canvas = StrictCanvas();
      renderer(disabled).renderAxisLine(canvas);
      expect(canvas.calls, isEmpty);
    });

    test('grid lines are horizontal over the content width, clipped to the '
        'content widened vertically', () {
      final axis = XAxis()..gridLineWidth = 2;
      final r = renderer(axis)..computeAxis(0, 4, false);
      final canvas = StrictCanvas();
      r.renderGridLines(canvas);

      expect(
        canvas.clipRects.single,
        const ui.Rect.fromLTRB(
          _contentLeft,
          _contentTop - 2,
          _contentRight,
          _contentBottom + 2,
        ),
      );
      expect(canvas.paths, hasLength(5));
      for (var i = 0; i < 5; i++) {
        final bounds = canvas.paths[i].bounds;
        expect(bounds.left, _contentLeft);
        expect(bounds.right, _contentRight);
        expect(bounds.top, closeTo(_py(i.toDouble()), 1e-4));
        expect(bounds.bottom, closeTo(_py(i.toDouble()), 1e-4));
      }
      expect(canvas.getSaveCount(), 1);
    });

    test('a limit line is horizontal at the pixel y of its limit, labelled '
        'inside the content', () {
      final axis = XAxis()
        ..addLimitLine(LimitLine(2, 'limit')..lineWidth = 2)
        ..addLimitLine(LimitLine(10, 'outside'));
      final r = renderer(axis);
      final canvas = StrictCanvas();
      r.renderLimitLines(canvas);

      expect(canvas.paths, hasLength(2));
      final bounds = canvas.paths.first.bounds;
      expect(bounds.left, _contentLeft);
      expect(bounds.right, _contentRight);
      expect(bounds.top, closeTo(_py(2), 1e-4));
      expect(bounds.bottom, closeTo(_py(2), 1e-4));
      expect(
        canvas.clipRects.first,
        const ui.Rect.fromLTRB(
          _contentLeft,
          _contentTop - 2,
          _contentRight,
          _contentBottom + 2,
        ),
      );
      // FILL_AND_STROKE text is a fill and a stroke paragraph; the line above the content has no label.
      expect(canvas.paragraphs, hasLength(2));

      final height = Utils.calcTextHeight(r.limitPaint, 'limit').toDouble();
      final (x, y) = _textAnchor(
        canvas.paragraphs.first,
        r.limitPaint,
        'limit',
        PaintAlign.RIGHT,
      );
      // RIGHT_TOP: right aligned 4 dp + x offset inside the right edge, above the line.
      expect(x, closeTo(_contentRight - 4 - 5, 1e-3));
      expect(y, closeTo(_py(2) - (2 + height + 5) + height, 1e-3));
      expect(canvas.getSaveCount(), 1);
    });

    test('limit labels on the left start 4 dp + x offset inside the content, '
        'and one near the top edge is moved down into it', () {
      for (final position in [
        LimitLabelPosition.LEFT_TOP,
        LimitLabelPosition.LEFT_BOTTOM,
      ]) {
        final axis = XAxis()
          ..addLimitLine(
            LimitLine(2, 'limit')
              ..labelPosition = position
              ..lineWidth = 2,
          );
        final r = renderer(axis);
        final canvas = StrictCanvas();
        r.renderLimitLines(canvas);

        final height = Utils.calcTextHeight(r.limitPaint, 'limit').toDouble();
        final (x, y) = _textAnchor(
          canvas.paragraphs.first,
          r.limitPaint,
          'limit',
          PaintAlign.LEFT,
        );
        expect(x, closeTo(_contentLeft + 4 + 5, 1e-3), reason: '$position');
        expect(
          y,
          closeTo(
            position == LimitLabelPosition.LEFT_TOP
                ? _py(2) - 7
                : _py(2) + 2 + height + 5,
            1e-3,
          ),
          reason: '$position',
        );
      }

      final axis = XAxis()..addLimitLine(LimitLine(4, 'top'));
      final r = renderer(axis);
      final canvas = StrictCanvas();
      r.renderLimitLines(canvas);
      final height = Utils.calcTextHeight(r.limitPaint, 'top').toDouble();
      final (_, y) = _textAnchor(
        canvas.paragraphs.first,
        r.limitPaint,
        'top',
        PaintAlign.RIGHT,
      );
      expect(y, closeTo(_contentTop + height, 1e-3));
    });
  });

  group('YAxisRendererHorizontalBarChart', () {
    _TestYRenderer renderer(
      YAxis axis, {
      ViewPortHandler? handler,
      double yMin = 0,
      bool inverted = false,
    }) {
      final h = handler ?? _handler();
      return _TestYRenderer(
        h,
        axis,
        _transformer(h, yMin: yMin, inverted: inverted),
      );
    }

    test('computeAxis takes the visible range from the left and right edge '
        'when zoomed horizontally', () {
      // The vertical YAxisRenderer only looks at vertical zoom and would label 0..10 here.
      final full = YAxis();
      renderer(full).computeAxis(0, 10, false);
      expect(full.entryCount, 6);
      expect(full.entries[5], 10);

      final handler = _handler();
      _zoom(handler, 2, 1);
      final zoomed = YAxis()..granularity = 1;
      renderer(zoomed, handler: handler).computeAxis(0, 10, false);
      expect(zoomed.entries.take(zoomed.entryCount), [0, 1, 2, 3, 4, 5]);

      // Inverted, the right edge holds the minimum.
      final invertedHandler = _handler();
      _zoom(invertedHandler, 2, 1);
      final inverted = YAxis()..granularity = 1;
      renderer(
        inverted,
        handler: invertedHandler,
        inverted: true,
      ).computeAxis(0, 10, true);
      expect(inverted.entries.take(inverted.entryCount), [0, 1, 2, 3, 4, 5]);
    });

    test('getTransformedPositions fills the pixel x of each entry', () {
      final axis = YAxis();
      final r = renderer(axis)..computeAxis(0, 10, false);
      final positions = r.positions();
      expect(positions, hasLength(2 * axis.entryCount));
      for (var i = 0; i < axis.entryCount; i++) {
        expect(positions[2 * i], closeTo(_px(axis.entries[i]), 1e-4));
      }
    });

    test('left axis labels are centered on their pixel x, 2.5 dp plus the y '
        'offset above the content, whatever the label position', () {
      // The brief asked for OUTSIDE_CHART; Kotlin ignores the label position here, so INSIDE_CHART is the same.
      for (final position in YAxisLabelPosition.values) {
        final axis = YAxis()
          ..labelPosition = position
          ..yOffset = 4;
        final r = renderer(axis)..computeAxis(0, 10, false);
        final canvas = StrictCanvas();
        r.renderAxisLabels(canvas);

        final line = r.labelLines.single;
        expect(
          line.fixedPosition,
          _contentTop - Utils.convertDpToPixel(2.5),
          reason: '$position',
        );
        expect(line.offset, Utils.convertDpToPixel(4), reason: '$position');
        expect(r.paintAxisLabels.textAlign, PaintAlign.CENTER);

        expect(canvas.paragraphs, hasLength(6), reason: '$position');
        for (var i = 0; i < 6; i++) {
          final text = axis.getFormattedLabel(i);
          final (x, y) = _textAnchor(
            canvas.paragraphs[i],
            r.paintAxisLabels,
            text,
            PaintAlign.CENTER,
          );
          expect(x, closeTo(_px(axis.entries[i]), 1e-3), reason: text);
          expect(y, closeTo(_contentTop - 2.5 - 4, 1e-3), reason: text);
        }
      }
    });

    test('right axis labels sit their text height plus 2.5 dp below the '
        'content', () {
      final axis = YAxis(AxisDependency.RIGHT);
      final r = renderer(axis)..computeAxis(0, 10, false);
      r.renderAxisLabels(StrictCanvas());

      final textHeight = Utils.calcTextHeight(r.paintAxisLabels, 'Q');
      expect(
        r.labelLines.single.fixedPosition,
        _contentBottom + textHeight + Utils.convertDpToPixel(2.5),
      );
    });

    test('drawYLabels moves the labels by the label x offset vertically and '
        'skips the top entry when it is disabled', () {
      // Kotlin adds labelXOffset to the vertical position here.
      final axis = YAxis()
        ..labelXOffset = 3
        ..isDrawTopYLabelEntryEnabled = false;
      final r = renderer(axis)..computeAxis(0, 10, false);
      final canvas = StrictCanvas();
      r.renderAxisLabels(canvas);

      expect(canvas.paragraphs, hasLength(5));
      final (_, y) = _textAnchor(
        canvas.paragraphs.first,
        r.paintAxisLabels,
        axis.getFormattedLabel(0),
        PaintAlign.CENTER,
      );
      // The y offset of a y axis is 0 by default.
      expect(y, closeTo(_contentTop - 2.5 + 3, 1e-3));
    });

    test('the axis line runs along the top for the left axis and the bottom '
        'for the right axis', () {
      var canvas = StrictCanvas();
      renderer(YAxis()).renderAxisLine(canvas);
      expect(
        (canvas.lines.single.p1, canvas.lines.single.p2),
        (
          const ui.Offset(_contentLeft, _contentTop),
          const ui.Offset(_contentRight, _contentTop),
        ),
      );

      canvas = StrictCanvas();
      renderer(YAxis(AxisDependency.RIGHT)).renderAxisLine(canvas);
      expect(
        (canvas.lines.single.p1, canvas.lines.single.p2),
        (
          const ui.Offset(_contentLeft, _contentBottom),
          const ui.Offset(_contentRight, _contentBottom),
        ),
      );
    });

    test('grid lines are vertical over the content height, clipped to the '
        'content widened horizontally', () {
      final axis = YAxis()..gridLineWidth = 2;
      final r = renderer(axis)..computeAxis(0, 10, false);
      final canvas = StrictCanvas();
      r.renderGridLines(canvas);

      expect(
        canvas.clipRects.single,
        const ui.Rect.fromLTRB(
          _contentLeft - 2,
          _contentTop,
          _contentRight + 2,
          _contentBottom,
        ),
      );
      expect(canvas.paths, hasLength(6));
      for (var i = 0; i < 6; i++) {
        final bounds = canvas.paths[i].bounds;
        expect(bounds.left, closeTo(_px(axis.entries[i]), 1e-4));
        expect(bounds.right, closeTo(_px(axis.entries[i]), 1e-4));
        expect(bounds.top, _contentTop);
        expect(bounds.bottom, _contentBottom);
      }
    });

    test('the zero line is vertical, one pixel left of the pixel x of 0', () {
      final axis = YAxis()
        ..isDrawGridLinesEnabled = false
        ..isDrawZeroLineEnabled = true
        ..zeroLineWidth = 3;
      final r = renderer(axis, yMin: -5);
      final canvas = StrictCanvas();
      r.renderGridLines(canvas);

      expect(
        canvas.clipRects.single,
        const ui.Rect.fromLTRB(
          _contentLeft - 3,
          _contentTop,
          _contentRight + 3,
          _contentBottom,
        ),
      );
      final bounds = canvas.paths.single.bounds;
      expect(bounds.left, closeTo(_px(0, yMin: -5) - 1, 1e-4));
      expect(bounds.right, closeTo(_px(0, yMin: -5) - 1, 1e-4));
      expect(bounds.top, _contentTop);
      expect(bounds.bottom, _contentBottom);
      expect(canvas.paths.single.strokeWidth, 3);
      expect(canvas.getSaveCount(), 1);
    });

    test('limit lines are vertical at the pixel x of their limit, labelled '
        'beside the line at the top or bottom', () {
      expect(renderer(YAxis()).limitPaint.textAlign, PaintAlign.LEFT);

      for (final position in LimitLabelPosition.values) {
        final axis = YAxis()
          ..addLimitLine(
            LimitLine(5, 'limit')
              ..labelPosition = position
              ..lineWidth = 2,
          )
          ..addLimitLine(LimitLine(20, 'outside'));
        final r = renderer(axis);
        final canvas = StrictCanvas();
        r.renderLimitLines(canvas);

        expect(canvas.paths, hasLength(2), reason: '$position');
        final bounds = canvas.paths.first.bounds;
        expect(bounds.left, closeTo(_px(5), 1e-4));
        expect(bounds.right, closeTo(_px(5), 1e-4));
        expect(bounds.top, _contentTop);
        expect(bounds.bottom, _contentBottom);
        expect(
          canvas.clipRects.first,
          const ui.Rect.fromLTRB(
            _contentLeft - 2,
            _contentTop,
            _contentRight + 2,
            _contentBottom,
          ),
        );
        // FILL_AND_STROKE text is a fill and a stroke paragraph; the line right of the content has no label.
        expect(canvas.paragraphs, hasLength(2), reason: '$position');

        final right =
            position == LimitLabelPosition.RIGHT_TOP ||
            position == LimitLabelPosition.RIGHT_BOTTOM;
        final top =
            position == LimitLabelPosition.RIGHT_TOP ||
            position == LimitLabelPosition.LEFT_TOP;
        final height = Utils.calcTextHeight(r.limitPaint, 'limit').toDouble();
        final (x, y) = _textAnchor(
          canvas.paragraphs.first,
          r.limitPaint,
          'limit',
          right ? PaintAlign.LEFT : PaintAlign.RIGHT,
        );
        // x offset: the line width (2) plus the limit line's x offset (5); y offset: 2 dp plus its y offset (5).
        expect(
          x,
          closeTo(right ? _px(5) + 7 : _px(5) - 7, 1e-3),
          reason: '$position',
        );
        expect(
          y,
          closeTo(top ? _contentTop + 7 + height : _contentBottom - 7, 1e-3),
          reason: '$position',
        );
        expect(canvas.getSaveCount(), 1);
      }
    });

    test(
      'a limit label near the right edge is moved left into the content',
      () {
        final axis = YAxis()..addLimitLine(LimitLine(9.9, 'limit'));
        final r = renderer(axis);
        final canvas = StrictCanvas();
        r.renderLimitLines(canvas);

        final width = Utils.calcTextWidth(r.limitPaint, 'limit').toDouble();
        final (x, _) = _textAnchor(
          canvas.paragraphs.first,
          r.limitPaint,
          'limit',
          PaintAlign.LEFT,
        );
        expect(x, closeTo(_contentRight - width, 1e-3));
      },
    );
  });
}
