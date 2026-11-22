// Ported from MPChartExample: design/EasingCurveView.kt.
//
// The preview of an easing curve that AnimationPlaygroundActivity shows next to the name of the chosen curve: a
// CustomPaint that draws the curve from 0 to 1 between the guide lines of 0 and 1. The View's properties are the
// widget's fields; a new value repaints, as the View's setters call `invalidate()`. Not ported: the View's own size
// (a parent such as a SizedBox gives it, as the layout XML does); a dp is a logical pixel, so the density factors of
// the stroke widths and the inset are gone.
import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

/// EasingCurveView: draws the curve of an easing function from 0 to 1, with room for curves that overshoot, like
/// elastic and back.
class EasingCurveView extends StatelessWidget {
  const EasingCurveView({
    super.key,
    this.easing = Easing.Linear,
    this.curveColor = const Color(0xFF000000),
    this.guideColor = const Color(0xFF000000),
  });

  /// `easing`, the curve drawn.
  final EasingFunction easing;

  /// `curveColor`, the colour of the curve; a Paint's default black when not set.
  final Color curveColor;

  /// `guideColor`, the colour of the lines at 0 and 1; a Paint's default black when not set.
  final Color guideColor;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _EasingCurvePainter(easing, curveColor, guideColor), size: Size.infinite);
}

class _EasingCurvePainter extends CustomPainter {
  _EasingCurvePainter(this.easing, this.curveColor, this.guideColor);

  final EasingFunction easing;
  final Color curveColor;
  final Color guideColor;

  /// `onDraw`.
  @override
  void paint(Canvas canvas, Size size) {
    final curvePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = curveColor;
    final guidePaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1
      ..color = guideColor;

    const inset = 3.0;
    final w = size.width - 2 * inset;
    final h = size.height - 2 * inset;
    // The value range -0.4..1.4 keeps overshooting curves inside the view.
    double y(double value) => inset + h * (1.4 - value) / 1.8;

    canvas.drawLine(Offset(inset, y(0)), Offset(inset + w, y(0)), guidePaint);
    canvas.drawLine(Offset(inset, y(1)), Offset(inset + w, y(1)), guidePaint);

    final path = Path();
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = inset + w * t;
      if (i == 0) {
        path.moveTo(x, y(easing(t)));
      } else {
        path.lineTo(x, y(easing(t)));
      }
    }
    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(_EasingCurvePainter oldDelegate) =>
      oldDelegate.easing != easing || oldDelegate.curveColor != curveColor || oldDelegate.guideColor != guideColor;
}
