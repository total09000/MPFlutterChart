// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/scatter/CircleShapeRenderer.kt
import 'dart:ui' as ui;

import '../../graphics/chart_canvas.dart';
import '../../graphics/chart_paint.dart';
import '../../interfaces/datasets/i_scatter_data_set.dart';
import '../../utils/color_template.dart';
import '../../utils/utils.dart';
import '../../utils/view_port_handler.dart';
import 'i_shape_renderer.dart';

/// Draws a scatter entry as a ring whose outer diameter is the shape size and whose hole has the hole radius
/// of the data set, a full disc when the hole radius is 0. The hole is filled with the hole color when one is set.
class CircleShapeRenderer implements IShapeRenderer {
  @override
  void renderShape(
    ui.Canvas c,
    IScatterDataSet dataSet,
    ViewPortHandler viewPortHandler,
    double posX,
    double posY,
    ChartPaint renderPaint,
  ) {
    final shapeSize = Utils.convertDpToPixel(dataSet.scatterShapeSize);
    final shapeHalf = shapeSize / 2;
    final shapeHoleSizeHalf = Utils.convertDpToPixel(
      dataSet.scatterShapeHoleRadius,
    );
    final shapeHoleSize = shapeHoleSizeHalf * 2;
    final shapeStrokeSize = (shapeSize - shapeHoleSize) / 2;
    final shapeStrokeSizeHalf = shapeStrokeSize / 2;

    final shapeHoleColor = dataSet.scatterShapeHoleColor;

    if (shapeSize > 0.0) {
      renderPaint.style = PaintStyle.STROKE;
      renderPaint.strokeWidth = shapeStrokeSize;

      c.drawCircleP(
        posX,
        posY,
        shapeHoleSizeHalf + shapeStrokeSizeHalf,
        renderPaint,
      );

      if (shapeHoleColor != ColorTemplate.COLOR_NONE) {
        renderPaint.style = PaintStyle.FILL;
        renderPaint.color = shapeHoleColor;
        c.drawCircleP(posX, posY, shapeHoleSizeHalf, renderPaint);
      }
    } else {
      renderPaint.style = PaintStyle.FILL;
      c.drawCircleP(posX, posY, shapeHalf, renderPaint);
    }
  }
}
