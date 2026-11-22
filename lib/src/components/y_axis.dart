// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/YAxis.kt
import 'dart:math' as math;
import 'dart:ui';

import '../graphics/chart_paint.dart';
import '../utils/f_size.dart';
import '../utils/float_math.dart';
import '../utils/utils.dart';
import 'axis_base.dart';
import 'y_axis_dependency.dart';

export 'y_axis_dependency.dart';

/// Placement of the y-axis labels: OUTSIDE_CHART next to the content area, INSIDE_CHART over it.
///
/// Kotlin's `YAxis.YAxisLabelPosition`; a top-level enum because Dart has no nested types.
enum YAxisLabelPosition { OUTSIDE_CHART, INSIDE_CHART }

/// A vertical axis of bar, line, scatter, candle and bubble charts, and the value axis of a radar chart. Charts have a
/// left and a right one; each data set picks its side with [AxisDependency]. Settings that change the value range must
/// be applied before data is set.
class YAxis extends AxisBase {
  /// The side of the chart this axis belongs to.
  final AxisDependency axisDependency;

  /// Creates the y-axis for [axisDependency], the left one by default.
  YAxis([this.axisDependency = AxisDependency.LEFT]) {
    yOffset = 0;
  }

  /// Whether the label at the bottom end of the axis is drawn. Default true.
  bool isDrawBottomYLabelEntryEnabled = true;

  /// Whether the label at the top end of the axis is drawn. Disable it when it collides with an x-axis label. Default
  /// true.
  bool isDrawTopYLabelEntryEnabled = true;

  /// Whether small values are at the top and large values at the bottom. Default false.
  bool isInverted = false;

  /// Whether a line is drawn at value 0 even when grid lines are disabled. Default false.
  bool isDrawZeroLineEnabled = false;

  /// Color of the zero line. Default gray.
  Color zeroLineColor = const Color(0xFF888888);

  /// Width of the zero line in dp. Default 0.5.
  double zeroLineWidth = 0.5;

  /// Space above the largest value as a percentage of the data range. Ignored when [axisMaximum] is fixed. Default 10.
  double spaceTop = 10;

  /// Space below the smallest value as a percentage of the data range. Ignored when [axisMinimum] is fixed. Default
  /// 10.
  double spaceBottom = 10;

  /// Whether the labels are drawn next to or inside the content area. Default [YAxisLabelPosition.OUTSIDE_CHART].
  YAxisLabelPosition labelPosition = YAxisLabelPosition.OUTSIDE_CHART;

  /// Horizontal shift in dp added to the label positions. Default 0.
  double labelXOffset = 0;

  /// Rotation of the labels in degrees, clockwise for positive values. The width reserved for the axis follows the
  /// rotated labels. Not used by horizontal bar and radar charts. Default 0.
  double labelRotationAngle = 0;

  /// Smallest width in dp the chart reserves for this axis. Default 0.
  double minWidth = 0;

  /// Largest width in dp the chart reserves for this axis. Default [double.infinity], no limit.
  double maxWidth = double.infinity;

  /// Width in px this axis needs in a vertical chart: the widest label, rotated by [labelRotationAngle], plus
  /// [xOffset] on both sides, clamped to [minWidth]..[maxWidth].
  ///
  /// [p] is the paint used to measure the labels; its text size is set to [textSize].
  double getRequiredWidthSpace(ChartPaint p) {
    p.textSize = Utils.convertDpToPixel(textSize);

    final label = longestLabel;
    var width = Utils.calcTextWidth(p, label);
    if (labelRotationAngle != 0) {
      final rotated = Utils.getSizeOfRotatedRectangleByDegrees(
        width,
        Utils.getLineHeight(p),
        labelRotationAngle,
      );
      width = rotated.width;
      FSize.recycleInstance(rotated);
    }
    width += Utils.convertDpToPixel(xOffset) * 2;

    var minWidth = this.minWidth;
    var maxWidth = this.maxWidth;

    if (minWidth > 0) minWidth = Utils.convertDpToPixel(minWidth);
    if (maxWidth > 0 && maxWidth != double.infinity) {
      maxWidth = Utils.convertDpToPixel(maxWidth);
    }

    width = math.max(
      minWidth,
      math.min(width, maxWidth > 0.0 ? maxWidth : width),
    );
    return width;
  }

  /// Height in px this axis needs in a horizontal bar chart: the label height plus [yOffset] on both sides.
  ///
  /// [p] is the paint used to measure the labels; its text size is set to [textSize].
  double getRequiredHeightSpace(ChartPaint p) {
    p.textSize = Utils.convertDpToPixel(textSize);
    final label = longestLabel;
    return Utils.calcTextHeight(p, label) + Utils.convertDpToPixel(yOffset) * 2;
  }

  /// Whether the chart must reserve space next to the content area: enabled, drawing labels, and labels outside.
  bool get needsOffset =>
      isEnabled &&
      isDrawLabelsEnabled &&
      labelPosition == YAxisLabelPosition.OUTSIDE_CHART;

  /// Computes the axis range from the data range. Fixed limits are kept, computed ones get [spaceBottom] and
  /// [spaceTop] percent of the range added, an empty range is widened around the value, and when the data lies
  /// entirely beyond one fixed limit the other end is derived from that limit.
  ///
  /// Like Kotlin's `calculate(dataMin: Float, dataMax: Float)`, [dataMin] and [dataMax] are rounded to Float on
  /// entry, so a data range below the Float resolution is empty and padded as on Android.
  @override
  void calculate(double dataMin, double dataMax) {
    var min = toKotlinFloat(dataMin);
    var max = toKotlinFloat(dataMax);

    if (min > max) {
      if (isAxisMaxCustom && isAxisMinCustom) {
        final t = min;
        min = max;
        max = t;
      } else if (isAxisMaxCustom) {
        min = kotlinFloatOverflow(max < 0 ? max * 1.5 : max * 0.5);
      } else if (isAxisMinCustom) {
        max = kotlinFloatOverflow(min < 0 ? min * 0.5 : min * 1.5);
      }
    }

    var range = kotlinFloatOverflow((max - min).abs());

    if (range == 0) {
      final padding = emptyRangePadding(max);
      max = kotlinFloatOverflow(max + padding);
      min = kotlinFloatOverflow(min - padding);
    }

    range = kotlinFloatOverflow((max - min).abs());

    final newMin = isAxisMinCustom
        ? axisMinimum
        : kotlinFloatOverflow(min - (range / 100) * spaceBottom);
    final newMax = isAxisMaxCustom
        ? axisMaximum
        : kotlinFloatOverflow(max + (range / 100) * spaceTop);

    applyAxisRange(newMin, newMax);
  }
}
