// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/interfaces/datasets/IDataSet.kt
import 'dart:ui';

import '../../components/legend_form.dart';
import '../../components/y_axis_dependency.dart';
import '../../data/data_set.dart';
import '../../data/entry.dart';
import '../../formatter/i_value_formatter.dart';
import '../../graphics/chart_paint.dart';
import '../../graphics/typeface.dart';
import '../../utils/mp_point_f.dart';

/// A set of entries with shared styling, the unit a chart draws as one line, one group of bars, one pie
/// and so on. Renderers and highlighters only read this interface; the concrete data set classes in
/// `data/` implement it and inherit these docs.
///
/// Entries are expected in ascending x order. Lookups by x value use binary search and cost time at runtime,
/// so avoid them in tight loops.
///
/// [T] is the entry type this data set holds. Kotlin's overloads `getEntryIndex(e: Entry)` and
/// `removeEntry(index: Int)` are [getEntryIndexOf] and [removeEntryByIndex] (Dart has no overloading).
abstract class IDataSet<T extends Entry> {
  /// Smallest y value in this data set, Kotlin `Float.MAX_VALUE` when empty.
  double get yMin;

  /// Largest y value in this data set, -`Float.MAX_VALUE` when empty.
  double get yMax;

  /// Smallest x value in this data set, Kotlin `Float.MAX_VALUE` when empty.
  double get xMin;

  /// Largest x value in this data set, -`Float.MAX_VALUE` when empty.
  double get xMax;

  /// Number of entries in this data set.
  int get entryCount;

  /// True when an entry's y may not be a finite number, so a renderer has to look for gaps before drawing a
  /// line. The default is true, which is always safe; answer false only when every y is known to be finite.
  bool get hasNonFiniteY => true;

  /// Recomputes [xMin], [xMax], [yMin] and [yMax] from all entries.
  void calcMinMax();

  /// Recomputes [yMin] and [yMax] from the entries between the x values [fromX] and [toX] only.
  /// Used when the chart auto scales its y axis to the visible range.
  void calcMinMaxY(double fromX, double toX);

  /// Returns the entry at [xValue], or the entry at the nearest x value according to [rounding] if there is none.
  ///
  /// [closestToY]: when several entries share the x value, the one whose y value is nearest to this wins;
  /// NaN picks the first. [rounding]: whether to round up, down or to the closest x value when [xValue] has no
  /// entry. Returns null if the data set is empty or rounding leaves the entry range.
  T? getEntryForXValue(
    double xValue, [
    double closestToY = double.nan,
    Rounding rounding = Rounding.CLOSEST,
  ]);

  /// Returns all entries whose x value equals [xValue], or an empty list if there is none.
  List<T> getEntriesForXValue(double xValue);

  /// Returns the entry at position [index] in the entry list.
  ///
  /// Throws a [RangeError] if [index] is outside 0 until [entryCount].
  T getEntryForIndex(int index);

  /// Returns the index of the entry at [xValue], or of the entry at the nearest x value according to [rounding].
  ///
  /// [closestToY]: when several entries share the x value, the one whose y value is nearest to this wins;
  /// NaN picks the first. [rounding]: whether to round up, down or to the closest x value when [xValue] has no
  /// entry. Returns -1 if the data set is empty or rounding leaves the entry range.
  int getEntryIndex(
    double xValue, [
    double closestToY = double.nan,
    Rounding rounding = Rounding.CLOSEST,
  ]);

  /// Returns the index of [e] in the entry list, or -1 if it is not contained.
  ///
  /// Kotlin's `getEntryIndex(e: Entry)` overload.
  int getEntryIndexOf(Entry e);

  /// Returns the index of the first entry whose x value equals [xIndex] by scanning all entries,
  /// or -1 if there is none.
  int getIndexInEntries(int xIndex);

  /// Appends [e] at the end of the entry list and updates the min and max values.
  ///
  /// Returns true if the entry was added.
  bool addEntry(T e);

