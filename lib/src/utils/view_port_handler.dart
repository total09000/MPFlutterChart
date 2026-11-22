// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/ViewPortHandler.kt
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show protected;

import '../graphics/matrix.dart';
import '../graphics/mutable_rect.dart';
import 'chart_invalidator.dart';
import 'float_math.dart';
import 'mp_point_f.dart';
import 'utils.dart';

/// Kotlin `Float.MAX_VALUE`, the default (unlimited) maximum scale.
const double _FLOAT_MAX_VALUE = 3.4028234663852886e38;

/// Keeps the current viewport of a chart: the chart size, the content rectangle the data is drawn in,
/// and the touch matrix that holds the current zoom and drag state with its limits.
///
/// The content rectangle is the chart size minus the offsets for axes, legend and extra offsets.
/// All sizes and positions are in pixels. The functions that return a [Matrix] build a new matrix
/// from [matrixTouch] with the change applied; pass the result to [refresh] to make it take effect.
/// When given an `outputMatrix` they write into that matrix instead of allocating, and return it.
class ViewPortHandler {
  /// Matrix holding the current scale and translation applied by touch gestures and zoom calls.
  final Matrix matrixTouch = Matrix();

  /// Rectangle in pixels in which the chart data is drawn, the chart area without the offsets.
  final MutableRect contentRect = MutableRect();

  double _chartWidth = 0;

  /// Full width of the chart view in pixels.
  double get chartWidth => _chartWidth;

  @protected
  set chartWidth(double value) => _chartWidth = value;

  double _chartHeight = 0;

  /// Full height of the chart view in pixels.
  double get chartHeight => _chartHeight;

  @protected
  set chartHeight(double value) => _chartHeight = value;

  // The scale limits are rounded to Float when set, as Kotlin's Float properties are: limitTransAndScale stores the
  // clamped scale in a Float matrix, and canZoom*More* compare it against these limits.
  double _minScaleY = 1;

  /// Smallest allowed y scale factor, at least 1. Default 1.
  double get minScaleY => _minScaleY;

  double _maxScaleY = _FLOAT_MAX_VALUE;

  /// Largest allowed y scale factor. Default Kotlin `Float.MAX_VALUE`, meaning unlimited.
  double get maxScaleY => _maxScaleY;

  double _minScaleX = 1;

  /// Smallest allowed x scale factor, at least 1. Default 1.
  double get minScaleX => _minScaleX;

  double _maxScaleX = _FLOAT_MAX_VALUE;

  /// Largest allowed x scale factor. Default Kotlin `Float.MAX_VALUE`, meaning unlimited.
  double get maxScaleX => _maxScaleX;

  double _scaleX = 1;

  /// Current x scale factor, 1 when not zoomed. Updated by [limitTransAndScale].
  double get scaleX => _scaleX;

  double _scaleY = 1;

  /// Current y scale factor, 1 when not zoomed. Updated by [limitTransAndScale].
  double get scaleY => _scaleY;

  double _transX = 0;

  /// Current drag translation on the x axis in pixels. Updated by [limitTransAndScale].
  double get transX => _transX;

  double _transY = 0;

  /// Current drag translation on the y axis in pixels. Updated by [limitTransAndScale].
  double get transY => _transY;

  /// Distance in dp the chart may be dragged beyond its data bounds on the x axis. Default 0.
  double dragOffsetX = 0;

  /// Distance in dp the chart may be dragged beyond its data bounds on the y axis. Default 0.
  double dragOffsetY = 0;

  /// Sets the chart size in pixels and recomputes [contentRect] keeping the current offsets.
  void setChartDimens(double width, double height) {
    final offsetLeft = this.offsetLeft;
    final offsetTop = this.offsetTop;
    final offsetRight = this.offsetRight;
    final offsetBottom = this.offsetBottom;

    chartHeight = height;
    chartWidth = width;

    restrainViewPort(offsetLeft, offsetTop, offsetRight, offsetBottom);
  }

