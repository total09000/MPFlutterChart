// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/IBarLineScatterCandleBubbleDataSet.kt
import 'dart:ui';

import '../../data/entry.dart';
import 'i_data_set.dart';

/// Styling shared by data sets of charts with an x axis and y axes: bar, line, scatter, candle and bubble.
abstract class IBarLineScatterCandleBubbleDataSet<T extends Entry>
    extends IDataSet<T> {
  /// Color of the highlight indicator drawn at a selected entry. Default a light orange, rgb(255, 187, 115).
  Color get highlightColor;
}
