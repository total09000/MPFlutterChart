// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/Utils.kt
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter;

import '../formatter/default_value_formatter.dart';
import '../formatter/i_value_formatter.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_drawable.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../graphics/text_measure.dart';
import 'f_size.dart';
import 'float_math.dart';
import 'mp_point_f.dart';

/// Static helpers shared by all charts: dp to pixel conversion, text measuring and drawing, number
/// formatting and small geometry functions.
///
/// Kotlin's `init(Context)` is not needed: Flutter coordinates are logical pixels, which are dp. The density it read
/// is [devicePixelRatio], which the chart widgets set. Its `velocityTrackerPointerUpCleanUpIfNecessary` lives in
/// `ChartVelocityTracker`, and `postInvalidateOnAnimation` has no counterpart (the chart host schedules frames).
abstract final class Utils {
  /// Minimum touch velocity in pixels per second that counts as a fling.
  static int minimumFlingVelocity = 50;

  /// Maximum touch velocity in pixels per second used for fling calculations.
  static int maximumFlingVelocity = 8000;

  /// Factor that converts degrees to radians as a double.
  static const double DEG2RAD = 3.141592653589793 / 180.0;

  /// Factor that converts degrees to radians, from Kotlin's Float `3.1415927f / 180f`.
  static const double FDEG2RAD = 3.1415927 / 180.0;

  /// Smallest positive double value, useful for comparisons against zero.
  static const double DOUBLE_EPSILON = double.minPositive;

  /// Smallest positive Float value (Kotlin `Float.MIN_VALUE`), so a comparison against it is effectively a
  /// comparison for equality.
  static const double FLOAT_EPSILON = 1.401298464324817e-45;

  /// Device pixels per logical pixel, the counterpart of the display density Android's `Utils.init(context)` reads.
  ///
  /// The port draws in logical pixels; this ratio is used only to round lengths the way Kotlin's `Int` pixels are
  /// rounded, on the device pixel grid: text bounds and widths ([ChartPaint.getTextBounds], [ChartPaint.measureText],
  /// [calcTextWidth], [calcTextHeight]), the axis label sizes, icon positions and the dash lengths of
  /// `DashPathEffect`, which Kotlin takes as device pixels. It does not scale anything else.
  ///
  /// The chart widgets set it from their view (`MediaQuery.devicePixelRatioOf`, else the `View`'s ratio) before each
  /// layout and paint of the chart, and lay the chart out again when it changes. It is a global: with views of
  /// different ratios, the chart laid out or painted last sets it. Charts drawn without a widget (`Chart.toImage`,
  /// tests) use whatever it is, 1.0 unless set.
  static double devicePixelRatio = 1.0;

  /// Converts a dp value to pixels.
  ///
  /// Flutter draws in logical pixels, which are dp, so this returns [dp] unchanged.
  static double convertDpToPixel(double dp) => dp;

  /// Converts a pixel value to dp.
  ///
  /// Flutter draws in logical pixels, which are dp, so this returns [px] unchanged.
  static double convertPixelsToDp(double px) => px;

  /// Measures the width in pixels that [demoText] takes with [paint], in whole device pixels
  /// ([devicePixelRatio]) like Kotlin's `Int`.
  ///
  /// Avoid calling this repeatedly inside drawing code.
  static double calcTextWidth(ChartPaint paint, String demoText) =>
      truncateToDevicePx(paint.measureText(demoText));

  static final MutableRect _calcTextHeightRect = MutableRect();

  /// Measures the height in pixels of the glyph bounds of [demoText] with [paint] (approximate ink bounds, see
  /// [ChartPaint.getTextBounds]), in whole device pixels ([devicePixelRatio]) like Kotlin's `Int`.
  ///
  /// Avoid calling this repeatedly inside drawing code.
  static double calcTextHeight(ChartPaint paint, String demoText) {
    final r = _calcTextHeightRect;
    r.set(0, 0, 0, 0);
    paint.getTextBounds(demoText, r);
    return r.height();
  }

  static final FontMetrics _fontMetrics = FontMetrics();

  /// Returns the line height in pixels of [paint], measured from ascent to descent.
  ///
  /// [fontMetrics] is a buffer that receives the font metrics; a shared buffer is used when omitted.
  static double getLineHeight(ChartPaint paint, [FontMetrics? fontMetrics]) {
    final fm = fontMetrics ?? _fontMetrics;
    paint.getFontMetrics(fm);
    return fm.descent - fm.ascent;
  }

