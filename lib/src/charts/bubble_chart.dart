// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/BubbleChart.kt
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../data/bubble_data.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../interfaces/dataprovider/bubble_data_provider.dart';
import '../renderer/bubble_chart_renderer.dart';
import 'bar_line_chart_base.dart';

/// Chart that draws [BubbleData] as circles whose area, not radius, represents the entry size.
/// It implements [BubbleDataProvider] for the bubble renderer.
class BubbleChart extends BarLineChartBase<BubbleData>
    implements BubbleDataProvider {
  @override
  void init() {
    super.init();

    renderer = BubbleChartRenderer(this, animator, viewPortHandler);
  }

  @override
  BubbleData? get bubbleData => data;

  /// Draws two filled circles of different sizes, overlapping, inside [bounds].
  @protected
  @override
  void drawNoDataIcon(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) {
    paint.style = PaintStyle.FILL;
    final h = bounds.height();
    canvas.drawCircleP(
      bounds.left + bounds.width() * 0.25,
      bounds.top + h * 0.62,
      h * 0.24,
      paint,
    );
    canvas.drawCircleP(
      bounds.left + bounds.width() * 0.66,
      bounds.top + h * 0.38,
      h * 0.34,
      paint,
    );
  }
}
