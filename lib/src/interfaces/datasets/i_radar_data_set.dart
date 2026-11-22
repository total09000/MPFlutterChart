// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/IRadarDataSet.kt
import 'dart:ui';

import '../../data/radar_data_set.dart';
import '../../data/radar_entry.dart';
import 'i_line_radar_data_set.dart';

/// What the radar chart renderer reads from a data set: the corner rounding of the polygon and the ring
/// drawn around a highlighted entry. Implemented by [RadarDataSet].
///
/// [D] is the type of the payload attached to each entry.
abstract class IRadarDataSet<D> extends ILineRadarDataSet<RadarEntry<D>> {
  /// Radius in dp the corners of the polygon are rounded with. 0, the default, draws sharp corners.
  double get cornerRadius;

  /// True to draw a ring around a highlighted entry. Default false.
  bool get isDrawHighlightCircleEnabled;

  set isDrawHighlightCircleEnabled(bool value);

  /// Fill color of the ring. Default white; `ColorTemplate.COLOR_NONE` draws no fill.
  Color get highlightCircleFillColor;

  /// Stroke color of the ring. Default `ColorTemplate.COLOR_NONE`, which uses the data set color.
  Color get highlightCircleStrokeColor;

  /// Opacity of the ring stroke from 0 to 255. Default 76.
  int get highlightCircleStrokeAlpha;

  /// Inner radius of the ring in dp. Default 3 dp.
  double get highlightCircleInnerRadius;

  /// Outer radius of the ring in dp. Default 4 dp.
  double get highlightCircleOuterRadius;

  /// Stroke width of the ring in dp. Default 2 dp.
  double get highlightCircleStrokeWidth;
}
