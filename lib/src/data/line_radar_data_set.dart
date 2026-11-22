// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/LineRadarDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../graphics/chart_drawable.dart';
import '../interfaces/datasets/i_line_radar_data_set.dart';
import 'entry.dart';
import 'line_scatter_candle_radar_data_set.dart';

/// Base for line and radar data sets: a stroked line with an optional filled area under it.
///
/// [T] is the entry type this set holds.
abstract class LineRadarDataSet<T extends Entry>
    extends LineScatterCandleRadarDataSet<T>
    implements ILineRadarDataSet<T> {
  /// Creates a set holding [entries] named [label].
  LineRadarDataSet(super.entries, super.label);

  Color _fillColor = const Color.fromARGB(255, 140, 234, 255);

  /// Color of the filled area. Assigning it clears [fillDrawable], which otherwise takes precedence.
  @override
  Color get fillColor => _fillColor;

  set fillColor(Color value) {
    _fillColor = value;
    fillDrawable = null;
  }

  @override
  ChartDrawable? fillDrawable;

  @override
  int fillAlpha = 85;

  double _lineWidth = 1;

  /// Width of the line in dp, clamped to 0 to 10. Default 1. Thinner lines draw faster.
  @override
  double get lineWidth => _lineWidth;

  set lineWidth(double value) {
    // Kotlin coerceIn(0f, 10f), which keeps NaN.
    _lineWidth = value < 0 ? 0 : (value > 10 ? 10 : value);
  }

  @override
  bool isDrawFilledEnabled = false;

  /// Copies the styling from this set into [dataSet]; entries are not copied here.
  @override
  @protected
  void copyTo(covariant LineRadarDataSet dataSet) {
    super.copyTo(dataSet);
    dataSet.isDrawFilledEnabled = isDrawFilledEnabled;
    dataSet.fillAlpha = fillAlpha;
    dataSet.fillColor = fillColor;
    dataSet.fillDrawable = fillDrawable;
    dataSet.lineWidth = lineWidth;
  }
}
