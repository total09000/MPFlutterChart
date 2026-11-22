// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/XAxis.kt
import 'axis_base.dart';

/// Placement of the x-axis labels: TOP above the content area, BOTTOM below it, BOTH_SIDED above and below,
/// TOP_INSIDE and BOTTOM_INSIDE inside the content area along its top or bottom edge.
///
/// Kotlin's `XAxis.XAxisPosition`; a top-level enum because Dart has no nested types.
enum XAxisPosition { TOP, BOTTOM, BOTH_SIDED, TOP_INSIDE, BOTTOM_INSIDE }

/// The horizontal axis of bar, line, scatter, candle and bubble charts, and the outer ring of a radar chart.
/// Its values are the entries' x values, not their indices. Not every setting applies to the radar chart.
class XAxis extends AxisBase {
  /// Width of the widest label in px, measured by the axis renderer. Whole device pixels (Kotlin's `Int`), so a
  /// fraction of a logical pixel when `Utils.devicePixelRatio` is not 1.
  ///
  /// Kotlin `internal set`: written by the axis renderer; do not change it.
  double labelWidth = 1;

  /// Height of the labels in px, measured by the axis renderer.
  ///
  /// Kotlin `internal set`: written by the axis renderer; do not change it.
  double labelHeight = 1;

  /// Width in px of the label bounds after rotating by [labelRotationAngle], measured by the axis renderer.
  ///
  /// Kotlin `internal set`: written by the axis renderer; do not change it.
  double labelRotatedWidth = 1;

  /// Height in px of the label bounds after rotating by [labelRotationAngle], measured by the axis renderer.
  ///
  /// Kotlin `internal set`: written by the axis renderer; do not change it.
  double labelRotatedHeight = 1;

  /// Rotation of the labels in degrees, clockwise for positive values. Default 0.
  double labelRotationAngle = 0;

  /// Whether the first and last label are moved inwards so they are not clipped at the content edge. Default false.
  bool isAvoidFirstLastClippingEnabled = false;

  /// Where the labels are drawn relative to the content area. Default [XAxisPosition.TOP].
  XAxisPosition position = XAxisPosition.TOP;

  /// Creates an x-axis with the default settings.
  XAxis() {
    yOffset = 4;
  }
}
