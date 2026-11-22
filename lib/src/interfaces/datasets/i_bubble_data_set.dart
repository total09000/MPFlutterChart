// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/IBubbleDataSet.kt
import '../../data/bubble_data_set.dart';
import '../../data/bubble_entry.dart';
import 'i_bar_line_scatter_candle_bubble_data_set.dart';

/// What the bubble chart renderer reads from a data set: bubble sizing and the highlight ring.
/// Implemented by [BubbleDataSet].
///
/// [D] is the type of the payload attached to each entry.
abstract class IBubbleDataSet<D>
    extends IBarLineScatterCandleBubbleDataSet<BubbleEntry<D>> {
  /// Stroke width in dp of the ring drawn around a highlighted bubble. Default 1 dp.
  double get highlightCircleWidth;

  set highlightCircleWidth(double value);

  /// Largest entry size in this data set, the reference for normalised bubble sizes.
  double get maxSize;

  /// True to scale bubbles relative to [maxSize] so the largest fills the reference size; false uses the entry
  /// size as a direct factor. Default true.
  bool get isNormalizeSizeEnabled;
}
