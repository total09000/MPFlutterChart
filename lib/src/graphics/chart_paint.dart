// Android shim: android.graphics.Paint (with Paint.Style, Paint.Align, Paint.FontMetrics, DashPathEffect) for MPAndroidChart v4.0.1 port
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../utils/float_math.dart';
import '../utils/utils.dart';
import 'mutable_rect.dart';
import 'roboto_glyph_extents.dart';
import 'text_measure.dart';
import 'typeface.dart';

/// How a shape is painted, like `Paint.Style`.
enum PaintStyle {
  /// Fill the shape.
  FILL,

  /// Stroke the outline of the shape.
  STROKE,

  /// Fill the shape and stroke its outline.
  FILL_AND_STROKE,
}

/// Where the x position of `drawText` sits on the text, like `Paint.Align`.
enum PaintAlign {
  /// x is the left edge of the text.
  LEFT,

  /// x is the horizontal center of the text.
  CENTER,

  /// x is the right edge of the text.
  RIGHT,
}

/// A dash pattern for stroked lines and paths, like `android.graphics.DashPathEffect`; applied by `dashPath`
/// (dash_path.dart).
class DashPathEffect {
  /// The lengths of the dashes and gaps in device pixels, as on Android, alternating on and off, starting with on.
  /// The `ChartCanvas` extension divides them by `Utils.devicePixelRatio` when it dashes a line.
  final List<double> intervals;

  /// The offset into [intervals] at which the pattern starts, in device pixels like [intervals].
  final double phase;

  /// Creates a dash pattern; like Android, [intervals] must hold at least two entries, and of an odd number of
  /// entries the last one is ignored. The intervals are copied.
  DashPathEffect(List<double> intervals, this.phase)
    : intervals = List<double>.unmodifiable(
        intervals.length < 2
            ? intervals
            : intervals.sublist(0, intervals.length & ~1),
      ) {
    if (intervals.length < 2) {
      throw ArgumentError.value(
        intervals,
        'intervals',
        'must contain at least two entries',
      );
    }
  }
}

/// The vertical metrics of a font in pixels, relative to the baseline, like `Paint.FontMetrics`: values above the
/// baseline are negative, values below it positive.
class FontMetrics {
  /// The highest point of any glyph above the baseline (negative).
  double top = 0;

  /// The recommended distance above the baseline for single spaced text (negative).
  double ascent = 0;

  /// The recommended distance below the baseline for single spaced text (positive).
  double descent = 0;

  /// The lowest point of any glyph below the baseline (positive).
  double bottom = 0;

  /// The recommended additional space between lines of text.
  double leading = 0;
}

/// The style and color of drawing, standing in for `android.graphics.Paint`.
///
/// Renderers keep Android's mutable form (`paint.color = ...; paint.textSize = ...; c.drawText(..., paint)`); the
/// `ChartCanvas` extension draws with it. The [ui.Paint] of [toPaint] and the [TextStyle]s for text are cached and
/// rebuilt only after a setter changed what they depend on. Text measurement goes through [TextMeasure].
class ChartPaint {
  /// Creates a paint with Android's defaults: opaque black, [PaintStyle.FILL], hairline stroke, butt caps, miter
  /// joins, [PaintAlign.LEFT], text size 12 and [Typeface.DEFAULT].
  ///
  /// Android's `Paint(Paint.ANTI_ALIAS_FLAG)` is `ChartPaint()`; a plain `Paint()` is `ChartPaint(antiAlias: false)`.
  ChartPaint({bool antiAlias = true}) : _isAntiAlias = antiAlias;

  Color _color = const Color(0xFF000000);
  PaintStyle _style = PaintStyle.FILL;
  double _strokeWidth = 0;
  double _textSize = 12;
  Typeface _typeface = Typeface.DEFAULT;
  StrokeCap _strokeCap = StrokeCap.butt;
  StrokeJoin _strokeJoin = StrokeJoin.miter;
  ui.Shader? _shader;
  BlendMode? _xfermode;
  bool _isAntiAlias;

