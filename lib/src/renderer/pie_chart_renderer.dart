// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/PieChartRenderer.kt
//
// The offscreen bitmap is not ported (drawBitmap, bitmapCanvas, releaseBitmap,
// and the bitmap creation, erasing and compositing of drawData / drawExtras; as LineChartRenderer). The
// slices, the highlighted slices, the hole and the transparent ring are drawn onto the canvas passed in. Kotlin drew
// them onto the bitmap and composited it source over after the hole, which gives the same pixels as drawing them
// directly, except for the transparent ring clipped to the slices: Kotlin drew it with SRC_ATOP, so it only tinted the
// pixels the slices already covered on the bitmap. Only in that case drawData opens a layer over the whole chart
// (saveLayer), drawHole draws the ring into it with BlendMode.srcATop and drawExtras closes the layer after the hole,
// where Kotlin composited the bitmap, and before the center text. The private _canDraw flag plays the role of Kotlin's
// `bitmapCanvas ?: return` in drawDataSet, drawHighlighted, drawHole and drawRoundedSlices: it is false before the
// first drawData and while the chart has no size, when Kotlin could not create its bitmap. (After the chart shrinks
// to no size, Kotlin keeps drawing the hole and the highlights onto its old bitmap, which a chart without a size does
// not show; here nothing is drawn.)
//
// Geometry that is not finite is skipped explicitly and never reaches a path or a canvas call. Slices of
// NaN or infinite values, a NaN rotation angle or a radius of 0 with slice space give angles, radii or points that are
// not finite, which Kotlin passes on to Android and which leave nothing drawn there. Here drawDataSet and
// drawHighlighted work out the whole outline of a slice before building its path and skip a slice whose outline is not
// finite (drawDataSet still advances its angle, as Kotlin's loop does); drawHole skips a hole or ring,
// drawRoundedSlices a circle, drawCenterText a hole or text box, and drawValues a text or value line that is not
// finite. Kotlin builds each slice path while it works out the inner edge; the operations on the path and their order
// are unchanged.
//
// Android builds rings from an outer circle added clockwise and an inner one added
// counter-clockwise, which the winding fill leaves empty in the middle. Here they are two concentric ovals filled
// PathFillType.evenOdd, which gives the same ring whichever circle is larger: the full circle slice around the hole
// and the transparent ring. The reused paths get their fill type set again after every reset.
//
// The center text is a String (Kotlin's CharSequence) laid out with one cached TextPainter, Kotlin's
// StaticLayout: centered, as wide as the bounding box rounded up and at least 1 px, without extra line spacing. It is
// laid out again when the text, the bounding box or the style of paintCenterText changes; the TextPainter holds its
// style, where a StaticLayout reads its paint when it draws. The replaced TextPainter is disposed, and so is the cached
// one when the chart is detached (releaseCenterTextLayout, called where Kotlin's PieChart released the bitmap). A text
// box that is not finite is neither drawn nor laid out.
//
// Android's Path.arcTo takes degrees and connects the arc to the current point; Flutter's takes radians, and
// forceMoveTo false connects the same way. Kotlin's `%` on angles is the signed `remainder`. Kotlin's `.toInt()` is
// kotlinFloatToInt, which gives 0 for NaN like Kotlin instead of throwing, and truncateToDevicePx for a px position.
// Kotlin's Float arithmetic is done in double precision, as in the rest of the port. Kotlin's private three rectangle
// buffer of drawCenterText is two fields.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show internal, protected, visibleForTesting;
import 'package:flutter/painting.dart'
    show TextAlign, TextDirection, TextPainter, TextSpan, TextStyle;

import '../animation/chart_animator.dart';
import '../charts/pie_chart.dart';
import '../data/entry.dart';
import '../data/pie_data_set.dart';
import '../formatter/i_value_formatter.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/highlight.dart';
import '../interfaces/datasets/i_pie_data_set.dart';
import '../utils/color_template.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'data_renderer.dart';

/// Draws a [PieChart]. [drawData] draws the slices, [drawHighlighted] the highlighted slices enlarged, and
/// [drawExtras] the hole, the transparent ring around it and the center text. [drawValues] draws the entry labels and
/// values inside or outside the slices. Angles are in degrees clockwise from 3 o'clock, offset by the chart's rotation
/// angle; radii are pixels.
///
/// While the transparent ring is clipped to the slices ([PieChart.isTransparentCircleClippedToSlices], with the hole
/// drawn and the ring larger than the hole), [drawData] opens a layer on the canvas that [drawExtras] closes: the
/// layer spans [drawData], [drawHighlighted] and [drawExtras], which must be called in that order on the same canvas,
/// as `PieChart.onDraw` does.
class PieChartRenderer extends DataRenderer {
  /// Creates the renderer of [chart], whose drawing follows the phases of [animator].
  PieChartRenderer(
    this.chart,
    ChartAnimator animator,
    ViewPortHandler viewPortHandler,
  ) : super(animator, viewPortHandler) {
    valuePaint.textSize = Utils.convertDpToPixel(13);
    valuePaint.color = const ui.Color(0xFFFFFFFF);
    valuePaint.textAlign = PaintAlign.CENTER;
  }

  /// The pie chart, which supplies the data, the circle box, the slice angles and the hole settings.
  @protected
  final PieChart chart;

  /// Paint for the hole in the middle of the chart; white by default. A fully transparent color skips the hole.
  ChartPaint paintHole = ChartPaint()
    ..color = const ui.Color(0xFFFFFFFF)
    ..style = PaintStyle.FILL;

  /// Paint for the translucent ring between the hole and the transparent circle radius; white at alpha 105 by
  /// default. The alpha is scaled by the animation phases while drawing.
  final ChartPaint paintTransparentCircle = ChartPaint()
    ..color = const ui.Color(0xFFFFFFFF)
    ..style = PaintStyle.FILL
    ..alpha = 105;

  /// Paint for the center text; black, 12 dp by default.
  ChartPaint paintCenterText = ChartPaint()
    ..color = const ui.Color(0xFF000000)
    ..textSize = Utils.convertDpToPixel(12);

  /// Paint for the entry labels drawn at the slices; white, centered, 13 dp by default.
  final ChartPaint paintEntryLabels = ChartPaint()
    ..color = const ui.Color(0xFFFFFFFF)
    ..textAlign = PaintAlign.CENTER
    ..textSize = Utils.convertDpToPixel(13);

  /// Stroke paint for the lines that connect outside labels to their slice; color and width (dp) come from the data
  /// set.
  @protected
  final ChartPaint valueLinePaint = ChartPaint()..style = PaintStyle.STROKE;

