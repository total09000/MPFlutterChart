// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/MarkerView.kt
import 'dart:ui' as ui;

import '../charts/chart.dart';
import '../data/entry.dart';
import '../highlight/highlight.dart';
import '../utils/f_size.dart';
import '../utils/mp_point_f.dart';
import 'i_marker.dart';

/// A marker drawn on the chart canvas at the highlighted value. Subclass it, implement [measure] and [drawContent],
/// and override [refreshContent] to update the content before each draw. The chart sets [chartView] when the marker is
/// assigned to it.
///
/// Kotlin's `MarkerView` is a `RelativeLayout` inflated from a layout resource. Flutter has no child views on the
/// chart canvas, so this is a canvas marker base class: it keeps [offset], [setOffset], [chartView], the
/// clamping of [getOffsetForDrawingAtPoint], [refreshContent] and [draw]; a subclass reports its size with [measure]
/// (instead of the measured view size) and paints with [drawContent] (instead of the view drawing itself), for
/// example with a `TextPainter` or a `Path`. The layout inflation is not ported.
abstract class MarkerView implements IMarker {
  /// Offset in px from the highlighted point to the top left corner of the marker. Default (0, 0).
  @override
  MPPointF offset = MPPointF();

  final MPPointF _drawingOffset = MPPointF();

  WeakReference<Chart>? _weakChart;

  /// Sets [offset] to [offsetX] / [offsetY] in px.
  void setOffset(double offsetX, double offsetY) {
    offset.x = offsetX;
    offset.y = offsetY;
  }

  /// The chart this marker is assigned to, held weakly, or null before it is assigned or after the chart was
  /// collected. Only its `width` and `height` are read.
  Chart? get chartView => _weakChart?.target;
  set chartView(Chart? value) {
    _weakChart = value == null ? null : WeakReference<Chart>(value);
  }

  /// The size of the marker content in px, standing in for the measured size of Kotlin's view. Called whenever the
  /// size is needed, so it should be cheap; compute and cache the size in [refreshContent] if measuring is costly.
  FSize measure();

  /// Paints the marker content with its top left corner at the canvas origin, standing in for Kotlin's
  /// `View.draw(canvas)`. [draw] has already translated the canvas to the marker position.
  void drawContent(ui.Canvas canvas);

  /// The width of the marker in px, from [measure].
  double get width => measure().width;

  /// The height of the marker in px, from [measure].
  double get height => measure().height;

  /// Returns [offset], shifted where needed so the marker stays inside the bounds of [chartView].
  @override
  MPPointF getOffsetForDrawingAtPoint(double posX, double posY) {
    final offset = this.offset;
    _drawingOffset.x = offset.x;
    _drawingOffset.y = offset.y;

    final chart = chartView;
    final size = measure();
    final width = size.width;
    final height = size.height;

    if (posX + _drawingOffset.x < 0) {
      _drawingOffset.x = -posX;
    } else if (chart != null && posX + width + _drawingOffset.x > chart.width) {
      _drawingOffset.x = chart.width - posX - width;
    }

    if (posY + _drawingOffset.y < 0) {
      _drawingOffset.y = -posY;
    } else if (chart != null &&
        posY + height + _drawingOffset.y > chart.height) {
      _drawingOffset.y = chart.height - posY - height;
    }

    return _drawingOffset;
  }

  /// Updates the content before the marker is drawn. Override it to update what [measure] and [drawContent] use.
  ///
  /// Kotlin measures and lays the view out again here; [measure] is called on demand instead, so the base
  /// implementation does nothing.
  @override
  void refreshContent(Entry e, Highlight highlight) {}

  /// Draws the marker translated by [getOffsetForDrawingAtPoint], by calling [drawContent].
  @override
  void draw(ui.Canvas canvas, double posX, double posY) {
    final offset = getOffsetForDrawingAtPoint(posX, posY);
    final saveId = canvas.getSaveCount();
    canvas.save();
    canvas.translate(posX + offset.x, posY + offset.y);
    drawContent(canvas);
    canvas.restoreToCount(saveId);
  }
}
