// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/ILineScatterCandleRadarDataSet.kt
import '../../data/entry.dart';
import '../../graphics/chart_paint.dart';
import '../../highlight/highlight_line_span.dart';
import 'i_bar_line_scatter_candle_bubble_data_set.dart';

/// Styling of the highlight indicator lines shared by line, scatter, candle and radar data sets.
abstract class ILineScatterCandleRadarDataSet<T extends Entry>
    extends IBarLineScatterCandleBubbleDataSet<T> {
  /// True to draw a vertical line through a highlighted entry. Default true.
  bool get isVerticalHighlightIndicatorEnabled;

  /// True to draw a horizontal line through a highlighted entry. Default true.
  bool get isHorizontalHighlightIndicatorEnabled;

  /// How far the vertical highlight line reaches. Default [HighlightLineSpan.FULL].
  HighlightLineSpan get verticalHighlightIndicatorSpan;

  /// How far the horizontal highlight line reaches. Default [HighlightLineSpan.FULL].
  HighlightLineSpan get horizontalHighlightIndicatorSpan;

  /// Width of the highlight indicator lines in dp. Default 0.5 dp.
  double get highlightLineWidth;

  /// Dash effect of the highlight indicator lines, null for solid lines.
  DashPathEffect? get dashPathEffectHighlight;
}
