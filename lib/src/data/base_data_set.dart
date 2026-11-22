// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BaseDataSet.kt
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../components/legend_form.dart';
import '../components/y_axis_dependency.dart';
import '../formatter/i_value_formatter.dart';
import '../graphics/chart_paint.dart';
import '../graphics/typeface.dart';
import '../interfaces/datasets/i_data_set.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import 'entry.dart';

const Color _BLACK = Color(0xFF000000);

/// Styling and bookkeeping shared by every data set: colors, value labels, legend form, axis and visibility.
/// Entry storage is left to `DataSet`; the entry related overrides here work through [getEntryForIndex].
///
/// [T] is the entry type this set holds.
///
/// Kotlin's `setColors(colorResIds, context)` is not ported (no Android resources). Kotlin's protected
/// `copy(baseDataSet)` is [copyTo] (it would clash with the public `DataSet.copy()`).
abstract class BaseDataSet<T extends Entry> implements IDataSet<T> {
  /// Creates the styling part of a data set named [label], shown in the legend and usable for lookup via
  /// `ChartData.getDataSetByLabel`.
  BaseDataSet([this.label = 'DataSet']);

  /// Colors used to draw the entries, reused from the start when there are more entries than colors.
  @override
  List<Color> colors = const [Color.fromARGB(255, 140, 234, 255)];

  /// Colors used to draw the value labels, reused from the start like [colors]. Default black.
  @override
  List<Color> valueTextColors = [_BLACK];

  @override
  String label;

  @override
  AxisDependency axisDependency = AxisDependency.LEFT;

  @override
  bool isHighlightEnabled = true;

  IValueFormatter? _formatter;

  /// Formatter for the value labels. Returns [Utils.defaultValueFormatter] until a custom one is assigned.
  @override
  IValueFormatter get valueFormatter =>
      _formatter ?? Utils.defaultValueFormatter;

  @override
  set valueFormatter(IValueFormatter value) {
    _formatter = value;
  }

  /// True while no custom [valueFormatter] is assigned, so the chart may apply its own default formatter.
  @override
  bool get needsFormatter => _formatter == null;

  @override
  Typeface? valueTypeface;

  /// Shape of this set's legend entry. [LegendForm.DEFAULT] uses the legend's form.
  @override
  LegendForm form = LegendForm.DEFAULT;

  /// Size of this set's legend form in dp. NaN (the default) uses the legend's form size.
  @override
  double formSize = double.nan;

  /// Line width of this set's legend form in dp when the form is a line. NaN uses the legend's width.
  @override
  double formLineWidth = double.nan;

  /// Dash effect for this set's legend form when the form is a line. Null uses the legend's dash effect.
  @override
  DashPathEffect? formLineDashEffect;

  @override
  bool isDrawValuesEnabled = true;

  @override
  bool isDrawIconsEnabled = true;

  final MPPointF _iconsOffset = MPPointF();

  /// Offset in dp applied to every entry icon. Assigning copies x and y into the existing point.
  @override
  MPPointF get iconsOffset => _iconsOffset;

  @override
  set iconsOffset(MPPointF value) {
    _iconsOffset.x = value.x;
    _iconsOffset.y = value.y;
  }

  /// Text size of the value labels in dp. Default 7.
  @override
  double valueTextSize = 7;

  @override
  bool isVisible = true;

  /// Recomputes the cached x and y ranges from the entries. Call after changing entries in place.
  void notifyDataSetChanged() {
    calcMinMax();
  }

  /// The first entry color, or black when [colors] is empty. Assigning replaces the whole [colors] list with this one
  /// color.
  @override
  Color get color => colors.isEmpty ? _BLACK : colors.first;

  set color(Color value) {
    colors = [value];
  }

  /// Returns the color for the entry at [index], wrapping around [colors] when there are fewer colors. Black when
  /// [colors] is empty.
  @override
  Color getColor(int index) => colorAt(colors, index);

  /// Replaces [colors] with the given colors (Kotlin's `setColors(vararg colors: Int)`), or, with [alpha], with the
  /// given colors after applying [alpha] (0 transparent to 255 opaque) to each of them, ignoring their own alpha
  /// (Kotlin's `setColors(colors: List<Int>, alpha: Int)`).
  void setColors(List<Color> colors, [int? alpha]) {
    if (alpha == null) {
      this.colors = colors.toList();
    } else {
      this.colors = colors.map((it) => it.withAlpha(alpha)).toList();
    }
  }

