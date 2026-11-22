// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/EntryXComparator.kt
import '../data/entry.dart';

/// Orders entries by their x value, ascending. Use it to sort entries before creating a data set,
/// which expects them in x order.
///
/// Kotlin implements `Comparator<Entry<*>>`; here pass the [compare] tear-off wherever a `Comparator<Entry>` function
/// is expected: `entries.sort(EntryXComparator().compare)`. The class is also callable.
class EntryXComparator {
  /// Compares the x values of [entry1] and [entry2]: negative, zero or positive like `Comparator.compare`.
  /// Like Kotlin's `Float.compareTo`, NaN sorts after every other value.
  int compare(Entry entry1, Entry entry2) {
    if (entry1.x == entry2.x) return 0;
    return entry1.x.compareTo(entry2.x);
  }

  /// Same as [compare], so the comparator can be used as a `Comparator<Entry>` function.
  int call(Entry entry1, Entry entry2) => compare(entry1, entry2);
}
