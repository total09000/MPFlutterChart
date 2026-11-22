// Ported from MPChartExample: custom/CustomScatterShapeRenderer.kt
import 'dart:ui' as ui;

import 'package:mp_flutter_chart/core.dart';

/// Draws each scatter value as a diagonal line from its top left to its bottom right.
class CustomScatterShapeRenderer implements IShapeRenderer {
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
    c.drawLineP(posX - shapeHalf, posY - shapeHalf, posX + shapeHalf, posY + shapeHalf, renderPaint);
  }
}
