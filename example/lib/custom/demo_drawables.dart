// The drawables of MPChartExample's res/ that its pages hand to a chart, as [ChartDrawable]s that paint themselves:
// res/drawable-hdpi/star.png, the icon of the entries, and res/drawable/fade_red.xml, the fill of LineChartActivity1.
// A painted drawable is there at once, where a bitmap would have to be decoded before the page could build its
// entries.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:mp_flutter_chart/core.dart';

/// `ContextCompat.getDrawable(this, R.drawable.star)`: a sand coloured star on a red disc.
///
/// star.png is 32 px for hdpi (240 dpi), so its intrinsic size is 32 / 1.5 dp, 21 as a whole number.
final ChartDrawable starDrawable = PainterDrawable(_paintStar, width: 21, height: 21);

final ui.Paint _starDisc = ui.Paint()
  ..color = const ui.Color(0xFFC75C5C)
  ..isAntiAlias = true;

final ui.Paint _starShape = ui.Paint()
  ..color = const ui.Color(0xFFF5CF87)
  ..isAntiAlias = true;

/// Paints star.png into [size]: in the 32 px bitmap the disc has a radius of 16 and the star, centred at (16, 15),
/// an outer radius of 10 and an inner radius of 4.5.
void _paintStar(ui.Canvas canvas, ui.Size size) {
  final scale = size.shortestSide / 32;
  final center = ui.Offset(size.width / 2, size.height / 2);
  canvas.drawCircle(center, 16 * scale, _starDisc);

  final star = ui.Path();
  for (var i = 0; i < 10; i++) {
    final radius = (i.isEven ? 10 : 4.5) * scale;
    final angle = -math.pi / 2 + i * math.pi / 5;
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy - scale + radius * math.sin(angle);
    if (i == 0) {
      star.moveTo(x, y);
    } else {
      star.lineTo(x, y);
    }
  }
  canvas.drawPath(star..close(), _starShape);
}

/// `ContextCompat.getDrawable(this, R.drawable.fade_red)`: a shape with a linear gradient at an angle of 90 degrees,
/// from transparent red at the bottom of its bounds to opaque red at the top. Like the shape, it has no intrinsic
/// size.
final ChartDrawable fadeRedDrawable = PainterDrawable(
  (canvas, size) {
    final rect = ui.Offset.zero & size;
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = ui.Gradient.linear(rect.bottomLeft, rect.topLeft, const [
          ui.Color(0x00FF0000),
          ui.Color(0xFFFF0000),
        ]),
    );
  },
  width: -1,
  height: -1,
);