  TextPainter? _centerTextLayout;
  String? _centerTextLastValue;
  final MutableRect _centerTextLastBounds = MutableRect();
  TextStyle? _centerTextLastStyle;
  int _centerTextLayoutCount = 0;

  /// How many times the center text has been laid out, so tests can see that an unchanged text is not laid out again.
  @visibleForTesting
  int get centerTextLayoutCount => _centerTextLayoutCount;

  /// Disposes the cached center text layout; the next [drawCenterText] lays the text out again. Called by
  /// `PieChart.onDetachedFromWindow`, where Kotlin released the renderer's offscreen bitmap. Internal API.
  @internal
  void releaseCenterTextLayout() {
    _centerTextLayout?.dispose();
    _centerTextLayout = null;
  }

  final MutableRect _holeRect = MutableRect();
  final MutableRect _boundingRect = MutableRect();

  final ui.Path _pathBuffer = ui.Path();
  final MutableRect _innerRectBuffer = MutableRect();
  final MutableRect _roundedCircleBox = MutableRect();
  final MutableRect _roundedEndCircleBox = MutableRect();
  final ui.Path _holeCirclePath = ui.Path();

  /// Path used to clip the center text to the hole.
  @protected
  final ui.Path drawCenterTextPathBuffer = ui.Path();

  /// Circle box enlarged by the selection shift, used for highlighted slices.
  @protected
  final MutableRect drawHighlightedRectF = MutableRect();

  /// Whether the last [drawData] ran on a chart with a size, Kotlin's `bitmapCanvas != null`.
  bool _canDraw = false;

  /// The save count to restore when [drawExtras] closes the layer [drawData] opened, or null without a layer.
  int? _layerSaveCount;

  /// Does nothing; slices are drawn without a buffer.
  @override
  void initBuffers() {}

  /// Draws every visible data set onto [c]. Does nothing while the chart has no size.
  ///
  /// When the transparent ring is clipped to the slices, it first opens a layer over the chart, which [drawExtras]
  /// closes after the hole (see the class documentation).
  @override
  void drawData(ui.Canvas c) {
    final width = kotlinFloatToInt(viewPortHandler.chartWidth);
    final height = kotlinFloatToInt(viewPortHandler.chartHeight);

    _layerSaveCount = null;
    if (width <= 0 || height <= 0) {
      _canDraw = false;
      return;
    }
    _canDraw = true;

    if (_isTransparentCircleClipped) {
      _layerSaveCount = c.getSaveCount();
      c.saveLayer(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint(),
      );
    }

    final pieData = chart.data;
    if (pieData == null) return;

    for (final set in pieData.dataSets) {
      if (set.isVisible && set.entryCount > 0) drawDataSet(c, set);
    }
  }

  /// Whether [drawHole] draws the transparent ring with SRC_ATOP: the same conditions as there.
  bool get _isTransparentCircleClipped =>
      chart.isDrawHoleEnabled &&
      chart.isTransparentCircleClippedToSlices &&
      chart.transparentCircleRadius > chart.holeRadius &&
      paintTransparentCircle.alpha > 0;

  /// Returns the smallest inner radius in pixels at which a slice with slice spacing still has room for the space on
  /// both of its sides, so that the slice keeps a straight inner edge.
  ///
  /// [center] is the center of the pie in pixels, [radius] the outer radius in pixels, [angle] the sweep of the slice
  /// in degrees before the spacing is removed, ([arcStartPointX], [arcStartPointY]) the pixel position where the outer
  /// arc starts, [startAngle] the start angle of the outer arc in degrees and [sweepAngle] its sweep in degrees.
  @protected
  double calculateMinimumRadiusForSpacedSlice(
    MPPointF center,
    double radius,
    double angle,
    double arcStartPointX,
    double arcStartPointY,
    double startAngle,
    double sweepAngle,
  ) {
    final angleMiddle = startAngle + sweepAngle / 2;

    final arcEndPointX =
        center.x +
        radius * math.cos((startAngle + sweepAngle) * Utils.FDEG2RAD);
    final arcEndPointY =
        center.y +
        radius * math.sin((startAngle + sweepAngle) * Utils.FDEG2RAD);

    final arcMidPointX =
        center.x + radius * math.cos(angleMiddle * Utils.FDEG2RAD);
    final arcMidPointY =
        center.y + radius * math.sin(angleMiddle * Utils.FDEG2RAD);

    final basePointsDistance = math.sqrt(
      math.pow(arcEndPointX - arcStartPointX, 2) +
          math.pow(arcEndPointY - arcStartPointY, 2),
    );

    // the triangle inside the slice keeps its angle when the space is removed from both sides
    final containedTriangleHeight =
        basePointsDistance /
        2.0 *
        math.tan((180.0 - angle) / 2.0 * Utils.DEG2RAD);

    var spacedRadius = radius - containedTriangleHeight;

    spacedRadius -= math.sqrt(
      math.pow(arcMidPointX - (arcEndPointX + arcStartPointX) / 2, 2) +
          math.pow(arcMidPointY - (arcEndPointY + arcStartPointY) / 2, 2),
    );

    return spacedRadius;
  }

  /// Returns the slice space of [dataSet] in pixels, or 0 when the data set disables spacing automatically and its
  /// smallest slice would be swallowed by the space.
  @protected
  double getSliceSpace(IPieDataSet dataSet) {
    if (!dataSet.isAutomaticallyDisableSliceSpacingEnabled) {
      return Utils.convertDpToPixel(dataSet.sliceSpace);
    }

    final yValueSum = chart.data?.yValueSum;
    if (yValueSum == null) return Utils.convertDpToPixel(dataSet.sliceSpace);
    final spaceSizeRatio =
        Utils.convertDpToPixel(dataSet.sliceSpace) /
        viewPortHandler.smallestContentExtension;
    final minValueRatio = dataSet.yMin / yValueSum * 2;

    return spaceSizeRatio > minValueRatio
        ? 0
        : Utils.convertDpToPixel(dataSet.sliceSpace);
  }

