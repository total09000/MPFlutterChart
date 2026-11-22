// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/PieChart.kt
//
// Not ported (Android only): the Context/AttributeSet constructors. Kotlin's onDetachedFromWindow released the
// renderer's offscreen bitmap, which the Flutter renderer does not have: it draws onto the chart canvas and opens a
// saveLayer where Kotlin needed the bitmap (as LineChart). The override here
// releases the renderer's cached center text layout instead (releaseCenterTextLayout), so that no TextPainter outlives
// the host.
//
// drawAngles and absoluteAngles are Float32Lists, Kotlin's FloatArray, with a public getter and private storage
// (Kotlin's `private set`): the angles keep Float precision, which decides the slice under a touch at a
// slice edge. calcAngles works out each slice angle, the minimum-angle offset and the shrink factor in double
// precision, as the port does with Kotlin's Float arithmetic elsewhere; only the stores into the two arrays round to
// Float. absoluteValueSum sums in double precision, so two slices near Float.MAX_VALUE make two half circles where
// Kotlin's Float sum overflows to infinity and every angle is 0. Kotlin `internal` is @internal.
// The centerTextTypeface and entryLabelTypeface getters return the paint's Typeface, which is never null
// (Typeface.DEFAULT when none is set), where Kotlin's are `Typeface?`; their setters take null for the default, as
// Kotlin's do.
// centerText is a String, Kotlin's CharSequence without spans. Kotlin's coerceIn keeps NaN, so the
// maxAngle and minAngleForSlices setters clamp by hand instead of with Dart's clamp, which turns NaN into the upper
// bound. Kotlin's `high.x.toInt()` is kotlinFloatToInt, which gives 0 for NaN like Kotlin instead of throwing.
// Flutter addition: onDraw ends with notifyAfterDraw() (Chart.afterDrawListeners, not in Kotlin), as BarLineChartBase.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show internal, protected;

import '../data/pie_data.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../graphics/typeface.dart';
import '../highlight/highlight.dart';
import '../highlight/pie_highlighter.dart';
import '../renderer/pie_chart_renderer.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import 'pie_radar_chart_base.dart';

/// Chart that draws one [PieData] set as slices of a circle. Slice sizes are shares of the sum of all absolute y
/// values; the first slice starts at [rotationAngle] and slices follow clockwise. Angles are in degrees.
class PieChart extends PieRadarChartBase<PieData> {
  /// Bounds of the pie in pixels, already shrunk by the data set's selection shift. Set by [calculateOffsets].
  final MutableRect circleBox = MutableRect();

  /// Whether the label of each `PieEntry` is drawn at its slice. Default true.
  bool isDrawEntryLabelsEnabled = true;

  Float32List _drawAngles = Float32List(1);

  /// Size of each slice in degrees, in entry order. Recomputed whenever the data changes (by [notifyDataSetChanged]);
  /// one 0 before any data.
  Float32List get drawAngles => _drawAngles;

  Float32List _absoluteAngles = Float32List(1);

  /// End angle of each slice in degrees, measured from [rotationAngle], in entry order; one 0 before any data.
  Float32List get absoluteAngles => _absoluteAngles;

  /// Whether the hole in the center is drawn. Default true.
  bool isDrawHoleEnabled = true;

  /// Whether the slices continue under the hole instead of stopping at its edge. Default false.
  bool isDrawSlicesUnderHoleEnabled = false;

  /// Whether values are handed to the value formatter as a percentage of the total instead of as is. Default false.
  bool isUsePercentValuesEnabled = false;

  /// Whether slice ends are rounded. Only applies with the hole drawn and slices not under the hole. Default false.
  bool isDrawRoundedSlicesEnabled = false;

  /// Whether rounded slice ends point counter-clockwise instead of clockwise: each slice then bulges out at its
  /// start and is hollowed at its end. Only applies with [isDrawRoundedSlicesEnabled]. Default false.
  bool isRoundedSlicesReversed = false;

  /// Text drawn in the center of the pie while [isDrawCenterTextEnabled] is true. Default empty.
  String centerText = '';

  final MPPointF _centerTextOffsetValue = MPPointF.getInstance(0, 0);

  /// Radius of the hole as a percentage of the pie radius. Default 50.
  double holeRadius = 50;

  /// Radius of the translucent ring around the hole as a percentage of the pie radius. Default 55.
  /// The ring is only drawn while this is larger than [holeRadius].
  double transparentCircleRadius = 55;

