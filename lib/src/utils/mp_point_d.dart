// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/MPPointD.kt
import 'float_math.dart';
import 'object_pool.dart';

/// Mutable point with double coordinates, used where chart values and pixel positions need the
/// extra precision, for example by `Transformer`.
///
/// Instances handed out by [getInstance] come from a shared pool and should go back through
/// [recycleInstance] once no longer needed. Points returned by public chart getters are fresh
/// instances that you may keep or recycle as you like. Recycling the same instance twice throws.
class MPPointD extends Poolable {
  /// The horizontal coordinate.
  double x;

  /// The vertical coordinate.
  double y;

  /// Creates a point at ([x], [y]).
  MPPointD(this.x, this.y);

  @override
  Poolable instantiate() => MPPointD(0, 0);

  @override
  String toString() => 'MPPointD, x: ${kotlinFloatToString(x)}, y: ${kotlinFloatToString(y)}';

  static final ObjectPool<MPPointD> _pool = ObjectPool.create(
    64,
    MPPointD(0, 0),
  )..replenishPercentage = 0.5;

  /// Takes a point from the pool and sets it to ([x], [y]).
  static MPPointD getInstance(double x, double y) {
    final result = _pool.get();
    result.x = x;
    result.y = y;
    return result;
  }

  /// Returns [instance] to the pool.
  ///
  /// Throws an [ArgumentError] if [instance] is already in the pool.
  static void recycleInstance(MPPointD instance) {
    _pool.recycle(instance);
  }

  /// Returns all [instances] to the pool.
  ///
  /// Throws an [ArgumentError] if one of them is already in the pool.
  static void recycleInstances(List<MPPointD> instances) {
    _pool.recycleAll(instances);
  }
}
