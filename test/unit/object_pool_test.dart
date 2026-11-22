// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/ObjectPoolTest.kt
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/utils/object_pool.dart';

class TestPoolable extends Poolable {
  int foo;
  int bar;

  TestPoolable._(this.foo, this.bar);

  @override
  Poolable instantiate() => TestPoolable._(0, 0);

  static final ObjectPool<TestPoolable> pool = ObjectPool.create(
    4,
    TestPoolable._(0, 0),
  );

  static TestPoolable getInstance(int foo, int bar) {
    final result = pool.get();
    result.foo = foo;
    result.bar = bar;
    return result;
  }

  static void recycleInstance(TestPoolable instance) => pool.recycle(instance);

  static void recycleInstances(List<TestPoolable> instances) =>
      pool.recycleAll(instances);
}

class _CappedPoolable extends Poolable {
  int value;

  _CappedPoolable(this.value);

  @override
  Poolable instantiate() => _CappedPoolable(0);
}

void main() {
  void assertPool(int capacity, int count) {
    expect(TestPoolable.pool.poolCapacity, capacity);
    expect(TestPoolable.pool.poolCount, count);
  }

  test('poolGrowsRecyclesAndRefills', () {
    assertPool(4, 4);

    var testPoolable = TestPoolable.getInstance(6, 7);
    expect(testPoolable.foo, 6);
    expect(testPoolable.bar, 7);
    assertPool(4, 3);

    TestPoolable.recycleInstance(testPoolable);
    assertPool(4, 4);

    testPoolable = TestPoolable.getInstance(20, 30);
    expect(testPoolable.foo, 20);
    expect(testPoolable.bar, 30);
    TestPoolable.recycleInstance(testPoolable);
    assertPool(4, 4);

    final testPoolables = <TestPoolable>[];
    testPoolables.add(TestPoolable.getInstance(12, 24));
    testPoolables.add(TestPoolable.getInstance(1, 2));
    testPoolables.add(TestPoolable.getInstance(3, 5));
    testPoolables.add(TestPoolable.getInstance(6, 8));
    assertPool(4, 0);

    TestPoolable.recycleInstances(testPoolables);
    assertPool(4, 4);
    testPoolables.clear();

    testPoolables.add(TestPoolable.getInstance(12, 24));
    testPoolables.add(TestPoolable.getInstance(1, 2));
    testPoolables.add(TestPoolable.getInstance(3, 5));
    testPoolables.add(TestPoolable.getInstance(6, 8));
    testPoolables.add(TestPoolable.getInstance(8, 9));
    expect(testPoolables[0].foo, 12);
    expect(testPoolables[0].bar, 24);
    expect(testPoolables[1].foo, 1);
    expect(testPoolables[1].bar, 2);
    expect(testPoolables[2].foo, 3);
    expect(testPoolables[2].bar, 5);
    expect(testPoolables[3].foo, 6);
    expect(testPoolables[3].bar, 8);
    expect(testPoolables[4].foo, 8);
    expect(testPoolables[4].bar, 9);
    assertPool(4, 3);

    TestPoolable.recycleInstances(testPoolables);
    assertPool(8, 8);
    testPoolables.clear();

    testPoolables.add(TestPoolable.getInstance(0, 0));
    testPoolables.add(TestPoolable.getInstance(6, 8));
    testPoolables.add(TestPoolable.getInstance(1, 2));
    testPoolables.add(TestPoolable.getInstance(3, 5));
    testPoolables.add(TestPoolable.getInstance(8, 9));
    testPoolables.add(TestPoolable.getInstance(12, 24));
    testPoolables.add(TestPoolable.getInstance(12, 24));
    testPoolables.add(TestPoolable.getInstance(12, 24));
    testPoolables.add(TestPoolable.getInstance(6, 8));
    testPoolables.add(TestPoolable.getInstance(6, 8));
    expect(testPoolables[0].foo, 0);
    expect(testPoolables[1].foo, 6);
    expect(testPoolables[2].foo, 1);
    expect(testPoolables[3].foo, 3);
    expect(testPoolables[4].foo, 8);
    expect(testPoolables[5].foo, 12);
    expect(testPoolables[6].foo, 12);
    expect(testPoolables[7].foo, 12);
    expect(testPoolables[8].foo, 6);
    expect(testPoolables[9].foo, 6);

    for (final p in testPoolables) {
      TestPoolable.recycleInstance(p);
    }
    assertPool(16, 16);

    testPoolable = TestPoolable.getInstance(9001, 9001);
    expect(testPoolable.foo, 9001);
    expect(testPoolable.bar, 9001);
    assertPool(16, 15);

    TestPoolable.recycleInstance(testPoolable);
    assertPool(16, 16);

    Object? thrown;
    try {
      TestPoolable.recycleInstance(testPoolable);
    } catch (ex) {
      thrown = ex;
    }
    expect(thrown, isNotNull);

    testPoolables.clear();
    TestPoolable.pool.replenishPercentage = 0.5;
    for (var i = 0; i < 16; i++) {
      testPoolables.add(TestPoolable.getInstance(0, 0));
    }
    assertPool(16, 0);

    testPoolables.add(TestPoolable.getInstance(0, 0));
    assertPool(16, 7);
  });

  test('poolStopsGrowingAtItsMaximum', () {
    final pool = ObjectPool.create(4, _CappedPoolable(0));
    pool.maxCapacity = 8;

    // Recycling instances the pool never handed out is how a caller could grow it without limit.
    for (var i = 0; i < 40; i++) {
      pool.recycle(_CappedPoolable(i));
    }

    expect(pool.poolCount, 8);
    expect(pool.poolCapacity, lessThanOrEqualTo(16));
  });
}
