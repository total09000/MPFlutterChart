// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BubbleEntry.kt
import 'entry.dart';

/// Entry for a bubble chart: a point plus the bubble's size.
///
/// [D] is the type of the payload stored in [data]. Kotlin's positional constructor and its payload-less
/// `BubbleEntry(x, y, size, icon)` factory are this constructor with named arguments, `data` optional.
class BubbleEntry<D> extends Entry<D> {
  /// Creates a bubble at [x] and [y] (its position in value space) with its [size] in value space, an optional
  /// [icon] drawn at the entry when icons are enabled and an optional [data] payload.
  BubbleEntry({
    required super.x,
    required super.y,
    required this.size,
    super.icon,
    super.data,
  });

  /// Size of the bubble in value space. Bubbles are scaled relative to the data set's largest size when
  /// `BubbleDataSet.isNormalizeSizeEnabled` is on.
  double size;

  @override
  BubbleEntry<D> copy() =>
      BubbleEntry<D>(x: x, y: y, size: size, icon: icon, data: data);
}
