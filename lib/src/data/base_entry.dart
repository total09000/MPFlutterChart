// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/data/BaseEntry.kt
import '../graphics/chart_drawable.dart';

/// Common part of every chart entry: a y value, an optional icon and a read-only payload.
///
/// [D] is the type of the payload; Kotlin uses `Nothing` when there is none, Dart leaves it `dynamic` (or `Never`).
abstract class BaseEntry<D> {
  /// The y value in value space; for pie and radar entries this is the entry's value.
  double y;

  /// Drawable drawn at the entry's position when the data set has icons enabled, or null for none.
  ChartDrawable? icon;

  /// Optional payload carried with the entry, for example the object the entry was made from.
  final D? data;

  /// Creates an entry part with [y] (default 0), an optional [icon] and an optional [data] payload.
  BaseEntry({this.y = 0, this.icon, this.data});
}