  /// True once the chart has a width and height greater than zero.
  bool hasChartDimens() => chartHeight > 0 && chartWidth > 0;

  /// Sets [contentRect] to the chart size minus the given offsets in pixels.
  void restrainViewPort(
    double offsetLeft,
    double offsetTop,
    double offsetRight,
    double offsetBottom,
  ) {
    contentRect.set(
      offsetLeft,
      offsetTop,
      chartWidth - offsetRight,
      chartHeight - offsetBottom,
    );
  }

  /// Space in pixels between the left chart edge and the content rectangle.
  double get offsetLeft => contentRect.left;

  /// Space in pixels between the content rectangle and the right chart edge.
  double get offsetRight => chartWidth - contentRect.right;

  /// Space in pixels between the top chart edge and the content rectangle.
  double get offsetTop => contentRect.top;

  /// Space in pixels between the content rectangle and the bottom chart edge.
  double get offsetBottom => chartHeight - contentRect.bottom;

  /// Top edge of the content rectangle in pixels.
  double get contentTop => contentRect.top;

  /// Left edge of the content rectangle in pixels.
  double get contentLeft => contentRect.left;

  /// Right edge of the content rectangle in pixels.
  double get contentRight => contentRect.right;

  /// Bottom edge of the content rectangle in pixels.
  double get contentBottom => contentRect.bottom;

  /// Width of the content rectangle in pixels.
  double get contentWidth => contentRect.width();

  /// Height of the content rectangle in pixels.
  double get contentHeight => contentRect.height();

  /// Center of the content rectangle in pixels, as a new [MPPointF] that is not pooled.
  MPPointF get contentCenter =>
      MPPointF(contentRect.centerX(), contentRect.centerY());

  /// The smaller of the content width and height in pixels.
  double get smallestContentExtension =>
      math.min(contentRect.width(), contentRect.height());

  /// Returns the touch matrix zoomed in by 1.4 around the pixel position ([x], [y]).
  ///
  /// Writes into [outputMatrix] if given (Kotlin's `zoomIn(x, y, outputMatrix)` overload), else into a new matrix.
  Matrix zoomIn(double x, double y, [Matrix? outputMatrix]) {
    final save = outputMatrix ?? Matrix();
    save.reset();
    save.set(matrixTouch);
    save.postScale(1.4, 1.4, x, y);
    return save;
  }

  /// Returns the touch matrix zoomed out by 0.7 around the pixel position ([x], [y]).
  ///
  /// Writes into [outputMatrix] if given (Kotlin's `zoomOut(x, y, outputMatrix)` overload), else into a new matrix.
  Matrix zoomOut(double x, double y, [Matrix? outputMatrix]) {
    final save = outputMatrix ?? Matrix();
    save.reset();
    save.set(matrixTouch);
    save.postScale(0.7, 0.7, x, y);
    return save;
  }

  /// Writes the current touch matrix into [outputMatrix] with the scale taken back to 1 around the content
  /// center, keeping the translation. [fitScreen] also resets the scale minima.
  void resetZoom(Matrix outputMatrix) {
    outputMatrix.reset();
    outputMatrix.set(matrixTouch);
    outputMatrix.postScale(
      1 / scaleX,
      1 / scaleY,
      contentRect.centerX(),
      contentRect.centerY(),
    );
  }

  /// Returns the touch matrix scaled by the given factors around the pixel position ([x], [y]), or around the origin
  /// without a pivot when [x] and [y] are null.
  ///
  /// Covers Kotlin's four `zoom` overloads: `zoom(sx, sy)`, `zoom(sx, sy, x, y)` and their `outputMatrix`
  /// variants; Kotlin's `zoom(sx, sy, outputMatrix)` is `zoom(sx, sy, null, null, outputMatrix)`. Writes into
  /// [outputMatrix] if given, else into a new matrix.
  Matrix zoom(
    double scaleX,
    double scaleY, [
    double? x,
    double? y,
    Matrix? outputMatrix,
  ]) {
    final save = outputMatrix ?? Matrix();
    save.reset();
    save.set(matrixTouch);
    save.postScale(scaleX, scaleY, x, y);
    return save;
  }

