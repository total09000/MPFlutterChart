// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/Description.kt
import '../graphics/chart_paint.dart';
import '../utils/mp_point_f.dart';
import 'component_base.dart';

/// A short text drawn on the chart, by default at the bottom right corner of the content area.
class Description extends ComponentBase {
  /// Creates a description with the default settings.
  Description() {
    textSize = 8;
  }

  /// The text to draw. Default "Description Label".
  String text = 'Description Label';

  /// Fixed position of the text in px on the chart view, or null to place it at the bottom right using [xOffset] and
  /// [yOffset].
  MPPointF? position;

  /// Alignment of the text relative to its position. Default [PaintAlign.RIGHT].
  PaintAlign textAlign = PaintAlign.RIGHT;

  /// Places the text at a fixed position on the chart view.
  ///
  /// [x] is the x coordinate in px and [y] the y coordinate of the text baseline in px.
  void setPosition(double x, double y) {
    final current = position;
    if (current == null) {
      position = MPPointF.getInstance(x, y);
    } else {
      current.x = x;
      current.y = y;
    }
  }
}
