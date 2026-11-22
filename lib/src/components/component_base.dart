// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/ComponentBase.kt
import 'dart:ui';

import '../graphics/typeface.dart';

/// Settings shared by every chart component that draws text: the axes, the legend, limit lines and the description.
abstract class ComponentBase {
  /// Whether the component is drawn at all. Default true.
  bool isEnabled = true;

  /// Horizontal space in dp kept between the component's labels and whatever they sit next to. Default 5.
  double xOffset = 5;

  /// Vertical space in dp kept between the component's labels and whatever they sit next to. Default 5.
  double yOffset = 5;

  /// Typeface for the labels, or null for the default typeface.
  Typeface? typeface;

  double _textSize = 10;

  /// Label text size in dp, clamped to 6..24. Default 10.
  double get textSize => _textSize;
  set textSize(double value) {
    // Kotlin coerceIn(6f, 24f): a NaN passes through unchanged.
    _textSize = value < 6
        ? 6
        : value > 24
        ? 24
        : value;
  }

  /// Label text color. Default black.
  Color textColor = const Color(0xFF000000);
}
