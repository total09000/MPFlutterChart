// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/RadarDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../interfaces/datasets/i_radar_data_set.dart';
import '../utils/color_template.dart';
import 'data_set.dart';
import 'line_radar_data_set.dart';
import 'radar_entry.dart';

/// One polygon in a radar chart. Each entry is the value on one axis of the web, in axis order.
///
/// [D] is the payload type of the entries.
class RadarDataSet<D> extends LineRadarDataSet<RadarEntry<D>>
    implements IRadarDataSet<D> {
  /// Creates a polygon from [entries], one value per web axis (kept by reference, see `DataSet.entries`), named
  /// [label], shown in the legend.
  RadarDataSet(super.entries, super.label);

  double _cornerRadius = 0;

  /// Radius in dp the corners of the polygon are rounded with. 0, the default, draws sharp corners, and the
  /// renderer clamps the radius to half the shortest edge so a small polygon keeps its shape. Negative values are
  /// stored as 0.
  @override
  double get cornerRadius => _cornerRadius;

  set cornerRadius(double value) {
    // Kotlin coerceAtLeast(0f), which keeps NaN.
    _cornerRadius = value < 0 ? 0 : value;
  }

  @override
  bool isDrawHighlightCircleEnabled = false;

  @override
  Color highlightCircleFillColor = const Color(0xFFFFFFFF);

  /// Stroke color of the highlight circle. [ColorTemplate.COLOR_NONE] (the default) uses the set's first color.
  @override
  Color highlightCircleStrokeColor = ColorTemplate.COLOR_NONE;

  @override
  int highlightCircleStrokeAlpha = (0.3 * 255).toInt();

  @override
  double highlightCircleInnerRadius = 3.0;

  @override
  double highlightCircleOuterRadius = 4.0;

  @override
  double highlightCircleStrokeWidth = 2.0;

  @override
  DataSet<RadarEntry<D>> copy() {
    final copiedEntries = [for (final it in entries) it.copy()];
    final copied = RadarDataSet<D>(copiedEntries, label);
    copyTo(copied);
    return copied;
  }

  /// Copies the styling into [radarDataSet]; the entries are not copied.
  @override
  @protected
  void copyTo(covariant RadarDataSet<D> radarDataSet) {
    super.copyTo(radarDataSet);
    radarDataSet.cornerRadius = cornerRadius;
    radarDataSet.isDrawHighlightCircleEnabled = isDrawHighlightCircleEnabled;
    radarDataSet.highlightCircleFillColor = highlightCircleFillColor;
    radarDataSet.highlightCircleInnerRadius = highlightCircleInnerRadius;
    radarDataSet.highlightCircleStrokeAlpha = highlightCircleStrokeAlpha;
    radarDataSet.highlightCircleStrokeColor = highlightCircleStrokeColor;
    radarDataSet.highlightCircleStrokeWidth = highlightCircleStrokeWidth;
    radarDataSet.highlightCircleOuterRadius = highlightCircleOuterRadius;
  }
}
