// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/scatter/TriangleShapeRenderer.kt
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../../graphics/chart_canvas.dart';
import '../../graphics/chart_paint.dart';
import '../../interfaces/datasets/i_scatter_data_set.dart';
import '../../utils/color_template.dart';
import '../../utils/utils.dart';
import '../../utils/view_port_handler.dart';
import 'i_shape_renderer.dart';

/// Draws a scatter entry as an upward pointing triangle of the shape size. With a hole radius on the data
/// set only the outline of that thickness is drawn, and the inner triangle is filled with the hole color when
/// one is set.
class TriangleShapeRenderer implements IShapeRenderer {
  /// Path reused for the triangle outline and its hole.
  @protected
  final ui.Path trianglePathBuffer = ui.Path();

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

    final shapeHoleColor = dataSet.scatterShapeHoleColor;

    renderPaint.style = PaintStyle.FILL;

    final tri = trianglePathBuffer;
    tri.reset();

    tri.moveTo(posX, posY - shapeHalf);
    tri.lineTo(posX + shapeHalf, posY + shapeHalf);
    tri.lineTo(posX - shapeHalf, posY + shapeHalf);

    if (shapeSize > 0.0) {
      tri.lineTo(posX, posY - shapeHalf);

      tri.moveTo(
        posX - shapeHalf + shapeStrokeSize,
        posY + shapeHalf - shapeStrokeSize,
      );
      tri.lineTo(
        posX + shapeHalf - shapeStrokeSize,
        posY + shapeHalf - shapeStrokeSize,
      );
      tri.lineTo(posX, posY - shapeHalf + shapeStrokeSize);
      tri.lineTo(
        posX - shapeHalf + shapeStrokeSize,
        posY + shapeHalf - shapeStrokeSize,
      );
    }

    tri.close();

    c.drawPathP(tri, renderPaint);
    tri.reset();

    if (shapeSize > 0.0 && shapeHoleColor != ColorTemplate.COLOR_NONE) {
      renderPaint.color = shapeHoleColor;

      tri.moveTo(posX, posY - shapeHalf + shapeStrokeSize);
      tri.lineTo(
        posX + shapeHalf - shapeStrokeSize,
        posY + shapeHalf - shapeStrokeSize,
      );
      tri.lineTo(
        posX - shapeHalf + shapeStrokeSize,
        posY + shapeHalf - shapeStrokeSize,
      );
      tri.close();

      c.drawPathP(tri, renderPaint);
      tri.reset();
    }
  }
}
