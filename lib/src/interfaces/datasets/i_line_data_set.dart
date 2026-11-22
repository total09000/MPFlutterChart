// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/ILineDataSet.kt
import 'dart:ui';

import '../../data/entry.dart';
import '../../data/line_data_set.dart';
import '../../formatter/i_fill_formatter.dart';
import '../../graphics/chart_paint.dart';
import 'i_line_radar_data_set.dart';

/// What the line chart renderer reads from a data set: line mode, circles at the entries, dashing and fill.
/// Implemented by [LineDataSet].
///
/// [D] is the type of the payload attached to each entry.
abstract class ILineDataSet<D> extends ILineRadarDataSet<Entry<D>> {
  /// How the entries are connected: straight, stepped, cubic or horizontal cubic. Default [LineDataSetMode.LINEAR].
  LineDataSetMode get mode;

  /// Curvature of cubic lines from 0.05 (nearly straight) to 1 (very round). Default 0.2.
  double get cubicIntensity;

  /// Radius of the circles drawn at the entries in dp. Default 4 dp.
  double get circleRadius;

  /// Radius of the hole inside each circle in dp. Default 2 dp.
  double get circleHoleRadius;

  /// Returns the circle color for entry [index], wrapping around the circle colors with modulo.
  Color getCircleColor(int index);

  /// Number of circle colors set.
  int get circleColorCount;

  /// True to draw a circle at every entry. Default true.
  bool get isDrawCirclesEnabled;

  /// Color of the hole inside the circles. Default white; `ColorTemplate.COLOR_NONE` leaves the hole transparent.
  Color get circleHoleColor;

  /// True to draw the hole inside the circles. Default true.
  bool get isDrawCircleHoleEnabled;

  /// Dash effect of the line, null for a solid line.
  DashPathEffect? get dashPathEffect;

  /// True if [dashPathEffect] is set, so the line is drawn dashed.
  bool get isDashedLineEnabled;

  /// True to draw a ring around the highlighted entry. Default false.
  bool get isDrawHighlightCircleEnabled;

  /// Radius of the highlight ring in dp. Default 5. The ring uses the line color, the halo behind it the highlight
  /// color.
  double get highlightCircleRadius;

  /// Decides the y value to which the filled area extends. Default fills to 0 when the values cross zero, otherwise
  /// to the nearer axis end.
  IFillFormatter get fillFormatter;
}