  /// Whether the translucent ring around the hole is drawn only over the slices, so that it tints each slice and
  /// leaves the slice space between them clear. Default false, which draws one closed ring.
  bool isTransparentCircleClippedToSlices = false;

  /// Whether [centerText] is drawn. Default true.
  bool isDrawCenterTextEnabled = true;

  /// Width of the box [centerText] wraps in, as a percentage of the hole diameter. Default 100.
  double centerTextRadiusPercent = 100;

  double _maxAngle = 360;

  /// Angle in degrees the whole pie spans, clamped to 90 until 360. 360 is a full circle, 180 a half pie.
  /// Default 360.
  double get maxAngle => _maxAngle;

  set maxAngle(double value) {
    _maxAngle = _coerceIn(value, 90, 360);
  }

  double _minAngleForSlices = 0;

  /// Smallest angle in degrees a slice is drawn with, clamped to 0 until half of [maxAngle]. Only applied when all
  /// slices fit at that size; call [notifyDataSetChanged] after changing it. Default 0.
  double get minAngleForSlices => _minAngleForSlices;

  set minAngleForSlices(double value) {
    _minAngleForSlices = _coerceIn(value, 0, maxAngle / 2);
  }

  /// Kotlin's `coerceIn`: NaN stays NaN.
  static double _coerceIn(double value, double min, double max) => value < min
      ? min
      : value > max
      ? max
      : value;

  PieChartRenderer get _pieRenderer => renderer as PieChartRenderer;

  @override
  void init() {
    super.init();

    renderer = PieChartRenderer(this, animator, viewPortHandler);
    highlighter = PieHighlighter(this);
  }

  /// Draws the slices, the highlighted slices, the hole and the center text, the values and labels, the legend, the
  /// description and the markers, in that order, or the empty state while there is nothing to draw.
  @override
  void onDraw(ui.Canvas canvas) {
    super.onDraw(canvas);

    if (showsEmptyState) return;

    renderer.drawData(canvas);

    final highlighted = this.highlighted;
    if (valuesToHighlight()) renderer.drawHighlighted(canvas, highlighted);

    renderer.drawExtras(canvas);

    renderer.drawValues(canvas);

    legendRenderer.renderLegend(canvas);

    drawDescription(canvas);

    drawMarkers(canvas);

    notifyAfterDraw();
  }

  /// Also sets [circleBox]: the largest centered square of the content area, shrunk by the selection shift of the
  /// data set on every side.
  @override
  void calculateOffsets() {
    super.calculateOffsets();

    final data = this.data;
    if (data == null) return;

    final radius = diameter / 2;

    final c = centerOffsets;

    final shift = Utils.convertDpToPixel(data.dataSet?.selectionShift ?? 0);

    circleBox.set(
      c.x - radius + shift,
      c.y - radius + shift,
      c.x + radius - shift,
      c.y + radius - shift,
    );

    MPPointF.recycleInstance(c);
  }

  /// Computes [drawAngles] and [absoluteAngles] from the data.
  @override
  void calcMinMax() {
    _calcAngles();
  }

  /// Pixel position of the marker for [high]: on the bisector of its slice, halfway between the hole edge and the
  /// rim (with the hole) or 3.6 tenths of the radius in from the rim (without). `[NaN, NaN]` when [high] is not a
  /// slice.
  @protected
  @override
  Float32List getMarkerPosition(Highlight high) {
    final center = centerCircleBox;
    var r = radius;

    var off = r / 10 * 3.6;

    if (isDrawHoleEnabled) {
      off = (r - (r / 100 * holeRadius)) / 2;
    }

    r -= off;

    final rotationAngle = this.rotationAngle;

    final entryIndex = kotlinFloatToInt(high.x);
    if (entryIndex < 0 ||
        entryIndex >= _drawAngles.length ||
        entryIndex >= _absoluteAngles.length) {
      MPPointF.recycleInstance(center);
      return Float32List.fromList([double.nan, double.nan]);
    }

    final offset = _drawAngles[entryIndex] / 2;

    final angle =
        (rotationAngle + _absoluteAngles[entryIndex] - offset) *
        animator.phaseY *
        Utils.DEG2RAD;
    final x = r * math.cos(angle) + center.x;
    final y = r * math.sin(angle) + center.y;

    MPPointF.recycleInstance(center);
    return Float32List.fromList([x, y]);
  }