  final ui.Paint _paint = ui.Paint();
  bool _paintDirty = true;
  TextStyle? _textStyle;
  TextStyle? _textStrokeStyle;
  bool _textStrokeStyleDirty = true;
  FontMetrics? _fontMetrics;

  /// The color, alpha included.
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    _paintDirty = true;
    _textStyle = null;
    _textStrokeStyleDirty = true;
  }

  /// The alpha of [color], 0 to 255; setting it keeps the red, green and blue of [color].
  int get alpha => (_color.a * 255).round();
  set alpha(int value) => color = _color.withAlpha(value);

  /// Whether shapes are filled, stroked or both.
  PaintStyle get style => _style;
  set style(PaintStyle value) {
    if (value == _style) return;
    _style = value;
    _paintDirty = true;
  }

  /// The stroke width in pixels; 0 draws a hairline.
  double get strokeWidth => _strokeWidth;
  set strokeWidth(double value) {
    if (value == _strokeWidth) return;
    _strokeWidth = value;
    _paintDirty = true;
    _textStrokeStyleDirty = true;
  }

  /// Where the x position of `drawText` sits on the text.
  PaintAlign textAlign = PaintAlign.LEFT;

  /// The text size in pixels.
  double get textSize => _textSize;
  set textSize(double value) {
    if (value == _textSize) return;
    _textSize = value;
    _invalidateText();
  }

  /// The typeface of text; setting null selects [Typeface.DEFAULT], like Android's `setTypeface(null)`.
  Typeface get typeface => _typeface;
  set typeface(Typeface? value) {
    final typeface = value ?? Typeface.DEFAULT;
    if (typeface == _typeface) return;
    _typeface = typeface;
    _invalidateText();
  }

  /// The dash pattern of lines and paths, or null for solid lines.
  DashPathEffect? pathEffect;

  /// The shape of stroke ends.
  StrokeCap get strokeCap => _strokeCap;
  set strokeCap(StrokeCap value) {
    if (value == _strokeCap) return;
    _strokeCap = value;
    _paintDirty = true;
    _textStrokeStyleDirty = true;
  }

  /// The shape of stroke corners.
  StrokeJoin get strokeJoin => _strokeJoin;
  set strokeJoin(StrokeJoin value) {
    if (value == _strokeJoin) return;
    _strokeJoin = value;
    _paintDirty = true;
    _textStrokeStyleDirty = true;
  }

  /// The shader of shapes (for example a gradient), or null to paint with [color].
  ui.Shader? get shader => _shader;
  set shader(ui.Shader? value) {
    if (identical(value, _shader)) return;
    _shader = value;
    _paintDirty = true;
  }

  /// The blend mode, standing in for `Paint.setXfermode(PorterDuffXfermode)`; null is source over.
  BlendMode? get xfermode => _xfermode;
  set xfermode(BlendMode? value) {
    if (value == _xfermode) return;
    _xfermode = value;
    _paintDirty = true;
  }

  /// Whether edges are antialiased.
  bool get isAntiAlias => _isAntiAlias;
  set isAntiAlias(bool value) {
    if (value == _isAntiAlias) return;
    _isAntiAlias = value;
    _paintDirty = true;
    _textStrokeStyleDirty = true;
  }

  void _invalidateText() {
    _textStyle = null;
    _textStrokeStyleDirty = true;
    _fontMetrics = null;
  }

  /// The [ui.Paint] for shapes; one instance per paint, updated only on the first call after a setter changed it.
  ///
  /// [PaintStyle.FILL_AND_STROKE] gives a filling paint; the `ChartCanvas` extension adds the stroke pass. Do not
  /// change the returned paint.
  ui.Paint toPaint() {
    if (_paintDirty) {
      _paint
        ..color = _color
        ..style = _style == PaintStyle.STROKE
            ? PaintingStyle.stroke
            : PaintingStyle.fill
        ..strokeWidth = _strokeWidth
        ..strokeCap = _strokeCap
        ..strokeJoin = _strokeJoin
        ..shader = _shader
        ..blendMode = _xfermode ?? BlendMode.srcOver
        ..isAntiAlias = _isAntiAlias;
      _paintDirty = false;
    }
    return _paint;
  }

  /// The style of filled text: [color], [textSize] and [typeface].
  TextStyle get textStyle => _textStyle ??= _typeface.apply(
    TextStyle(color: _color, fontSize: _textSize),
  );

  /// The style of the stroke pass of text drawn with [PaintStyle.STROKE] or [PaintStyle.FILL_AND_STROKE]: the
  /// outline in [color] with [strokeWidth], [strokeCap] and [strokeJoin].
  ///
  /// A [TextStyle] compares its foreground paint by identity, so equal settings must give the identical style or
  /// every frame would lay the label out again: styles are shared by their settings, and setting a value back (as the
  /// limit line renderers do every frame) returns the same instance.
  TextStyle get textStrokeStyle {
    final cached = _textStrokeStyle;
    if (cached != null && !_textStrokeStyleDirty) return cached;
    final key = (
      _color,
      _textSize,
      _typeface,
      _strokeWidth,
      _strokeCap,
      _strokeJoin,
      _isAntiAlias,
    );
    var style = _strokeStyles[key];
    if (style == null) {
      if (_strokeStyles.length >= _maxStrokeStyles) _strokeStyles.clear();
      style = _strokeStyles[key] = _typeface.apply(
        TextStyle(
          fontSize: _textSize,
          foreground: ui.Paint()
            ..color = _color
            ..style = PaintingStyle.stroke
            ..strokeWidth = _strokeWidth
            ..strokeCap = _strokeCap
            ..strokeJoin = _strokeJoin
            ..isAntiAlias = _isAntiAlias,
        ),
      );
    }
    _textStrokeStyleDirty = false;
    return _textStrokeStyle = style;
  }

  /// Stroke text styles by their settings; never changed once created.
  static final Map<
    (Color, double, Typeface, double, StrokeCap, StrokeJoin, bool),
    TextStyle
  >
  _strokeStyles = {};

  static const int _maxStrokeStyles = 256;

  /// The advance width of [text] in pixels, like `Paint.measureText`: the advance Flutter lays the text out with,
  /// rounded up to whole device pixels ([Utils.devicePixelRatio]), as Android rounds its summed advance up to a whole
  /// pixel.
  ///
  /// `drawText` aligns text by its unrounded advance, as Android does.
  double measureText(String text) {
    if (text.isEmpty) return 0;
    return ceilToDevicePx(_advance(text));
  }

  /// The unrounded advance of [text] as Flutter lays it out.
  double _advance(String text) =>
      text.isEmpty ? 0 : TextMeasure.layout(text, textStyle).width;

  /// Writes the bounds of [text] relative to its origin on the baseline into [bounds] (a new rectangle when
  /// omitted) and returns it, like `Paint.getTextBounds(text, 0, text.length, rect)`.
  ///
  /// Android reports the union of the glyphs' ink rectangles, rounded outwards to whole device pixels in an integer
  /// `Rect`. Flutter exposes no ink bounds, so they are approximated from a table of Roboto's glyph extents (Android's
  /// default font): the top and bottom are the highest and lowest ink of the glyphs, the left edge is the left side
  /// bearing of the first glyph with ink (after the advance of any glyphs before it, such as spaces), and the right
  /// edge is the advance of the text through the last glyph with ink, as Flutter lays it out (so kerning counts), less
  /// that glyph's right side bearing. The edges are rounded outwards on the device pixel grid of
  /// [Utils.devicePixelRatio].
  ///
  /// The table is used for every typeface and on every platform, so the bounds are exact only for Android's default
  /// font; other fonts get Roboto's extents. A character the table lacks (CJK, emoji and anything else outside Latin-1
  /// and a few symbols) counts as the line box: the font's ascent to descent, with no side bearings. Empty text, and
  /// text without ink (only spaces), give the empty rectangle at the origin.
  MutableRect getTextBounds(String text, [MutableRect? bounds]) {
    final r = bounds ?? MutableRect();
    final scale = _textSize / robotoUnitsPerEm;
    var top = double.infinity;
    var bottom = double.negativeInfinity;
    var firstInk = -1;
    var firstLeft = 0.0;
    var lastInkEnd = -1;
    var lastRightBearing = 0.0;
    var offset = 0;
    for (final codePoint in text.runes) {
      final start = offset;
      offset += codePoint > 0xFFFF ? 2 : 1;
      final double glyphTop, glyphBottom, left, rightBearing;
      final extents = robotoGlyphExtents(codePoint);
      if (extents == null) {
        final metrics = _metrics;
        glyphTop = metrics.ascent;
        glyphBottom = metrics.descent;
        left = 0;
        rightBearing = 0;
      } else {
        final (xMin, yMin, xMax, yMax, advance) = extents;
        if (xMin == 0 && yMin == 0 && xMax == 0 && yMax == 0) continue;
        glyphTop = -yMax * scale;
        glyphBottom = -yMin * scale;
        left = xMin * scale;
        rightBearing = (advance - xMax) * scale;
      }
      if (firstInk < 0) {
        firstInk = start;
        firstLeft = left;
      }
      lastInkEnd = offset;
      lastRightBearing = rightBearing;
      if (glyphTop < top) top = glyphTop;
      if (glyphBottom > bottom) bottom = glyphBottom;
    }
    if (firstInk < 0) {
      r.set(0, 0, 0, 0);
      return r;
    }
    final left = _advance(text.substring(0, firstInk)) + firstLeft;
    final right =
        _advance(
          lastInkEnd == text.length ? text : text.substring(0, lastInkEnd),
        ) -
        lastRightBearing;
    r.set(
      floorToDevicePx(left),
      floorToDevicePx(top),
      ceilToDevicePx(right),
      ceilToDevicePx(bottom),
    );
    return r;
  }

  /// Writes the font metrics of [textSize] and [typeface] into [metrics] (a new instance when omitted) and returns
  /// it, like `Paint.getFontMetrics`.
  ///
  /// Flutter reports only the line ascent and descent of the font, so [FontMetrics.top] equals the ascent,
  /// [FontMetrics.bottom] equals the descent and [FontMetrics.leading] is 0.
  FontMetrics getFontMetrics([FontMetrics? metrics]) {
    final source = _metrics;
    return (metrics ?? FontMetrics())
      ..top = source.top
      ..ascent = source.ascent
      ..descent = source.descent
      ..bottom = source.bottom
      ..leading = source.leading;
  }

  /// The recommended line spacing, `descent - ascent + leading`; this is what Android's
  /// `getFontMetrics(FontMetrics)` returns.
  double getFontSpacing() {
    final metrics = _metrics;
    return metrics.descent - metrics.ascent + metrics.leading;
  }

  /// The ascent of the font, negative, like `Paint.ascent()`.
  double ascent() => _metrics.ascent;

  /// The descent of the font, positive, like `Paint.descent()`.
  double descent() => _metrics.descent;

  FontMetrics get _metrics {
    final cached = _fontMetrics;
    if (cached != null) return cached;
    // An empty line still has the height of the font: ascent above the baseline, descent below it. Its metrics come
    // from the font, not from glyphs, so they do not depend on any text.
    final painter = TextMeasure.layout(
      '',
      _typeface.apply(TextStyle(fontSize: _textSize)),
    );
    final ascent = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final descent = painter.height - ascent;
    return _fontMetrics = FontMetrics()
      ..top = -ascent
      ..ascent = -ascent
      ..descent = descent
      ..bottom = descent;
  }

  /// Returns a new paint with the same settings, like Android's `Paint(Paint)`.
  ChartPaint copy() => ChartPaint(antiAlias: _isAntiAlias)
    .._color = _color
    .._style = _style
    .._strokeWidth = _strokeWidth
    ..textAlign = textAlign
    .._textSize = _textSize
    .._typeface = _typeface
    ..pathEffect = pathEffect
    .._strokeCap = _strokeCap
    .._strokeJoin = _strokeJoin
    .._shader = _shader
    .._xfermode = _xfermode;
}