  /// Returns a matrix that holds only the given absolute scale factors around the pixel position ([x], [y]), or
  /// without a pivot when [x] and [y] are null; the current translation is dropped.
  ///
  /// Covers Kotlin's `setZoom(sx, sy)`, `setZoom(sx, sy, x, y)` and `setZoom(sx, sy, outputMatrix)` overloads; the
  /// last is `setZoom(sx, sy, null, null, outputMatrix)`. Writes into [outputMatrix] if given, else into a new matrix.
  Matrix setZoom(
    double scaleX,
    double scaleY, [
    double? x,
    double? y,
    Matrix? outputMatrix,
  ]) {
    final save = outputMatrix ?? Matrix();
    save.reset();
    save.set(matrixTouch);
    save.setScale(scaleX, scaleY, x, y);
    return save;
  }

  final Float32List _valsBufferForFitScreen = Float32List(9);

  /// Returns the touch matrix with scale 1 and no translation, so the data fits the content rectangle exactly.
  /// Also resets [minScaleX] and [minScaleY] to 1.
  ///
  /// Writes into [outputMatrix] if given (Kotlin's `fitScreen(outputMatrix)` overload), else into a new matrix.
  Matrix fitScreen([Matrix? outputMatrix]) {
    final save = outputMatrix ?? Matrix();
    _minScaleX = 1;
    _minScaleY = 1;

    save.set(matrixTouch);

    final vals = _valsBufferForFitScreen;
    vals.fillRange(0, vals.length, 0);
    save.getValues(vals);

    vals[Matrix.MTRANS_X] = 0;
    vals[Matrix.MTRANS_Y] = 0;
    vals[Matrix.MSCALE_X] = 1;
    vals[Matrix.MSCALE_Y] = 1;

    save.setValues(vals);
    return save;
  }

  /// Returns the touch matrix translated so that the pixel position in [transformedPts] moves to the top left
  /// of the content rectangle.
  ///
  /// [transformedPts] holds x at index 0 and y at index 1, in pixels. Writes into [outputMatrix] if given
  /// (Kotlin's `translate(transformedPts, outputMatrix)` overload), else into a new matrix.
  Matrix translate(Float32List transformedPts, [Matrix? outputMatrix]) {
    final save = outputMatrix ?? Matrix();
    save.reset();
    save.set(matrixTouch);
    final x = transformedPts[0] - offsetLeft;
    final y = transformedPts[1] - offsetTop;
    save.postTranslate(-x, -y);
    return save;
  }

  final Matrix _centerViewPortMatrixBuffer = Matrix();

  /// Moves the viewport so that the pixel position in [transformedPts] sits at the top left of the content
  /// rectangle, applies the limits and redraws [view]. Positions outside the data bounds are clamped.
  ///
  /// [transformedPts] holds x at index 0 and y at index 1, in pixels.
  void centerViewPort(Float32List transformedPts, ChartInvalidator view) {
    final save = _centerViewPortMatrixBuffer;
    save.reset();
    save.set(matrixTouch);
    final x = transformedPts[0] - offsetLeft;
    final y = transformedPts[1] - offsetTop;
    save.postTranslate(-x, -y);
    refresh(save, view, true);
  }

  final Float32List _matrixBuffer = Float32List(9);

  /// Makes [newMatrix] the current touch matrix after clamping its scale and translation to the limits.
  ///
  /// [chart] is the chart to redraw; [invalidate] is true to redraw it right away. Returns [newMatrix], updated to
  /// the clamped values.
  Matrix refresh(Matrix newMatrix, ChartInvalidator chart, bool invalidate) {
    matrixTouch.set(newMatrix);
    limitTransAndScale(matrixTouch, contentRect);
    if (invalidate) chart.invalidate();
    newMatrix.set(matrixTouch);
    return newMatrix;
  }

