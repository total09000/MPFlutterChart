// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/ObjectPool.kt

/// Pool that hands out and takes back instances of one [Poolable] type to avoid allocations while drawing.
///
/// Create a pool with [create]. [get] returns an instance and [recycle] takes it back. Each instance
/// remembers which pool holds it, so the pool can tell without searching whether an instance is already
/// stored, and it refuses instances that are stored in this or another pool. An empty pool creates new
/// instances from the model object, and a full pool doubles its capacity. Both operations cost time with
/// large capacities; lower [replenishPercentage] if refilling is a concern.
///
/// Kotlin synchronises [create], [get] and [recycle]; a Dart isolate is single-threaded, so no lock is needed.
class ObjectPool<T extends Poolable> {
  ObjectPool._(this._desiredCapacity, this._modelObject) {
    if (!(_desiredCapacity > 0)) {
      throw ArgumentError(
        'Object Pool must be instantiated with a capacity greater than 0!',
      );
    }
    _objects = List<Poolable?>.filled(_desiredCapacity, null);
    _refillPool();
  }

  int _desiredCapacity;
  final T _modelObject;

  /// Number that identifies this pool. Instances stored in the pool carry it as their owner.
  int get poolId => _poolId;
  int _poolId = 0;

  late List<Poolable?> _objects;
  int _objectsPointer = 0;

  /// Fraction of the capacity that is created when the pool runs empty, between 0 and 1. Default 1.
  /// Values outside that range are clamped. With 0 the pool never refills and [get] fails once empty.
  double get replenishPercentage => _replenishPercentage;
  set replenishPercentage(double value) {
    _replenishPercentage = value < 0
        ? 0
        : value > 1
        ? 1
        : value;
  }

  double _replenishPercentage = 1;

  void _refillPool([double? percentage]) {
    final p = percentage ?? replenishPercentage;
    final scaled = _desiredCapacity * p;
    // Kotlin's Float.toInt() gives 0 for NaN.
    var portionOfCapacity = scaled.isNaN ? 0 : scaled.toInt();
    if (portionOfCapacity < 1) portionOfCapacity = 1;
    if (portionOfCapacity > _desiredCapacity) {
      portionOfCapacity = _desiredCapacity;
    }
    for (var i = 0; i < portionOfCapacity; i++) {
      _objects[i] = _modelObject.instantiate();
    }
    _objectsPointer = portionOfCapacity - 1;
  }

  /// Takes an instance out of the pool. The instance keeps whatever state it had before.
  ///
  /// Refills the pool first when it is empty and [replenishPercentage] is above 0.
  T get() {
    if (_objectsPointer == -1 && replenishPercentage > 0) {
      _refillPool();
    }
    final result = _objects[_objectsPointer] as T;
    _objects[_objectsPointer] = null;
    result.currentOwnerId = Poolable.NO_OWNER;
    _objectsPointer--;
    return result;
  }

  /// Largest number of instances the pool keeps. Anything handed to [recycle] beyond that is dropped and
  /// collected normally, so a caller that recycles more instances than it takes cannot grow the pool forever.
  int get maxCapacity => _maxCapacity;
  set maxCapacity(int value) {
    _maxCapacity = value < 1 ? 1 : value;
  }

  int _maxCapacity = 4096;

  /// Puts [obj] back into the pool. The pool grows when it is full, up to [maxCapacity], and drops the instance
  /// once it is.
  ///
  /// Throws an [ArgumentError] if [obj] is already stored in this pool or in another pool.
  void recycle(T obj) {
    _checkNotOwned(obj);
    if (_objectsPointer + 1 >= maxCapacity) return;
    _objectsPointer++;
    if (_objectsPointer >= _objects.length) {
      _resizePool();
    }
    obj.currentOwnerId = poolId;
    _objects[_objectsPointer] = obj;
  }

  /// Puts all [objects] back into the pool. The pool grows when it is full, up to [maxCapacity], and the
  /// instances that no longer fit are dropped.
  ///
  /// Kotlin's `recycle(objects: List<T>)` overload; Dart has no overloading.
  ///
  /// Throws an [ArgumentError] if one of them is already stored in this pool or in another pool.
  void recycleAll(List<T> objects) {
    final room = maxCapacity - (_objectsPointer + 1);
    if (room <= 0) return;
    final taken = objects.take(room).toList();

    while (taken.length + _objectsPointer + 1 > _desiredCapacity) {
      _resizePool();
    }
    for (var i = 0; i < taken.length; i++) {
      final obj = taken[i];
      _checkNotOwned(obj);
      obj.currentOwnerId = poolId;
      _objects[_objectsPointer + 1 + i] = obj;
    }
    _objectsPointer += taken.length;
  }

  void _checkNotOwned(T obj) {
    if (obj.currentOwnerId == Poolable.NO_OWNER) return;
    if (obj.currentOwnerId == poolId) {
      throw ArgumentError('The object passed is already stored in this pool!');
    }
    throw ArgumentError(
      'The object to recycle already belongs to poolId ${obj.currentOwnerId}.  Object cannot belong to two '
      'different pool instances simultaneously!',
    );
  }

  void _resizePool() {
    final oldCapacity = _desiredCapacity;
    _desiredCapacity *= 2;
    final temp = List<Poolable?>.filled(_desiredCapacity, null);
    for (var i = 0; i < oldCapacity; i++) {
      temp[i] = _objects[i];
    }
    _objects = temp;
  }

  /// Number of instances the pool can hold before it has to grow.
  int get poolCapacity => _objects.length;

  /// Number of instances currently stored in the pool and available to [get].
  int get poolCount => _objectsPointer + 1;

  static int _ids = 0;

  /// Creates a pool with a unique [poolId] that starts filled to [withCapacity].
  ///
  /// [withCapacity] is the initial capacity and must be greater than 0. [obj] is the model object whose
  /// [Poolable.instantiate] creates the pooled instances. Throws an [ArgumentError] if [withCapacity] is 0 or
  /// negative.
  static ObjectPool<T> create<T extends Poolable>(int withCapacity, T obj) {
    final result = ObjectPool<T>._(withCapacity, obj);
    result._poolId = _ids;
    _ids++;
    return result;
  }
}

/// Base class for objects that can be stored in an [ObjectPool] (Kotlin `ObjectPool.Poolable`).
///
/// Subclasses implement [instantiate] so the pool can create new instances from a model object.
abstract class Poolable {
  /// Owner id of an instance that is not stored in any pool.
  static const int NO_OWNER = -1;

  /// The [ObjectPool.poolId] of the pool that stores this instance, or [NO_OWNER]. Kotlin `internal`: maintained
  /// by [ObjectPool]; do not change it.
  int currentOwnerId = NO_OWNER;

  /// Creates a new, blank instance of the same type.
  Poolable instantiate();
}
