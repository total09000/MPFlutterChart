// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/MPPointF.kt
import 'object_pool.dart';

/// Mutable point with float coordinates, usually a pixel position.
///
/// Instances handed out by [getInstance] come from a shared pool and should go back through
/// [recycleInstance] once no longer needed. Points returned by public chart getters are fresh
/// instances that you may keep or recycle as you like. Recycling the same instance twice throws.
class MPPointF extends Poolable {
  /// The horizontal coordinate.
  double x;

  /// The vertical coordinate.
  double y;

  /// Creates a point at ([x], [y]), the origin by default.
  MPPointF([this.x = 0, this.y = 0]);

  @override
  Poolable instantiate() => MPPointF(0, 0);

  static final ObjectPool<MPPointF> _pool = ObjectPool.create(
    32,
    MPPointF(0, 0),
  )..replenishPercentage = 0.5;

  /// Takes a point from the pool and sets it to ([x], [y]).
  ///
  /// Called without arguments (Kotlin `getInstance()`) the point keeps whatever coordinates it held before.
  static MPPointF getInstance([double? x, double? y]) {
    final result = _pool.get();
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    return result;
  }

  /// Takes a point from the pool and sets it to the coordinates of [copy].
  ///
  /// Kotlin's `getInstance(copy: MPPointF)` overload; Dart has no overloading.
  static MPPointF getInstanceFrom(MPPointF copy) {
    final result = _pool.get();
    result.x = copy.x;
    result.y = copy.y;
    return result;
  }

  /// Returns [instance] to the pool.
  ///
  /// Throws an [ArgumentError] if [instance] is already in the pool.
  static void recycleInstance(MPPointF instance) {
    _pool.recycle(instance);
  }

  /// Returns all [instances] to the pool.
  ///
  /// Throws an [ArgumentError] if one of them is already in the pool.
  static void recycleInstances(List<MPPointF> instances) {
    _pool.recycleAll(instances);
  }
}
