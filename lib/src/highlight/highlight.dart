// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/highlight/Highlight.kt
import '../components/y_axis_dependency.dart';
import '../utils/float_math.dart';

/// Identifies one selected value in a chart: which entry it is, where it sits on screen and which
/// data set, axis and, for stacked bars, which stack value it belongs to.
///
/// Highlighters create these from touch positions; charts pass them to `OnChartValueSelectedListener` and use them
/// to draw highlight indicators and markers. You can also create one yourself and pass it to
/// `chart.highlightValue(...)`.
///
/// Kotlin's four constructors are [Highlight.new], [Highlight.stacked], [Highlight.withPixels] and
/// [Highlight.stackedWithPixels], since Dart has no constructor overloading.
class Highlight {
  /// The x value of the highlighted entry in value space. For pie and radar charts this is the entry index.
  final double x;

  /// The y value of the highlighted entry in value space; NaN when the highlight was created from x only.
  final double y;

  double _xPx = 0;

  /// The x position of the highlighted entry in pixels; 0 when created without pixel positions.
  double get xPx => _xPx;

  double _yPx = 0;

  /// The y position of the highlighted entry in pixels; 0 when created without pixel positions.
  double get yPx => _yPx;

  /// Index of the data object inside a combined chart's data, for example 0 for its line data and 1 for
  /// its bar data. -1 for charts with a single data object.
  int dataIndex = -1;

  /// Index of the data set the highlighted entry belongs to.
  final int dataSetIndex;

  /// Index of the selected value inside a stacked bar entry; -1 when the entry is not stacked.
  int stackIndex = -1;

  AxisDependency? _axis;

  /// The y axis the highlighted entry is plotted against; null when unknown.
  AxisDependency? get axis => _axis;

  double _drawX = 0;

  /// The x position in pixels where this highlight was last drawn, set by the renderer through [setDraw].
  double get drawX => _drawX;

  double _drawY = 0;

  /// The y position in pixels where this highlight was last drawn, set by the renderer through [setDraw].
  double get drawY => _drawY;

  /// Creates a highlight from values only. Pixel positions stay 0 and the axis stays null.
  ///
  /// [x] is the x value of the entry, [y] the y value used to pick between entries that share the same x,
  /// [dataSetIndex] the index of the data set and [dataIndex] the index of the data object in a combined chart,
  /// -1 otherwise.
  Highlight(this.x, this.y, this.dataSetIndex, [this.dataIndex = -1]);

  /// Creates a highlight for one value of a stacked bar entry. The y value is NaN.
  ///
  /// [x] is the x value of the bar entry, [dataSetIndex] the index of the data set and [stackIndex] the index of
  /// the value inside the stack.
  Highlight.stacked(this.x, this.dataSetIndex, this.stackIndex)
    : y = double.nan;

  /// Creates a highlight with values, pixel position and axis, as the highlighters do.
  ///
  /// [x] / [y] are the values of the entry, [xPx] / [yPx] its position in pixels, [dataSetIndex] the index of the
  /// data set and [axis] the y axis the entry is plotted against.
  Highlight.withPixels(
    this.x,
    this.y,
    double xPx,
    double yPx,
    this.dataSetIndex,
    AxisDependency? axis,
  ) : _xPx = xPx,
      _yPx = yPx,
      _axis = axis;

  /// Creates a highlight for one value of a stacked bar entry with its pixel position and axis.
  ///
  /// [x] / [y] are the values of the bar entry, [xPx] the x position in pixels, [yPx] the y position of the
  /// selected stack value in pixels, [dataSetIndex] the index of the data set, [stackIndex] the index of the value
  /// inside the stack and [axis] the y axis the entry is plotted against.
  Highlight.stackedWithPixels(
    this.x,
    this.y,
    double xPx,
    double yPx,
    this.dataSetIndex,
    this.stackIndex,
    AxisDependency? axis,
  ) : _xPx = xPx,
      _yPx = yPx,
      _axis = axis;

  /// True if this highlight points at one value inside a stacked bar entry.
  bool get isStacked => stackIndex >= 0;

  /// Records the pixel position where this highlight was drawn, see [drawX] and [drawY].
  void setDraw(double x, double y) {
    _drawX = x;
    _drawY = y;
  }

  /// True if [h] selects the same entry: same data set index, x value, stack index and data index.
  /// The y value and pixel positions are not compared. Null returns false.
  bool equalTo(Highlight? h) {
    if (h == null) return false;
    return dataSetIndex == h.dataSetIndex &&
        x == h.x &&
        stackIndex == h.stackIndex &&
        dataIndex == h.dataIndex;
  }

  @override
  String toString() {
    return 'Highlight, x: ${kotlinFloatToString(x)}, y: ${kotlinFloatToString(y)}, dataSetIndex: $dataSetIndex, '
        'stackIndex (only stacked barentry): $stackIndex';
  }
}
