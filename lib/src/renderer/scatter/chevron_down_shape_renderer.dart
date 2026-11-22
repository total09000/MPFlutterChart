// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/scatter/ChevronDownShapeRenderer.kt
import 'dart:ui' as ui;

import '../../graphics/chart_canvas.dart';
import '../../graphics/chart_paint.dart';
import '../../interfaces/datasets/i_scatter_data_set.dart';
import '../../utils/utils.dart';
import '../../utils/view_port_handler.dart';
import 'i_shape_renderer.dart';

/// Draws a scatter entry as a downward pointing chevron (an open V) with a 1 dp stroke. The tip sits one shape
/// size below the entry position.
class ChevronDownShapeRenderer implements IShapeRenderer {
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
      posX,
      posY + (2 * shapeHalf),
      posX + (2 * shapeHalf),
      posY,
      renderPaint,
    );
    c.drawLineP(
      posX,
      posY + (2 * shapeHalf),
      posX - (2 * shapeHalf),
      posY,
      renderPaint,
    );
  }
}