  /// Draws all slices of [dataSet] onto [c], as arcs around the hole with the slice space removed on both sides.
  /// Empty slices are skipped, and so are highlighted ones (drawn by [drawHighlighted]) and slices whose outline is not
  /// finite. Does nothing before the first [drawData] and while the chart has no size.
  @protected
  void drawDataSet(ui.Canvas c, IPieDataSet dataSet) {
    if (!_canDraw) return;

    var angle = 0.0;
    final rotationAngle = chart.rotationAngle;

    final phaseX = animator.phaseX;
    final phaseY = animator.phaseY;

    final circleBox = chart.circleBox;

    final drawAngles = chart.drawAngles;
    final entryCount = math.min(dataSet.entryCount, drawAngles.length);
    final center = chart.centerCircleBox;
    final radius = chart.radius;
    final drawInnerArc =
        chart.isDrawHoleEnabled && !chart.isDrawSlicesUnderHoleEnabled;
    final userInnerRadius = drawInnerArc
        ? radius * (chart.holeRadius / 100)
        : 0.0;
    final roundedRadius = (radius - (radius * chart.holeRadius / 100)) / 2;
    final drawRoundedSlices = drawInnerArc && chart.isDrawRoundedSlicesEnabled;
    final roundedStartSweep = chart.isRoundedSlicesReversed ? 180.0 : -180.0;

    var visibleAngleCount = 0;
    for (var j = 0; j < entryCount; j++) {
      if (dataSet.getEntryForIndex(j).y.abs() > Utils.FLOAT_EPSILON) {
        visibleAngleCount++;
      }
    }

    final sliceSpace = visibleAngleCount <= 1 ? 0.0 : getSliceSpace(dataSet);

    for (var j = 0; j < entryCount; j++) {
      final sliceAngle = drawAngles[j];
      var innerRadius = userInnerRadius;

      final e = dataSet.getEntryForIndex(j);

      if (!(e.y.abs() > Utils.FLOAT_EPSILON)) {
        angle += sliceAngle * phaseX;
        continue;
      }

      if (dataSet.isHighlightEnabled && chart.needsHighlight(j)) {
        angle += sliceAngle * phaseX;
        continue;
      }

      final accountForSliceSpacing = sliceSpace > 0 && sliceAngle <= 180;

      renderPaint.color = dataSet.getColor(j);

      final sliceSpaceAngleOuter = visibleAngleCount == 1
          ? 0.0
          : sliceSpace / (Utils.FDEG2RAD * radius);
      final startAngleOuter =
          rotationAngle + (angle + sliceSpaceAngleOuter / 2) * phaseY;
      var sweepAngleOuter = (sliceAngle - sliceSpaceAngleOuter) * phaseY;
      if (sweepAngleOuter < 0) {
        sweepAngleOuter = 0;
      }
      // Android draws arcs "mod 360", so a full sweep needs a circle
      final fullCircle = _isFullCircle(sweepAngleOuter);

      if (drawRoundedSlices) {
        final x =
            center.x +
            (radius - roundedRadius) *
                math.cos(startAngleOuter * Utils.FDEG2RAD);
        final y =
            center.y +
            (radius - roundedRadius) *
                math.sin(startAngleOuter * Utils.FDEG2RAD);
        _roundedCircleBox.set(
          x - roundedRadius,
          y - roundedRadius,
          x + roundedRadius,
          y + roundedRadius,
        );
      }

      final arcStartPointX =
          center.x + radius * math.cos(startAngleOuter * Utils.FDEG2RAD);
      final arcStartPointY =
          center.y + radius * math.sin(startAngleOuter * Utils.FDEG2RAD);

      _innerRectBuffer.set(
        center.x - innerRadius,
        center.y - innerRadius,
        center.x + innerRadius,
        center.y + innerRadius,
      );

      // Kotlin works out the inner edge while it builds the path. Here the whole outline is worked out
      // first, so that a slice whose outline is not finite is skipped before anything reaches the path.
      final drawInnerEdge =
          drawInnerArc && (innerRadius > 0 || accountForSliceSpacing);
      var sweepAngleInner = 0.0;
      var endAngleInner = 0.0;
      // The point the outer arc is connected to by a line, if any: the start of the inner arc, the tip of a spaced
      // slice or the center.
      var lineToEdge = false;
      var edgeX = center.x;
      var edgeY = center.y;

      if (drawInnerEdge) {
        if (accountForSliceSpacing) {
          var minSpacedRadius = calculateMinimumRadiusForSpacedSlice(
            center,
            radius,
            sliceAngle * phaseY,
            arcStartPointX,
            arcStartPointY,
            startAngleOuter,
            sweepAngleOuter,
          );

          if (minSpacedRadius < 0) minSpacedRadius = -minSpacedRadius;

          innerRadius = math.max(innerRadius, minSpacedRadius);
        }

        final sliceSpaceAngleInner =
            (visibleAngleCount == 1 || innerRadius == 0)
            ? 0.0
            : sliceSpace / (Utils.FDEG2RAD * innerRadius);
        final startAngleInner =
            rotationAngle + (angle + sliceSpaceAngleInner / 2) * phaseY;
        sweepAngleInner = (sliceAngle - sliceSpaceAngleInner) * phaseY;
        if (sweepAngleInner < 0) {
          sweepAngleInner = 0;
        }
        endAngleInner = startAngleInner + sweepAngleInner;

        if (!fullCircle) {
          if (drawRoundedSlices) {
            final x =
                center.x +
                (radius - roundedRadius) *
                    math.cos(endAngleInner * Utils.FDEG2RAD);
            final y =
                center.y +
                (radius - roundedRadius) *
                    math.sin(endAngleInner * Utils.FDEG2RAD);
            _roundedEndCircleBox.set(
              x - roundedRadius,
              y - roundedRadius,
              x + roundedRadius,
              y + roundedRadius,
            );
          } else {
            lineToEdge = true;
            edgeX =
                center.x +
                innerRadius * math.cos(endAngleInner * Utils.FDEG2RAD);
            edgeY =
                center.y +
                innerRadius * math.sin(endAngleInner * Utils.FDEG2RAD);
          }
        }
      } else if (sweepAngleOuter.remainder(360) > Utils.FLOAT_EPSILON) {
        lineToEdge = true;
        if (accountForSliceSpacing) {
          final angleMiddle = startAngleOuter + sweepAngleOuter / 2;

          final sliceSpaceOffset = calculateMinimumRadiusForSpacedSlice(
            center,
            radius,
            sliceAngle * phaseY,
            arcStartPointX,
            arcStartPointY,
            startAngleOuter,
            sweepAngleOuter,
          );

          edgeX =
              center.x +
              sliceSpaceOffset * math.cos(angleMiddle * Utils.FDEG2RAD);
          edgeY =
              center.y +
              sliceSpaceOffset * math.sin(angleMiddle * Utils.FDEG2RAD);
        }
      }

      final outlineIsFinite =
          _isFinitePoint(center.x, center.y) &&
          (fullCircle
              ? radius.isFinite
              : startAngleOuter.isFinite &&
                    sweepAngleOuter.isFinite &&
                    _isFiniteRect(circleBox) &&
                    (!drawRoundedSlices || _isFiniteRect(_roundedCircleBox))) &&
          (!drawInnerEdge ||
              (fullCircle
                  ? innerRadius.isFinite
                  : endAngleInner.isFinite &&
                        sweepAngleInner.isFinite &&
                        _isFiniteRect(_innerRectBuffer) &&
                        (!drawRoundedSlices ||
                            _isFiniteRect(_roundedEndCircleBox)))) &&
          (!lineToEdge || _isFinitePoint(edgeX, edgeY));
      if (!outlineIsFinite) {
        angle += sliceAngle * phaseX;
        continue;
      }

      _pathBuffer.reset();
      _pathBuffer.fillType = ui.PathFillType.nonZero;

      if (fullCircle) {
        _addCircle(_pathBuffer, center.x, center.y, radius);
      } else {
        if (drawRoundedSlices) {
          _arcTo(
            _pathBuffer,
            _roundedCircleBox,
            startAngleOuter + 180,
            roundedStartSweep,
          );
        }

        _arcTo(_pathBuffer, circleBox, startAngleOuter, sweepAngleOuter);
      }

      if (drawInnerEdge) {
        if (fullCircle) {
          _addCircle(_pathBuffer, center.x, center.y, innerRadius);
          // The two circles make a ring.
          _pathBuffer.fillType = ui.PathFillType.evenOdd;
        } else {
          if (drawRoundedSlices) {
            _arcTo(
              _pathBuffer,
              _roundedEndCircleBox,
              endAngleInner,
              -roundedStartSweep,
            );
          } else {
            _pathBuffer.lineTo(edgeX, edgeY);
          }

          _arcTo(
            _pathBuffer,
            _innerRectBuffer,
            endAngleInner,
            -sweepAngleInner,
          );
        }
      } else if (lineToEdge) {
        _pathBuffer.lineTo(edgeX, edgeY);
      }

      _pathBuffer.close();

      c.drawPathP(_pathBuffer, renderPaint);

      angle += sliceAngle * phaseX;
    }

    MPPointF.recycleInstance(center);
  }

