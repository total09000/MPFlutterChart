// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/RadarData.kt
//
// Kotlin's `highlight.x.toInt()` is `kotlinFloatToInt`, which gives 0 for NaN like Kotlin instead of throwing.
import '../highlight/highlight.dart';
import '../interfaces/datasets/i_radar_data_set.dart';
import '../utils/float_math.dart';
import 'chart_data.dart';
import 'entry.dart';

/// Data for a radar chart: one or more [IRadarDataSet]s, one polygon each.
class RadarData extends ChartData<IRadarDataSet> {
  /// Creates a data object holding [dataSets] (kept by reference), or an empty one (Kotlin's `()`,
  /// `(vararg dataSets)` and `(dataSets: List)` constructors).
  RadarData([super.dataSets]);

  /// Returns the entry a highlight refers to. For radar charts [Highlight.x] holds the entry index (truncated
  /// towards zero), not an x value.
  ///
  /// Returns the entry, or null when [Highlight.dataSetIndex] or the entry index is out of range.
  @override
  Entry? getEntryForHighlight(Highlight highlight) {
    final set = getDataSetByIndex(highlight.dataSetIndex);
    if (set == null) return null;
    final index = kotlinFloatToInt(highlight.x);
    return (index >= 0 && index < set.entryCount)
        ? set.getEntryForIndex(index)
        : null;
  }
}
