// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/ScatterDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../charts/scatter_shape.dart';
import '../interfaces/datasets/i_scatter_data_set.dart';
import '../renderer/scatter/chevron_down_shape_renderer.dart';
import '../renderer/scatter/chevron_up_shape_renderer.dart';
import '../renderer/scatter/circle_shape_renderer.dart';
import '../renderer/scatter/cross_shape_renderer.dart';
import '../renderer/scatter/i_shape_renderer.dart';
import '../renderer/scatter/square_shape_renderer.dart';
import '../renderer/scatter/triangle_shape_renderer.dart';
import '../renderer/scatter/x_shape_renderer.dart';
import '../utils/color_template.dart';
import 'data_set.dart';
import 'entry.dart';
import 'line_scatter_candle_radar_data_set.dart';

/// One series of points in a scatter chart, all drawn with the same shape.
///
/// [D] is the payload type of the entries.
class ScatterDataSet<D> extends LineScatterCandleRadarDataSet<Entry<D>>
    implements IScatterDataSet<D> {
  /// Creates a set from [entries], the points sorted by x (kept by reference, see `DataSet.entries`), named [label],
  /// shown in the legend.
  ScatterDataSet(super.entries, super.label);

  @override
  double scatterShapeSize = 7.5;

  /// Draws the shape at each point. Default a square; use [setScatterShape] for the built-in shapes.
  @override
  IShapeRenderer shapeRenderer = SquareShapeRenderer();

  @override
  double scatterShapeHoleRadius = 0;

  /// Color of the hole inside each shape. [ColorTemplate.COLOR_NONE], the default, leaves the hole transparent.
  @override
  Color scatterShapeHoleColor = ColorTemplate.COLOR_NONE;

  @override
  DataSet<Entry<D>> copy() {
    final copiedEntries = [for (final it in entries) it.copy()];
    final copied = ScatterDataSet<D>(copiedEntries, label);
    copyTo(copied);
    return copied;
  }

  /// Copies the styling from this set into [scatterDataSet]; entries are not copied, the renderer is shared.
  @override
  @protected
  void copyTo(covariant ScatterDataSet<D> scatterDataSet) {
    super.copyTo(scatterDataSet);
    scatterDataSet.scatterShapeSize = scatterShapeSize;
    scatterDataSet.shapeRenderer = shapeRenderer;
    scatterDataSet.scatterShapeHoleRadius = scatterShapeHoleRadius;
    scatterDataSet.scatterShapeHoleColor = scatterShapeHoleColor;
  }

  /// Replaces [shapeRenderer] with the built-in renderer for [shape].
  void setScatterShape(ScatterShape shape) {
    shapeRenderer = getRendererForShape(shape);
  }

  /// Returns a new built-in renderer that draws [shape].
  ///
  /// Kotlin's `ScatterDataSet.Companion.getRendererForShape`.
  static IShapeRenderer getRendererForShape(ScatterShape shape) {
    return switch (shape) {
      ScatterShape.SQUARE => SquareShapeRenderer(),
      ScatterShape.CIRCLE => CircleShapeRenderer(),
      ScatterShape.TRIANGLE => TriangleShapeRenderer(),
      ScatterShape.CROSS => CrossShapeRenderer(),
      ScatterShape.X => XShapeRenderer(),
      ScatterShape.CHEVRON_UP => ChevronUpShapeRenderer(),
      ScatterShape.CHEVRON_DOWN => ChevronDownShapeRenderer(),
    };
  }
}
