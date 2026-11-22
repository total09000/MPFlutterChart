// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/LimitLine.kt
import 'dart:ui';

import '../graphics/chart_paint.dart';
import 'component_base.dart';

/// Placement of the label of a [LimitLine]. For a horizontal line on a y-axis, LEFT and RIGHT pick the end of the line
/// and TOP and BOTTOM the side of it. For a vertical line on an x-axis, LEFT and RIGHT pick the side of the line and
/// TOP and BOTTOM the end.
///
/// Kotlin's `LimitLine.LimitLabelPosition`; a top-level enum because Dart has no nested types.
enum LimitLabelPosition { LEFT_TOP, LEFT_BOTTOM, RIGHT_TOP, RIGHT_BOTTOM }

/// A line at a fixed value on an axis with an optional label, for example a target or a threshold. Add it with
/// `AxisBase.addLimitLine`: on a `YAxis` it runs horizontally, on an `XAxis` vertically.
class LimitLine extends ComponentBase {
  /// The value in value space at which the line is drawn.
  final double limit;

  /// Text drawn next to the line; an empty string draws no label.
  String label;

  /// Creates a limit line at [limit] with an optional [label].
  LimitLine(this.limit, [this.label = '']);

  double _lineWidth = 1;

  /// Width of the line in dp, clamped to 0.2..12. Thicker lines cost more performance. Default 1.
  double get lineWidth => _lineWidth;
  set lineWidth(double value) {
    // Kotlin coerceIn(0.2f, 12f): a NaN passes through unchanged.
    _lineWidth = value < 0.2
        ? 0.2
        : value > 12
        ? 12
        : value;
  }

  /// Color of the line. Default a light red.
  Color lineColor = const Color.fromARGB(255, 237, 91, 91);

  /// Paint style used for the label text. Default [PaintStyle.FILL_AND_STROKE].
  PaintStyle textStyle = PaintStyle.FILL_AND_STROKE;

  /// Dash pattern of the line, or null for a solid line. See [enableDashedLine].
  DashPathEffect? dashPathEffect;

  /// Where the label is drawn relative to the line. Not supported by the radar chart. Default
  /// [LimitLabelPosition.RIGHT_TOP].
  LimitLabelPosition labelPosition = LimitLabelPosition.RIGHT_TOP;

  /// Draws the line dashed.
  ///
  /// [lineLength] is the length of each dash, [spaceLength] the length of the gap between two dashes and [phase] the
  /// offset into the dash pattern, normally 0, all in device px (as on Android: the canvas divides them by
  /// `Utils.devicePixelRatio`).
  void enableDashedLine(double lineLength, double spaceLength, double phase) {
    dashPathEffect = DashPathEffect([lineLength, spaceLength], phase);
  }

  /// Draws the line solid again.
  void disableDashedLine() {
    dashPathEffect = null;
  }

  /// Whether the line is drawn dashed.
  bool get isDashedLineEnabled => dashPathEffect != null;
}
