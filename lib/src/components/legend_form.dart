// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/Legend.kt (nested enum Legend.LegendForm)

/// Shape drawn in front of a legend label.
///
/// Kotlin's `Legend.LegendForm`; a top-level enum because Dart has no nested types.
enum LegendForm {
  /// No form, and no space kept for one.
  NONE,

  /// No form, but the space for one is kept.
  EMPTY,

  /// On an entry: the legend's `form`. On the legend itself: drawn as a circle.
  DEFAULT,

  /// A filled square.
  SQUARE,

  /// A filled circle.
  CIRCLE,

  /// A horizontal line using the legend's `formLineWidth` and `formLineDashEffect`.
  LINE,
}
