// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/PieEntry.kt
import 'entry.dart';

/// Entry for a pie chart: one slice with a value and an optional label.
/// A pie entry has no meaningful x; [x] is always 0 and the slice position is the entry's index in the data set.
///
/// [D] is the type of the payload stored in [data]. Kotlin's payload-less `PieEntry(value, label, icon)` factory is
/// this constructor without `data`. Kotlin's `label` and `icon` are positional with defaults; here [value] is the only
/// positional parameter and the rest are named, like the named parameters of [Entry].
class PieEntry<D> extends Entry<D> {
  /// Creates a slice of size [value] with an optional [label], an optional [icon] drawn at the slice when icons are
  /// enabled and an optional [data] payload.
  PieEntry(double value, {this.label, super.icon, super.data})
    : super(x: 0, y: value);

  /// Text drawn for the slice, or null for none. Also used for the legend.
  String? label;

  /// Size of the slice; the same as [y]. Assign [y] to change it.
  double get value => y;

  /// Returns a new entry with the same value, label, icon and payload. The icon and payload are shared, not copied.
  @override
  PieEntry<D> copy() => PieEntry<D>(y, label: label, icon: icon, data: data);
}