  void _calcAngles() {
    final data = this.data;
    if (data == null) return;

    final entryCount = data.entryCount;

    if (_drawAngles.length != entryCount) {
      _drawAngles = Float32List(entryCount);
    } else {
      _drawAngles.fillRange(0, entryCount, 0);
    }
    if (_absoluteAngles.length != entryCount) {
      _absoluteAngles = Float32List(entryCount);
    } else {
      _absoluteAngles.fillRange(0, entryCount, 0);
    }

    final yValueSum = absoluteValueSum;

    final dataSets = data.dataSets;

    final hasMinAngle =
        minAngleForSlices != 0 && entryCount * minAngleForSlices <= maxAngle;
    final minAngles = Float32List(entryCount);

    var cnt = 0;
    var offset = 0.0;
    var diff = 0.0;

    for (var i = 0; i < data.dataSetCount; i++) {
      final set = dataSets[i];

      for (var j = 0; j < set.entryCount; j++) {
        final drawAngle = _calcAngle(
          set.getEntryForIndex(j).y.abs(),
          yValueSum,
        );

        if (hasMinAngle) {
          final temp = drawAngle - minAngleForSlices;
          if (temp <= 0) {
            minAngles[cnt] = minAngleForSlices;
            offset += -temp;
          } else {
            minAngles[cnt] = drawAngle;
            diff += temp;
          }
        }

        _drawAngles[cnt] = drawAngle;

        _absoluteAngles[cnt] = cnt == 0
            ? _drawAngles[cnt]
            : _absoluteAngles[cnt - 1] + _drawAngles[cnt];

        cnt++;
      }
    }

    if (hasMinAngle) {
      final shrink = diff > 0 ? offset / diff : 0.0;
      for (var i = 0; i < entryCount; i++) {
        minAngles[i] -= (minAngles[i] - minAngleForSlices) * shrink;
        _absoluteAngles[i] = i == 0
            ? minAngles[0]
            : _absoluteAngles[i - 1] + minAngles[i];
      }

      _drawAngles = minAngles;
    }
  }

  /// True when the slice at [index] is currently highlighted.
  bool needsHighlight(int index) {
    if (!valuesToHighlight()) return false;

    final highlighted = this.highlighted;
    for (final high in highlighted) {
      if (kotlinFloatToInt(high.x) == index) return true;
    }
    return false;
  }

  double _calcAngle(double value, double yValueSum) {
    if (yValueSum == 0) return 0;
    return value / yValueSum * maxAngle;
  }

  /// Sum of the absolute y values of all slices, which is what the slice angles and percentages are shares of; 0
  /// without data. Summed in double precision. Internal API.
  @internal
  double get absoluteValueSum {
    final dataSets = data?.dataSets;
    if (dataSets == null) return 0;
    var sum = 0.0;
    for (final set in dataSets) {
      for (var j = 0; j < set.entryCount; j++) {
        sum += set.getEntryForIndex(j).y.abs();
      }
    }
    return sum;
  }

  /// Index of the slice lying under [angle] in degrees (0 at 3 o'clock, increasing clockwise), taking
  /// [rotationAngle] into account, or -1 when no slice lies under it (beyond [maxAngle] or without data).
  @override
  int getIndexForAngle(double angle) {
    final a = Utils.getNormalizedAngle(angle - rotationAngle);

    for (var i = 0; i < _absoluteAngles.length; i++) {
      if (_absoluteAngles[i] > a) return i;
    }

    return -1;
  }

  /// Index of the data set that holds an entry at the given x value.
  ///
  /// [xIndex] is the x value to look for. Returns the data set index, or -1 when there is no data or no entry has
  /// that x value. Every `PieEntry` has the x value 0 and the lookup rounds to the closest entry, so any [xIndex]
  /// finds the set once it holds an entry.
  int getDataSetIndexForIndex(int xIndex) {
    final dataSets = data?.dataSets;
    if (dataSets == null) return -1;

    for (var i = 0; i < dataSets.length; i++) {
      if (dataSets[i].getEntryForXValue(xIndex.toDouble(), double.nan) !=
          null) {
        return i;
      }
    }

    return -1;
  }

  /// Paint used for the hole in the middle of the pie, the renderer's `paintHole`.
  ChartPaint get holePaint => _pieRenderer.paintHole;

  set holePaint(ChartPaint value) {
    _pieRenderer.paintHole = value;
  }

  /// Paint used for the center text, the renderer's `paintCenterText`.
  ChartPaint get centerTextPaint => _pieRenderer.paintCenterText;

  set centerTextPaint(ChartPaint value) {
    _pieRenderer.paintCenterText = value;
  }

  /// Fill color of the hole, used while [isDrawHoleEnabled] is true. Default white; a fully transparent color
  /// leaves the hole empty.
  ui.Color get holeColor => _pieRenderer.paintHole.color;

