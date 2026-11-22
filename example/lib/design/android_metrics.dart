// Android's layout rounding, emulated for the ports of MPChartExample's XML layouts: DesignActivity's cards
// (activity_design.xml, design_card.xml) and PillMarkerView (marker_pill.xml).
//
// Android lays a View out in whole device pixels. A layout XML's dimensions (padding, margins, a fixed height, the text
// size) go through `Resources.getDimensionPixelSize`, which rounds dp × density to a whole px. A TextView is as tall as
// its font metrics rounded out to whole px, plus a whole-px line pitch for each line its text wraps onto, and, with
// wrap_content, as wide as its text rounded up to a whole px. Flutter keeps fractional logical sizes instead, so a port
// that writes the dp values as logical px drifts from Android by up to a pixel per dimension (C2 finding D5). These
// helpers give the logical size of what Android lays out, Android's px / devicePixelRatio, so the port's boxes land on
// the same device pixels. A Flutter devicePixelRatio is Android's `DisplayMetrics.density`.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// `TypedValue.complexToDimensionPixelSize`, which `Resources.getDimensionPixelSize` and the layout XML's dimension
/// attributes use: [value] (dp, or sp already scaled by the font size) times [density], rounded half away from zero to
/// whole px, and at least 1 px (or -1 px) for a non-zero value.
int androidDimensionPixelSize(double value, double density) {
  final f = value * density;
  final res = (f >= 0 ? f + 0.5 : f - 0.5).truncate();
  if (res != 0) return res;
  if (value == 0) return 0;
  return value > 0 ? 1 : -1;
}

/// [dp] as Android lays it out at [devicePixelRatio], in logical px: [androidDimensionPixelSize] / [devicePixelRatio].
/// At 2.625 (420 dpi), 4 dp is 11 px, 6 dp 16 px, 8 dp 21 px, 10 dp 26 px, 12 dp 32 px, 14 dp 37 px and 230 dp 604 px.
double androidDimensionPx(double dp, double devicePixelRatio) =>
    androidDimensionPixelSize(dp, devicePixelRatio) / devicePixelRatio;

/// Roboto's font bounding box, `head.yMax` and `-head.yMin` in 2048 units per em: Android's `Paint.FontMetrics.top`
/// is `-_robotoTop × size` and `bottom` is `_robotoBottom × size`.
const double _robotoTop = 2163 / 2048;
const double _robotoBottom = 555 / 2048;

/// Roboto's ascender and descender, `hhea.ascender` and `-hhea.descender` in 2048 units per em: Android's
/// `Paint.FontMetrics.ascent` is `-_robotoAscent × size` and `descent` is `_robotoDescent × size`. These are the
/// emulator's /system/fonts/Roboto-Regular.ttf (hhea ascender 1900, descender -500, lineGap 0). Its OS/2 table leaves
/// fsSelection's USE_TYPO_METRICS bit off, so Skia takes the hhea values, not OS/2's (typo 2146 / -555).
const double _robotoAscent = 1900 / 2048;
const double _robotoDescent = 500 / 2048;

/// The px size Android draws `android:textSize` [sp] at: TextView reads the attribute with getDimensionPixelSize
/// (TextView.java, `TextAppearance_textSize`), so the size is a whole px, after [textScaler] has scaled the sp as the
/// system font size scales it.
int _textSizePx(double sp, double devicePixelRatio, TextScaler textScaler) =>
    androidDimensionPixelSize(textScaler.scale(sp), devicePixelRatio);

/// `Paint.getFontMetricsInt` for Roboto at [size] px. hwui rounds Skia's metrics with `SkScalarFloorToInt` for the top,
/// `SkScalarCeilToInt` for the bottom, and `SkScalarRoundToInt`, floor(x + 0.5), for the ascent and the descent.
({int top, int ascent, int descent, int bottom}) _fontMetricsInt(int size) => (
  top: (-_robotoTop * size).floor(),
  ascent: (-_robotoAscent * size + 0.5).floor(),
  descent: (_robotoDescent * size + 0.5).floor(),
  bottom: (_robotoBottom * size).ceil(),
);

/// The text size of a TextView of [sp], in logical px: `android:textSize` rounded to a whole px at [devicePixelRatio]
/// (15 sp is 39 px at 2.625, 12 sp is 32 px). It is already scaled by [textScaler], so the text it sizes must not be
/// scaled again.
double androidTextSize(
  double sp,
  double devicePixelRatio, {
  TextScaler textScaler = TextScaler.noScaling,
}) => _textSizePx(sp, devicePixelRatio, textScaler) / devicePixelRatio;

