// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/PieDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../interfaces/datasets/i_pie_data_set.dart';
import 'data_set.dart';
import 'pie_entry.dart';

/// The slices of a pie chart. A `PieData` holds exactly one of these. Only the y range is tracked, the
/// x range stays at its empty values because pie entries have no x.
///
/// [D] is the payload type of the entries. Kotlin's nested `PieDataSet.ValuePosition` is the top-level
/// [ValuePosition].
class PieDataSet<D> extends DataSet<PieEntry<D>> implements IPieDataSet<D> {
  /// Creates a set from [entries], the slices in drawing order (kept by reference, see `DataSet.entries`), named
  /// [label].
  PieDataSet(super.entries, super.label);

  double _sliceSpace = 0;

  /// Gap between slices in dp, clamped to 0 to 20. Default 0.
  @override
  double get sliceSpace => _sliceSpace;

  set sliceSpace(double value) {
    // Kotlin coerceIn(0f, 20f), which keeps NaN.
    _sliceSpace = value < 0 ? 0 : (value > 20 ? 20 : value);
  }

  @override
  bool isAutomaticallyDisableSliceSpacingEnabled = false;

  @override
  double selectionShift = 9;

  @override
  ValuePosition xValuePosition = ValuePosition.INSIDE_SLICE;

  @override
  ValuePosition yValuePosition = ValuePosition.INSIDE_SLICE;

  @override
  Color valueLineColor = const Color(0xFF000000);

  @override
  bool isUseValueColorForLineEnabled = false;

  @override
  double valueLineWidth = 1.0;

  @override
  double valueLinePart1OffsetPercentage = 75;

  @override
  double valueLinePart1Length = 0.3;

  @override
  double valueLinePart2Length = 0.4;

  @override
  bool isValueLineVariableLength = true;

  /// Color of a highlighted slice, or null (the default) to keep the slice's own color.
  @override
  Color? highlightColor;

  @override
  DataSet<PieEntry<D>> copy() {
    final copiedEntries = [for (final it in entries) it.copy()];
    final copied = PieDataSet<D>(copiedEntries, label);
    copyTo(copied);
    return copied;
  }

  /// Copies the inherited styling into [pieDataSet]; the pie specific settings are not copied (as in Kotlin, whose
  /// `copy(pieDataSet)` only calls `super`).
  @override
  @protected
  void copyTo(covariant PieDataSet<D> pieDataSet) {
    super.copyTo(pieDataSet);
  }

  /// Widens only the y range; pie entries have no x.
  ///
  /// Kotlin's protected `calcMinMax(e: PieEntry<D>)` override.
  @override
  @protected
  void calcMinMaxForEntry(PieEntry<D> e) {
    calcMinMaxYForEntry(e);
  }
}

/// Where a slice's label or value is drawn.
///
/// Kotlin's `PieDataSet.ValuePosition`; a top-level enum because Dart has no nested types.
enum ValuePosition {
  /// Inside the slice.
  INSIDE_SLICE,

  /// Outside the pie, connected to the slice with a line.
  OUTSIDE_SLICE,
}