  /// Draws the value and the entry label of each slice, either inside the slice or outside it at the end of a
  /// two-part value line, and the entry icon at the label radius.
  @override
  void drawValues(ui.Canvas c) {
    final center = chart.centerCircleBox;

    final radius = chart.radius;
    var rotationAngle = chart.rotationAngle;
    final drawAngles = chart.drawAngles;
    final absoluteAngles = chart.absoluteAngles;

    final phaseX = animator.phaseX;
    final phaseY = animator.phaseY;

    final roundedRadius = (radius - (radius * chart.holeRadius / 100)) / 2;
    final holeRadiusPercent = chart.holeRadius / 100;
    var labelRadiusOffset = radius / 10 * 3.6;

    if (chart.isDrawHoleEnabled) {
      labelRadiusOffset = (radius - (radius * holeRadiusPercent)) / 2;

      if (!chart.isDrawSlicesUnderHoleEnabled &&
          chart.isDrawRoundedSlicesEnabled) {
        // shift by the rounded slice so the label sits inside it
        final roundedAngle = roundedRadius * 360 / (math.pi * 2 * radius);
        rotationAngle += chart.isRoundedSlicesReversed
            ? -roundedAngle
            : roundedAngle;
      }
    }

    final labelRadius = radius - labelRadiusOffset;

    final data = chart.data;
    if (data == null) {
      MPPointF.recycleInstance(center);
      return;
    }
    final dataSets = data.dataSets;

    final yValueSum = chart.absoluteValueSum;

    final drawEntryLabels = chart.isDrawEntryLabelsEnabled;

    double angle;
    var xIndex = 0;

    c.save();

    final offset = Utils.convertDpToPixel(5);

    for (var i = 0; i < dataSets.length; i++) {
      final dataSet = dataSets[i];

      final drawValues = dataSet.isDrawValuesEnabled;

      if (!drawValues && !drawEntryLabels) continue;

      final xValuePosition = dataSet.xValuePosition;
      final yValuePosition = dataSet.yValuePosition;

      applyValueTextStyle(dataSet);

      final lineHeight =
          Utils.calcTextHeight(valuePaint, 'Q') + Utils.convertDpToPixel(4);

      final formatter = dataSet.valueFormatter;

      final entryCount = dataSet.entryCount;

      final isUseValueColorForLineEnabled =
          dataSet.isUseValueColorForLineEnabled;
      final valueLineColor = dataSet.valueLineColor;

      valueLinePaint.strokeWidth = Utils.convertDpToPixel(
        dataSet.valueLineWidth,
      );

      final sliceSpace = getSliceSpace(dataSet);

      final iconsOffset = MPPointF.getInstanceFrom(dataSet.iconsOffset);
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      for (var j = 0; j < entryCount; j++) {
        if (xIndex >= drawAngles.length || xIndex >= absoluteAngles.length) {
          break;
        }

        final entry = dataSet.getEntryForIndex(j);

        angle = xIndex == 0 ? 0 : absoluteAngles[xIndex - 1] * phaseX;

        final sliceAngle = drawAngles[xIndex];
        final sliceSpaceMiddleAngle =
            sliceSpace / (Utils.FDEG2RAD * labelRadius);

        final angleOffset = (sliceAngle - sliceSpaceMiddleAngle / 2) / 2;

        angle += angleOffset;

        final transformedAngle = rotationAngle + angle * phaseY;

        final value = !chart.isUsePercentValuesEnabled
            ? entry.y
            : yValueSum == 0
            ? 0.0
            : entry.y / yValueSum * 100;
        final entryLabel = entry.label;

        final sliceXBase = math.cos(transformedAngle * Utils.FDEG2RAD);
        final sliceYBase = math.sin(transformedAngle * Utils.FDEG2RAD);

        final drawXOutside =
            drawEntryLabels && xValuePosition == ValuePosition.OUTSIDE_SLICE;
        final drawYOutside =
            drawValues && yValuePosition == ValuePosition.OUTSIDE_SLICE;
        final drawXInside =
            drawEntryLabels && xValuePosition == ValuePosition.INSIDE_SLICE;
        final drawYInside =
            drawValues && yValuePosition == ValuePosition.INSIDE_SLICE;

        if (drawXOutside || drawYOutside) {
          final valueLineLength1 = dataSet.valueLinePart1Length;
          final valueLineLength2 = dataSet.valueLinePart2Length;
          final valueLinePart1OffsetPercentage =
              dataSet.valueLinePart1OffsetPercentage / 100;

          final double pt2x;
          final double pt2y;
          final double labelPtx;
          final double labelPty;

          final line1Radius = chart.isDrawHoleEnabled
              ? (radius - (radius * holeRadiusPercent)) *
                        valueLinePart1OffsetPercentage +
                    (radius * holeRadiusPercent)
              : radius * valueLinePart1OffsetPercentage;

          final polyline2Width = dataSet.isValueLineVariableLength
              ? labelRadius *
                    valueLineLength2 *
                    math.sin(transformedAngle * Utils.FDEG2RAD).abs()
              : labelRadius * valueLineLength2;

          final pt0x = line1Radius * sliceXBase + center.x;
          final pt0y = line1Radius * sliceYBase + center.y;

          final pt1x =
              labelRadius * (1 + valueLineLength1) * sliceXBase + center.x;
          final pt1y =
              labelRadius * (1 + valueLineLength1) * sliceYBase + center.y;

          if (transformedAngle.remainder(360.0) >= 90.0 &&
              transformedAngle.remainder(360.0) <= 270.0) {
            pt2x = pt1x - polyline2Width;
            pt2y = pt1y;

            valuePaint.textAlign = PaintAlign.RIGHT;

            if (drawXOutside) paintEntryLabels.textAlign = PaintAlign.RIGHT;

            labelPtx = pt2x - offset;
            labelPty = pt2y;
          } else {
            pt2x = pt1x + polyline2Width;
            pt2y = pt1y;
            valuePaint.textAlign = PaintAlign.LEFT;

            if (drawXOutside) paintEntryLabels.textAlign = PaintAlign.LEFT;

            labelPtx = pt2x + offset;
            labelPty = pt2y;
          }

          var lineColor = ColorTemplate.COLOR_NONE;

          if (isUseValueColorForLineEnabled) {
            lineColor = dataSet.getColor(j);
          } else if (valueLineColor != ColorTemplate.COLOR_NONE) {
            lineColor = valueLineColor;
          }

          if (lineColor != ColorTemplate.COLOR_NONE) {
            valueLinePaint.color = lineColor;
            _drawLine(c, pt0x, pt0y, pt1x, pt1y, valueLinePaint);
            _drawLine(c, pt1x, pt1y, pt2x, pt2y, valueLinePaint);
          }

          if (drawXOutside && drawYOutside) {
            drawValue(
              c,
              formatter,
              value,
              entry,
              0,
              labelPtx,
              labelPty,
              dataSet.getValueTextColor(j),
            );

            if (j < data.entryCount && entryLabel != null) {
              final labelY =
                  labelPty +
                  lineHeight +
                  _extraLineShift(formatter, value, entry, entryLabel);
              drawEntryLabel(c, entryLabel, labelPtx, labelY);
            }
          } else if (drawXOutside) {
            if (j < data.entryCount && entryLabel != null) {
              drawEntryLabel(
                c,
                entryLabel,
                labelPtx,
                labelPty + lineHeight / 2,
              );
            }
          } else if (drawYOutside) {
            drawValue(
              c,
              formatter,
              value,
              entry,
              0,
              labelPtx,
              labelPty + lineHeight / 2,
              dataSet.getValueTextColor(j),
            );
          }
        }

        if (drawXInside || drawYInside) {
          final x = labelRadius * sliceXBase + center.x;
          final y = labelRadius * sliceYBase + center.y;

          valuePaint.textAlign = PaintAlign.CENTER;

          if (drawXInside && drawYInside) {
            drawValue(
              c,
              formatter,
              value,
              entry,
              0,
              x,
              y,
              dataSet.getValueTextColor(j),
            );

            if (j < data.entryCount && entryLabel != null) {
              drawEntryLabel(
                c,
                entryLabel,
                x,
                y +
                    lineHeight +
                    _extraLineShift(formatter, value, entry, entryLabel),
              );
            }
          } else if (drawXInside) {
            if (j < data.entryCount && entryLabel != null) {
              drawEntryLabel(c, entryLabel, x, y + lineHeight / 2);
            }
          } else if (drawYInside) {
            drawValue(
              c,
              formatter,
              value,
              entry,
              0,
              x,
              y + lineHeight / 2,
              dataSet.getValueTextColor(j),
            );
          }
        }

        final icon = entry.icon;
        if (icon != null && dataSet.isDrawIconsEnabled) {
          final x = (labelRadius + iconsOffset.y) * sliceXBase + center.x;
          var y = (labelRadius + iconsOffset.y) * sliceYBase + center.y;
          y += iconsOffset.x;

          Utils.drawImage(
            c,
            icon,
            truncateToDevicePx(x),
            truncateToDevicePx(y),
            icon.intrinsicWidth,
            icon.intrinsicHeight,
          );
        }

        xIndex++;
      }

      MPPointF.recycleInstance(iconsOffset);
    }
    MPPointF.recycleInstance(center);
    c.restore();
  }

