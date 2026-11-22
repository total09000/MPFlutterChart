// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/dataprovider/BarLineScatterCandleBubbleDataProvider.kt
import '../../components/y_axis_dependency.dart';
import '../../data/bar_line_scatter_candle_bubble_data.dart';
import '../../utils/transformer.dart';
import 'chart_interface.dart';

/// What charts with an x axis and two y axes expose to their renderers and highlighters.
/// Implemented by `BarLineChartBase`.
abstract class BarLineScatterCandleBubbleDataProvider extends ChartInterface {
  /// Returns the transformer that maps values of [axis] to pixels and back.
  Transformer getTransformer(AxisDependency axis);

  /// True if [axis] is drawn with larger values further down.
  bool isInverted(AxisDependency axis);

  /// Smallest x value currently visible in the content rectangle, at least the axis minimum.
  double get lowestVisibleX;

  /// Largest x value currently visible in the content rectangle, at most the axis maximum.
  double get highestVisibleX;

  /// True while the renderers may drop entries that share a pixel column with another entry. The entries they
  /// keep are the first, the lowest, the highest and the last of each column, so peaks survive. It also governs
  /// the circles of a line chart, of which only those no other circle would cover are drawn.
  ///
  /// Off unless a chart turns it on, so nothing is dropped from a drawing by default.
  bool get isDecimationEnabled => false;

  @override
  BarLineScatterCandleBubbleData? get data;
}
