// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/scatter/IShapeRenderer.kt
import 'dart:ui' as ui;

import '../../graphics/chart_paint.dart';
import '../../interfaces/datasets/i_scatter_data_set.dart';
import '../../utils/view_port_handler.dart';

/// Draws the shape of one scatter entry. Assign an implementation to `ScatterDataSet.shapeRenderer`, either one
/// of the built-in shapes or a function:
/// `IShapeRenderer.fromFunction((c, set, vph, x, y, paint) => c.drawCircleP(x, y, 4, paint))`.
///
/// Kotlin's `fun interface`; a lambda is wrapped with [IShapeRenderer.fromFunction].
abstract class IShapeRenderer {
  /// Lets subclasses be constant.
  const IShapeRenderer();

  /// Wraps [renderShape] in a shape renderer.
  const factory IShapeRenderer.fromFunction(
    void Function(
      ui.Canvas c,
      IScatterDataSet dataSet,
      ViewPortHandler viewPortHandler,
      double posX,
      double posY,
      ChartPaint renderPaint,
    )
    renderShape,
  ) = _FunctionShapeRenderer;

  /// Draws the shape centered at the pixel position ([posX], [posY]).
  ///
  /// [dataSet] supplies the shape size and the hole radius, both in dp, and the hole color; [viewPortHandler] gives
  /// the content bounds of the chart, in pixels; [renderPaint] is already set to the color of the entry, and its
  /// style and stroke width may be changed.
  void renderShape(
    ui.Canvas c,
    IScatterDataSet dataSet,
    ViewPortHandler viewPortHandler,
    double posX,
    double posY,
    ChartPaint renderPaint,
  );
}

class _FunctionShapeRenderer extends IShapeRenderer {
  const _FunctionShapeRenderer(this._renderShape);

  final void Function(
    ui.Canvas c,
    IScatterDataSet dataSet,
    ViewPortHandler viewPortHandler,
    double posX,
    double posY,
    ChartPaint renderPaint,
  )
  _renderShape;

  @override
  void renderShape(
    ui.Canvas c,
    IScatterDataSet dataSet,
    ViewPortHandler viewPortHandler,
    double posX,
    double posY,
    ChartPaint renderPaint,
  ) => _renderShape(c, dataSet, viewPortHandler, posX, posY, renderPaint);
}