  /// Draws an entry label with [paintEntryLabels] at the pixel position ([x], [y]), where [y] is the text baseline.
  /// A label containing line breaks is drawn one line per part, with the lines centered vertically on [y].
  @protected
  void drawEntryLabel(ui.Canvas c, String label, double x, double y) {
    _drawTextLines(c, label, x, y, paintEntryLabels);
  }

  /// Draws one value label with [valuePaint] in [color] at the pixel position ([x], [y]), where [y] is the text
  /// baseline. A formatted value containing line breaks is drawn one line per part, with the lines centered
  /// vertically on [y].
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
    valuePaint.color = color;
    _drawTextLines(
      c,
      formatter.getFormattedValue(value, entry, dataSetIndex, viewPortHandler),
      x,
      y,
      valuePaint,
    );
  }

  void _drawTextLines(
    ui.Canvas c,
    String text,
    double x,
    double y,
    ChartPaint paint,
  ) {
    // Text at a position that is not finite is not drawn.
    if (!_isFinitePoint(x, y)) return;
    if (!text.contains('\n')) {
      c.drawText(text, x, y, paint);
      return;
    }

    final lines = text.split('\n');
    final lineSpacing = paint.getFontSpacing();
    var lineY = y - (lines.length - 1) * lineSpacing / 2;
    for (final line in lines) {
      c.drawText(line, x, lineY, paint);
      lineY += lineSpacing;
    }
  }

  /// How far a label below a value moves down so that the extra lines of both do not overlap.
  double _extraLineShift(
    IValueFormatter formatter,
    double value,
    Entry entry,
    String label,
  ) {
    final extraValueLines = '\n'
        .allMatches(
          formatter.getFormattedValue(value, entry, 0, viewPortHandler),
        )
        .length;
    final extraLabelLines = '\n'.allMatches(label).length;
    return (extraValueLines * valuePaint.getFontSpacing() +
            extraLabelLines * paintEntryLabels.getFontSpacing()) /
        2;
  }

  /// Draws the hole and the transparent ring, closes the layer [drawData] opened for a ring clipped to the slices,
  /// and draws the center text on top.
  @override
  void drawExtras(ui.Canvas c) {
    drawHole(c);
    // Where Kotlin composited its bitmap.
    final saved = _layerSaveCount;
    if (saved != null) {
      _layerSaveCount = null;
      c.restoreToCount(saved);
    }
    drawCenterText(c);
  }

  /// Draws the hole and the transparent ring onto [c] when the chart enables the hole. The ring is only drawn when
  /// its radius is larger than the hole radius, and only over the slices (with [ui.BlendMode.srcATop] into the layer
  /// of [drawData]) when [PieChart.isTransparentCircleClippedToSlices] is set. Does nothing before the first
  /// [drawData] and while the chart has no size.
  @protected
  void drawHole(ui.Canvas c) {
    if (!_canDraw) return;
    if (!chart.isDrawHoleEnabled) return;

    final radius = chart.radius;
    final holeRadius = radius * (chart.holeRadius / 100);
    final center = chart.centerCircleBox;

    // A hole or ring that is not finite is not drawn.
    final centerIsFinite = _isFinitePoint(center.x, center.y);

    if (paintHole.alpha > 0 && centerIsFinite && holeRadius.isFinite) {
      c.drawCircleP(center.x, center.y, holeRadius, paintHole);
    }

    final secondHoleRadius = radius * (chart.transparentCircleRadius / 100);

    // only visible when it reaches beyond the hole
    if (paintTransparentCircle.alpha > 0 &&
        chart.transparentCircleRadius > chart.holeRadius &&
        centerIsFinite &&
        holeRadius.isFinite &&
        secondHoleRadius.isFinite) {
      final alpha = paintTransparentCircle.alpha;

      paintTransparentCircle.alpha = kotlinFloatToInt(
        alpha * animator.phaseX * animator.phaseY,
      );

      _holeCirclePath.reset();
      _holeCirclePath.fillType = ui.PathFillType.evenOdd;
      _addCircle(_holeCirclePath, center.x, center.y, secondHoleRadius);
      _addCircle(_holeCirclePath, center.x, center.y, holeRadius);
      // the slices are already in the layer, so SRC_ATOP paints only where a slice is
      if (chart.isTransparentCircleClippedToSlices) {
        paintTransparentCircle.xfermode = ui.BlendMode.srcATop;
      }
      c.drawPathP(_holeCirclePath, paintTransparentCircle);

      paintTransparentCircle.xfermode = null;
      paintTransparentCircle.alpha = alpha;
    }
    MPPointF.recycleInstance(center);
  }

  /// Draws the center text of the chart, wrapped to the center text radius percent of the hole, centered and clipped
  /// to the hole (or to the whole pie without a hole). The text layout is cached until the text, its bounds or its
  /// style change. Does nothing when the chart disables the center text.
  @protected
  void drawCenterText(ui.Canvas c) {
    final centerText = chart.centerText;

    if (!chart.isDrawCenterTextEnabled) return;

    final center = chart.centerCircleBox;
    final offset = chart.centerTextOffset;

    final x = center.x + Utils.convertDpToPixel(offset.x);
    final y = center.y + Utils.convertDpToPixel(offset.y);

    final innerRadius =
        (chart.isDrawHoleEnabled && !chart.isDrawSlicesUnderHoleEnabled)
        ? chart.radius * (chart.holeRadius / 100)
        : chart.radius;

    final holeRect = _holeRect;
    holeRect.left = x - innerRadius;
    holeRect.top = y - innerRadius;
    holeRect.right = x + innerRadius;
    holeRect.bottom = y + innerRadius;
    final boundingRect = _boundingRect;
    boundingRect.setFrom(holeRect);

    final radiusPercent = chart.centerTextRadiusPercent / 100;
    if (radiusPercent > 0.0) {
      boundingRect.inset(
        (boundingRect.width() - boundingRect.width() * radiusPercent) / 2,
        (boundingRect.height() - boundingRect.height() * radiusPercent) / 2,
      );
    }

    // A hole or text box that is not finite (a center text offset that is not a number or infinite) is
    // not drawn. Checked before the layout, which such a box would redo on every frame (its bounds never equal the
    // last ones), and the cached layout and its bounds are left as they are.
    if (!_isFiniteRect(holeRect) || !_isFiniteRect(boundingRect)) {
      MPPointF.recycleInstance(center);
      MPPointF.recycleInstance(offset);
      return;
    }

    final style = paintCenterText.textStyle;
    var layout = _centerTextLayout;
    if (layout == null ||
        centerText != _centerTextLastValue ||
        !_sameRect(boundingRect, _centerTextLastBounds) ||
        style != _centerTextLastStyle) {
      _centerTextLastBounds.setFrom(boundingRect);
      _centerTextLastValue = centerText;
      _centerTextLastStyle = style;

      final width = _centerTextLastBounds.width();

      // Kotlin's "a width of 0 crashes the layout" is about its StaticLayout; TextPainter accepts 0, but the layout
      // keeps Kotlin's minimum width of 1 px. Kotlin's ceil and toInt are in device px.
      final layoutWidth = math.max(ceilToDevicePx(width), oneDevicePx);
      layout = TextPainter(
        text: TextSpan(text: centerText, style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: layoutWidth, maxWidth: layoutWidth);
      _centerTextLayout?.dispose();
      _centerTextLayout = layout;
      _centerTextLayoutCount++;
    }

    final layoutHeight = layout.height;

    c.save();
    final path = drawCenterTextPathBuffer;
    path.reset();
    path.addOval(holeRect.toRect());
    c.clipPath(path);

    c.translate(
      boundingRect.left,
      boundingRect.top + (boundingRect.height() - layoutHeight) / 2,
    );
    layout.paint(c, ui.Offset.zero);

    c.restore();

    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(offset);
  }

  /// Redraws each highlighted slice onto [c], enlarged by the selection shift (dp) of its data set and in the
  /// highlight color when the data set has one. A slice whose outline is not finite is skipped. Does
  /// nothing before the first [drawData] and while the chart has no size.
  @override
  void drawHighlighted(ui.Canvas c, List<Highlight> indices) {
    final drawInnerArc =
        chart.isDrawHoleEnabled && !chart.isDrawSlicesUnderHoleEnabled;
    final drawRoundedSlices = drawInnerArc && chart.isDrawRoundedSlicesEnabled;
    final roundedStartSweep = chart.isRoundedSlicesReversed ? 180.0 : -180.0;

    if (!_canDraw) return;
    final data = chart.data;
    if (data == null) return;

    final phaseX = animator.phaseX;
    final phaseY = animator.phaseY;

    double angle;
    final rotationAngle = chart.rotationAngle;

    final drawAngles = chart.drawAngles;
    final absoluteAngles = chart.absoluteAngles;
    final center = chart.centerCircleBox;
    final radius = chart.radius;
    final userInnerRadius = drawInnerArc
        ? radius * (chart.holeRadius / 100)
        : 0.0;

    final highlightedCircleBox = drawHighlightedRectF;
    highlightedCircleBox.set(0, 0, 0, 0);

    for (var i = 0; i < indices.length; i++) {
      final index = kotlinFloatToInt(indices[i].x);

      if (index < 0 ||
          index >= drawAngles.length ||
          index > absoluteAngles.length) {
        continue;
      }

      final set = data.getDataSetByIndex(indices[i].dataSetIndex);

      if (set == null || !set.isHighlightEnabled) continue;

      final entryCount = set.entryCount;
      var visibleAngleCount = 0;
      for (var j = 0; j < entryCount; j++) {
        if (set.getEntryForIndex(j).y.abs() > Utils.FLOAT_EPSILON) {
          visibleAngleCount++;
        }
      }

      angle = index == 0 ? 0 : absoluteAngles[index - 1] * phaseX;

      final sliceSpace = visibleAngleCount <= 1
          ? 0.0
          : Utils.convertDpToPixel(set.sliceSpace);

      final sliceAngle = drawAngles[index];
      var innerRadius = userInnerRadius;

      final shift = Utils.convertDpToPixel(set.selectionShift);
      final highlightedRadius = radius + shift;
      highlightedCircleBox.setFrom(chart.circleBox);
      highlightedCircleBox.inset(-shift, -shift);

      final accountForSliceSpacing = sliceSpace > 0 && sliceAngle <= 180;

      renderPaint.color = set.highlightColor ?? set.getColor(index);

      final sliceSpaceAngleOuter = visibleAngleCount == 1
          ? 0.0
          : sliceSpace / (Utils.FDEG2RAD * radius);

      final sliceSpaceAngleShifted = visibleAngleCount == 1
          ? 0.0
          : sliceSpace / (Utils.FDEG2RAD * highlightedRadius);

      final startAngleOuter =
          rotationAngle + (angle + sliceSpaceAngleOuter / 2) * phaseY;
      var sweepAngleOuter = (sliceAngle - sliceSpaceAngleOuter) * phaseY;
      if (sweepAngleOuter < 0) {
        sweepAngleOuter = 0;
      }

      final startAngleShifted =
          rotationAngle + (angle + sliceSpaceAngleShifted / 2) * phaseY;
      var sweepAngleShifted = (sliceAngle - sliceSpaceAngleShifted) * phaseY;
      if (sweepAngleShifted < 0) {
        sweepAngleShifted = 0;
      }

      final roundedRadius = (highlightedRadius - innerRadius) / 2;
      final fullCircle = _isFullCircle(sweepAngleOuter);

      if (!fullCircle && drawRoundedSlices) {
        final x =
            center.x +
            (highlightedRadius - roundedRadius) *
                math.cos(startAngleShifted * Utils.FDEG2RAD);
        final y =
            center.y +
            (highlightedRadius - roundedRadius) *
                math.sin(startAngleShifted * Utils.FDEG2RAD);
        _roundedCircleBox.set(
          x - roundedRadius,
          y - roundedRadius,
          x + roundedRadius,
          y + roundedRadius,
        );
      }

      var sliceSpaceRadius = 0.0;
      if (accountForSliceSpacing) {
        sliceSpaceRadius = calculateMinimumRadiusForSpacedSlice(
          center,
          radius,
          sliceAngle * phaseY,
          center.x + radius * math.cos(startAngleOuter * Utils.FDEG2RAD),
          center.y + radius * math.sin(startAngleOuter * Utils.FDEG2RAD),
          startAngleOuter,
          sweepAngleOuter,
        );
      }

      _innerRectBuffer.set(
        center.x - innerRadius,
        center.y - innerRadius,
        center.x + innerRadius,
        center.y + innerRadius,
      );

      // The whole outline is worked out before anything reaches the path, as in drawDataSet.
      final drawInnerEdge =
          drawInnerArc && (innerRadius > 0 || accountForSliceSpacing);
      var sweepAngleInner = 0.0;
      var endAngleInner = 0.0;
      var lineToEdge = false;
      var edgeX = center.x;
      var edgeY = center.y;

      if (drawInnerEdge) {
        if (accountForSliceSpacing) {
          var minSpacedRadius = sliceSpaceRadius;

          if (minSpacedRadius < 0) minSpacedRadius = -minSpacedRadius;

          innerRadius = math.max(innerRadius, minSpacedRadius);
        }

        final sliceSpaceAngleInner =
            (visibleAngleCount == 1 || innerRadius == 0)
            ? 0.0
            : sliceSpace / (Utils.FDEG2RAD * innerRadius);
        final startAngleInner =
            rotationAngle + (angle + sliceSpaceAngleInner / 2) * phaseY;
        sweepAngleInner = (sliceAngle - sliceSpaceAngleInner) * phaseY;
        if (sweepAngleInner < 0) {
          sweepAngleInner = 0;
        }
        endAngleInner = startAngleInner + sweepAngleInner;

        if (!fullCircle) {
          if (drawRoundedSlices) {
            final x =
                center.x +
                (highlightedRadius - roundedRadius) *
                    math.cos(endAngleInner * Utils.FDEG2RAD);
            final y =
                center.y +
                (highlightedRadius - roundedRadius) *
                    math.sin(endAngleInner * Utils.FDEG2RAD);
            _roundedEndCircleBox.set(
              x - roundedRadius,
              y - roundedRadius,
              x + roundedRadius,
              y + roundedRadius,
            );
          } else {
            lineToEdge = true;
            edgeX =
                center.x +
                innerRadius * math.cos(endAngleInner * Utils.FDEG2RAD);
            edgeY =
                center.y +
                innerRadius * math.sin(endAngleInner * Utils.FDEG2RAD);
          }
        }
      } else if (sweepAngleOuter.remainder(360) > Utils.FLOAT_EPSILON) {
        lineToEdge = true;
        if (accountForSliceSpacing) {
          final angleMiddle = startAngleOuter + sweepAngleOuter / 2;

          edgeX =
              center.x +
              sliceSpaceRadius * math.cos(angleMiddle * Utils.FDEG2RAD);
          edgeY =
              center.y +
              sliceSpaceRadius * math.sin(angleMiddle * Utils.FDEG2RAD);
        }
      }

      final startX =
          center.x +
          highlightedRadius * math.cos(startAngleShifted * Utils.FDEG2RAD);
      final startY =
          center.y +
          highlightedRadius * math.sin(startAngleShifted * Utils.FDEG2RAD);

      final outlineIsFinite =
          _isFinitePoint(center.x, center.y) &&
          (fullCircle
              ? highlightedRadius.isFinite
              : startAngleShifted.isFinite &&
                    sweepAngleShifted.isFinite &&
                    _isFiniteRect(highlightedCircleBox) &&
                    (drawRoundedSlices
                        ? _isFiniteRect(_roundedCircleBox)
                        : _isFinitePoint(startX, startY))) &&
          (!drawInnerEdge ||
              (fullCircle
                  ? innerRadius.isFinite
                  : endAngleInner.isFinite &&
                        sweepAngleInner.isFinite &&
                        _isFiniteRect(_innerRectBuffer) &&
                        (!drawRoundedSlices ||
                            _isFiniteRect(_roundedEndCircleBox)))) &&
          (!lineToEdge || _isFinitePoint(edgeX, edgeY));
      if (!outlineIsFinite) continue;

      _pathBuffer.reset();
      _pathBuffer.fillType = ui.PathFillType.nonZero;

      if (fullCircle) {
        _addCircle(_pathBuffer, center.x, center.y, highlightedRadius);
      } else {
        if (drawRoundedSlices) {
          _arcTo(
            _pathBuffer,
            _roundedCircleBox,
            startAngleShifted + 180,
            roundedStartSweep,
          );
        } else {
          _pathBuffer.moveTo(startX, startY);
        }

        _arcTo(
          _pathBuffer,
          highlightedCircleBox,
          startAngleShifted,
          sweepAngleShifted,
        );
      }

      if (drawInnerEdge) {
        if (fullCircle) {
          _addCircle(_pathBuffer, center.x, center.y, innerRadius);
          // The two circles make a ring.
          _pathBuffer.fillType = ui.PathFillType.evenOdd;
        } else {
          if (drawRoundedSlices) {
            _arcTo(
              _pathBuffer,
              _roundedEndCircleBox,
              endAngleInner,
              -roundedStartSweep,
            );
          } else {
            _pathBuffer.lineTo(edgeX, edgeY);
          }

          _arcTo(
            _pathBuffer,
            _innerRectBuffer,
            endAngleInner,
            -sweepAngleInner,
          );
        }
      } else if (lineToEdge) {
        _pathBuffer.lineTo(edgeX, edgeY);
      }

      _pathBuffer.close();

      c.drawPathP(_pathBuffer, renderPaint);
    }

    MPPointF.recycleInstance(center);
  }

  /// Draws a circle in the slice color at the outer end of every non-empty slice, rounding the slice off. Not part
  /// of the default draw pass; call it from a subclass when needed. Does nothing before the first [drawData] and
  /// while the chart has no size.
  @protected
  void drawRoundedSlices(ui.Canvas c) {
    if (!chart.isDrawRoundedSlicesEnabled) return;

    if (!_canDraw) return;
    final dataSet = chart.data?.dataSet;
    if (dataSet == null) return;

    if (!dataSet.isVisible) return;

    final phaseX = animator.phaseX;
    final phaseY = animator.phaseY;

    final center = chart.centerCircleBox;
    final r = chart.radius;

    final circleRadius = (r - (r * chart.holeRadius / 100)) / 2;

    final drawAngles = chart.drawAngles;
    var angle = chart.rotationAngle;

    for (var j = 0; j < math.min(dataSet.entryCount, drawAngles.length); j++) {
      final sliceAngle = drawAngles[j];

      final e = dataSet.getEntryForIndex(j);

      if (e.y.abs() > Utils.FLOAT_EPSILON) {
        final x =
            (r - circleRadius) *
                math.cos((angle + sliceAngle) * phaseY * Utils.DEG2RAD) +
            center.x;
        final y =
            (r - circleRadius) *
                math.sin((angle + sliceAngle) * phaseY * Utils.DEG2RAD) +
            center.y;

        renderPaint.color = dataSet.getColor(j);
        // A circle that is not finite is not drawn.
        if (_isFinitePoint(x, y) && circleRadius.isFinite) {
          c.drawCircleP(x, y, circleRadius, renderPaint);
        }
      }

      angle += sliceAngle * phaseX;
    }
    MPPointF.recycleInstance(center);
  }

  /// Kotlin's `sweepAngle >= 360f && sweepAngle % 360f <= Utils.FLOAT_EPSILON`: a sweep that Android's arcTo would
  /// draw as nothing, so it is drawn as a circle.
  static bool _isFullCircle(double sweepAngle) =>
      sweepAngle >= 360 && sweepAngle.remainder(360) <= Utils.FLOAT_EPSILON;

  /// Android's `Path.addCircle(x, y, radius, direction)`; the direction only matters for the winding fill, which the
  /// rings replace with the even-odd fill.
  static void _addCircle(ui.Path path, double x, double y, double radius) {
    path.addOval(ui.Rect.fromCircle(center: ui.Offset(x, y), radius: radius));
  }

  /// Android's `Path.arcTo(RectF oval, startAngle, sweepAngle)` with the angles in degrees: the arc is connected to
  /// the current point by a line, or starts the path when it is empty.
  static void _arcTo(
    ui.Path path,
    MutableRect oval,
    double startAngle,
    double sweepAngle,
  ) {
    path.arcTo(
      oval.toRect(),
      startAngle * Utils.DEG2RAD,
      sweepAngle * Utils.DEG2RAD,
      false,
    );
  }

  /// `Canvas.drawLine`; a line with an end that is not finite is not drawn.
  static void _drawLine(
    ui.Canvas c,
    double x1,
    double y1,
    double x2,
    double y2,
    ChartPaint paint,
  ) {
    if (_isFinitePoint(x1, y1) && _isFinitePoint(x2, y2)) {
      c.drawLineP(x1, y1, x2, y2, paint);
    }
  }

  static bool _isFinitePoint(double x, double y) => x.isFinite && y.isFinite;

  static bool _isFiniteRect(MutableRect r) =>
      _isFinitePoint(r.left, r.top) && _isFinitePoint(r.right, r.bottom);

  static bool _sameRect(MutableRect a, MutableRect b) =>
      a.left == b.left &&
      a.top == b.top &&
      a.right == b.right &&
      a.bottom == b.bottom;
}
