// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/Range.kt

/// The value span one value of a stacked bar entry covers, from where the previous value ended to where
/// this one ends. Bar entries build one range per stack value; `BarHighlighter` uses them to find the
/// touched stack value.
class Range {
  /// Value where the span starts, excluded from it.
  double from;

  /// Value where the span ends, included in it.
  double to;

  /// Creates the span from [from] (excluded) to [to] (included).
  Range(this.from, this.to);

  /// True if [value] lies inside the range, excluding [from] and including [to].
  bool contains(double value) => value > from && value <= to;

  /// True if [value] lies beyond [to].
  bool isLarger(double value) => value > to;

  /// True if [value] lies before [from].
  bool isSmaller(double value) => value < from;
}
