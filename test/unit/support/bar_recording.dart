// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/RecordingCanvas.kt
//
// Only the `barColorsByX` extension, as a function over the lane D `RecordingCanvas`, which must not
// be changed. Kotlin's canvas records only the four-float `drawRect`, so bar shadows and the grid background, drawn
// from a `RectF`, never reach its `rects`; this canvas records every `drawRect`. Tests that read bar colors keep bar
// shadows, the grid background, the borders and the legend off, so only the bars are left in `rects`.
import 'dart:ui' as ui;

import 'package:mp_flutter_chart/src/charts/bar_line_chart_base.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_d.dart';

import '../../recording/recording_canvas.dart';

/// The colors of each bar [chart] drew into [canvas], bottom section first, keyed by the x value of the bar.
/// Rectangles without width are the room a short stack leaves unused and are left out.
///
/// The x value is that of the horizontal center of each rectangle on the left axis, rounded to an integer. The
/// colors of a bar are in the order it drew its sections, which is bottom first for a stack of positive values.
Map<int, List<ui.Color>> barColorsByX(
  RecordingCanvas canvas,
  BarLineChartBase chart,
) {
  final transformer = chart.getTransformer(AxisDependency.LEFT);
  final point = MPPointD.getInstance(0.0, 0.0);
  final byBar = <int, List<ui.Color>>{};

  for (final draw in canvas.rects) {
    final rect = draw.rect;
    if (rect.left == rect.right) continue;

    transformer.getValuesByTouchPoint((rect.left + rect.right) / 2, 0, point);
    byBar.putIfAbsent(point.x.round(), () => []).add(draw.color);
  }

  MPPointD.recycleInstance(point);
  return byBar;
}
