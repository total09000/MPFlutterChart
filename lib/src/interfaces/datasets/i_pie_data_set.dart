// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/IPieDataSet.kt
import 'dart:ui';

import '../../data/pie_data_set.dart';
import '../../data/pie_entry.dart';
import 'i_data_set.dart';

/// What the pie chart renderer reads from a data set: slice spacing, selection shift and the placement of
/// value labels with their connector lines. Implemented by [PieDataSet].
///
/// [D] is the type of the payload attached to each entry.
abstract class IPieDataSet<D> extends IDataSet<PieEntry<D>> {
  /// Gap between neighbouring slices in dp, from 0 to 20. Default 0.
  double get sliceSpace;

  /// True to drop the slice space when the smallest slice would be narrower than the space itself. Default false.
  bool get isAutomaticallyDisableSliceSpacingEnabled;

  /// Distance in dp a highlighted slice is pushed outwards from the center. Default 9 dp.
  double get selectionShift;

  /// Where the entry labels are drawn, inside or outside the slice. Default [ValuePosition.INSIDE_SLICE].
  ValuePosition get xValuePosition;

  /// Where the values are drawn, inside or outside the slice. Default [ValuePosition.INSIDE_SLICE].
  ValuePosition get yValuePosition;

  /// Color of the connector line for values drawn outside the slice. Default black.
  Color get valueLineColor;

  /// True to draw the connector line in the slice color instead of [valueLineColor]. Default false.
  bool get isUseValueColorForLineEnabled;

  /// Stroke width of the connector line in dp. Default 1 dp.
  double get valueLineWidth;

  /// Where the connector line starts, as a percentage of the radius measured from the slice edge. Default 75.
  double get valueLinePart1OffsetPercentage;

  /// Length of the first, outward pointing part of the connector line as a fraction of the radius. Default 0.3.
  double get valueLinePart1Length;

  /// Length of the second, horizontal part of the connector line as a fraction of the radius. Default 0.4.
  double get valueLinePart2Length;

  /// True to shorten the connector line for slices near the horizontal center. Default true.
  bool get isValueLineVariableLength;

  /// Color of a highlighted slice, null to keep the slice color.
  Color? get highlightColor;
}