  /// Returns the extra spacing in pixels between two lines of [paint], the part of the font
  /// above the ascent plus the part below the descent.
  ///
  /// [fontMetrics] is a buffer that receives the font metrics; a shared buffer is used when omitted.
  static double getLineSpacing(ChartPaint paint, [FontMetrics? fontMetrics]) {
    final fm = fontMetrics ?? _fontMetrics;
    paint.getFontMetrics(fm);
    return fm.ascent - fm.top + fm.bottom;
  }

  static final MutableRect _calcTextSizeRect = MutableRect();

  /// Measures the glyph bounds of [demoText] with [paint] (see [ChartPaint.getTextBounds]) and writes the width and
  /// height in pixels, whole device pixels, into [outputFSize].
  ///
  /// Without [outputFSize] (Kotlin's two-argument overload) the result is a pooled [FSize]; recycle it with
  /// [FSize.recycleInstance] when done. Returns the size written to.
  static FSize calcTextSize(
    ChartPaint paint,
    String demoText, [
    FSize? outputFSize,
  ]) {
    final result = outputFSize ?? FSize.getInstance(0, 0);
    final r = _calcTextSizeRect;
    r.set(0, 0, 0, 0);
    paint.getTextBounds(demoText, r);
    result.width = r.width();
    result.height = r.height();
    return result;
  }

  static const List<int> _POW_10 = [
    1,
    10,
    100,
    1000,
    10000,
    100000,
    1000000,
    10000000,
    100000000,
    1000000000,
  ];

  /// Formatter with one decimal place, used by chart components that have no formatter of their own.
  static final IValueFormatter defaultValueFormatter = DefaultValueFormatter(1);

  /// Formats [number] with a fixed number of decimals, using a comma as the decimal separator.
  ///
  /// Zero returns "0". Values between -1 and 1 get a leading "0". NaN and infinite values return their
  /// `toString()`. The result is at most 35 characters.
  ///
  /// [digitCount] is the number of decimals to show, limited to 0..9. [separateThousands] is true to insert
  /// [separateChar] between groups of three integer digits; [separateChar] is the thousands separator, a dot by
  /// default.
  static String formatNumber(
    double number,
    int digitCount,
    bool separateThousands, [
    String separateChar = '.',
  ]) {
    final out = List<String>.filled(35, '');
    var value = number;
    var digits = digitCount < 0 ? 0 : digitCount;
    var neg = false;

    if (value == 0) return '0';
    if (!value.isFinite) return value.toString();

    final zero = value < 1 && value > -1;

    if (value < 0) {
      neg = true;
      value = -value;
    }

    if (digits >= _POW_10.length) {
      digits = _POW_10.length - 1;
    }

    value *= _POW_10[digits];
    var lval = _roundToLong(value);
    var ind = out.length - 1;
    var charCount = 0;
    var decimalPointAdded = false;

    while (lval != 0 || charCount < digits + 1) {
      final digit = lval % 10;
      lval ~/= 10;
      out[ind--] = String.fromCharCode(0x30 + digit);
      charCount++;

      if (charCount == digits) {
        out[ind--] = ',';
        charCount++;
        decimalPointAdded = true;
      } else if (separateThousands && lval != 0 && charCount > digits) {
        if (decimalPointAdded) {
          if ((charCount - digits) % 4 == 0) {
            out[ind--] = separateChar;
            charCount++;
          }
        } else {
          if ((charCount - digits) % 4 == 3) {
            out[ind--] = separateChar;
            charCount++;
          }
        }
      }
    }

    if (zero) {
      out[ind--] = '0';
      charCount += 1;
    }

    if (neg) {
      out[ind--] = '-';
      charCount += 1;
    }

    final start = out.length - charCount;
    return out.sublist(start).join();
  }

  /// Rounds [number] to one significant digit, for example 123 to 100, 0.0234 to 0.02 and 150 to 200.
  ///
  /// Infinite, NaN and zero input return 0. Axis renderers use this to pick a readable label interval.
  ///
  /// Kotlin computes the magnitude and the result in Float; this port rounds to Float at the same places, so the
  /// result is the Kotlin Float value (1234 gives 999.99994, the Float `1 / 0.001f`) and the Float overflow
  /// behaviour is kept (a magnitude above Float range gives 0, one below it gives NaN).
  static double roundToNextSignificant(double number) {
    if (number.isInfinite || number.isNaN || number == 0.0) return 0;

    final d = toKotlinFloat(
      _log10(number < 0 ? -number : number),
    ).ceilToDouble();
    final pw = 1 - kotlinFloatToInt(d);
    final magnitude = toKotlinFloat(math.pow(10.0, pw.toDouble()).toDouble());
    final shifted = _roundToLong(number * magnitude);
    return toKotlinFloat(toKotlinFloat(shifted.toDouble()) / magnitude);
  }