/// The height of a one-line TextView of [sp], in logical px. With `includeFontPadding` (the default) the line runs from
/// `Paint.getFontMetricsInt().top` to its `bottom`, which are Roboto's bounding box at the px text size rounded out to
/// whole px: `ceil(fBottom) - floor(fTop)`. At 2.625, 15 sp is 53 px and 12 sp is 43 px.
double androidTextViewLineHeight(
  double sp,
  double devicePixelRatio, {
  TextScaler textScaler = TextScaler.noScaling,
}) => androidTextViewHeight(
  sp,
  devicePixelRatio,
  textScaler: textScaler,
  lines: 1,
);

/// How far apart the baselines of two lines of a TextView of [sp] are, in logical px: `descent - ascent` of
/// `Paint.getFontMetricsInt()`, Roboto's ascender and descender at the px text size each rounded to a whole px.
/// At 2.625, 15 sp is 36 + 10 = 46 px and 12 sp is 30 + 8 = 38 px.
double androidTextViewLinePitch(
  double sp,
  double devicePixelRatio, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final fm = _fontMetricsInt(_textSizePx(sp, devicePixelRatio, textScaler));
  return (fm.descent - fm.ascent) / devicePixelRatio;
}

/// The height of a TextView of [sp] whose text takes [lines] lines, in logical px. StaticLayout.out gives the first
/// line the font's top and the last line its bottom (`includeFontPadding`) and spaces the lines by the font's ascent
/// and descent, so the box is [androidTextViewLineHeight] plus [androidTextViewLinePitch] for each line after the
/// first: `(ceil(fBottom) - floor(fTop)) + (lines - 1) × (round(fDescent) - round(fAscent))`. At 2.625, two lines of
/// 15 sp are 53 + 46 = 99 px.
double androidTextViewHeight(
  double sp,
  double devicePixelRatio, {
  TextScaler textScaler = TextScaler.noScaling,
  required int lines,
}) {
  final fm = _fontMetricsInt(_textSizePx(sp, devicePixelRatio, textScaler));
  return (fm.bottom - fm.top + (lines - 1) * (fm.descent - fm.ascent)) /
      devicePixelRatio;
}

/// How far the baseline of a TextView's first line of [sp] sits below the box's top, in logical px: `-floor(fTop)`.
/// At 2.625, 15 sp is 42 px and 12 sp is 34 px.
double androidTextViewBaseline(
  double sp,
  double devicePixelRatio, {
  TextScaler textScaler = TextScaler.noScaling,
}) =>
    -_fontMetricsInt(_textSizePx(sp, devicePixelRatio, textScaler)).top /
    devicePixelRatio;

/// How far above a whole px a width measured in logical px may land and still count as that px. A logical width is
/// the engine's 32-bit float of px / devicePixelRatio, so a text exactly 64 px wide can come back as 64.0000012 px.
const double _pxTolerance = 1e-3;

/// The width of a wrap_content TextView's text, in logical px: TextView.onMeasure takes `ceil(desired width)`, the
/// text's advance rounded up to a whole px. [width] is the text's width in logical px as Flutter lays it out; a width
/// within [_pxTolerance] above a whole px counts as that px.
double androidTextViewWidth(double width, double devicePixelRatio) =>
    (width * devicePixelRatio - _pxTolerance).ceil() / devicePixelRatio;

/// A TextView of `android:textSize` [sp] with wrap_content width, as design_card.xml's are (no maxLines, singleLine
/// or ellipsize): [text] in [style] at the TextView's whole-px text size, wrapped at the width the parent gives. The
/// box comes from Android's metrics, not the font Flutter draws with, so it is the same on every platform: it is
/// [androidTextViewHeight] tall for the lines the text takes, with the first line's alphabetic baseline
/// [androidTextViewBaseline] below its top, and as wide as the unwrapped text rounded up to a whole px
/// ([androidTextViewWidth]), at most the parent's width, as TextView.onMeasure makes it. A text that wraps is
/// therefore as wide as the parent. The density and the system font size are the [MediaQuery]'s.
///
/// On Android each later line's baseline is one [androidTextViewLinePitch] below the one before. Flutter rounds the
/// height of a paragraph's lines to a whole logical px, so here the lines are that pitch rounded to a whole logical px
/// apart: at 2.625, 15 sp lines are 18 logical px (47.25 px) apart instead of 46 px, so the second line sits 1.25 px
/// lower than on Android, the third 2.5 px and so on, and the last line's glyphs can reach past the box's bottom.
/// Wrapped texts have not been checked on a device. Where a line breaks is up to Flutter's line breaker and the font
/// Flutter draws with, so a text that only just fits can take a line more or fewer than on Android.
class AndroidTextView extends StatelessWidget {
  /// [text] in [style], whose size is replaced by the TextView's for [sp].
  const AndroidTextView(
    this.text, {
    super.key,
    required this.sp,
    required this.style,
  });

