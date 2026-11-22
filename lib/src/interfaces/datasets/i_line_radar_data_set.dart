// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/ILineRadarDataSet.kt
import 'dart:ui';

import '../../data/entry.dart';
import '../../graphics/chart_drawable.dart';
import 'i_line_scatter_candle_radar_data_set.dart';

/// Styling of the line and the filled area below it, shared by line and radar data sets.
abstract class ILineRadarDataSet<T extends Entry>
    extends ILineScatterCandleRadarDataSet<T> {
  /// Color of the filled area, used when [fillDrawable] is null.
  Color get fillColor;

  /// Drawable painted into the filled area instead of [fillColor], null to use the color.
  ChartDrawable? get fillDrawable;

  /// Opacity of the filled area from 0 to 255. Default 85.
  int get fillAlpha;

  /// Stroke width of the line in dp. Default 1 dp.
  double get lineWidth;

  /// True to fill the area between the line and the axis. Default false. Filling clips the canvas to a path
  /// and costs more than drawing the line alone.
  bool get isDrawFilledEnabled;

  set isDrawFilledEnabled(bool value);
}
