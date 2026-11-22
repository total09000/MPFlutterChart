// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/LineDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint, protected;

import '../formatter/default_fill_formatter.dart';
import '../formatter/i_fill_formatter.dart';
import '../graphics/chart_paint.dart';
import '../interfaces/datasets/i_line_data_set.dart';
import 'base_data_set.dart';
import 'data_set.dart';
import 'entry.dart';
import 'line_radar_data_set.dart';

/// One line in a line chart, with its drawing mode, circle markers, dash pattern and fill settings.
///
/// [D] is the payload type of the entries. Kotlin's `setCircleColors(colorResIds, context)` is not ported (no
/// Android resources).
class LineDataSet<D> extends LineRadarDataSet<Entry<D>>
    implements ILineDataSet<D> {
  /// Creates a line from [entries], the points of the line sorted by x (kept by reference, see
  /// `DataSet.entries`), named [label], shown in the legend.
  LineDataSet(super.entries, super.label);

  @override
  LineDataSetMode mode = LineDataSetMode.LINEAR;

  /// Colors of the circles drawn at the entries, one per entry index; the renderer wraps around the list.
  List<Color> circleColors = const [Color.fromARGB(255, 140, 234, 255)];

  @override
  Color circleHoleColor = const Color(0xFFFFFFFF);

  @override
  bool isDrawHighlightCircleEnabled = false;

  @override
  double highlightCircleRadius = 5;

  double _circleRadius = 4;

  /// Radius of the circles drawn at the entries in dp. Default 4. Values below 1 are ignored and logged.
  @override
  double get circleRadius => _circleRadius;

  set circleRadius(double value) {
    if (value >= 1) {
      _circleRadius = value;
    } else {
      debugPrint('LineDataSet<D>: Circle radius cannot be < 1');
    }
  }

  double _circleHoleRadius = 2;

  /// Radius of the hole inside each circle in dp. Default 2. Values below 0.5 are ignored and logged.
  @override
  double get circleHoleRadius => _circleHoleRadius;

  set circleHoleRadius(double value) {
    if (value >= 0.5) {
      _circleHoleRadius = value;
    } else {
      debugPrint('LineDataSet<D>: Circle radius cannot be < 0.5');
    }
  }

  double _cubicIntensity = 0.2;

  /// How strongly [LineDataSetMode.CUBIC_BEZIER] curves the line, clamped to 0.05 (almost straight) to 1. Default
  /// 0.2.
  @override
  double get cubicIntensity => _cubicIntensity;

  set cubicIntensity(double value) {
    // Kotlin coerceIn(0.05f, 1f), which keeps NaN.
    _cubicIntensity = value < 0.05 ? 0.05 : (value > 1 ? 1 : value);
  }

  DashPathEffect? _dashPathEffect;

  /// Dash pattern of the line, or null for a solid line. Set through [enableDashedLine].
  @override
  DashPathEffect? get dashPathEffect => _dashPathEffect;

  @protected
  set dashPathEffect(DashPathEffect? value) => _dashPathEffect = value;

  @override
  IFillFormatter fillFormatter = DefaultFillFormatter();

  @override
  bool isDrawCirclesEnabled = true;

  @override
  bool isDrawCircleHoleEnabled = true;

  @override
  DataSet<Entry<D>> copy() {
    final copiedEntries = [for (final it in entries) it.copy()];
    final copied = LineDataSet<D>(copiedEntries, label);
    copyTo(copied);
    return copied;
  }

  /// Copies the styling from this set into [lineDataSet]; entries are not copied here.
  @override
  @protected
  void copyTo(covariant LineDataSet<D> lineDataSet) {
    super.copyTo(lineDataSet);
    lineDataSet.circleColors = circleColors;
    lineDataSet.circleHoleColor = circleHoleColor;
    lineDataSet.circleHoleRadius = circleHoleRadius;
    lineDataSet.circleRadius = circleRadius;
    lineDataSet.cubicIntensity = cubicIntensity;
    lineDataSet.dashPathEffect = dashPathEffect;
    lineDataSet.isDrawCircleHoleEnabled = isDrawCircleHoleEnabled;
    lineDataSet.isDrawCirclesEnabled = isDrawCirclesEnabled;
    lineDataSet.fillFormatter = fillFormatter;
    lineDataSet.mode = mode;
    lineDataSet.isDrawHighlightCircleEnabled = isDrawHighlightCircleEnabled;
    lineDataSet.highlightCircleRadius = highlightCircleRadius;
  }

  /// Draws the line dashed, like "- - - -".
  ///
  /// [lineLength] is the length of each dash, [spaceLength] the length of the gap between dashes and [phase] the
  /// offset into the pattern, normally 0, all in device px (as on Android: the canvas divides them by
  /// `Utils.devicePixelRatio`).
  void enableDashedLine(double lineLength, double spaceLength, double phase) {
    dashPathEffect = DashPathEffect([lineLength, spaceLength], phase);
  }

  /// Draws the line solid again.
  void disableDashedLine() {
    dashPathEffect = null;
  }

  @override
  bool get isDashedLineEnabled => dashPathEffect != null;

  /// Returns the circle color at [index], wrapping around when the index is past the end of [circleColors]. Black
  /// when [circleColors] is empty.
  @override
  Color getCircleColor(int index) => colorAt(circleColors, index);

  @override
  int get circleColorCount => circleColors.length;

  /// Replaces [circleColors] with the given colors (Kotlin's `setCircleColors(vararg colors: Int)`).
  void setCircleColors(List<Color> colors) {
    circleColors = colors.toList();
  }

  /// The first circle color. Assigning replaces the whole [circleColors] list with this one color.
  Color get circleColor => circleColors[0];

  set circleColor(Color value) {
    circleColors = [value];
  }

  /// Removes all circle colors. Add at least one before circles are drawn.
  void resetCircleColors() {
    circleColors = [];
  }
}

/// How the segments between entries of a [LineDataSet] are drawn.
///
/// Kotlin's `LineDataSet.Mode`; a top-level enum named after its outer class because Dart has no nested types.
enum LineDataSetMode {
  /// Straight segments from point to point.
  LINEAR,

  /// Horizontal steps, the y value changes at each entry.
  STEPPED,

  /// Smooth curve through the points, bent by `cubicIntensity`.
  CUBIC_BEZIER,

  /// Smooth curve whose control points are horizontal, so the curve never overshoots in y.
  HORIZONTAL_BEZIER,
}
