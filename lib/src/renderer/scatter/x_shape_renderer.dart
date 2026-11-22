// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/scatter/XShapeRenderer.kt
import 'dart:ui' as ui;

import '../../graphics/chart_canvas.dart';
import '../../graphics/chart_paint.dart';
import '../../interfaces/datasets/i_scatter_data_set.dart';
import '../../utils/utils.dart';
import '../../utils/view_port_handler.dart';
import 'i_shape_renderer.dart';

/// Draws a scatter entry as a diagonal cross (an X) of the shape size with a 1 dp stroke.
class XShapeRenderer implements IShapeRenderer {
  @override
  void renderShape(
    ui.Canvas c,
    IScatterDataSet dataSet,
    ViewPortHandler viewPortHandler,
    double posX,
    double posY,
    ChartPaint renderPaint,
  ) {
    final shapeHalf = Utils.convertDpToPixel(dataSet.scatterShapeSize) / 2;

    renderPaint.style = PaintStyle.STROKE;
    renderPaint.strokeWidth = Utils.convertDpToPixel(1);

    c.drawLineP(
      posX - shapeHalf,
      posY - shapeHalf,
      posX + shapeHalf,
      posY + shapeHalf,
      renderPaint,
    );
    c.drawLineP(
      posX + shapeHalf,
      posY - shapeHalf,
      posX - shapeHalf,
      posY + shapeHalf,
      renderPaint,
    );
  }
}
