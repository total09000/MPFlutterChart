// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/PieRadarChartBase.kt
//
// Not ported (Android only): the Context/AttributeSet constructors. Log.i is debugPrint while Chart.isLogEnabled.
// The two getPosition overloads are one with an optional trailing output point, which it writes and returns.
// spin's `onEnd: () -> Unit = {}` is a nullable named parameter. Kotlin's `.toFloat()` results
// are doubles, as in the rest of the port.
//
// getAngleForPoint follows Kotlin's code, not its KDoc: the KDoc says a point exactly at 3 o'clock yields 360, but the
// code wraps every angle of 360 or more back by 360, so 3 o'clock yields 0.
//
// calculateOffsets keeps Kotlin's `this is RadarChart` branch; the import of radar_chart.dart for it closes an import
// cycle with radar_chart.dart, which Dart allows.
//
// Not in Kotlin: onDetachedFromWindow and onHostVsyncChanged also stop the rotation deceleration of the touch
// listener, whose ticker runs on the host's vsync, as BarLineChartBase does for its
// fling. This class does not override onDraw: PieChart and RadarChart draw and end their onDraw with notifyAfterDraw.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, protected;

import '../animation/chart_animator.dart';
import '../animation/easing.dart';
import '../components/legend.dart';
import '../data/chart_data.dart';
import '../graphics/mutable_rect.dart';
import '../listener/pie_radar_chart_touch_listener.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../widgets/chart_touch_event.dart';
import 'chart.dart';
import 'radar_chart.dart';

/// Base class of the round charts, `PieChart` and `RadarChart`. It adds rotation by touch and the angle and distance
/// helpers around the chart center. Angles are in degrees, 0 at 3 o'clock, increasing clockwise.
///
/// [T] is the [ChartData] type this chart displays, fixed by each subclass.
abstract class PieRadarChartBase<T extends ChartData> extends Chart<T> {
  double _rotationAngle = 270;

  /// Angle in degrees at which the first slice or entry starts, normalized to 0 (inclusive) until 360 (exclusive).
  /// Default 270, the top of the chart. Setting it also stores the unnormalized value in [rawRotationAngle].
  double get rotationAngle => _rotationAngle;

  set rotationAngle(double value) {
    _rawRotationAngle = value;
    _rotationAngle = Utils.getNormalizedAngle(value);
  }

  double _rawRotationAngle = 270;

  /// The last value given to [rotationAngle] before normalizing, in degrees, which may be negative or above 360.
  /// Default 270.
  double get rawRotationAngle => _rawRotationAngle;

  /// Whether the chart can be rotated by dragging. Default true.
  bool isRotationEnabled = true;

  /// Smallest space in dp between the view edge and the chart on every side. Default 0.
  double minOffset = 0;

  @override
  void init() {
    super.init();
    chartTouchListener = PieRadarChartTouchListener(this);
  }

  @override
  void calcMinMax() {}

  /// The number of entries of the data, or 0 without data.
  @override
  int get maxVisibleCount => data?.entryCount ?? 0;

  /// Passes [event] to the [chartTouchListener] while [isTouchEnabled] is true and a listener is assigned, and returns
  /// what it returns; otherwise consumes nothing.
  @override
  bool onTouchEvent(ChartTouchEvent event) {
    return isTouchEnabled && isChartTouchListenerInitialized
        ? chartTouchListener.onTouch(this, event)
        : super.onTouchEvent(event);
  }

  /// Advances the rotation deceleration of the [chartTouchListener] by one frame.
  @override
  void computeScroll() {
    final listener = chartTouchListener;
    if (listener is PieRadarChartTouchListener) listener.computeScroll();
  }

  /// Also stops a running rotation deceleration, whose ticker runs on the host's vsync.
  ///
  /// Not in Kotlin, where a detached view simply stops getting `computeScroll` calls: here no ticker may outlive the
  /// host.
  @override
  void onDetachedFromWindow() {
    _stopDeceleration();
    super.onDetachedFromWindow();
  }

  /// Also stops a running rotation deceleration, whose ticker runs on the previous vsync. Not in Kotlin.
  @override
  void onHostVsyncChanged() {
    _stopDeceleration();
    super.onHostVsyncChanged();
  }

  /// Stops the rotation deceleration of the touch listener, once one is assigned.
  void _stopDeceleration() {
    if (!isChartTouchListenerInitialized) return;
    final listener = chartTouchListener;
    if (listener is PieRadarChartTouchListener) listener.stopDeceleration();
  }

  @override
  void notifyDataSetChanged() {
    final data = this.data;
    if (data == null) return;

    data.notifyDataChanged();
    calcMinMax();
    renderer.initBuffers();

    legendRenderer.computeLegend(data);

    calculateOffsets();
    invalidate();
  }