  /// Inserts [e] at the position matching its x value and updates the min and max values.
  void addEntryOrdered(T e);

  /// Removes the entry at index 0. Returns false if the data set is empty.
  bool removeFirst();

  /// Removes the last entry. Returns false if the data set is empty.
  bool removeLast();

  /// Removes [e] and updates the min and max values. Returns false if [e] is not contained.
  bool removeEntry(T e);

  /// Removes the entry at or closest to [xValue]. Returns false if the data set is empty.
  bool removeEntryByXValue(double xValue);

  /// Removes the entry at [index] and returns true. Throws when [index] is out of range.
  ///
  /// Kotlin's `removeEntry(index: Int)` overload.
  bool removeEntryByIndex(int index);

  /// True if [entry] is in this data set. Scans all entries.
  bool contains(T entry);

  /// Removes all entries and resets the min and max values.
  void clear();

  /// Name shown in the legend for this data set.
  String get label;

  set label(String value);

  /// The y axis this data set is plotted against. Default [AxisDependency.LEFT].
  AxisDependency get axisDependency;

  set axisDependency(AxisDependency value);

  /// Colors used to draw the entries, cycled by [getColor] when there are fewer colors than entries.
  List<Color> get colors;

  /// The first of [colors], the color used when only one is set.
  Color get color;

  /// Returns the color for entry [index], wrapping around [colors] with modulo.
  Color getColor(int index);

  /// True if entries of this data set can be highlighted by touch or `chart.highlightValue(...)`. Default true.
  bool get isHighlightEnabled;

  set isHighlightEnabled(bool value);

  /// Formatter for the value labels drawn at the entries. Until one is set, the chart's default formatter is
  /// returned and [needsFormatter] is true.
  IValueFormatter get valueFormatter;

  set valueFormatter(IValueFormatter value);

  /// True if no formatter was set, so the chart should supply its default formatter.
  bool get needsFormatter;

  /// Color of the value labels. Reading it returns the first of [valueTextColors]; writing replaces the whole list.
  Color get valueTextColor;

  set valueTextColor(Color value);

  /// Colors of the value labels, cycled by [getValueTextColor] when there are fewer colors than entries.
  List<Color> get valueTextColors;

  set valueTextColors(List<Color> value);

  /// Returns the value label color for entry [index], wrapping around [valueTextColors] with modulo.
  Color getValueTextColor(int index);

  /// Typeface of the value labels, null for the default.
  Typeface? get valueTypeface;

  set valueTypeface(Typeface? value);

  /// Text size of the value labels in dp. Default 7 dp.
  double get valueTextSize;

  set valueTextSize(double value);

  /// Shape drawn for this data set in the legend. [LegendForm.DEFAULT] uses the legend's form.
  LegendForm get form;

  /// Size of the legend form in dp. NaN uses the legend's form size.
  double get formSize;

  /// Line width in dp for legend forms drawn as lines. NaN uses the legend's line width.
  double get formLineWidth;

  /// Dash effect for legend forms drawn as lines. Null uses the legend's dash effect.
  DashPathEffect? get formLineDashEffect;

  /// True to draw the value labels at the entries. Default true. Not drawn when more entries are visible
  /// than the chart's `maxVisibleCount` allows.
  bool get isDrawValuesEnabled;

  set isDrawValuesEnabled(bool value);

  /// True to draw the entry icons. Default true. Not drawn when more entries are visible than the chart's
  /// `maxVisibleCount` allows.
  bool get isDrawIconsEnabled;

  set isDrawIconsEnabled(bool value);

  /// Offset of the icons from their entry position in dp. For pie and radar charts x moves the icon along
  /// the value direction and y moves it towards or away from the center.
  MPPointF get iconsOffset;

  set iconsOffset(MPPointF value);

  /// True if this data set is drawn. Default true. Hidden data sets still count for the axis ranges.
  bool get isVisible;

  set isVisible(bool value);
}
