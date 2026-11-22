// Ported from MPChartExample: custom/MyMarkerView.kt, custom/XYMarkerView.kt and custom/StackedBarsMarkerView.kt,
// with res/layout/custom_marker_view.xml drawn on the chart canvas.
//
// Kotlin's three markers inflate the same layout and differ in the text they show, so the layout is the base class
// [CustomMarkerView] here and each marker sets its [CustomMarkerView.text] in `refreshContent`. The layout is a
// RelativeLayout 40dp high and as wide as its text, with the bitmap marker2.png as its background: a grey box with
// a pointer below its middle. The bitmap is drawn as a path, so no image has to be decoded before the first
// highlight. A view is at least as big as its background, and marker2.png is 180 px wide at every density.
import 'package:flutter/painting.dart';
import 'package:mp_flutter_chart/core.dart';

/// res/layout/custom_marker_view.xml: white 12sp text on the grey box of marker2.png, with the pointer of the box at
/// the highlighted point.
abstract class CustomMarkerView extends MarkerView {
  final TextPainter _textPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…');

  final FSize _size = FSize();

  /// `android:layout_height="40dp"`.
  static const double _height = 40;

  /// tvContent's `layout_marginLeft` and `layout_marginRight`.
  static const double _marginHorizontal = 5;

  /// tvContent's `layout_marginTop`.
  static const double _marginTop = 7;

  /// The width of marker2.png in px; the bitmap is in drawable-nodpi, so no density scales it.
  static const double _backgroundWidthPx = 180;

  /// The colour of marker2.png.
  static final Paint _background = Paint()
    ..color = const Color(0xFFB4B4B4)
    ..isAntiAlias = true;

  /// tvContent's text.
  String get text => _text;
  String _text = '';
  set text(String value) {
    _text = value;
    _textPainter
      ..text = TextSpan(text: value, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12))
      ..layout();
  }

  /// Above the highlighted point, centred on it: `MPPointF(-(width / 2f), -height.toFloat())`.
  @override
  MPPointF get offset => MPPointF(-(width / 2), -height);

  @override
  FSize measure() {
    final minimum = _backgroundWidthPx / Utils.devicePixelRatio;
    final wrapped = _textPainter.width + 2 * _marginHorizontal;
    _size.width = wrapped > minimum ? wrapped : minimum;
    _size.height = _height;
    return _size;
  }

  @override
  void drawContent(Canvas canvas) {
    final size = measure();
    // marker2.png is 180 x 99: the box from (2, 2) to (178, 75) and the pointer from (73, 75) and (103, 75) down to
    // (88, 95), stretched to the view.
    final sx = size.width / 180;
    final sy = size.height / 99;
    canvas.drawPath(
      Path()
        ..moveTo(2 * sx, 2 * sy)
        ..lineTo(178 * sx, 2 * sy)
        ..lineTo(178 * sx, 75 * sy)
        ..lineTo(103 * sx, 75 * sy)
        ..lineTo(88 * sx, 95 * sy)
        ..lineTo(73 * sx, 75 * sy)
        ..lineTo(2 * sx, 75 * sy)
        ..close(),
      _background,
    );
    _textPainter.paint(canvas, Offset((size.width - _textPainter.width) / 2, _marginTop));
  }
}

/// MyMarkerView: shows the y value of the highlighted entry without decimals, a candle's high.
class MyMarkerView extends CustomMarkerView {
  @override
  void refreshContent(Entry e, Highlight highlight) {
    text = e is CandleEntry ? Utils.formatNumber(e.high, 0, true) : Utils.formatNumber(e.y, 0, true);
    super.refreshContent(e, highlight);
  }
}

/// XYMarkerView: shows the x value as the x axis formats it and the y value with one decimal.
class XYMarkerView extends CustomMarkerView {
  XYMarkerView(this._xAxisValueFormatter);

  final IAxisValueFormatter _xAxisValueFormatter;

  final DecimalFormat _format = DecimalFormat('###.0');

  @override
  void refreshContent(Entry e, Highlight highlight) {
    final x = _xAxisValueFormatter.getFormattedValue(e.x, (chartView! as BarLineChartBase).xAxis);
    text = 'x: $x, y: ${_format.format(e.y)}';
    super.refreshContent(e, highlight);
  }
}

/// StackedBarsMarkerView: shows the highlighted value of a stack, or the y value of an entry without one.
class StackedBarsMarkerView extends CustomMarkerView {
  @override
  void refreshContent(Entry e, Highlight highlight) {
    final stackValues = e is BarEntry ? e.stackValues : null;
    text = stackValues != null
        ? Utils.formatNumber(stackValues[highlight.stackIndex], 0, true)
        : Utils.formatNumber(e.y, 0, true);
    super.refreshContent(e, highlight);
  }
}
