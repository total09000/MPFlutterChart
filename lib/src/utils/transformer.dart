// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/Transformer.kt
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb, protected, visibleForTesting;

import '../graphics/matrix.dart';
import '../graphics/mutable_rect.dart';
import 'float_math.dart';
import 'mp_point_d.dart';
import 'view_port_handler.dart';

/// Converts chart values to pixel positions and back for one y axis of a bar, line, scatter, candle
/// or bubble chart.
///
/// Three matrices are applied in order: the value matrix from [prepareMatrixValuePx], the touch
/// matrix of the [ViewPortHandler] holding zoom and drag, and the offset matrix from [prepareMatrixOffset].
/// Functions without an output parameter change the passed array, path or rectangle in place.
/// The charts call the prepare functions themselves; use `BarLineChartBase.getTransformer`
/// to get the transformer of an axis.
class Transformer {
  /// The viewport whose content rectangle and touch matrix this transformer maps into.
  @protected
  final ViewPortHandler viewPortHandler;

  Transformer(this.viewPortHandler);

  /// Matrix that scales chart values to unzoomed pixel distances.
  @protected
  final Matrix matrixValueToPx = Matrix();

  /// Matrix that moves the scaled values into the content rectangle and flips the y axis.
  @protected
  final Matrix matrixOffset = Matrix();

  /// Builds the value matrix from the visible value range and the content size.
  ///
  /// [xChartMin] is the smallest x value of the chart, [deltaX] the x range of the chart, [deltaY] the y range of
  /// the axis and [yChartMin] the smallest y value of the axis.
  void prepareMatrixValuePx(
    double xChartMin,
    double deltaX,
    double deltaY,
    double yChartMin,
  ) {
    double scaleX = viewPortHandler.contentWidth / deltaX;
    double scaleY = viewPortHandler.contentHeight / deltaY;

    if (!scaleX.isFinite) scaleX = 0;
    if (!scaleY.isFinite) scaleY = 0;

    matrixValueToPx.reset();
    matrixValueToPx.postTranslate(-xChartMin, -yChartMin);
    matrixValueToPx.postScale(scaleX, -scaleY);
  }

  /// Builds the offset matrix from the current content offsets.
  ///
  /// [inverted] is true if the y axis is inverted, so larger values are drawn further down.
  void prepareMatrixOffset(bool inverted) {
    matrixOffset.reset();
    if (!inverted) {
      matrixOffset.postTranslate(
        viewPortHandler.offsetLeft,
        viewPortHandler.chartHeight - viewPortHandler.offsetBottom,
      );
    } else {
      matrixOffset.setTranslate(
        viewPortHandler.offsetLeft,
        -viewPortHandler.offsetTop,
      );
      matrixOffset.postScale(1.0, -1.0);
    }
  }

  /// The one-step matrix of [pathValueToPixel], reused by every call.
  final Float64List _pathMatrix4 = Float64List(16);

  /// Holds the input of [pathValueToPixel] while the transformed points are written back; empty between calls.
  final ui.Path _pathBuffer = ui.Path();

  /// Converts a path built from chart values to pixel space in place.
  ///
  /// Android transforms the path in place three times. `ui.Path` has no in-place transform, so the three matrices are
  /// applied as one ([valueToPixelMatrix4]) while the path is copied back into itself through a reused buffer: a call
  /// creates no path and no matrix list on this hot path (the line and fill paths of every frame). The
  /// [ui.Path.fillType] of [path] is kept. When the one-step matrix does not exist (skew or perspective) or a term of
  /// it does not fit the Float range of the engine's matrices, the three matrices are applied one after another, as
  /// three `ui.Path.transform` copies.
  ///
  /// On the web the one-step matrix is applied through a `ui.Path.transform` copy: a path of the web engine that was
  /// added to another path and then reset leaves that other path empty, so the buffer cannot be used there.
  void pathValueToPixel(ui.Path path) {
    final matrix4 = _pathMatrix4;
    if (!valueToPixelMatrix4(matrix4) || !_fitsFloat(matrix4)) {
      _pathValueToPixelInSteps(path);
      return;
    }
    if (kIsWeb) {
      final transformed = path.transform(matrix4);
      final fillType = path.fillType;
      path.reset();
      path.fillType = fillType;
      path.addPath(transformed, ui.Offset.zero);
      return;
    }
    final buffer = _pathBuffer;
    buffer.addPath(path, ui.Offset.zero);
    final fillType = path.fillType;
    path.reset();
    path.fillType = fillType;
    path.addPath(buffer, ui.Offset.zero, matrix4: matrix4);
    buffer.reset();
  }

