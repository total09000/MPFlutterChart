// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/LineScatterCandleRadarDataSet.kt
import 'package:flutter/foundation.dart' show protected;

import '../graphics/chart_paint.dart';
import '../highlight/highlight_line_span.dart';
import '../interfaces/datasets/i_line_scatter_candle_radar_data_set.dart';
import 'bar_line_scatter_candle_bubble_data_set.dart';
import 'entry.dart';

/// Base for the data sets whose highlight is drawn as crosshair lines (line, scatter, candle and radar).
/// Holds the settings for those highlight lines.
///
/// [T] is the entry type this set holds.
abstract class LineScatterCandleRadarDataSet<T extends Entry>
    extends BarLineScatterCandleBubbleDataSet<T>
    implements ILineScatterCandleRadarDataSet<T> {
  /// Creates a set holding [entries] named [label].
  LineScatterCandleRadarDataSet(super.entries, super.label);

  @override
  bool isVerticalHighlightIndicatorEnabled = true;

  @override
  bool isHorizontalHighlightIndicatorEnabled = true;

  @override
  HighlightLineSpan verticalHighlightIndicatorSpan = HighlightLineSpan.FULL;

  @override
  HighlightLineSpan horizontalHighlightIndicatorSpan = HighlightLineSpan.FULL;

  @override
  double highlightLineWidth = 0.5;

  DashPathEffect? _dashPathEffectHighlight;

  /// Dash pattern of the highlight lines, or null for solid lines. Set through [enableDashedHighlightLine].
  @override
  DashPathEffect? get dashPathEffectHighlight => _dashPathEffectHighlight;

  @protected
  set dashPathEffectHighlight(DashPathEffect? value) =>
      _dashPathEffectHighlight = value;

  /// Turns both the vertical and the horizontal highlight line on or off at once.
  void setDrawHighlightIndicators(bool enabled) {
    isVerticalHighlightIndicatorEnabled = enabled;
    isHorizontalHighlightIndicatorEnabled = enabled;
  }

  /// Draws the highlight lines dashed, like "- - - -".
  ///
  /// [lineLength] is the length of each dash, [spaceLength] the length of the gap between dashes and [phase] the
  /// offset into the pattern, normally 0, all in device px (as on Android: the canvas divides them by
  /// `Utils.devicePixelRatio`).
  void enableDashedHighlightLine(
    double lineLength,
    double spaceLength,
    double phase,
  ) {
    dashPathEffectHighlight = DashPathEffect([lineLength, spaceLength], phase);
  }

  /// Draws the highlight lines solid again.
  void disableDashedHighlightLine() {
    dashPathEffectHighlight = null;
  }

  /// True while a dash pattern is set for the highlight lines. Default false.
  bool get isDashedHighlightLineEnabled => dashPathEffectHighlight != null;

  /// Copies the styling from this set into [dataSet]; entries are not copied here.
  @override
  @protected
  void copyTo(covariant LineScatterCandleRadarDataSet dataSet) {
    super.copyTo(dataSet);
    dataSet.isHorizontalHighlightIndicatorEnabled =
        isHorizontalHighlightIndicatorEnabled;
    dataSet.isVerticalHighlightIndicatorEnabled =
        isVerticalHighlightIndicatorEnabled;
    dataSet.verticalHighlightIndicatorSpan = verticalHighlightIndicatorSpan;
    dataSet.horizontalHighlightIndicatorSpan = horizontalHighlightIndicatorSpan;
    dataSet.highlightLineWidth = highlightLineWidth;
    dataSet.dashPathEffectHighlight = dashPathEffectHighlight;
  }
}
