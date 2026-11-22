// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/AxisBase.kt
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint, protected;

import '../formatter/default_axis_value_formatter.dart';
import '../formatter/i_axis_value_formatter.dart';
import '../graphics/chart_paint.dart';
import '../utils/float_math.dart';
import 'component_base.dart';
import 'limit_line.dart';

const Color _GRAY = Color(0xFF888888);

/// Base of `XAxis` and `YAxis`: the value range, the label entries, grid and axis lines, limit lines and label
/// formatting. Sizes are in dp and converted to px at draw time. The label entries are computed by the chart's axis
/// renderer from the visible range, so they are empty until the chart has data and was laid out.
///
/// The range arithmetic of [calculate], [applyAxisRange] and the [axisMinimum] / [axisMaximum] setters overflows like
/// Kotlin's `Float` math ([kotlinFloatOverflow]), so a range beyond the Float range becomes infinite as on Android
/// (the axis renderer draws no labels for an infinite range); values within it keep double precision.
abstract class AxisBase extends ComponentBase {
  IAxisValueFormatter? _axisValueFormatter;

  /// Color of the grid lines drawn from each label across the content area. Default gray.
  Color gridColor = _GRAY;

  /// Width of the grid lines in dp. Default 0.5.
  double gridLineWidth = 0.5;

  /// Color of the line drawn along the axis. Default gray.
  Color axisLineColor = _GRAY;

  /// Width of the line drawn along the axis in dp. Default 0.5.
  double axisLineWidth = 0.5;

  /// Values in value space at which labels and grid lines are drawn. Computed by the axis renderer, which
  /// only grows the array, so read the first [entryCount] of them.
  ///
  /// Kotlin `internal set`: written by the axis renderer; do not change it.
  Float32List entries = Float32List(0);

  /// Values halfway between neighbouring [entries], used when [isCenterAxisLabelsEnabled] is true.
  ///
  /// Kotlin `internal set`: written by the axis renderer; do not change it.
  Float32List centeredEntries = Float32List(0);

  /// Number of computed [entries].
  ///
  /// Kotlin `internal set`: written by the axis renderer; do not change it.
  int entryCount = 0;

  /// Decimal digits the default label formatter uses, derived from the label interval by the axis renderer.
  ///
  /// Kotlin `internal set`: written by the axis renderer; do not change it.
  int decimals = 0;

  int _labelCount = 6;

  /// Number of labels the axis should have, clamped to [axisMinLabels]..[axisMaxLabels], where [axisMaxLabels] wins
  /// when the two overlap. Default 6.
  /// The label interval is rounded to a nice value, so the real count only approximates this unless
  /// [isForceLabelsEnabled] is true.
  int get labelCount => _labelCount;
  set labelCount(int value) {
    // Kotlin coerceAtLeast(axisMinLabels).coerceAtMost(axisMaxLabels); int.clamp would throw when min > max.
    _labelCount = math.min(math.max(value, axisMinLabels), axisMaxLabels);
  }

  /// Draws exactly [labelCount] labels, evenly spread, instead of rounding to nice values. Default false.
  bool isForceLabelsEnabled = false;

  double _granularity = 1.0;

  /// Smallest allowed interval between two labels in value space, which stops labels from repeating when zooming in.
  /// Assigning a value also sets [isGranularityEnabled] to true. Default 1.
  double get granularity => _granularity;
  set granularity(double value) {
    _granularity = value;
    isGranularityEnabled = true;
  }

  /// Whether the label interval is kept at or above [granularity]. Default false; assigning [granularity] enables it.
  bool isGranularityEnabled = false;

  /// Whether grid lines are drawn from each label across the content area. Default true.
  bool isDrawGridLinesEnabled = true;

  /// Whether the line along the axis is drawn. Default true.
  bool isDrawAxisLineEnabled = true;

  /// Whether the labels are drawn. Grid and axis lines are not affected. Default true.
  bool isDrawLabelsEnabled = true;

  bool _isCenterAxisLabelsEnabled = false;

  /// Draws each label halfway between two grid lines instead of at its value, useful for grouped bar charts.
  /// Reads as false while the axis has no [entries]. Default false.
  bool get isCenterAxisLabelsEnabled =>
      _isCenterAxisLabelsEnabled && entryCount > 0;
  set isCenterAxisLabelsEnabled(bool value) =>
      _isCenterAxisLabelsEnabled = value;