  /// Returns how many decimals are needed to show [number] with two digits beyond its magnitude,
  /// for example 0 for 100, 2 for 5 and 4 for 0.02.
  ///
  /// Charts use this to build their default value formatter. As in Kotlin, [number] is taken as a Float.
  static int getDecimals(double number) {
    final n = toKotlinFloat(number);
    if (n == 0) return 0;
    final i = roundToNextSignificant(n);
    if (i == 0 || i.isInfinite) return 0;
    return kotlinFloatToInt((-toKotlinFloat(_log10(i))).ceilToDouble()) + 2;
  }

  static final ByteData _nextUpBits = ByteData(8);

  /// Returns the smallest double that is greater than [d]. Positive infinity is returned unchanged.
  static double nextUp(double d) {
    if (d == double.infinity) return d;
    final value = d + 0.0;
    // Kotlin adds or subtracts 1 on the raw 64 bits; done on two 32-bit halves so it also works on the web.
    final bits = _nextUpBits..setFloat64(0, value);
    var hi = bits.getUint32(0);
    var lo = bits.getUint32(4);
    if (value >= 0.0) {
      lo = (lo + 1) & 0xFFFFFFFF;
      if (lo == 0) hi = (hi + 1) & 0xFFFFFFFF;
    } else {
      if (lo == 0) {
        lo = 0xFFFFFFFF;
        hi = (hi - 1) & 0xFFFFFFFF;
      } else {
        lo -= 1;
      }
    }
    bits
      ..setUint32(0, hi)
      ..setUint32(4, lo);
    return bits.getFloat64(0);
  }

  /// Calculates the point at [dist] pixels from [center] at [angle] degrees, measured clockwise from
  /// 3 o'clock, and writes it into [outputPoint].
  ///
  /// Without [outputPoint] (Kotlin's three-argument overload) the result is a pooled [MPPointF]; recycle it with
  /// [MPPointF.recycleInstance] when done. Returns the point written to.
  static MPPointF getPosition(
    MPPointF center,
    double dist,
    double angle, [
    MPPointF? outputPoint,
  ]) {
    final p = outputPoint ?? MPPointF.getInstance(0, 0);
    p.x = center.x + dist * math.cos(angle * DEG2RAD);
    p.y = center.y + dist * math.sin(angle * DEG2RAD);
    return p;
  }

  /// Maps [angle] in degrees into the range 0 (inclusive) to 360 (exclusive). NaN and infinite angles give NaN.
  ///
  /// As in Kotlin, the angle is a Float: a tiny negative angle wraps to 0, not to just below 360.
  static double getNormalizedAngle(double angle) {
    final normalized = toKotlinFloat(angle).remainder(360.0);
    return normalized < 0
        ? toKotlinFloat(normalized + 360.0).remainder(360.0)
        : normalized;
  }

