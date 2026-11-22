// KotlinRandom against fixtures/design_random.json, which was produced on the JVM with the real kotlin-stdlib
// `kotlin.random.Random`, called in the order DesignCharts calls it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart_example/design/kotlin_random.dart';

/// The ground truth: `raw_nextInt_seed11` is `Random(11).nextInt()` eight times; `candle_seed11`, `bubble_seed5` and
/// `scatter_seed3` are the `nextInt(from, until)` results of DesignCharts.candle, .bubble and .scatter, one list per
/// entry in call order.
final Map<String, dynamic> _truth =
    jsonDecode(File('test/fixtures/design_random.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('nextInt() of Random(11) matches the JVM', () {
    final random = KotlinRandom(11);
    expect([
      for (var i = 0; i < 8; i++) random.nextInt(),
    ], _truth['raw_nextInt_seed11']);
  });

  test('nextIntRange matches the JVM in DesignCharts.candle order', () {
    final random = KotlinRandom(11);
    expect([
      for (var i = 0; i < 20; i++)
        [
          random.nextIntRange(-8, 10),
          random.nextIntRange(1, 6),
          random.nextIntRange(1, 6),
        ],
    ], _truth['candle_seed11']);
  });

  test('nextIntRange matches the JVM in DesignCharts.bubble order, a power '
      'of two range included', () {
    final random = KotlinRandom(5);
    expect([
      for (var i = 0; i < 16; i++)
        [
          random.nextIntRange(0, 60),
          random.nextIntRange(15, 95),
          // 32 values: the nextBits path.
          random.nextIntRange(8, 40),
        ],
    ], _truth['bubble_seed5']);
  });

  test('nextIntRange matches the JVM in DesignCharts.scatter order', () {
    final random = KotlinRandom(3);
    expect([
      for (var set = 0; set < 3; set++)
        [
          for (var i = 0; i < 15; i++)
            [random.nextIntRange(0, 100), random.nextIntRange(5, 98)],
        ],
    ], _truth['scatter_seed3']);
  });

  test('nextBits takes the upper bits of nextInt()', () {
    final a = KotlinRandom(11);
    final b = KotlinRandom(11);
    expect(a.nextBits(32), b.nextInt());
    expect(a.nextBits(5), (b.nextInt() & 0xFFFFFFFF) >>> 27);
    expect(a.nextBits(0), 0);
  });

  test('nextIntRange rejects an empty range, as Kotlin does', () {
    final random = KotlinRandom(11);
    expect(() => random.nextIntRange(5, 5), throwsArgumentError);
    expect(() => random.nextIntRange(6, 5), throwsArgumentError);
  });

  test('nextIntRange covers a range wider than Int.MAX_VALUE', () {
    final random = KotlinRandom(11);
    for (var i = 0; i < 100; i++) {
      final value = random.nextIntRange(-0x80000000, 0x7FFFFFFF);
      expect(value, inInclusiveRange(-0x80000000, 0x7FFFFFFE));
    }
  });
}