  /// Clamps the scale of [matrix] to the min and max scale limits and its translation so the data cannot be
  /// dragged out of [content] further than [dragOffsetX] and [dragOffsetY] allow. Updates [scaleX], [scaleY],
  /// [transX] and [transY].
  ///
  /// [content] is the content rectangle in pixels; null is treated as an empty rectangle.
  void limitTransAndScale(Matrix matrix, MutableRect? content) {
    matrix.getValues(_matrixBuffer);

    final curTransX = _matrixBuffer[Matrix.MTRANS_X];
    final curScaleX = _matrixBuffer[Matrix.MSCALE_X];
    final curTransY = _matrixBuffer[Matrix.MTRANS_Y];
    final curScaleY = _matrixBuffer[Matrix.MSCALE_Y];

    _scaleX = math.min(math.max(minScaleX, curScaleX), maxScaleX);
    _scaleY = math.min(math.max(minScaleY, curScaleY), maxScaleY);

    final width = content?.width() ?? 0.0;
    final height = content?.height() ?? 0.0;

    final transOffsetX = Utils.convertDpToPixel(dragOffsetX);
    final transOffsetY = Utils.convertDpToPixel(dragOffsetY);

    final maxTransX = -width * (scaleX - 1);
    _transX = math.min(
      math.max(curTransX, maxTransX - transOffsetX),
      transOffsetX,
    );

    final maxTransY = height * (scaleY - 1);
    _transY = math.max(
      math.min(curTransY, maxTransY + transOffsetY),
      -transOffsetY,
    );

    _matrixBuffer[Matrix.MTRANS_X] = transX;
    _matrixBuffer[Matrix.MSCALE_X] = scaleX;
    _matrixBuffer[Matrix.MTRANS_Y] = transY;
    _matrixBuffer[Matrix.MSCALE_Y] = scaleY;

    matrix.setValues(_matrixBuffer);
  }

  /// Sets the smallest allowed x scale factor and clamps the current touch matrix to it.
  ///
  /// Values of [xScale] below 1 are raised to 1.
  void setMinimumScaleX(double xScale) {
    _minScaleX = toKotlinFloat(math.max(xScale, 1));
    limitTransAndScale(matrixTouch, contentRect);
  }

  /// Sets the largest allowed x scale factor and clamps the current touch matrix to it.
  ///
  /// An [xScale] of 0 removes the limit.
  void setMaximumScaleX(double xScale) {
    final max = toKotlinFloat(xScale);
    _maxScaleX = max == 0 ? _FLOAT_MAX_VALUE : max;
    limitTransAndScale(matrixTouch, contentRect);
  }

  /// Sets both x scale limits and clamps the current touch matrix to them.
  ///
  /// Values of [minScaleX] below 1 are raised to 1; a [maxScaleX] of 0 removes the limit.
  void setMinMaxScaleX(double minScaleX, double maxScaleX) {
    _minScaleX = toKotlinFloat(math.max(minScaleX, 1));
    final max = toKotlinFloat(maxScaleX);
    _maxScaleX = max == 0 ? _FLOAT_MAX_VALUE : max;
    limitTransAndScale(matrixTouch, contentRect);
  }

  /// Sets the smallest allowed y scale factor and clamps the current touch matrix to it.
  ///
  /// Values of [yScale] below 1 are raised to 1.
  void setMinimumScaleY(double yScale) {
    _minScaleY = toKotlinFloat(math.max(yScale, 1));
    limitTransAndScale(matrixTouch, contentRect);
  }

  /// Sets the largest allowed y scale factor and clamps the current touch matrix to it.
  ///
  /// A [yScale] of 0 removes the limit.
  void setMaximumScaleY(double yScale) {
    final max = toKotlinFloat(yScale);
    _maxScaleY = max == 0 ? _FLOAT_MAX_VALUE : max;
    limitTransAndScale(matrixTouch, contentRect);
  }

