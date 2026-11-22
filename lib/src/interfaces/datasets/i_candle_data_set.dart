// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/ICandleDataSet.kt
import 'dart:ui';

import '../../data/candle_data_set.dart';
import '../../data/candle_entry.dart';
import '../../graphics/chart_paint.dart';
import 'i_line_scatter_candle_radar_data_set.dart';

/// What the candle stick renderer reads from a data set: candle body width, colors per direction and the
/// shadow line. Implemented by [CandleDataSet].
///
/// Every color may be `ColorTemplate.COLOR_NONE` to fall back to the data set color of the entry. That is the
/// default for all of them.
///
/// [D] is the type of the payload attached to each entry.
abstract class ICandleDataSet<D>
    extends ILineScatterCandleRadarDataSet<CandleEntry<D>> {
  /// Space left free on each side of a candle body, as a fraction of the x step from 0 to 0.45. Default 0.1.
  double get barSpace;

  /// True to draw candle bodies; false draws only the open and close ticks on the shadow line. Default true.
  bool get showCandleBar;

  /// Stroke width of the shadow line between high and low in dp. Default 1.5 dp.
  double get shadowWidth;

  /// Color of the shadow line, unless [shadowColorSameAsCandle] is true.
  Color get shadowColor;

  /// Body color when open equals close.
  Color get neutralColor;

  /// Body color when close is above open.
  Color get increasingColor;

  /// Body color when close is below open.
  Color get decreasingColor;

  /// Whether increasing bodies are filled or outlined. Default [PaintStyle.STROKE].
  PaintStyle get increasingPaintStyle;

  /// Whether decreasing bodies are filled or outlined. Default [PaintStyle.FILL].
  PaintStyle get decreasingPaintStyle;

  /// True to draw the shadow line in the body color of its candle instead of [shadowColor]. Default false.
  bool get shadowColorSameAsCandle;
}