  /// The text shown.
  final String text;

  /// `android:textSize`, in sp.
  final double sp;

  /// The colour, weight and so on of the text; its font size is set from [sp].
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final size = androidTextSize(sp, dpr, textScaler: scaler);
    return _TextViewBox(
      sp: sp,
      devicePixelRatio: dpr,
      textScaler: scaler,
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        // Every line is as tall, whatever the font's own metrics, so the box can count them.
        strutStyle: StrutStyle(
          fontSize: size,
          height: _paragraphLineHeight(sp, dpr, scaler) / size,
          forceStrutHeight: true,
        ),
        style: style.copyWith(fontSize: size),
      ),
    );
  }
}

/// The height of each line of an [AndroidTextView]'s paragraph, in logical px: [androidTextViewLinePitch] rounded to a
/// whole logical px, as Flutter's paragraph rounds a line's height (SkParagraph's `InternalLineMetrics::height`).
/// Asking for the rounded height keeps the line count exact if the engine stops rounding.
double _paragraphLineHeight(double sp, double dpr, TextScaler textScaler) =>
    math.max(
      1,
      androidTextViewLinePitch(sp, dpr, textScaler: textScaler).roundToDouble(),
    );

/// Lays [child], the text of a TextView of [sp], out in the TextView's box (see [AndroidTextView]). The child's lines
/// are [_paragraphLineHeight] each; it wraps at the parent's width, at the left, with its first baseline at
/// [androidTextViewBaseline].
class _TextViewBox extends SingleChildRenderObjectWidget {
  const _TextViewBox({
    required this.sp,
    required this.devicePixelRatio,
    required this.textScaler,
    required Widget super.child,
  });

  final double sp;
  final double devicePixelRatio;
  final TextScaler textScaler;

  @override
  _RenderTextViewBox createRenderObject(BuildContext context) =>
      _RenderTextViewBox(sp, devicePixelRatio, textScaler);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTextViewBox renderObject,
  ) {
    renderObject
      ..sp = sp
      ..devicePixelRatio = devicePixelRatio
      ..textScaler = textScaler;
  }
}

class _RenderTextViewBox extends RenderShiftedBox {
  _RenderTextViewBox(this._sp, this._devicePixelRatio, this._textScaler)
    : super(null);

  double get sp => _sp;
  double _sp;
  set sp(double value) {
    if (value == _sp) return;
    _sp = value;
    markNeedsLayout();
  }

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsLayout();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    markNeedsLayout();
  }

  /// The first line's baseline, below the box's top.
  double get _baseline =>
      androidTextViewBaseline(_sp, _devicePixelRatio, textScaler: _textScaler);

  /// The box's height for a child [childHeight] tall: one line per [_paragraphLineHeight].
  double _heightFor(double childHeight) {
    final lineHeight = _paragraphLineHeight(
      _sp,
      _devicePixelRatio,
      _textScaler,
    );
    return androidTextViewHeight(
      _sp,
      _devicePixelRatio,
      textScaler: _textScaler,
      lines: math.max(1, (childHeight / lineHeight).round()),
    );
  }

  /// The box's width: `ceil(desired width)` with the desired width the unwrapped text's
  /// (Layout.getDesiredWidthWithLimit), at most the parent's width (TextView.onMeasure, AT_MOST).
  double _widthIn(BoxConstraints constraints) => constraints.constrainWidth(
    androidTextViewWidth(
      child!.getMaxIntrinsicWidth(double.infinity),
      _devicePixelRatio,
    ),
  );

  /// The child wraps at the parent's width and is as tall as its lines.
  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  double computeMinIntrinsicWidth(double height) => androidTextViewWidth(
    child!.getMinIntrinsicWidth(height),
    _devicePixelRatio,
  );

  @override
  double computeMaxIntrinsicWidth(double height) => androidTextViewWidth(
    child!.getMaxIntrinsicWidth(height),
    _devicePixelRatio,
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _heightFor(child!.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _heightFor(child!.getMaxIntrinsicHeight(width));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(
        Size(
          _widthIn(constraints),
          _heightFor(
            child!.getDryLayout(_childConstraints(constraints)).height,
          ),
        ),
      );

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final childConstraints = _childConstraints(constraints);
    final childBaseline = child!.getDryBaseline(childConstraints, baseline);
    final childAlphabetic = child!.getDryBaseline(
      childConstraints,
      TextBaseline.alphabetic,
    );
    if (childBaseline == null || childAlphabetic == null) return null;
    return _baseline - childAlphabetic + childBaseline;
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      _baseline - child.getDistanceToBaseline(TextBaseline.alphabetic)!,
    );
    size = constraints.constrain(
      Size(_widthIn(constraints), _heightFor(child.size.height)),
    );
  }
}
