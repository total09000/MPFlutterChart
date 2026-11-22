// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/dataprovider/ChartInterface.kt
import '../../data/chart_data.dart';
import '../../formatter/i_value_formatter.dart';
import '../../graphics/mutable_rect.dart';
import '../../utils/mp_point_f.dart';

/// What every chart exposes to its renderers, highlighters and markers: value ranges, layout in pixels
/// and the data. Implemented by `Chart`.
abstract class ChartInterface {
  /// Smallest x value of the x axis, independent of zoom and drag.
  double get xChartMin;

  /// Largest x value of the x axis, independent of zoom and drag.
  double get xChartMax;

  /// Difference between [xChartMax] and [xChartMin].
  double get xRange;

  /// Smallest y value across all y axes, independent of zoom and drag.
  double get yChartMin;

  /// Largest y value across all y axes, independent of zoom and drag.
  double get yChartMax;

  /// Maximum distance in dp between a touch and an entry for the entry to be highlighted.
  double get maxHighlightDistance;

  /// Center of the whole chart view in pixels, as a fresh [MPPointF].
  MPPointF get centerOfView;

  /// Center of the content rectangle in pixels, as a fresh [MPPointF].
  MPPointF get centerOffsets;

  /// Rectangle in pixels in which the data is drawn, the view minus axis, legend and extra offsets.
  MutableRect get contentRect;

  /// Formatter the chart computed from its data, used by data sets that have no formatter of their own.
  IValueFormatter get defaultValueFormatter;

  /// The data shown in the chart, null before data is set.
  ChartData? get data;

  /// Number of entries one data set may have inside the visible x range for its values and icons to be drawn.
  /// A set with more entries in view draws none, because the labels would sit too close together to read.
  int get maxVisibleCount;
}
