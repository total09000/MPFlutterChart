// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/ScatterData.kt
import 'dart:math' as math;

import '../interfaces/datasets/i_scatter_data_set.dart';
import 'bar_line_scatter_candle_bubble_data.dart';

/// Data for a scatter chart: one or more [IScatterDataSet]s.
class ScatterData extends BarLineScatterCandleBubbleData<IScatterDataSet> {
  /// Creates a data object holding [dataSets] (kept by reference), or an empty one (Kotlin's `()`,
  /// `(vararg dataSets)` and `(dataSets: List)` constructors).
  ScatterData([super.dataSets]);

  /// Largest [IScatterDataSet.scatterShapeSize] in dp over all sets, or 0 with no sets.
  double get greatestShapeSize {
    if (dataSets.isEmpty) return 0;
    // Kotlin maxOfOrNull, which is NaN once any size is NaN, like math.max.
    return dataSets
        .map((it) => it.scatterShapeSize)
        .reduce((a, b) => math.max(a, b));
  }
}
