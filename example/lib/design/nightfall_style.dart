// Ported from MPChartExample: design/NightfallStyle.kt. Its extension functions are top-level functions here that take
// the receiver first: `chart.nightfallBase(theme)` is `nightfallBase(chart, theme)`.
import 'dart:ui' as ui;

import 'package:mp_flutter_chart/core.dart';

import 'nightfall.dart';

/// Applies the Nightfall look to any chart: no description, no legend, no axis lines, faint horizontal grid, muted
/// labels.
void nightfallBase(Chart chart, NightfallTheme theme) {
  chart.description.isEnabled = false;
  chart.legend.isEnabled = false;
  chart.noDataTextColor = theme.muted;
  if (chart is BarLineChartBase) {
    chart.isScaleEnabled = false;
    chart.isDragEnabled = false;
    chart.isDoubleTapToZoomEnabled = false;
    chart.setExtraOffsets(0, 8, 8, 4);
    chart.xAxis.position = XAxisPosition.BOTTOM;
    nightfallAxis(chart.xAxis, theme);
    chart.xAxis.isDrawGridLinesEnabled = false;
    chart.xAxis.yOffset = 8;
    nightfallAxis(chart.axisLeft, theme);
    chart.axisLeft.isDrawGridLinesEnabled = true;
    chart.axisLeft.gridColor = theme.grid;
    chart.axisLeft.gridLineWidth = 1;
    chart.axisLeft.xOffset = 10;
    chart.axisRight.isEnabled = false;
  }
}

void nightfallAxis(AxisBase axis, NightfallTheme theme) {
  axis.isDrawAxisLineEnabled = false;
  axis.textColor = theme.muted;
  axis.textSize = 10;
}

/// Spreads the entries over the full plot width, so the line touches the left and right edge.
/// The first and last labels are pulled inside the chart so they are not cut off.
void nightfallFullWidthX(BarLineChartBase chart, int pointCount) {
  chart.xAxis.axisMinimum = 0;
  chart.xAxis.axisMaximum = (pointCount - 1).toDouble();
  chart.xAxis.granularity = 1;
  chart.xAxis.labelCount = pointCount;
  chart.xAxis.isAvoidFirstLastClippingEnabled = true;
  chart.setExtraOffsets(6, 8, 6, 4);
}

/// Leaves half a slot of space before the first and after the last entry, the way bar charts sit.
void nightfallPaddedX(BarLineChartBase chart, int pointCount) {
  chart.xAxis.axisMinimum = -0.5;
  chart.xAxis.axisMaximum = pointCount - 0.5;
  chart.xAxis.granularity = 1;
  chart.xAxis.labelCount = pointCount;
}

/// Smooth line with a fading area fill, a dashed guide and a ring on the highlighted entry.
void nightfallLine(
  LineDataSet set,
  NightfallTheme theme, [
  ui.Color lineColor = Nightfall.accent,
]) {
  set.mode = LineDataSetMode.CUBIC_BEZIER;
  set.cubicIntensity = 0.18;
  set.color = lineColor;
  set.lineWidth = 3;
  set.isDrawCirclesEnabled = false;
  set.isDrawValuesEnabled = false;
  set.isDrawFilledEnabled = true;
  set.fillDrawable = _topBottomGradient(
    Nightfall.withAlpha(lineColor, 115),
    Nightfall.withAlpha(lineColor, 0),
  );
  set.highlightColor = lineColor;
  set.highlightLineWidth = 1;
  set.enableDashedHighlightLine(8, 8, 0);
  set.isHorizontalHighlightIndicatorEnabled = false;
  set.isDrawHighlightCircleEnabled = true;
  set.circleHoleColor = theme.card;
}

/// Rounded bars with a vertical gradient per bar; [selected] gets the secondary color.
void nightfallBars(
  BarDataSet set, {
  ui.Color barColor = Nightfall.accent,
  int selected = -1,
  ui.Color selectedColor = Nightfall.violet,
}) {
  set.barCornerRadius = 7;
  set.isDrawValuesEnabled = false;
  set.highlightAlpha = 0;
  set.fills = List.generate(set.entries.length, (i) {
    final color = i == selected ? selectedColor : barColor;
    return Fill.ofColors(color, Nightfall.withAlpha(color, 90));
  });
}

/// Donut with rounded slice ends, no labels on the slices and a legend on the right.
void nightfallDonut(PieChart chart, NightfallTheme theme) {
  nightfallBase(chart, theme);
  chart.isDrawEntryLabelsEnabled = false;
  chart.holeRadius = 72;
  chart.transparentCircleRadius = 0;
  chart.holeColor = theme.card;
  chart.isDrawRoundedSlicesEnabled = true;
  chart.isRotationEnabled = false;
  chart.centerTextColor = theme.text;
  chart.centerTextSize = 11;
  chart.legend
    ..isEnabled = true
    ..verticalAlignment = LegendVerticalAlignment.CENTER
    ..horizontalAlignment = LegendHorizontalAlignment.RIGHT
    ..orientation = LegendOrientation.VERTICAL
    ..form = LegendForm.SQUARE
    ..formSize = 10
    ..textColor = theme.text
    ..textSize = 12
    ..yEntrySpace = 8
    ..xEntrySpace = 8;
  chart.setExtraOffsets(0, 0, 24, 0);
}

void nightfallSlices(PieDataSet set) {
  set.sliceSpace = 3;
  set.colors = Nightfall.palette.take(set.entryCount).toList();
  set.isDrawValuesEnabled = false;
}

/// `GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(top, bottom))`: a rectangle filled with a
/// linear gradient from [top] at the top edge of its bounds to [bottom] at the bottom edge. Like a GradientDrawable
/// without a size, it has no intrinsic size.
ChartDrawable _topBottomGradient(ui.Color top, ui.Color bottom) =>
    PainterDrawable(
      (canvas, size) {
        final rect = ui.Offset.zero & size;
        canvas.drawRect(
          rect,
          ui.Paint()
            ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomLeft, [
              top,
              bottom,
            ]),
        );
      },
      width: -1,
      height: -1,
    );
