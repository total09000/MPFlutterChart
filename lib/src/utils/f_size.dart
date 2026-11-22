// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/FSize.kt
import 'object_pool.dart';

/// Mutable width and height pair, usually a size in pixels such as measured text bounds.
///
/// Instances handed out by [getInstance] come from a shared pool and should go back through
/// [recycleInstance] once no longer needed. Recycling the same instance twice throws.
/// Two sizes are equal when width and height match.
class FSize extends Poolable {
  /// The horizontal extent.
  double width;

  /// The vertical extent.
  double height;

  /// Creates a [width] by [height] size, zero by default.
  FSize([this.width = 0, this.height = 0]);

  @override
  Poolable instantiate() => FSize(0, 0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FSize) return false;
    return width == other.width && height == other.height;
  }

  @override
  int get hashCode => width.hashCode ^ height.hashCode;

  @override
  String toString() => '${width}x$height';

  static final ObjectPool<FSize> _pool = ObjectPool.create(256, FSize(0, 0))
    ..replenishPercentage = 0.5;

  /// Takes a size from the pool and sets it to [width] by [height].
  static FSize getInstance(double width, double height) {
    final result = _pool.get();
    result.width = width;
    result.height = height;
    return result;
  }

  /// Returns [instance] to the pool.
  ///
  /// Throws an [ArgumentError] if [instance] is already in the pool.
  static void recycleInstance(FSize instance) {
    _pool.recycle(instance);
  }

  /// Returns all [instances] to the pool.
  ///
  /// Throws an [ArgumentError] if one of them is already in the pool.
  static void recycleInstances(List<FSize> instances) {
    _pool.recycleAll(instances);
  }
}