  set holeColor(ui.Color value) {
    _pieRenderer.paintHole.color = value;
  }

  /// Twice the legend text size in pixels.
  @protected
  @override
  double get requiredLegendOffset => legendRenderer.labelPaint.textSize * 2;

  /// Always 0: a pie needs no room beside itself.
  @protected
  @override
  double get requiredBaseOffset => 0;

  /// Radius of the pie in pixels: half the smaller side of [circleBox].
  @override
  double get radius => math.min(circleBox.width() / 2, circleBox.height() / 2);

  /// Center of [circleBox] in pixels, as a new point.
  MPPointF get centerCircleBox =>
      MPPointF(circleBox.centerX(), circleBox.centerY());

  /// Typeface of [centerText]; null sets the default.
  Typeface get centerTextTypeface => _pieRenderer.paintCenterText.typeface;

  set centerTextTypeface(Typeface? value) {
    _pieRenderer.paintCenterText.typeface = value;
  }

  /// Text size of [centerText] in dp. Default 12.
  double get centerTextSize =>
      Utils.convertPixelsToDp(_pieRenderer.paintCenterText.textSize);

  set centerTextSize(double value) {
    _pieRenderer.paintCenterText.textSize = Utils.convertDpToPixel(value);
  }

  /// Moves [centerText] away from the center of the pie.
  ///
  /// [x] is the horizontal shift in dp, positive to the right; [y] the vertical shift in dp, positive downwards. Both
  /// default to 0.
  void setCenterTextOffset(double x, double y) {
    _centerTextOffsetValue.x = x;
    _centerTextOffsetValue.y = y;
  }

  /// Copy of the shift set with [setCenterTextOffset], in dp.
  MPPointF get centerTextOffset =>
      MPPointF(_centerTextOffsetValue.x, _centerTextOffsetValue.y);

  /// Color of [centerText]. Default black.
  ui.Color get centerTextColor => _pieRenderer.paintCenterText.color;

  set centerTextColor(ui.Color value) {
    _pieRenderer.paintCenterText.color = value;
  }

  /// Color of the translucent ring around the hole. Setting it keeps the current [transparentCircleAlpha]. Default
  /// white.
  ui.Color get transparentCircleColor =>
      _pieRenderer.paintTransparentCircle.color;

  set transparentCircleColor(ui.Color value) {
    final p = _pieRenderer.paintTransparentCircle;
    final alpha = p.alpha;
    p.color = value;
    p.alpha = alpha;
  }

  /// Opacity of the translucent ring from 0 (invisible) to 255 (opaque). Default 105.
  int get transparentCircleAlpha => _pieRenderer.paintTransparentCircle.alpha;

  set transparentCircleAlpha(int value) {
    _pieRenderer.paintTransparentCircle.alpha = value;
  }

  /// Color of the entry labels drawn at the slices. Default white.
  ui.Color get entryLabelColor => _pieRenderer.paintEntryLabels.color;

  set entryLabelColor(ui.Color value) {
    _pieRenderer.paintEntryLabels.color = value;
  }

  /// Typeface of the entry labels drawn at the slices; null sets the default.
  Typeface get entryLabelTypeface => _pieRenderer.paintEntryLabels.typeface;

  set entryLabelTypeface(Typeface? value) {
    _pieRenderer.paintEntryLabels.typeface = value;
  }

  /// Text size in dp of the entry labels drawn at the slices. Default 13.
  double get entryLabelTextSize =>
      Utils.convertPixelsToDp(_pieRenderer.paintEntryLabels.textSize);

  set entryLabelTextSize(double value) {
    _pieRenderer.paintEntryLabels.textSize = Utils.convertDpToPixel(value);
  }

  /// Releases the renderer's cached center text layout, where Kotlin released its offscreen bitmap, then does what
  /// every round chart does when its host goes away (stops the rotation deceleration and running animations).
  @override
  void onDetachedFromWindow() {
    if (isRendererInitialized) {
      final renderer = this.renderer;
      if (renderer is PieChartRenderer) renderer.releaseCenterTextLayout();
    }
    super.onDetachedFromWindow();
  }

  /// Draws a ring, the outline of a pie, inside [bounds] for the empty state.
  @protected
  @override
  void drawNoDataIcon(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) {
    paint.style = PaintStyle.STROKE;
    paint.strokeWidth = bounds.height() / 5;
    final radius = (bounds.height() - paint.strokeWidth) / 2;
    canvas.drawCircleP(bounds.centerX(), bounds.centerY(), radius, paint);
  }
}
