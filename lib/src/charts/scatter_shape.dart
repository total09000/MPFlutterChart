// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/ScatterChart.kt (nested enum ScatterChart.ScatterShape)

/// Built-in shapes a scatter data set can be drawn with. Setting one on the data set picks its renderer.
///
/// Kotlin's `ScatterChart.ScatterShape`; a top-level enum in its own file because Dart has no nested types,
/// so that the scatter data set can use it without depending on the chart.
enum ScatterShape {
  SQUARE('SQUARE'),
  CIRCLE('CIRCLE'),
  TRIANGLE('TRIANGLE'),
  CROSS('CROSS'),
  X('X'),
  CHEVRON_UP('CHEVRON_UP'),
  CHEVRON_DOWN('CHEVRON_DOWN');

  const ScatterShape(this._shapeIdentifier);

  final String _shapeIdentifier;

  /// The identifier of the shape, its name (`SQUARE`, `CIRCLE`, …).
  @override
  String toString() => _shapeIdentifier;
}
