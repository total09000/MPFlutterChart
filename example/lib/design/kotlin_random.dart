// Ported from kotlin-stdlib: kotlin/random/Random.kt (`Random(seed: Int)`, `nextInt(from, until)`) and
// kotlin/random/XorWowRandom.kt, bit for bit, so DesignCharts' seeded data equals MPChartExample's.
//
// Kotlin's `Int` is 32-bit two's complement; a Dart `int` is 64-bit, so every result is cut back with toSigned(32)
// and `ushr` masks to 32 bits before shifting.

/// Kotlin's `kotlin.random.Random(seed)`: the xorwow generator `XorWowRandom(seed, seed shr 31)`, giving the same
/// numbers as the JVM for the same seed and the same calls.
class KotlinRandom {
  int _x;
  int _y;
  int _z;
  int _w;
  int _v;
  int _addend;

  /// `Random(seed)`, which is `XorWowRandom(seed1 = seed, seed2 = seed shr 31)`.
  factory KotlinRandom(int seed) =>
      KotlinRandom._seeded(seed.toSigned(32), seed.toSigned(32) >> 31);

  /// `XorWowRandom(seed1, seed2)`: the state `(seed1, seed2, 0, 0, seed1.inv(), (seed1 shl 10) xor (seed2 ushr 4))`,
  /// after which the first 64 numbers are discarded, since some trivial seeds give several numbers with zeroes in
  /// the upper bits.
  KotlinRandom._seeded(int seed1, int seed2)
    : _x = seed1,
      _y = seed2,
      _z = 0,
      _w = 0,
      _v = (~seed1).toSigned(32),
      _addend = (_shl(seed1, 10) ^ _ushr(seed2, 4)).toSigned(32) {
    if ((_x | _y | _z | _w | _v) == 0) {
      throw ArgumentError(
        'Initial state must have at least one non-zero element.',
      );
    }
    for (var i = 0; i < 64; i++) {
      nextInt();
    }
  }

  static int _shl(int value, int bits) => (value << bits).toSigned(32);

  static int _ushr(int value, int bits) =>
      ((value & 0xFFFFFFFF) >>> bits).toSigned(32);

  /// The next random 32-bit integer, `XorWowRandom.nextInt()`: Marsaglia's xorwow (2003, Xorshift RNGs, p. 5).
  int nextInt() {
    var t = _x;
    t = (t ^ _ushr(t, 2)).toSigned(32);
    _x = _y;
    _y = _z;
    _z = _w;
    final v0 = _v;
    _w = v0;
    t = ((t ^ _shl(t, 1)) ^ v0 ^ _shl(v0, 4)).toSigned(32);
    _v = t;
    _addend = (_addend + 362437).toSigned(32);
    return (t + _addend).toSigned(32);
  }

  /// [bitCount] random bits, `nextInt().takeUpperBits(bitCount)`: the upper [bitCount] bits of [nextInt], or 0 for a
  /// [bitCount] of 0.
  int nextBits(int bitCount) =>
      (_ushr(nextInt(), 32 - bitCount) & ((-bitCount) >> 31)).toSigned(32);

  /// A random integer from [from] inclusive to [until] exclusive, Kotlin's `nextInt(from, until)`; renamed because
  /// Dart has no overloading. Throws an [ArgumentError] when [until] is not greater than [from].
  int nextIntRange(int from, int until) {
    if (until <= from) {
      throw ArgumentError('Random range is empty: [$from, $until).');
    }
    final n = (until - from).toSigned(32);
    if (n > 0 || n == -0x80000000) {
      final int rnd;
      if ((n & (-n).toSigned(32)) == n) {
        rnd = nextBits(_fastLog2(n));
      } else {
        int v;
        int bits;
        do {
          bits = _ushr(nextInt(), 1);
          v = bits % n;
        } while ((bits - v + (n - 1)).toSigned(32) < 0);
        rnd = v;
      }
      return (from + rnd).toSigned(32);
    } else {
      while (true) {
        final rnd = nextInt();
        if (rnd >= from && rnd < until) return rnd;
      }
    }
  }

  /// `fastLog2(value) = 31 - value.countLeadingZeroBits()`, for a power of two seen as 32 bits.
  static int _fastLog2(int value) => (value & 0xFFFFFFFF).bitLength - 1;
}
