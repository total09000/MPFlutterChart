// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/Fill.kt
import 'dart:ui' as ui;

import '../graphics/chart_canvas.dart';
import '../graphics/chart_drawable.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import 'float_math.dart';

/// What a [Fill] paints with (Kotlin `Fill.Type`): [EMPTY] draws nothing, [COLOR] a solid [Fill.color] with
/// [Fill.alpha] applied, [LINEAR_GRADIENT] a gradient built from [Fill.gradientColors] and [Fill.gradientPositions],
/// [DRAWABLE] the [Fill.drawable] stretched to the filled area.
enum FillType { EMPTY, COLOR, LINEAR_GRADIENT, DRAWABLE }

/// Direction in which a linear gradient runs across the filled rectangle (Kotlin `Fill.Direction`): [DOWN] from the
/// top edge, [UP] from the bottom edge, [RIGHT] from the left edge and [LEFT] from the right edge.
///
/// As in Kotlin, [Fill.fillRect] actually starts a [RIGHT] gradient at the right edge and a [LEFT] gradient at the
/// left edge.
enum FillDirection { DOWN, UP, RIGHT, LEFT }

/// Describes how an area is filled: with nothing, a solid color, a linear gradient or a drawable.
///
/// Bar data sets use a list of fills to paint their bars. Pick the constructor for the fill you want;
/// the default constructor creates an empty fill that draws nothing. [type] decides which of the
/// other properties are used when drawing.
class Fill {
  /// Creates an empty fill that draws nothing.
  Fill();

  /// Creates a solid color fill.
  Fill.ofColor(ui.Color color) {
    type = FillType.COLOR;
    this.color = color;
  }

  /// Creates a two-color linear gradient fill.
  Fill.ofColors(ui.Color startColor, ui.Color endColor) {
    type = FillType.LINEAR_GRADIENT;
    gradientColors = [startColor, endColor];
  }

  /// Creates a linear gradient fill; without [gradientPositions] the colors are spread evenly, otherwise each color
  /// gets a position from 0 to 1.
  ///
  /// Kotlin's `Fill(gradientColors)` and `Fill(gradientColors, gradientPositions)` constructors.
  Fill.ofGradient(
    List<ui.Color> this.gradientColors, [
    this.gradientPositions,
  ]) {
    type = FillType.LINEAR_GRADIENT;
  }

  /// Creates a fill that draws [drawable] stretched to the filled area.
  Fill.ofDrawable(ChartDrawable this.drawable) {
    type = FillType.DRAWABLE;
  }

  /// Which kind of fill is drawn. Set by the constructors, [FillType.EMPTY] by default.
  FillType type = FillType.EMPTY;

  /// Solid color for [FillType.COLOR]. Setting it recomputes the drawn color together with [alpha].
  ui.Color? get color => _color;
  set color(ui.Color? value) {
    _color = value;
    _calculateFinalColor();
  }

  ui.Color? _color;

  ui.Color? _finalColor;

  /// Drawable for [FillType.DRAWABLE]. It is drawn into the filled area on each draw.
  ChartDrawable? drawable;

  /// Colors of the gradient for [FillType.LINEAR_GRADIENT], at least two.
  List<ui.Color>? gradientColors;

  /// Positions from 0 to 1 for each of [gradientColors]; null spreads the colors evenly.
  List<double>? gradientPositions;

  /// Opacity applied on top of [color], from 0 to 255. Default 255. Setting it recomputes the drawn color.
  /// Only used by [FillType.COLOR].
  int get alpha => _alpha;
  set alpha(int value) {
    _alpha = value;
    _calculateFinalColor();
  }

  int _alpha = 255;

  /// Replaces [gradientColors] with the two given colors. Does not change [type].
  void setGradientColors(ui.Color startColor, ui.Color endColor) {
    gradientColors = [startColor, endColor];
  }

  void _calculateFinalColor() {
    final color = _color;
    if (color == null) {
      _finalColor = null;
    } else {
      final alpha =
          (((color.toARGB32() >>> 24) / 255.0) * (_alpha / 255.0) * 255.0)
              .floor();
      _finalColor = color.withAlpha(alpha & 0xff);
    }
  }

