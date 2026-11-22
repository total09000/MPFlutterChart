// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/Entry.kt
import '../utils/utils.dart';
import 'base_entry.dart';

/// One point in a chart: an x value, a y value, an optional icon and a typed payload.
/// Used directly by line and scatter charts; the other chart types use subclasses.
///
/// [D] is the type of the payload stored in [data]. Kotlin's payload-less `Entry(x, y, icon)` factory is this
/// constructor without `data`. `Parcelable` (`writeToParcel`, `CREATOR`) is not ported.
class Entry<D> extends BaseEntry<D> {
  /// Position on the x axis in value space (not an index).
  double x;

  /// Creates an entry at [x] / [y] with an optional [icon] drawn at the entry and an optional [data] payload.
  Entry({required this.x, required super.y, super.icon, super.data});

  /// Returns a new entry with the same x, y, icon and payload. The icon and payload are shared, not copied.
  Entry<D> copy() => Entry<D>(x: x, y: y, icon: icon, data: data);

  /// Compares x and y within [Utils.FLOAT_EPSILON] and requires the same payload instance.
  /// Unlike `==`, two separately created entries with the same values are considered equal.
  ///
  /// Returns true if [e] is not null and matches in x, y and payload.
  bool equalTo(Entry? e) {
    if (e == null) return false;
    if (!identical(e.data, data)) return false;
    if ((e.x - x).abs() > Utils.FLOAT_EPSILON) return false;
    if ((e.y - y).abs() > Utils.FLOAT_EPSILON) return false;
    return true;
  }

  @override
  String toString() => 'Entry, x: $x y: $y';
}