  /// Draws [drawable] centered on the pixel position ([x], [y]) at the given size.
  ///
  /// The canvas is translated and restored afterwards. [width] and [height] are in pixels. Kotlin's `Int` position
  /// is whole device pixels: the renderers pass [x] and [y] truncated on the device pixel grid
  /// ([devicePixelRatio]), and half the size is truncated there too, as Kotlin's `width / 2` is.
  static void drawImage(
    ui.Canvas canvas,
    ChartDrawable drawable,
    double x,
    double y,
    int width,
    int height,
  ) {
    // As in Kotlin, the pooled point is not recycled.
    final drawOffset = MPPointF.getInstance();
    drawOffset.x = x - truncateToDevicePx(width / 2);
    drawOffset.y = y - truncateToDevicePx(height / 2);

    final saveId = canvas.getSaveCount();
    canvas.save();
    canvas.translate(drawOffset.x, drawOffset.y);
    // Kotlin keeps the drawable's previous bounds origin, (0, 0) for a drawable whose bounds were never set; a
    // ChartDrawable has no bounds of its own (see ChartDrawable).
    drawable.draw(
      canvas,
      MutableRect(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.restoreToCount(saveId);
  }

  static final MutableRect _drawTextRectBuffer = MutableRect();
  static final FontMetrics _fontMetricsBuffer = FontMetrics();

  /// Draws a single line of text at the pixel position ([x], [y]), optionally rotated.
  ///
  /// The text alignment of [paint] is temporarily set to left and restored afterwards.
  ///
  /// [anchor] says which point of the text box sits on ([x], [y]), from (0, 0) top left to (1, 1) bottom right.
  /// [angleDegrees] is the rotation around the anchor in degrees, clockwise.
  static void drawXAxisValue(
    ui.Canvas c,
    String text,
    double x,
    double y,
    ChartPaint paint,
    MPPointF anchor,
    double angleDegrees,
  ) {
    var drawOffsetX = 0.0;
    var drawOffsetY = 0.0;

    paint.getFontMetrics(_fontMetricsBuffer);
    final lineHeight = paint.getFontSpacing();
    paint.getTextBounds(text, _drawTextRectBuffer);

    drawOffsetX -= _drawTextRectBuffer.left;
    drawOffsetY += -_fontMetricsBuffer.ascent;

    final originalTextAlign = paint.textAlign;
    paint.textAlign = PaintAlign.LEFT;

    if (angleDegrees != 0) {
      drawOffsetX -= _drawTextRectBuffer.width() * 0.5;
      drawOffsetY -= lineHeight * 0.5;

      var translateX = x;
      var translateY = y;

      if (anchor.x != 0.5 || anchor.y != 0.5) {
        final rotatedSize = getSizeOfRotatedRectangleByDegrees(
          _drawTextRectBuffer.width(),
          lineHeight,
          angleDegrees,
        );
        translateX -= rotatedSize.width * (anchor.x - 0.5);
        translateY -= rotatedSize.height * (anchor.y - 0.5);
        FSize.recycleInstance(rotatedSize);
      }

      c.save();
      c.translate(translateX, translateY);
      c.rotate(angleDegrees * DEG2RAD);
      c.drawText(text, drawOffsetX, drawOffsetY, paint);
      c.restore();
    } else {
      if (anchor.x != 0 || anchor.y != 0) {
        drawOffsetX -= _drawTextRectBuffer.width() * anchor.x;
        drawOffsetY -= lineHeight * anchor.y;
      }
      drawOffsetX += x;
      drawOffsetY += y;
      c.drawText(text, drawOffsetX, drawOffsetY, paint);
    }

    paint.textAlign = originalTextAlign;
  }

  /// Draws an already laid out multi-line text at the pixel position ([x], [y]), optionally rotated.
  ///
  /// Kotlin's public `drawMultilineText(Canvas, StaticLayout, …)` overload; `StaticLayout` is Android only, so here
  /// it is the implementation of [drawMultilineText]. [layoutWidth] is the width the text was laid out to
  /// (`StaticLayout.getWidth()`), not the width of its longest line.
  static void _drawMultilineTextLayout(
    ui.Canvas c,
    TextPainter textLayout,
    double layoutWidth,
    double x,
    double y,
    ChartPaint paint,
    MPPointF anchor,
    double angleDegrees,
  ) {
    var drawOffsetX = 0.0;
    var drawOffsetY = 0.0;

    paint.getFontMetrics(_fontMetricsBuffer);
    final lineHeight = paint.getFontSpacing();
    final drawWidth = layoutWidth;
    final drawHeight = textLayout.computeLineMetrics().length * lineHeight;

    // As in Kotlin, this reads the text bounds of the last drawXAxisValue call.
    drawOffsetX -= _drawTextRectBuffer.left;
    drawOffsetY += drawHeight;

    final originalTextAlign = paint.textAlign;
    paint.textAlign = PaintAlign.LEFT;

    if (angleDegrees != 0) {
      drawOffsetX -= drawWidth * 0.5;
      drawOffsetY -= drawHeight * 0.5;

      var translateX = x;
      var translateY = y;

      if (anchor.x != 0.5 || anchor.y != 0.5) {
        final rotatedSize = getSizeOfRotatedRectangleByDegrees(
          drawWidth,
          drawHeight,
          angleDegrees,
        );
        translateX -= rotatedSize.width * (anchor.x - 0.5);
        translateY -= rotatedSize.height * (anchor.y - 0.5);
        FSize.recycleInstance(rotatedSize);
      }

      c.save();
      c.translate(translateX, translateY);
      c.rotate(angleDegrees * DEG2RAD);
      c.translate(drawOffsetX, drawOffsetY);
      textLayout.paint(c, ui.Offset.zero);
      c.restore();
    } else {
      if (anchor.x != 0 || anchor.y != 0) {
        drawOffsetX -= drawWidth * anchor.x;
        drawOffsetY -= drawHeight * anchor.y;
      }
      drawOffsetX += x;
      drawOffsetY += y;
      c.save();
      c.translate(drawOffsetX, drawOffsetY);
      textLayout.paint(c, ui.Offset.zero);
      c.restore();
    }

    paint.textAlign = originalTextAlign;
  }

  /// Lays out [text] so it wraps within the width of [constrainedToSize] and draws it at the pixel
  /// position ([x], [y]), optionally rotated.
  ///
  /// Only the width of [constrainedToSize] is used; it is rounded up to whole device pixels ([devicePixelRatio]) and
  /// at least 1 device pixel. [anchor] says which point
  /// of the text box sits on ([x], [y]), from (0, 0) top left to (1, 1) bottom right. [angleDegrees] is the rotation
  /// around the anchor in degrees, clockwise.
  ///
  /// The text is laid out with `TextMeasure.layout` (Kotlin: `StaticLayout`, left aligned, no extra line spacing,
  /// no font padding) in the fill style of [paint].
  static void drawMultilineText(
    ui.Canvas c,
    String text,
    double x,
    double y,
    ChartPaint paint,
    FSize constrainedToSize,
    MPPointF anchor,
    double angleDegrees,
  ) {
    final width = math.max(
      ceilToDevicePx(constrainedToSize.width),
      oneDevicePx,
    );
    final textLayout = TextMeasure.layout(
      text,
      paint.textStyle,
      maxWidth: width,
    );
    _drawMultilineTextLayout(
      c,
      textLayout,
      width,
      x,
      y,
      paint,
      anchor,
      angleDegrees,
    );
  }

  /// Returns the bounding box size of [rectangleSize] after rotating it by [degrees].
  ///
  /// Kotlin's `getSizeOfRotatedRectangleByDegrees(FSize, Float)` overload; Dart has no overloading.
  ///
  /// The result is a pooled [FSize]; recycle it with [FSize.recycleInstance] when done.
  static FSize getSizeOfRotatedRectangleByDegreesFromSize(
    FSize rectangleSize,
    double degrees,
  ) {
    return getSizeOfRotatedRectangleByRadians(
      rectangleSize.width,
      rectangleSize.height,
      degrees * FDEG2RAD,
    );
  }

  /// Returns the bounding box size of [rectangleSize] after rotating it by [radians].
  ///
  /// Kotlin's `getSizeOfRotatedRectangleByRadians(FSize, Float)` overload; Dart has no overloading.
  ///
  /// The result is a pooled [FSize]; recycle it with [FSize.recycleInstance] when done.
  static FSize getSizeOfRotatedRectangleByRadiansFromSize(
    FSize rectangleSize,
    double radians,
  ) {
    return getSizeOfRotatedRectangleByRadians(
      rectangleSize.width,
      rectangleSize.height,
      radians,
    );
  }

  /// Returns the bounding box size of a [rectangleWidth] by [rectangleHeight] rectangle rotated by [degrees].
  ///
  /// The result is a pooled [FSize]; recycle it with [FSize.recycleInstance] when done.
  static FSize getSizeOfRotatedRectangleByDegrees(
    double rectangleWidth,
    double rectangleHeight,
    double degrees,
  ) {
    return getSizeOfRotatedRectangleByRadians(
      rectangleWidth,
      rectangleHeight,
      degrees * FDEG2RAD,
    );
  }

  /// Returns the bounding box size of a [rectangleWidth] by [rectangleHeight] rectangle rotated by [radians].
  ///
  /// The result is a pooled [FSize]; recycle it with [FSize.recycleInstance] when done.
  static FSize getSizeOfRotatedRectangleByRadians(
    double rectangleWidth,
    double rectangleHeight,
    double radians,
  ) {
    return FSize.getInstance(
      (rectangleWidth * math.cos(radians)).abs() +
          (rectangleHeight * math.sin(radians)).abs(),
      (rectangleWidth * math.sin(radians)).abs() +
          (rectangleHeight * math.cos(radians)).abs(),
    );
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Kotlin numeric semantics that Dart does not share.

  // Float rounding and Float.toInt() come from float_math.dart (toKotlinFloat, kotlinFloatToInt).

  static final int _LONG_MAX = int.parse('9223372036854775807');
  static final int _LONG_MIN = int.parse('-9223372036854775808');

  /// Kotlin `Double.roundToLong()`: `Math.round` (ties towards positive infinity, so -2.5 gives -2), saturating at
  /// the Long range; NaN throws.
  static int _roundToLong(double value) {
    if (value.isNaN) {
      throw ArgumentError('Cannot round NaN value.');
    }
    if (value >= 9223372036854775807.0) return _LONG_MAX;
    if (value <= -9223372036854775808.0) return _LONG_MIN;
    final f = value.floorToDouble();
    return (value - f >= 0.5 ? f + 1 : f).toInt();
  }

  /// `kotlin.math.log10`.
  static double _log10(double value) => math.log(value) / math.ln10;
}
