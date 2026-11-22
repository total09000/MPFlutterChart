// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/IBarDataSet.kt
import 'dart:ui';

import '../../data/bar_data_set.dart';
import '../../data/bar_entry.dart';
import '../../utils/fill.dart';
import 'i_bar_line_scatter_candle_bubble_data_set.dart';

/// What the bar chart renderer reads from a data set: fills, borders, shadows and stack information.
/// Implemented by [BarDataSet].
///
/// [D] is the type of the payload attached to each entry.
abstract class IBarDataSet<D>
    extends IBarLineScatterCandleBubbleDataSet<BarEntry<D>> {
  /// Fills used instead of plain colors, cycled per bar; null or empty to draw with [colors].
  List<Fill>? get fills;

  /// Returns the fill for bar [index], wrapping around [fills], or an empty fill that draws nothing when there are
  /// none.
  Fill getFill(int index);

  /// True if the entries hold stacked values, that is [stackSize] is greater than 1.
  bool get isStacked;

  /// Largest number of stacked values in one entry; 1 for plain bars.
  int get stackSize;

  /// Color of the shadow bar drawn behind each bar when the chart enables bar shadows.
  Color get barShadowColor;

  /// Width of the border around each bar in dp. 0 draws no border.
  double get barBorderWidth;

  /// Color of the border around each bar.
  Color get barBorderColor;

  /// Opacity of the highlight drawn over a selected bar, from 0 to 255. Default 120.
  int get highlightAlpha;

  /// Legend labels for the stack values, one per stack position. Only used for stacked bars.
  List<String> get stackLabels;

  /// Corner radius of the bars in dp. 0 draws sharp corners. Stacked bars round only the segment farthest from zero.
  double get barCornerRadius;

  /// True to give every section of a stacked bar its own rounded corners instead of rounding the bar as a whole.
  bool get isStackSectionsRounded;
}