  /// Appends one color to [colors].
  void addColor(Color color) {
    colors = [...colors, color];
  }

  /// Replaces [colors] with this one color after applying [alpha].
  ///
  /// [color]'s own alpha is ignored; [alpha] is the opacity from 0 (transparent) to 255 (opaque).
  void setColor(Color color, int alpha) {
    this.color = color.withAlpha(alpha);
  }

  /// Removes all colors. Add at least one color before the set is drawn; until then [getColor] returns black.
  void resetColors() {
    colors = [];
  }

  /// The first value label color, or black when the list is empty. Assigning replaces the whole [valueTextColors]
  /// list with this one color.
  @override
  Color get valueTextColor =>
      valueTextColors.isEmpty ? _BLACK : valueTextColors.first;

  @override
  set valueTextColor(Color value) {
    valueTextColors = [value];
  }

  /// Returns the value label color for the entry at [index], wrapping around [valueTextColors]. Black when the list
  /// is empty.
  @override
  Color getValueTextColor(int index) => colorAt(valueTextColors, index);

  /// Finds the entry whose x equals [xIndex] exactly by scanning all entries.
  ///
  /// Returns the index in the entries, or -1 if no entry has that x.
  @override
  int getIndexInEntries(int xIndex) {
    for (var i = 0; i < entryCount; i++) {
      if (xIndex.toDouble() == getEntryForIndex(i).x) return i;
    }
    return -1;
  }

  /// Removes the first entry. Returns false and does nothing when the set is empty.
  @override
  bool removeFirst() {
    if (entryCount <= 0) return false;
    return removeEntry(getEntryForIndex(0));
  }

  /// Removes the last entry. Returns false and does nothing when the set is empty.
  @override
  bool removeLast() {
    if (entryCount <= 0) return false;
    return removeEntry(getEntryForIndex(entryCount - 1));
  }

  /// Removes the entry whose x is closest to [xValue], which need not be an exact match.
  ///
  /// Returns true if an entry was removed, false when the set is empty.
  @override
  bool removeEntryByXValue(double xValue) {
    final e = getEntryForXValue(xValue, double.nan);
    if (e == null) return false;
    return removeEntry(e);
  }

  /// Removes the entry at [index].
  ///
  /// Throws a [RangeError] when [index] is not a valid entry index.
  @override
  bool removeEntryByIndex(int index) {
    return removeEntry(getEntryForIndex(index));
  }

  /// Returns true if [entry] is one of this set's entries, compared with `==` (identity for [Entry]).
  @override
  bool contains(T entry) {
    for (var i = 0; i < entryCount; i++) {
      if (getEntryForIndex(i) == entry) return true;
    }
    return false;
  }

  /// Copies all styling from this set into [baseDataSet]. Color lists and the formatter are shared.
  ///
  /// Kotlin's protected `copy(baseDataSet: BaseDataSet<*>)`; subclasses narrow the parameter and call
  /// `super.copyTo(...)`.
  @protected
  void copyTo(covariant BaseDataSet baseDataSet) {
    baseDataSet.axisDependency = axisDependency;
    baseDataSet.colors = colors;
    baseDataSet.isDrawIconsEnabled = isDrawIconsEnabled;
    baseDataSet.isDrawValuesEnabled = isDrawValuesEnabled;
    baseDataSet.form = form;
    baseDataSet.formLineDashEffect = formLineDashEffect;
    baseDataSet.formLineWidth = formLineWidth;
    baseDataSet.formSize = formSize;
    baseDataSet.isHighlightEnabled = isHighlightEnabled;
    baseDataSet.iconsOffset = iconsOffset;
    baseDataSet.valueTextColors = valueTextColors;
    baseDataSet._formatter = _formatter;
    baseDataSet.valueTextSize = valueTextSize;
    baseDataSet.valueTypeface = valueTypeface;
    baseDataSet.isVisible = isVisible;
  }
}

/// Returns the color at [index] in [colors], wrapping around (Kotlin `Math.floorMod`); black when [colors] is empty.
///
/// Kotlin `internal`: package-internal helper shared with the data set classes, not MPAndroidChart API; the library
/// entry points hide it.
Color colorAt(List<Color> colors, int index) =>
    colors.isEmpty ? _BLACK : colors[index % colors.length];
