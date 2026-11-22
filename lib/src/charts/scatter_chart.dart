// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/ScatterChart.kt
//
// The nested enum ScatterChart.ScatterShape is the top-level ScatterShape in scatter_shape.dart.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../data/scatter_data.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../interfaces/dataprovider/scatter_data_provider.dart';
import '../renderer/scatter_chart_renderer.dart';
import 'bar_line_chart_base.dart';

/// Chart that draws [ScatterData] as one shape per entry. It implements [ScatterDataProvider] for the
/// scatter renderer. Circles and squares draw fastest, triangles slowest.
class ScatterChart extends BarLineChartBase<ScatterData>
    implements ScatterDataProvider {
  @override
  void init() {
    super.init();

    renderer = ScatterChartRenderer(this, animator, viewPortHandler);

    xAxis.spaceMin = 0.5;
    xAxis.spaceMax = 0.5;
  }

  @override
  ScatterData? get scatterData => data;

  /// Draws four filled circles of a seventh of the height of [bounds], scattered over it.
  @protected
  @override
  void drawNoDataIcon(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) {
    paint.style = PaintStyle.FILL;
    final r = bounds.height() / 7;
    // (x, y) fractions of the bounds, pairwise.
    final centers = Float32List.fromList([
      0.15, 0.75, //
      0.4, 0.35, //
      0.62, 0.6, //
      0.85, 0.2, //
    ]);
    for (var i = 0; i < centers.length; i += 2) {
      final fx = centers[i];
      final fy = centers[i + 1];
      canvas.drawCircleP(
        bounds.left + bounds.width() * fx,
        bounds.top + bounds.height() * fy,
        r,
        paint,
      );
    }
  }
}
