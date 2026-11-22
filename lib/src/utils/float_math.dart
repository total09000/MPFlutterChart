// Kotlin Float emulation helpers for the MPAndroidChart v4.0.1 port; no Kotlin counterpart.
//
// Internal to the package: these are not MPAndroidChart API, so this file is not exported from core.dart or
// mp_flutter_chart.dart, and the helpers are top-level functions with non-Kotlin names rather than Utils members.
// They reproduce Kotlin `Float` behaviour that Dart's `double` does not have, where a ported formula depends on it,
// and the rounding of Kotlin's `Int` pixels, which are device pixels, on the device pixel grid.
import 'dart:math' as math;
import 'dart:typed_data';

import 'utils.dart';

final Float32List _floatBuffer = Float32List(1);

/// Kotlin `Double.toFloat()`: rounds [value] to the nearest Float (overflowing to ±infinity).
double toKotlinFloat(double value) {
  _floatBuffer[0] = value;
  return _floatBuffer[0];
}

/// Kotlin's `Float.toString()` as far as Dart's `double.toString()` gives it: a whole number keeps its `.0` on the
/// web too, where Dart prints `1.0` as `1`.
String kotlinFloatToString(double value) {
  final s = value.toString();
  if (!value.isFinite || s.contains('.') || s.contains('e')) return s;
  return '$s.0';
}

/// Kotlin `Float.toInt()`: truncates towards zero, saturating at the Int range; NaN gives 0.
int kotlinFloatToInt(double value) {
  if (value.isNaN) return 0;
  if (value >= 2147483647.0) return 2147483647;
  if (value <= -2147483648.0) return -2147483648;
  return value.toInt();
}

/// Kotlin `Float.MAX_VALUE`, the largest finite Float. The data classes use it (and its negation) as the "no data"
/// value of their cached ranges, so code that checks for an empty range compares against this exact value (it equals
/// ViewPortHandler's private `_FLOAT_MAX_VALUE`).
const double kotlinFloatMaxValue = 3.4028234663852886e38;

/// Kotlin `Float` overflow without the Float rounding: returns [value] unchanged while it lies within the Float range
/// and what Kotlin's Float arithmetic gives beyond it (±infinity, or ±Float.MAX_VALUE within half an ulp above it).
///
/// The axes use it for their range arithmetic, where Kotlin's overflow to infinity is load-bearing (for example the
/// empty-data range Float.MAX_VALUE .. -Float.MAX_VALUE has an infinite span, for which the axis renderer computes no
/// labels), while in-range values keep the precision of the double they were computed from.
double kotlinFloatOverflow(double value) =>
    value.isFinite && value.abs() > kotlinFloatMaxValue
    ? toKotlinFloat(value)
    : value;

/// `kotlin.math.log10` (Java `Math.log10`): the base 10 logarithm, exact at the powers of ten a double holds
/// exactly (`log10(1000.0)` is 3), where `log(x) / ln10` is off by an ulp (2.9999999999999996). The axis renderer
/// truncates the logarithm to pick the label magnitude, so that ulp would change the result.
double kotlinLog10(double value) {
  final r = math.log(value) / math.ln10;
  if (!r.isFinite) return r;
  final n = r.roundToDouble();
  if (n != r && (n - r).abs() < 1e-9 && math.pow(10.0, n) == value) return n;
  return r;
}

// ---------------------------------------------------------------------------------------------------------------
// Kotlin's Int pixels are device px; the port's lengths are logical px. These round a logical px value on the device
// px grid of Utils.devicePixelRatio and return it in logical px, so `(v * r).floor() / r` and so on.

/// The ratio the grid helpers use: [Utils.devicePixelRatio], or 1 when it is not a positive finite number.
double get _ratio {
  final r = Utils.devicePixelRatio;
  return r > 0 && r.isFinite ? r : 1.0;
}

/// [value] in device px at [ratio]. A value within 1e-6 device px of a whole number is taken as that number: a value
/// already on the grid (`n / r`) multiplies back to `n` give or take an ulp, which floor and ceil would otherwise
/// turn into a whole px.
double _toDevice(double value, double ratio) {
  final d = value * ratio;
  if (!d.isFinite) return d;
  final n = d.roundToDouble();
  return (d - n).abs() <= 1e-6 ? n : d;
}

/// [value] (logical px) rounded down to whole device px. NaN and infinities are returned unchanged.
double floorToDevicePx(double value) {
  final r = _ratio;
  if (r == 1.0) return value.floorToDouble();
  return _toDevice(value, r).floorToDouble() / r;
}

/// [value] (logical px) rounded up to whole device px. NaN and infinities are returned unchanged.
double ceilToDevicePx(double value) {
  final r = _ratio;
  if (r == 1.0) return value.ceilToDouble();
  return _toDevice(value, r).ceilToDouble() / r;
}

/// Kotlin `Float.toInt()` of [value] in device px, in logical px: truncates towards zero to whole device px,
/// saturating at the Int range of device px; NaN gives 0 (see [kotlinFloatToInt]).
double truncateToDevicePx(double value) {
  final r = _ratio;
  if (r == 1.0) return kotlinFloatToInt(value).toDouble();
  if (value.isNaN) return 0;
  return kotlinFloatToInt(_toDevice(value, r)) / r;
}

/// Kotlin `Float.roundToInt()` of [value] in device px, in logical px: `Math.round` (ties towards positive
/// infinity), saturating at the Int range of device px; NaN throws.
double roundToDevicePx(double value) {
  if (value.isNaN) {
    throw ArgumentError('Cannot round NaN value.');
  }
  final r = _ratio;
  return kotlinFloatToInt((_toDevice(value, r) + 0.5).floorToDouble()) / r;
}

/// One device px in logical px, Kotlin's `1f` minimum of a pixel width.
double get oneDevicePx => 1 / _ratio;
