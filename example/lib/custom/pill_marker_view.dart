// Ported from MPChartExample: design/PillMarkerView.kt, with res/layout/marker_pill.xml drawn on the chart canvas.
//
// Kotlin's MarkerView inflates marker_pill.xml, a TextView with 10dp x 6dp padding, 12sp bold text and a
// GradientDrawable background with 8dp corners. The core MarkerView is a canvas marker (lib/src/components/
// marker_view.dart): [measure] reports the TextView's wrap_content size and [drawContent] paints its background and
// text, with a TextPainter for the TextView and an RRect for the GradientDrawable. Kotlin's `context` gives the
// inflated layout its density and font scale; here they are the devicePixelRatio and the TextScaler, which lay the
// padding and the text line out in whole device px as Android does (design/android_metrics.dart).
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:mp_flutter_chart/core.dart';

import '../design/android_metrics.dart';
import '../design/nightfall.dart';

/// A rounded label above the highlighted entry, filled with the theme's pill colors.
class PillMarkerView extends MarkerView {
  /// A pill in [theme]'s pill colors that shows what [label] returns for the highlighted entry, laid out in whole
  /// device px at [devicePixelRatio], with its 12sp text scaled by [textScaler] as the system font size scales it.
  PillMarkerView(
    NightfallTheme theme,
    this._label, {
    required double devicePixelRatio,
    required TextScaler textScaler,
  }) : _textColor = theme.pillText,
       _background = Paint()..color = theme.pillBackground,
       _paddingHorizontal = androidDimensionPx(
         _paddingHorizontalDp,
         devicePixelRatio,
       ),
       _paddingVertical = androidDimensionPx(
         _paddingVerticalDp,
         devicePixelRatio,
       ),
       _devicePixelRatio = devicePixelRatio,
       _textSize = androidTextSize(
         _textSizeSp,
         devicePixelRatio,
         textScaler: textScaler,
       ),
       _lineHeight = androidTextViewLineHeight(
         _textSizeSp,
         devicePixelRatio,
         textScaler: textScaler,
       ),
       _baseline = androidTextViewBaseline(
         _textSizeSp,
         devicePixelRatio,
         textScaler: textScaler,
       ) {
    _setText('');
  }

  final String Function(Entry e) _label;

  /// tvPill's text color, `theme.pillText`.
  final Color _textColor;

  /// The GradientDrawable's color, `theme.pillBackground`.
  final Paint _background;

  /// tvPill, laid out with its current text.
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  /// The size of the TextView, measured with wrap_content.
  final FSize _size = FSize();

  /// `android:paddingHorizontal="10dp"`.
  static const double _paddingHorizontalDp = 10;

  /// `android:paddingVertical="6dp"`.
  static const double _paddingVerticalDp = 6;

  /// `android:textSize="12sp"`.
  static const double _textSizeSp = 12;

  /// The GradientDrawable's `cornerRadius = Utils.convertDpToPixel(8f)`, a float that is not rounded to a whole px.
  static const double _cornerRadius = 8;

  /// The horizontal padding in whole device px (26 px at 2.625).
  final double _paddingHorizontal;

  /// The vertical padding in whole device px (16 px at 2.625).
  final double _paddingVertical;

  /// The density the pill is laid out at, for the text width's whole px.
  final double _devicePixelRatio;

  /// The text size in whole device px (32 px at 2.625), already scaled with the system font size.
  final double _textSize;

  /// The TextView's line (43 px at 2.625) and its baseline below the line's top (34 px).
  final double _lineHeight;
  final double _baseline;

  /// The text shown, tvPill's text.
  @visibleForTesting
  String get text => _text;
  String _text = '';

  /// `text.text = value`, with `android:textStyle="bold"`; lays the text out again. The TextPainter does not scale the
  /// text again: [_textSize] already follows the system font size, as an sp size does.
  void _setText(String value) {
    _text = value;
    _textPainter.text = TextSpan(
      text: value,
      style: TextStyle(
        color: _textColor,
        fontSize: _textSize,
        fontWeight: FontWeight.bold,
      ),
    );
    _textPainter.layout();
    // wrap_content: the text's width rounded up to a whole px, plus the padding.
    _size.width =
        androidTextViewWidth(_textPainter.width, _devicePixelRatio) +
        2 * _paddingHorizontal;
    _size.height = _lineHeight + 2 * _paddingVertical;
  }

  @override
  void refreshContent(Entry e, Highlight highlight) {
    _setText(_label(e));
    super.refreshContent(e, highlight);
  }

  /// Centred above the point, its bottom 14 dp above it. The setter is MarkerView's, as in Kotlin.
  @override
  MPPointF get offset =>
      MPPointF(-(width / 2), -height - Utils.convertDpToPixel(14));

  @override
  FSize measure() => _size;

  @override
  void drawContent(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, _size.width, _size.height),
        Radius.circular(Utils.convertDpToPixel(_cornerRadius)),
      ),
      _background,
    );
    // The text's baseline on the TextView's, below the top padding.
    _textPainter.paint(
      canvas,
      Offset(
        _paddingHorizontal,
        _paddingVertical +
            _baseline -
            _textPainter.computeDistanceToActualBaseline(
              TextBaseline.alphabetic,
            ),
      ),
    );
  }
}