  /// Computes the content rectangle from the legend, the offsets the chart requires, the extra offsets and
  /// [minOffset].
  @override
  void calculateOffsets() {
    var legendLeft = 0.0;
    var legendRight = 0.0;
    var legendBottom = 0.0;
    var legendTop = 0.0;

    final legend = this.legend;
    if (legend.isEnabled && !legend.isDrawInsideEnabled) {
      final fullLegendWidth = math.min(
        legend.neededWidth,
        viewPortHandler.chartWidth * legend.maxSizePercent,
      );

      switch (legend.orientation) {
        case LegendOrientation.VERTICAL:
          var xLegendOffset = 0.0;

          if (legend.horizontalAlignment == LegendHorizontalAlignment.LEFT ||
              legend.horizontalAlignment == LegendHorizontalAlignment.RIGHT) {
            if (legend.verticalAlignment == LegendVerticalAlignment.CENTER) {
              final spacing = Utils.convertDpToPixel(13);
              xLegendOffset = fullLegendWidth + spacing;
            } else {
              final spacing = Utils.convertDpToPixel(8);

              final legendWidth = fullLegendWidth + spacing;
              final legendHeight = legend.neededHeight + legend.textHeightMax;

              final center = this.center;

              final bottomX =
                  legend.horizontalAlignment == LegendHorizontalAlignment.RIGHT
                  ? width - legendWidth + 15
                  : legendWidth - 15;
              final bottomY = legendHeight + 15;
              final distLegend = distanceToCenter(bottomX, bottomY);

              final reference = getPosition(
                center,
                radius,
                getAngleForPoint(bottomX, bottomY),
              );

              final distReference = distanceToCenter(reference.x, reference.y);
              final minOffset = Utils.convertDpToPixel(5);

              if (bottomY >= center.y && height - legendWidth > width) {
                xLegendOffset = legendWidth;
              } else if (distLegend < distReference) {
                final diff = distReference - distLegend;
                xLegendOffset = minOffset + diff;
              }

              MPPointF.recycleInstance(center);
              MPPointF.recycleInstance(reference);
            }
          }

          switch (legend.horizontalAlignment) {
            case LegendHorizontalAlignment.LEFT:
              legendLeft = xLegendOffset;
            case LegendHorizontalAlignment.RIGHT:
              legendRight = xLegendOffset;
            case LegendHorizontalAlignment.CENTER:
              switch (legend.verticalAlignment) {
                case LegendVerticalAlignment.TOP:
                  legendTop = math.min(
                    legend.neededHeight,
                    viewPortHandler.chartHeight * legend.maxSizePercent,
                  );
                case LegendVerticalAlignment.BOTTOM:
                  legendBottom = math.min(
                    legend.neededHeight,
                    viewPortHandler.chartHeight * legend.maxSizePercent,
                  );
                case LegendVerticalAlignment.CENTER:
                  break;
              }
          }
        case LegendOrientation.HORIZONTAL:
          if (legend.verticalAlignment == LegendVerticalAlignment.TOP ||
              legend.verticalAlignment == LegendVerticalAlignment.BOTTOM) {
            final yOffset = requiredLegendOffset;

            final yLegendOffset = math.min(
              legend.neededHeight + yOffset,
              viewPortHandler.chartHeight * legend.maxSizePercent,
            );

            switch (legend.verticalAlignment) {
              case LegendVerticalAlignment.TOP:
                legendTop = yLegendOffset;
              case LegendVerticalAlignment.BOTTOM:
                legendBottom = yLegendOffset;
              case LegendVerticalAlignment.CENTER:
                break;
            }
          }
      }

      legendLeft += requiredBaseOffset;
      legendRight += requiredBaseOffset;
      legendTop += requiredVerticalBaseOffset;
      legendBottom += requiredVerticalBaseOffset;
    }

    var minOffsetSides = Utils.convertDpToPixel(minOffset);
    var minOffsetTopBottom = minOffsetSides;

    if (this is RadarChart) {
      final x = xAxis;
      if (x.isEnabled && x.isDrawLabelsEnabled) {
        minOffsetSides = math.max(minOffsetSides, requiredBaseOffset);
        minOffsetTopBottom = math.max(
          minOffsetTopBottom,
          requiredVerticalBaseOffset,
        );
      }
    }

    legendTop += Utils.convertDpToPixel(extraTopOffset);
    legendRight += Utils.convertDpToPixel(extraRightOffset);
    legendBottom += Utils.convertDpToPixel(extraBottomOffset);
    legendLeft += Utils.convertDpToPixel(extraLeftOffset);

    final offsetLeft = math.max(minOffsetSides, legendLeft);
    final offsetTop = math.max(minOffsetTopBottom, legendTop);
    final offsetRight = math.max(minOffsetSides, legendRight);
    final offsetBottom = math.max(
      minOffsetTopBottom,
      math.max(requiredVerticalBaseOffset, legendBottom),
    );

    viewPortHandler.restrainViewPort(
      offsetLeft,
      offsetTop,
      offsetRight,
      offsetBottom,
    );

    if (isLogEnabled) {
      debugPrint(
        '${Chart.LOG_TAG}: offsetLeft: $offsetLeft, offsetTop: $offsetTop, offsetRight: $offsetRight, '
        'offsetBottom: $offsetBottom',
      );
    }
  }