  /// Sets both y scale limits and clamps the current touch matrix to them.
  ///
  /// Values of [minScaleY] below 1 are raised to 1; a [maxScaleY] of 0 removes the limit.
  void setMinMaxScaleY(double minScaleY, double maxScaleY) {
    _minScaleY = toKotlinFloat(math.max(minScaleY, 1));
    final max = toKotlinFloat(maxScaleY);
    _maxScaleY = max == 0 ? _FLOAT_MAX_VALUE : max;
    limitTransAndScale(matrixTouch, contentRect);
  }

  /// True if the pixel x position lies within the content rectangle, with a 1 pixel tolerance on both sides.
  bool isInBoundsX(double x) => isInBoundsLeft(x) && isInBoundsRight(x);

  /// True if the pixel y position lies within the content rectangle.
  bool isInBoundsY(double y) => isInBoundsTop(y) && isInBoundsBottom(y);

  /// True if the pixel position lies within the content rectangle.
  bool isInBounds(double x, double y) => isInBoundsX(x) && isInBoundsY(y);

  /// True if the pixel x position is not more than 1 pixel left of the content rectangle.
  bool isInBoundsLeft(double x) => contentRect.left <= x + 1;

  /// True if the pixel x position is not more than 1 pixel right of the content rectangle.
  bool isInBoundsRight(double x) {
    final rounded = _roundToHundredths(x);
    return contentRect.right >= rounded - 1;
  }

  /// True if the pixel y position is not above the content rectangle.
  bool isInBoundsTop(double y) => contentRect.top <= y;

  /// True if the pixel y position is not below the content rectangle.
  bool isInBoundsBottom(double y) {
    final rounded = _roundToHundredths(y);
    return contentRect.bottom >= rounded;
  }

  /// True if the chart is at scale 1 on both axes and no minimum scale above 1 is set.
  bool get isFullyZoomedOut => isFullyZoomedOutX && isFullyZoomedOutY;

  /// True if the chart is at scale 1 on the y axis and no minimum y scale above 1 is set.
  bool get isFullyZoomedOutY => !(scaleY > minScaleY || minScaleY > 1);

  /// True if the chart is at scale 1 on the x axis and no minimum x scale above 1 is set.
  bool get isFullyZoomedOutX => !(scaleX > minScaleX || minScaleX > 1);

  /// True if neither [dragOffsetX] nor [dragOffsetY] is set.
  bool get hasNoDragOffset => dragOffsetX <= 0 && dragOffsetY <= 0;

  /// True if the x scale is above [minScaleX].
  bool get canZoomOutMoreX => scaleX > minScaleX;

  /// True if the x scale is below [maxScaleX].
  bool get canZoomInMoreX => scaleX < maxScaleX;

  /// True if the y scale is above [minScaleY].
  bool get canZoomOutMoreY => scaleY > minScaleY;

  /// True if the y scale is below [maxScaleY].
  bool get canZoomInMoreY => scaleY < maxScaleY;

  // ---------------------------------------------------------------------------------------------------------------
  // Kotlin Float semantics that Dart does not share.

  /// Kotlin `(v * 100f).toInt() / 100f` with Float arithmetic: truncates [v] to two decimals.
  ///
  /// Done in Float like Kotlin (e.g. `0.29f * 100f` is exactly 29, while `0.29 * 100` in double truncates to 28),
  /// and with Kotlin's `toInt()`, which gives 0 for NaN and saturates for ±infinity where Dart's would throw.
  static double _roundToHundredths(double v) {
    final scaled = toKotlinFloat(toKotlinFloat(v) * 100);
    final truncated = kotlinFloatToInt(scaled);
    return toKotlinFloat(toKotlinFloat(truncated.toDouble()) / 100);
  }
}
