// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/IScatterDataSet.kt
import 'dart:ui';

import '../../data/entry.dart';
import '../../data/scatter_data_set.dart';
import '../../renderer/scatter/i_shape_renderer.dart';
import 'i_line_scatter_candle_radar_data_set.dart';

/// What the scatter chart renderer reads from a data set: shape size, hole and the renderer that draws
/// the shape. Implemented by [ScatterDataSet].
///
/// [D] is the type of the payload attached to each entry.
abstract class IScatterDataSet<D>
    extends ILineScatterCandleRadarDataSet<Entry<D>> {
  /// Size of each shape in dp. Default 7.5.
  double get scatterShapeSize;

  /// Radius of the hole in the middle of each shape, in dp like [scatterShapeSize]. 0 draws no hole.
  double get scatterShapeHoleRadius;

  /// Color of the hole. `ColorTemplate.COLOR_NONE` leaves it transparent.
  Color get scatterShapeHoleColor;

  /// Draws the shape for each entry. Default the square renderer.
  IShapeRenderer get shapeRenderer;
}
