// Ported from MPChartExample: custom/RadarMarkerView.kt, with res/layout/radar_markerview.xml drawn on the chart
// canvas. The layout is 55dp by 40dp with the bitmap radar_marker.png as its background, a triangle that points down;
// the bitmap is drawn as a path, so no image has to be decoded before the first highlight.
import 'package:flutter/painting.dart';
import 'package:mp_flutter_chart/core.dart';

import '../notimportant/demo_base.dart';

/// Shows the highlighted value as a percentage on a triangle whose tip is 10 px above the highlighted point.
class RadarMarkerView extends MarkerView {
  final DecimalFormat _format = DecimalFormat('##0');

  final TextPainter _textPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…');

  /// `android:layout_width="55dp"` and `android:layout_height="40dp"`.
  final FSize _size = FSize(55, 40);

  /// tvContent's `layout_marginTop`.
  static const double _marginTop = 3;

  static final Paint _fill = Paint()
    ..color = const Color(0xFF79A2AF)
    ..isAntiAlias = true;

  static final Paint _stroke = Paint()
    ..color = const Color(0xFF3E5D67)
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  void refreshContent(Entry e, Highlight highlight) {
    _textPainter
      ..text = TextSpan(
        text: '${_format.format(e.y)} %',
        style: tfLight.apply(const TextStyle(color: Color(0xFFFFFFFF), fontSize: 10)),
      )
      ..layout(maxWidth: _size.width - 10);
    super.refreshContent(e, highlight);
  }

  /// `MPPointF(-(width / 2f), -height.toFloat() - 10)`.
  @override
  MPPointF get offset => MPPointF(-(width / 2), -height - 10);

  @override
  FSize measure() => _size;

  @override
  void drawContent(Canvas canvas) {
    // radar_marker.png is 400 x 300: a triangle from (29, 4) and (371, 4) down to (200, 296) with a 3 px outline,
    // stretched to the view.
    final sx = _size.width / 400;
    final sy = _size.height / 300;
    final triangle = Path()
      ..moveTo(29 * sx, 4 * sy)
      ..lineTo(371 * sx, 4 * sy)
      ..lineTo(200 * sx, 296 * sy)
      ..close();
    canvas.drawPath(triangle, _fill);
    canvas.drawPath(triangle, _stroke..strokeWidth = 3 * sx);
    _textPainter.paint(canvas, Offset((_size.width - _textPainter.width) / 2, _marginTop));
  }
}
