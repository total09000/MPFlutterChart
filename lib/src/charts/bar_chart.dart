// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/BarChart.kt
//
// Overloads: getBarBounds(e) and getBarBounds(e, outputRect) are one getBarBounds with an optional output rectangle
// that it writes to and returns. Log.e is debugPrint, as in Chart.
import 'package:flutter/foundation.dart' show debugPrint;

import '../components/y_axis_dependency.dart';
import '../data/bar_data.dart';
import '../data/bar_entry.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/bar_highlighter.dart';
import '../highlight/highlight.dart';
import '../interfaces/dataprovider/bar_data_provider.dart';
import '../renderer/bar_chart_renderer.dart';
import '../utils/utils.dart';
import 'bar_line_chart_base.dart';
import 'chart.dart';

/// Chart that draws [BarData] as vertical bars, plain, grouped or stacked. It implements
/// [BarDataProvider] for the bar renderer and highlighter. See `HorizontalBarChart` for horizontal bars.
class BarChart extends BarLineChartBase<BarData> implements BarDataProvider {
  /// Whether a tap highlights the whole stacked bar instead of the single tapped stack value. Default false.
  @override
  bool isHighlightFullBarEnabled = false;

  /// Whether value labels sit above the bar top instead of below it. Default true.
  @override
  bool isDrawValueAboveBarEnabled = true;

  /// Whether a grey area up to the axis maximum is drawn behind each bar. Costs performance. Default false.
  @override
  bool isDrawBarShadowEnabled = false;

  /// Whether the x axis range is widened by half a bar width on each side so the outer bars are
  /// fully visible. Takes effect on the next [notifyDataSetChanged].
  bool isFitBarsEnabled = false;

  @override
  void init() {
    super.init();

    renderer = BarChartRenderer(this, animator, viewPortHandler);

    highlighter = BarHighlighter(this);

    xAxis.spaceMin = 0.5;
    xAxis.spaceMax = 0.5;
  }

  @override
  void calcMinMax() {
    final data = this.data;
    if (data == null) return;

    if (isFitBarsEnabled) {
      xAxis.calculate(
        data.xMin - data.barWidth / 2,
        data.xMax + data.barWidth / 2,
      );
    } else {
      xAxis.calculate(data.xMin, data.xMax);
    }

    axisLeft.calculate(
      data.getYMin(AxisDependency.LEFT),
      data.getYMax(AxisDependency.LEFT),
    );
    axisRight.calculate(
      data.getYMin(AxisDependency.RIGHT),
      data.getYMax(AxisDependency.RIGHT),
    );
  }

  /// Like [Chart.getHighlightByTouchPoint], but while [isHighlightFullBarEnabled] is on the highlight of a stacked
  /// bar has a stack index of -1, so it selects the whole bar.
  @override
  Highlight? getHighlightByTouchPoint(double x, double y) {
    if (data == null) {
      debugPrint("${Chart.LOG_TAG}: Can't select by touch. No data set.");
      return null;
    }

    final h = highlighter.getHighlight(x, y);
    if (h == null || !isHighlightFullBarEnabled) return h;

    return Highlight.stackedWithPixels(
      h.x,
      h.y,
      h.xPx,
      h.yPx,
      h.dataSetIndex,
      -1,
      h.axis,
    );
  }

  /// Bounding box in pixels of the bar drawn for [e]. It is written into [outputRect] when one is given, which
  /// avoids the allocation in hot code, and returned.
  ///
  /// Returns the bounds, or a rectangle with `Float.MIN_VALUE` ([Utils.FLOAT_EPSILON]) on all sides when the
  /// entry is not in the data.
  MutableRect getBarBounds(BarEntry e, [MutableRect? outputRect]) {
    final bounds = outputRect ?? MutableRect();

    final data = this.data;
    final set = data?.getDataSetForEntry(e);

    if (data == null || set == null) {
      bounds.set(
        Utils.FLOAT_EPSILON,
        Utils.FLOAT_EPSILON,
        Utils.FLOAT_EPSILON,
        Utils.FLOAT_EPSILON,
      );
      return bounds;
    }

    final y = e.y;
    final x = e.x;

    final barWidth = data.barWidth;

    final left = x - barWidth / 2;
    final right = x + barWidth / 2;
    final top = y >= 0 ? y : 0.0;
    final bottom = y <= 0 ? y : 0.0;

    bounds.set(left, top, right, bottom);

    getTransformer(set.axisDependency).rectValueToPixel(bounds);
    return bounds;
  }

  @override
  BarData? get barData => data;

  /// Places the bars of all data sets side by side in groups, one group per x position, then refreshes
  /// the chart. Delegates to [BarData.groupBars], which also changes the bar width and entry x values.
  ///
  /// [fromX] is the x value where the first group starts, [groupSpace] the space between two groups and
  /// [barSpace] the space between two bars inside a group, both in x units.
  ///
  /// Throws a [StateError] when no data has been set.
  void groupBars(double fromX, double groupSpace, double barSpace) {
    final barData = this.barData;
    if (barData == null) {
      throw StateError(
        'You need to set data for the chart before grouping bars.',
      );
    }
    barData.groupBars(fromX, groupSpace, barSpace);
    notifyDataSetChanged();
  }
}
