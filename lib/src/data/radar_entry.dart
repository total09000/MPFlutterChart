// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/RadarEntry.kt
import 'entry.dart';

/// Entry for a radar chart: one value on one axis of the web.
/// [x] is always 0; the axis the value belongs to is the entry's index in the data set.
///
/// [D] is the type of the payload stored in [data]. Kotlin's payload-less `RadarEntry(value, icon)` factory is this
/// constructor without `data`. Kotlin's `icon` is positional with a default; here [value] is the only positional
/// parameter and the rest are named, like the named parameters of [Entry].
class RadarEntry<D> extends Entry<D> {
  /// Creates an entry at distance [value] from the center of the web with an optional [icon] drawn at the entry when
  /// icons are enabled and an optional [data] payload.
  RadarEntry(double value, {super.icon, super.data}) : super(x: 0, y: value);

  /// Distance from the center of the web; the same as [y]. Assign [y] to change it.
  double get value => y;

  /// Returns a new entry with the same value, icon and payload. The icon and payload are shared, not copied.
  @override
  RadarEntry<D> copy() => RadarEntry<D>(y, icon: icon, data: data);
}
