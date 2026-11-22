// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/LineRadarRenderer.kt
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../graphics/chart_canvas.dart';
import '../graphics/chart_drawable.dart';
import '../graphics/mutable_rect.dart';
import '../utils/float_math.dart';
import 'line_scatter_candle_radar_renderer.dart';

/// Base class of the line and radar renderers, which can fill the area enclosed by their line.
abstract class LineRadarRenderer extends LineScatterCandleRadarRenderer {
  /// Creates a renderer whose drawing follows the phases of [animator].
  LineRadarRenderer(super.animator, super.viewPortHandler);

  /// The bounds the fill drawable is drawn into; Kotlin's `Drawable.setBounds` with the content rectangle
  /// truncated to whole device pixels.
  final MutableRect _drawableBounds = MutableRect();

  /// Draws [drawable] stretched over the content rectangle, clipped to [filledPath] (pixels).
  @protected
  void drawFilledPath(ui.Canvas c, ui.Path filledPath, ChartDrawable drawable) {
    final save = c.getSaveCount();
    c.save();
    c.clipPath(filledPath);

    _drawableBounds.set(
      truncateToDevicePx(viewPortHandler.contentLeft),
      truncateToDevicePx(viewPortHandler.contentTop),
      truncateToDevicePx(viewPortHandler.contentRight),
      truncateToDevicePx(viewPortHandler.contentBottom),
    );
    drawable.draw(c, _drawableBounds);

    c.restoreToCount(save);
  }

  /// Fills [filledPath] (pixels) with [fillColor] at [fillAlpha] (0 to 255). The alpha of the color itself is
  /// ignored.
  ///
  /// Kotlin's `drawFilledPath(c, filledPath, fillColor, fillAlpha)` overload; renamed because Dart has no
  /// overloading.
  @protected
  void drawFilledPathColor(
    ui.Canvas c,
    ui.Path filledPath,
    ui.Color fillColor,
    int fillAlpha,
  ) {
    final color = ui.Color(
      ((fillAlpha << 24) | (fillColor.toARGB32() & 0xffffff)) & 0xffffffff,
    );

    final save = c.getSaveCount();
    c.save();
    c.clipPath(filledPath);
    c.drawColorP(color);
    c.restoreToCount(save);
  }
}