  /// [pathValueToPixel] for matrices without a one-step form: the three transforms one after another, each
  /// `ui.Path.transform` returning a new path.
  void _pathValueToPixelInSteps(ui.Path path) {
    var transformed = path.transform(matrixValueToPx.toMatrix4Storage());
    transformed = transformed.transform(
      viewPortHandler.matrixTouch.toMatrix4Storage(),
    );
    transformed = transformed.transform(matrixOffset.toMatrix4Storage());
    final fillType = path.fillType;
    path.reset();
    path.fillType = fillType;
    path.addPath(transformed, ui.Offset.zero);
  }

  /// Writes the matrix that [pathValueToPixel] applies in one step, `matrixOffset × matrixTouch × matrixValueToPx`,
  /// into [out] as column-major 4×4 storage (the form `ui.Path.transform` takes) and returns true. Returns false and
  /// leaves [out] unchanged when one of the three matrices has skew or perspective.
  ///
  /// Each axis is combined on its own: `x' = sx·x + tx` with `sx = offset.sx · touch.sx · value.sx` and
  /// `tx = offset.sx · (touch.sx · value.tx + touch.tx) + offset.tx`, likewise for y, which is what the three
  /// transforms do to a point one after another. A full 3×3 product such as [valueToPixelMatrix] also multiplies the
  /// zero skew terms, so a non-finite x term would make the y terms NaN (0 × ∞); here it stays in x. Not in Kotlin,
  /// which transforms paths in place; public for tests.
  @visibleForTesting
  bool valueToPixelMatrix4(Float64List out) {
    final v = matrixValueToPx.values;
    final t = viewPortHandler.matrixTouch.values;
    final o = matrixOffset.values;
    if (!_isScaleTranslate(v) ||
        !_isScaleTranslate(t) ||
        !_isScaleTranslate(o)) {
      return false;
    }
    const sx = Matrix.MSCALE_X, tx = Matrix.MTRANS_X;
    const sy = Matrix.MSCALE_Y, ty = Matrix.MTRANS_Y;
    out.fillRange(0, 16, 0.0);
    out[0] = o[sx] * (t[sx] * v[sx]);
    out[5] = o[sy] * (t[sy] * v[sy]);
    out[10] = 1;
    out[12] = o[sx] * (t[sx] * v[tx] + t[tx]) + o[tx];
    out[13] = o[sy] * (t[sy] * v[ty] + t[ty]) + o[ty];
    out[15] = 1;
    return true;
  }

  /// Whether the scale and translation terms of the one-step [matrix4] are finite and within the Float range. The
  /// engine stores path matrices in Float and clamps a larger finite term to Float.MAX, so such a product (two huge
  /// scales whose steps stay finite one after another) is applied in steps instead.
  static bool _fitsFloat(Float64List matrix4) =>
      matrix4[0].abs() <= kotlinFloatMaxValue &&
      matrix4[5].abs() <= kotlinFloatMaxValue &&
      matrix4[12].abs() <= kotlinFloatMaxValue &&
      matrix4[13].abs() <= kotlinFloatMaxValue;

  /// Whether the Android-order [values] have neither skew nor perspective.
  static bool _isScaleTranslate(Float64List values) =>
      values[Matrix.MSKEW_X] == 0 &&
      values[Matrix.MSKEW_Y] == 0 &&
      values[Matrix.MPERSP_0] == 0 &&
      values[Matrix.MPERSP_1] == 0 &&
      values[Matrix.MPERSP_2] == 1;

  /// Converts several paths built from chart values to pixel space in place.
  void pathValuesToPixel(List<ui.Path> paths) {
    for (final path in paths) {
      pathValueToPixel(path);
    }
  }

  /// Converts chart values to pixel positions in place.
  ///
  /// [pts] holds x, y pairs in value space, which are replaced by pixel positions. With [count] (Kotlin's
  /// `pointValuesToPixel(pts, count)` overload) only the first [count] floats are converted and the rest is left
  /// untouched, so a buffer that is longer than the data in it can be converted in one pass; [count] is an even
  /// number no larger than the size of [pts].
  void pointValuesToPixel(Float32List pts, [int? count]) {
    if (count == null) {
      matrixValueToPx.mapPoints(pts);
      viewPortHandler.matrixTouch.mapPoints(pts);
      matrixOffset.mapPoints(pts);
      return;
    }
    final points = count ~/ 2;
    matrixValueToPx.mapPoints(pts, 0, pts, 0, points);
    viewPortHandler.matrixTouch.mapPoints(pts, 0, pts, 0, points);
    matrixOffset.mapPoints(pts, 0, pts, 0, points);
  }