  /// Fills the rectangle given in pixels on [c].
  ///
  /// Solid colors clip the canvas to the rectangle; gradients set a shader on [paint] that stays
  /// there afterwards. Does nothing for [FillType.EMPTY] or when the data for the type is missing.
  ///
  /// Does nothing either when an edge is NaN: Skia draws nothing for such a rectangle, Flutter's canvas asserts.
  ///
  /// [gradientDirection] is the direction of a linear gradient; ignored by the other types.
  void fillRect(
    ui.Canvas c,
    ChartPaint paint,
    double left,
    double top,
    double right,
    double bottom,
    FillDirection gradientDirection,
  ) {
    if (left.isNaN || top.isNaN || right.isNaN || bottom.isNaN) return;
    switch (type) {
      case FillType.EMPTY:
        return;
      case FillType.COLOR:
        final finalColor = _finalColor;
        if (finalColor == null) return;
        final save = c.getSaveCount();
        c.save();
        c.clipRect(
          ui.Rect.fromLTRB(left, top, right, bottom),
          doAntiAlias: false,
        );
        c.drawColorP(finalColor);
        c.restoreToCount(save);
      case FillType.LINEAR_GRADIENT:
        final gradientColors = this.gradientColors;
        if (gradientColors == null || gradientColors.isEmpty) return;
        final gradient = ui.Gradient.linear(
          ui.Offset(
            _toIntToFloat(
              gradientDirection == FillDirection.RIGHT ? right : left,
            ),
            _toIntToFloat(gradientDirection == FillDirection.UP ? bottom : top),
          ),
          ui.Offset(
            _toIntToFloat(
              gradientDirection == FillDirection.RIGHT
                  ? left
                  : gradientDirection == FillDirection.LEFT
                  ? right
                  : left,
            ),
            _toIntToFloat(
              gradientDirection == FillDirection.UP
                  ? top
                  : gradientDirection == FillDirection.DOWN
                  ? bottom
                  : top,
            ),
          ),
          _gradientColorArray(gradientColors),
          _gradientPositionArray(gradientColors),
          ui.TileMode.mirror,
        );
        paint.shader = gradient;
        c.drawRectP(MutableRect(left, top, right, bottom), paint);
      case FillType.DRAWABLE:
        final drawable = this.drawable;
        if (drawable == null) return;
        drawable.draw(
          c,
          MutableRect(
            _toIntToFloat(left),
            _toIntToFloat(top),
            _toIntToFloat(right),
            _toIntToFloat(bottom),
          ),
        );
    }
  }

  /// Fills [path], given in pixels, on [c].
  ///
  /// Gradients run from the top left to the bottom right of the canvas and set a shader on [paint]
  /// that stays there afterwards. Does nothing for [FillType.EMPTY] or when the data for the type is missing.
  ///
  /// [clipRect]: for a solid color, non-null clips to the path instead of drawing it with [paint];
  /// for a drawable it sets the drawable bounds, the whole canvas when null.
  ///
  /// [canvasSize] stands in for Android's `Canvas.getWidth()` / `getHeight()`, which a [ui.Canvas] does not know;
  /// pass the size of the canvas (for a chart, its width and height).
  void fillPath(
    ui.Canvas c,
    ui.Path path,
    ChartPaint paint,
    MutableRect? clipRect,
    ui.Size canvasSize,
  ) {
    switch (type) {
      case FillType.EMPTY:
        return;
      case FillType.COLOR:
        final finalColor = _finalColor;
        if (finalColor == null) return;
        if (clipRect != null) {
          final save = c.getSaveCount();
          c.save();
          c.clipPath(path);
          c.drawColorP(finalColor);
          c.restoreToCount(save);
        } else {
          final previous = paint.style;
          final previousColor = paint.color;
          paint.style = PaintStyle.FILL;
          paint.color = finalColor;
          c.drawPathP(path, paint);
          paint.color = previousColor;
          paint.style = previous;
        }
      case FillType.LINEAR_GRADIENT:
        final gradientColors = this.gradientColors;
        if (gradientColors == null || gradientColors.isEmpty) return;
        final gradient = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(canvasSize.width, canvasSize.height),
          _gradientColorArray(gradientColors),
          _gradientPositionArray(gradientColors),
          ui.TileMode.mirror,
        );
        paint.shader = gradient;
        c.drawPathP(path, paint);
      case FillType.DRAWABLE:
        final drawable = this.drawable;
        if (drawable == null) return;
        final save = c.getSaveCount();
        c.save();
        c.clipPath(path);
        drawable.draw(
          c,
          MutableRect(
            clipRect != null ? _toIntToFloat(clipRect.left) : 0,
            clipRect != null ? _toIntToFloat(clipRect.top) : 0,
            clipRect != null ? _toIntToFloat(clipRect.right) : canvasSize.width,
            clipRect != null
                ? _toIntToFloat(clipRect.bottom)
                : canvasSize.height,
          ),
        );
        c.restoreToCount(save);
    }
  }

  /// `LinearGradient` needs at least two colors, so a single color becomes a flat gradient.
  List<ui.Color> _gradientColorArray(List<ui.Color> colors) =>
      colors.length == 1 ? [colors[0], colors[0]] : List.of(colors);

  /// Positions are only used when there is one for each color.
  List<double>? _gradientPositionArray(List<ui.Color> colors) {
    final positions = gradientPositions;
    return positions != null &&
            positions.length == colors.length &&
            colors.length > 1
        ? List.of(positions)
        : null;
  }

  /// Kotlin's `Float.toInt().toFloat()` of a px value: truncates towards zero to whole device px
  /// (`Utils.devicePixelRatio`), saturating at the Int range, NaN becomes 0.
  static double _toIntToFloat(double value) => truncateToDevicePx(value);
}
