// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/MarkerImage.kt
import 'dart:ui' as ui;

import '../charts/chart.dart';
import '../data/entry.dart';
import '../graphics/chart_drawable.dart';
import '../graphics/mutable_rect.dart';
import '../highlight/highlight.dart';
import '../utils/f_size.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import 'i_marker.dart';

/// A marker that draws a drawable at the highlighted value. The chart sets [chartView] when the marker is assigned to
/// it.
///
/// Kotlin's `MarkerImage(context, drawableResourceId)` loads a drawable resource; here the [ChartDrawable] is passed
/// in (load images with Flutter and wrap them in an `ImageDrawable`).
class MarkerImage implements IMarker {
  final ChartDrawable _drawable;

  /// Creates a marker that draws [drawable].
  MarkerImage(ChartDrawable drawable) : _drawable = drawable;

  /// Offset in px from the highlighted point to the top left corner of the drawable. Default (0, 0).
  @override
  MPPointF offset = MPPointF();

  final MPPointF _drawingOffset = MPPointF();

  WeakReference<Chart>? _weakChart;

  /// Size of the drawable in px; a width or height of 0 uses the drawable's intrinsic size. Default (0, 0).
  FSize size = FSize();

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

  /// Returns [offset], shifted where needed so the drawable stays inside the bounds of [chartView].
  @override
  MPPointF getOffsetForDrawingAtPoint(double posX, double posY) {
    final offset = this.offset;
    _drawingOffset.x = offset.x;
    _drawingOffset.y = offset.y;

    final chart = chartView;

    var width = size.width;
    var height = size.height;

    if (width == 0) width = _drawable.intrinsicWidth.toDouble();
    if (height == 0) height = _drawable.intrinsicHeight.toDouble();

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

  /// Does nothing; the image has no content to update.
  @override
  void refreshContent(Entry e, Highlight highlight) {}

  /// Draws the drawable at [size], translated by [getOffsetForDrawingAtPoint].
  ///
  /// Kotlin sets the drawable bounds to the size (keeping their origin) and restores them afterwards; a
  /// [ChartDrawable] keeps no bounds, so it is drawn into `(0, 0, width, height)` after the translation.
  @override
  void draw(ui.Canvas canvas, double posX, double posY) {
    final offset = getOffsetForDrawingAtPoint(posX, posY);

    var width = size.width;
    var height = size.height;

    if (width == 0) width = _drawable.intrinsicWidth.toDouble();
    if (height == 0) height = _drawable.intrinsicHeight.toDouble();

    final saveId = canvas.getSaveCount();
    canvas.save();
    canvas.translate(posX + offset.x, posY + offset.y);
    _drawable.draw(
      canvas,
      MutableRect(0, 0, truncateToDevicePx(width), truncateToDevicePx(height)),
    );
    canvas.restoreToCount(saveId);
  }
}