  /// Converts a rectangle in value space to pixel space in place.
  void rectValueToPixel(MutableRect r) {
    matrixValueToPx.mapRect(r);
    viewPortHandler.matrixTouch.mapRect(r);
    matrixOffset.mapRect(r);
  }

  /// Multiplies the top and bottom of [r] by the y animation phase, then converts it to pixel space in place.
  /// Used for vertical bars.
  void rectToPixelPhase(MutableRect r, double phaseY) {
    r.top *= phaseY;
    r.bottom *= phaseY;
    rectValueToPixel(r);
  }

  /// Multiplies the left and right of [r] by the y animation phase, then converts it to pixel space in place.
  /// Used for horizontal bars, where the value runs along the x axis.
  void rectToPixelPhaseHorizontal(MutableRect r, double phaseY) {
    r.left *= phaseY;
    r.right *= phaseY;
    rectValueToPixel(r);
  }

  /// Converts a rectangle in value space to pixel space in place. Same as [rectValueToPixel].
  ///
  /// With [phaseY] (Kotlin's `rectValueToPixelHorizontal(r, phaseY)` overload) the left and right of [r] are first
  /// multiplied by the y animation phase, the same as [rectToPixelPhaseHorizontal].
  void rectValueToPixelHorizontal(MutableRect r, [double? phaseY]) {
    if (phaseY == null) {
      rectValueToPixel(r);
      return;
    }
    r.left *= phaseY;
    r.right *= phaseY;
    rectValueToPixel(r);
  }

  /// Converts several rectangles in value space to pixel space in place.
  void rectValuesToPixel(List<MutableRect> rects) {
    final m = valueToPixelMatrix;
    for (final rect in rects) {
      m.mapRect(rect);
    }
  }

  final Matrix _pixelToValueMatrixBuffer = Matrix();

  /// Converts pixel positions to chart values in place.
  ///
  /// [pixels] holds x, y pairs in pixels, which are replaced by values.
  void pixelsToValue(Float32List pixels) {
    final tmp = _pixelToValueMatrixBuffer;
    tmp.reset();
    matrixOffset.invert(tmp);
    tmp.mapPoints(pixels);
    viewPortHandler.matrixTouch.invert(tmp);
    tmp.mapPoints(pixels);
    matrixValueToPx.invert(tmp);
    tmp.mapPoints(pixels);
  }

  final Float32List _ptsBuffer = Float32List(2);

  /// Converts a pixel position, for example a touch, to the x and y value at that point.
  ///
  /// Writes into [outputPoint] and returns it if given (Kotlin's `getValuesByTouchPoint(x, y, outputPoint)`
  /// overload); otherwise returns a new [MPPointD] that is not taken from the pool, which may still be given to
  /// [MPPointD.recycleInstance].
  MPPointD getValuesByTouchPoint(double x, double y, [MPPointD? outputPoint]) {
    final result = outputPoint ?? MPPointD(0.0, 0.0);
    _ptsBuffer[0] = x;
    _ptsBuffer[1] = y;
    pixelsToValue(_ptsBuffer);
    result.x = _ptsBuffer[0];
    result.y = _ptsBuffer[1];
    return result;
  }

  /// Converts an x and y value to its pixel position.
  ///
  /// Returns a new [MPPointD] that is not taken from the pool; it may still be given to
  /// [MPPointD.recycleInstance].
  MPPointD getPixelForValues(double x, double y) {
    _ptsBuffer[0] = x;
    _ptsBuffer[1] = y;
    pointValuesToPixel(_ptsBuffer);
    return MPPointD(_ptsBuffer[0], _ptsBuffer[1]);
  }

  /// The value matrix built by [prepareMatrixValuePx]. Do not modify it.
  Matrix get valueMatrix => matrixValueToPx;

  /// The offset matrix built by [prepareMatrixOffset]. Do not modify it.
  Matrix get offsetMatrix => matrixOffset;

  final Matrix _mBuffer1 = Matrix();

  /// The combined value, touch and offset matrix that maps values to pixels.
  /// Returns a buffer that is overwritten on the next access; do not keep a reference to it.
  Matrix get valueToPixelMatrix {
    _mBuffer1.set(matrixValueToPx);
    _mBuffer1.postConcat(viewPortHandler.matrixTouch);
    _mBuffer1.postConcat(matrixOffset);
    return _mBuffer1;
  }

  final Matrix _mBuffer2 = Matrix();

  /// The inverse of [valueToPixelMatrix], mapping pixels to values.
  /// Returns a buffer that is overwritten on the next access; do not keep a reference to it.
  Matrix get pixelToValueMatrix {
    valueToPixelMatrix.invert(_mBuffer2);
    return _mBuffer2;
  }
}