  /// Dash pattern of the axis line, or null for a solid line. See [enableAxisLineDashedLine].
  DashPathEffect? axisLineDashPathEffect;

  /// Dash pattern of the grid lines, or null for solid lines. See [enableGridDashedLine].
  DashPathEffect? gridDashPathEffect;

  /// Limit lines drawn on this axis, in the order they were added.
  final List<LimitLine> limitLines = [];

  /// Whether the limit lines are drawn behind the data instead of on top of it. Default false.
  bool isDrawLimitLinesBehindDataEnabled = false;

  /// Whether the grid lines are drawn behind the data instead of on top of it. Default true.
  bool isDrawGridLinesBehindDataEnabled = true;

  /// Value space padding subtracted from the data minimum when the axis minimum is computed. Default 0.
  double spaceMin = 0;

  /// Value space padding added to the data maximum when the axis maximum is computed. Default 0.
  double spaceMax = 0;

  double _axisMinimumValue = 0;

  double _axisMaximumValue = 0;

  /// Smallest value on the axis, in value space. Assigning it fixes the minimum, so it is no longer computed from the
  /// data until [resetAxisMinimum] is called, and updates [axisRange].
  double get axisMinimum => _axisMinimumValue;
  set axisMinimum(double value) {
    _isAxisMinCustom = true;
    _axisMinimumValue = value;
    _axisRange = kotlinFloatOverflow((_axisMaximumValue - value).abs());
  }

  /// Largest value on the axis, in value space. Assigning it fixes the maximum, so it is no longer computed from the
  /// data until [resetAxisMaximum] is called, and updates [axisRange].
  double get axisMaximum => _axisMaximumValue;
  set axisMaximum(double value) {
    _isAxisMaxCustom = true;
    _axisMaximumValue = value;
    _axisRange = kotlinFloatOverflow((value - _axisMinimumValue).abs());
  }

  double _axisRange = 0;

  /// Distance between [axisMinimum] and [axisMaximum] in value space.
  double get axisRange => _axisRange;

  /// Kotlin `protected set`.
  @protected
  set axisRange(double value) => _axisRange = value;

  bool _isAxisMinCustom = false;

  /// Whether [axisMinimum] was assigned by the user rather than computed from the data.
  bool get isAxisMinCustom => _isAxisMinCustom;

  bool _isAxisMaxCustom = false;

  /// Whether [axisMaximum] was assigned by the user rather than computed from the data.
  bool get isAxisMaxCustom => _isAxisMaxCustom;

  int _axisMinLabels = 2;

  /// Lower bound applied to [labelCount]. Values of 0 or less are ignored. Default 2.
  int get axisMinLabels => _axisMinLabels;
  set axisMinLabels(int value) {
    if (value > 0) _axisMinLabels = value;
  }

  int _axisMaxLabels = 25;

  /// Upper bound applied to [labelCount]. Values of 0 or less are ignored. Default 25.
  int get axisMaxLabels => _axisMaxLabels;
  set axisMaxLabels(int value) {
    if (value > 0) _axisMaxLabels = value;
  }

  /// Adds [l] to [limitLines]. Logs a warning once the axis has more than 6 limit lines.
  void addLimitLine(LimitLine l) {
    limitLines.add(l);
    if (limitLines.length > 6) {
      debugPrint(
        'MPAndroidChart: Warning! You have more than 6 LimitLines on your axis, do you really want that?',
      );
    }
  }

  /// Removes [l] from [limitLines]. Does nothing if it was not added.
  void removeLimitLine(LimitLine l) {
    limitLines.remove(l);
  }

  /// Removes every limit line from this axis.
  void removeAllLimitLines() {
    limitLines.clear();
  }

  /// The formatted label with the most characters, or an empty string while the axis has no [entries].
  String get longestLabel {
    var longest = '';
    for (var i = 0; i < entryCount; i++) {
      final text = getFormattedLabel(i);
      if (longest.length < text.length) longest = text;
    }
    return longest;
  }

  /// Formats the entry at [index] with [valueFormatter].
  ///
  /// Returns the label text, or an empty string if [index] is not below [entryCount].
  String getFormattedLabel(int index) {
    if (index < 0 || index >= entryCount) return '';
    return valueFormatter.getFormattedValue(entries[index], this);
  }

