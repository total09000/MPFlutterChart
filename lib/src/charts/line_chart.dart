// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/LineChart.kt
//
// onDetachedFromWindow is not overridden: it only released the renderer's offscreen bitmap, which the Flutter
// renderer does not have.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../data/line_data.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../interfaces/dataprovider/line_data_provider.dart';
import '../renderer/line_chart_renderer.dart';
import 'bar_line_chart_base.dart';

/// Chart that draws [LineData] as straight, stepped or curved lines with optional circles and filled
/// areas. It implements [LineDataProvider] for the line renderer.
class LineChart extends BarLineChartBase<LineData> implements LineDataProvider {
  @override
  void init() {
    super.init();

    renderer = LineChartRenderer(this, animator, viewPortHandler);
  }

  @override
  LineData? get lineData => data;

  @protected
  @override
  void drawNoDataIcon(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) {
    paint.style = PaintStyle.STROKE;
    paint.strokeWidth = bounds.height() / 8;
    paint.strokeCap = ui.StrokeCap.round;
    paint.strokeJoin = ui.StrokeJoin.round;
    final inset = paint.strokeWidth / 2;
    final ys = Float32List.fromList([0.8, 0.45, 0.65, 0.15]);
    final path = ui.Path();
    for (var i = 0; i < ys.length; i++) {
      final x =
          bounds.left +
          inset +
          (bounds.width() - 2 * inset) * i / (ys.length - 1);
      final y = bounds.top + inset + (bounds.height() - 2 * inset) * ys[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPathP(path, paint);
  }
}
