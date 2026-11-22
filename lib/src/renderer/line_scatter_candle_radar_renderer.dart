// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/LineScatterCandleRadarRenderer.kt
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../graphics/chart_canvas.dart';
import '../highlight/highlight_line_span.dart';
import '../interfaces/datasets/i_line_scatter_candle_radar_data_set.dart';
import '../utils/utils.dart';
import 'bar_line_scatter_candle_bubble_renderer.dart';

/// Base class of the renderers that mark a selected entry with vertical and horizontal highlight lines.
abstract class LineScatterCandleRadarRenderer
    extends BarLineScatterCandleBubbleRenderer {
  /// Creates a renderer whose drawing follows the phases of [animator].
  LineScatterCandleRadarRenderer(super.animator, super.viewPortHandler);

  final ui.Path _highlightLinePath = ui.Path();

  /// Draws the highlight lines of [set] through the pixel position ([x], [y]): a vertical line over the content
  /// height and a horizontal line over the content width, each only when the data set enables that indicator and
  /// each as far as its span allows. Uses the highlight color, line width (dp) and dash effect of the data set
  /// on [highlightPaint].
  @protected
  void drawHighlightLines(
    ui.Canvas c,
    double x,
    double y,
    ILineScatterCandleRadarDataSet set,
  ) {
    highlightPaint.color = set.highlightColor;
    highlightPaint.strokeWidth = Utils.convertDpToPixel(set.highlightLineWidth);
    highlightPaint.pathEffect = set.dashPathEffectHighlight;

    if (set.isVerticalHighlightIndicatorEnabled) {
      final from = switch (set.verticalHighlightIndicatorSpan) {
        HighlightLineSpan.FROM_ENTRY => y,
        _ => viewPortHandler.contentBottom,
      };
      final to = switch (set.verticalHighlightIndicatorSpan) {
        HighlightLineSpan.TO_ENTRY => y,
        _ => viewPortHandler.contentTop,
      };

      _highlightLinePath.reset();
      _highlightLinePath.moveTo(x, from);
      _highlightLinePath.lineTo(x, to);
      c.drawPathP(_highlightLinePath, highlightPaint);
    }

    if (set.isHorizontalHighlightIndicatorEnabled) {
      final from = switch (set.horizontalHighlightIndicatorSpan) {
        HighlightLineSpan.FROM_ENTRY => x,
        _ => viewPortHandler.contentLeft,
      };
      final to = switch (set.horizontalHighlightIndicatorSpan) {
        HighlightLineSpan.TO_ENTRY => x,
        _ => viewPortHandler.contentRight,
      };

      _highlightLinePath.reset();
      _highlightLinePath.moveTo(from, y);
      _highlightLinePath.lineTo(to, y);
      c.drawPathP(_highlightLinePath, highlightPaint);
    }
  }
}