  /// Angle in degrees of the pixel position ([x], [y]) around the content center: 0 at 3 o'clock, 90 at 6 o'clock,
  /// 180 at 9 o'clock, 270 at 12 o'clock; from 0 (inclusive) to 360 (exclusive) for a finite position. The center
  /// itself yields 90.
  double getAngleForPoint(double x, double y) {
    final c = centerOffsets;

    final tx = x - c.x;
    final ty = y - c.y;
    final length = math.sqrt(tx * tx + ty * ty);
    if (length == 0.0) {
      MPPointF.recycleInstance(c);
      return 90;
    }
    final r = math.acos(ty / length);

    var angle = r * (180 / math.pi);

    if (x > c.x) angle = 360 - angle;

    angle += 90;

    if (angle >= 360) angle -= 360;

    MPPointF.recycleInstance(c);

    return angle;
  }

  /// Pixel position at the distance [dist] in pixels and the angle [angle] in degrees (0 at 3 o'clock, increasing
  /// clockwise) from the point [center] in pixels.
  ///
  /// Writes the position into [outputPoint] and returns it, or returns a new point when [outputPoint] is null.
  /// Kotlin's `getPosition(center, dist, angle)` and `getPosition(center, dist, angle, outputPoint)` overloads.
  MPPointF getPosition(
    MPPointF center,
    double dist,
    double angle, [
    MPPointF? outputPoint,
  ]) {
    final p = outputPoint ?? MPPointF(0, 0);
    p.x = center.x + dist * math.cos(angle * Utils.DEG2RAD);
    p.y = center.y + dist * math.sin(angle * Utils.DEG2RAD);
    return p;
  }

  /// Distance in pixels between the pixel position ([x], [y]) and the content center.
  double distanceToCenter(double x, double y) {
    final c = centerOffsets;

    final xDist = x > c.x ? x - c.x : c.x - x;
    final yDist = y > c.y ? y - c.y : c.y - y;

    final dist = math.sqrt(math.pow(xDist, 2) + math.pow(yDist, 2));

    MPPointF.recycleInstance(c);

    return dist;
  }

  /// Index of the entry lying under [angle] around the center, taking [rotationAngle] into account.
  ///
  /// [angle] is in degrees, 0 at 3 o'clock, increasing clockwise, as [getAngleForPoint] returns it. Returns the entry
  /// index, or -1 when no entry lies under that angle.
  int getIndexForAngle(double angle);

  final MutableRect _diameterRect = MutableRect();

  /// Largest circle diameter in pixels that fits the content area after the extra offsets.
  ///
  /// The extra offsets are subtracted from the current content rectangle, which [calculateOffsets] has already
  /// shrunk by them, as in Kotlin.
  double get diameter {
    final content = _diameterRect;
    content.setFrom(viewPortHandler.contentRect);
    content.left += Utils.convertDpToPixel(extraLeftOffset);
    content.top += Utils.convertDpToPixel(extraTopOffset);
    content.right -= Utils.convertDpToPixel(extraRightOffset);
    content.bottom -= Utils.convertDpToPixel(extraBottomOffset);
    return math.min(content.width(), content.height());
  }

  /// Radius of the drawn chart in pixels.
  double get radius;

  /// Space in pixels the legend needs between itself and the chart.
  @protected
  double get requiredLegendOffset;

  /// Space in pixels the chart needs left and right of itself before the legend is considered.
  @protected
  double get requiredBaseOffset;

  /// Space in pixels the chart needs above and below itself before the legend is considered. The same as
  /// [requiredBaseOffset] unless a chart needs less room there, as a radar chart does: its labels reach as far
  /// sideways as they are wide, but only as far up and down as they are tall.
  @protected
  double get requiredVerticalBaseOffset => requiredBaseOffset;

  /// Always 0: a round chart has no y axis.
  @override
  double get yChartMax => 0;

  /// Always 0: a round chart has no y axis.
  @override
  double get yChartMin => 0;

  /// Animates [rotationAngle] from one angle to another and redraws on every step. A running spin is cancelled
  /// first.
  ///
  /// [durationMillis] is the animation duration in milliseconds; 0 or less ends the spin at once, as does a chart
  /// without a host vsync. [fromAngle] is the start angle in degrees, applied at once. [toAngle] is the end angle in
  /// degrees; values outside 0 until 360 keep spinning through full turns. [easing] is the easing of the animation,
  /// [Easing.Linear] by default. [onEnd], when not null, is called once when the spin ends: when it finishes, when
  /// [stopAnimations] or leaving the window ends it at [toAngle], and when a new spin cancels it.
  void spin(
    int durationMillis,
    double fromAngle,
    double toAngle, {
    EasingFunction easing = Easing.Linear,
    void Function()? onEnd,
  }) {
    rotationAngle = fromAngle;
    animator.start(
      key: ChartAnimator.SPIN,
      from: fromAngle,
      to: toAngle,
      durationMillis: durationMillis,
      easing: easing,
      onUpdate: (value) => rotationAngle = value,
      onEnd: (_) => onEnd?.call(),
    );
  }
}