  /// Formatter for the axis labels. While none is assigned, reading it returns a [DefaultAxisValueFormatter] with
  /// the computed [decimals], replaced whenever [decimals] changes.
  IAxisValueFormatter get valueFormatter {
    final current = _axisValueFormatter;
    if (current == null ||
        (current is DefaultAxisValueFormatter &&
            current.decimalDigits != decimals)) {
      return _axisValueFormatter = DefaultAxisValueFormatter(decimals);
    }
    return current;
  }

  set valueFormatter(IAxisValueFormatter value) {
    _axisValueFormatter = value;
  }

  /// Draws the grid lines dashed.
  ///
  /// [lineLength] is the length of each dash, [spaceLength] the length of the gap between two dashes and [phase] the
  /// offset into the dash pattern, normally 0, all in device px (as on Android: the canvas divides them by
  /// `Utils.devicePixelRatio`).
  void enableGridDashedLine(
    double lineLength,
    double spaceLength,
    double phase,
  ) {
    gridDashPathEffect = DashPathEffect([lineLength, spaceLength], phase);
  }

  /// Draws the grid lines solid again.
  void disableGridDashedLine() {
    gridDashPathEffect = null;
  }

  /// Whether the grid lines are drawn dashed.
  bool get isGridDashedLineEnabled => gridDashPathEffect != null;

  /// Draws the axis line dashed.
  ///
  /// [lineLength] is the length of each dash, [spaceLength] the length of the gap between two dashes and [phase] the
  /// offset into the dash pattern, normally 0, all in device px (as on Android: the canvas divides them by
  /// `Utils.devicePixelRatio`).
  void enableAxisLineDashedLine(
    double lineLength,
    double spaceLength,
    double phase,
  ) {
    axisLineDashPathEffect = DashPathEffect([lineLength, spaceLength], phase);
  }

  /// Draws the axis line solid again.
  void disableAxisLineDashedLine() {
    axisLineDashPathEffect = null;
  }

  /// Whether the axis line is drawn dashed.
  bool get isAxisLineDashedLineEnabled => axisLineDashPathEffect != null;

  /// Computes the maximum from the data again after [axisMaximum] was assigned. Applied on the next [calculate].
  void resetAxisMaximum() {
    _isAxisMaxCustom = false;
  }

  /// Computes the minimum from the data again after [axisMinimum] was assigned. Applied on the next [calculate].
  void resetAxisMinimum() {
    _isAxisMinCustom = false;
  }

  /// Sets [axisMinimum], [axisMaximum] and [axisRange] without fixing either limit. Used by [calculate]; assign
  /// [axisMinimum] or [axisMaximum] to fix a limit instead.
  ///
  /// [min] is the new minimum and [max] the new maximum, in value space.
  void applyAxisRange(double min, double max) {
    _axisMinimumValue = min;
    _axisMaximumValue = max;
    _axisRange = kotlinFloatOverflow((max - min).abs());
  }

  /// Half the span an empty range is widened to. It grows with the value, because adding 1 to a value above about
  /// 33 million leaves it unchanged in float precision, which would leave the axis with a range of zero and
  /// nothing drawn.
  @protected
  double emptyRangePadding(double value) => math.max(1.0, value.abs() / 100);

  /// Computes the axis range from the data range. Fixed limits are kept, computed ones get [spaceMin] and [spaceMax]
  /// added, and an empty range is widened around the value. The chart calls this whenever its data changes.
  ///
  /// [dataMin] is the smallest and [dataMax] the largest value in the chart data. Like Kotlin's
  /// `calculate(dataMin: Float, dataMax: Float)`, both are rounded to Float on entry, so a data range below the
  /// Float resolution is empty and padded as on Android.
  void calculate(double dataMin, double dataMax) {
    var min = _isAxisMinCustom
        ? _axisMinimumValue
        : kotlinFloatOverflow(toKotlinFloat(dataMin) - spaceMin);
    var max = _isAxisMaxCustom
        ? _axisMaximumValue
        : kotlinFloatOverflow(toKotlinFloat(dataMax) + spaceMax);

    if ((max - min).abs() == 0) {
      final padding = emptyRangePadding(max);
      max = kotlinFloatOverflow(max + padding);
      min = kotlinFloatOverflow(min - padding);
    }

    applyAxisRange(min, max);
  }
}
