// Android shim: android.graphics.DashPathEffect (path dashing) for MPAndroidChart v4.0.1 port
import 'dart:ui' as ui;

import 'chart_paint.dart';

/// Returns the dashes of [source] for [effect], with the semantics of Skia's dash path effect behind Android's
/// `DashPathEffect`.
///
/// The intervals alternate on and off, starting with on; the phase is an offset into the pattern taken modulo its
/// total length, negative phases included. The pattern starts again at the phase on every contour. An effect with
/// a negative or non-finite interval, or whose intervals add up to zero, is not applied: [source] is returned.
///
/// Unlike Skia, the first and the last dash of a closed contour are not joined into one.
ui.Path dashPath(ui.Path source, DashPathEffect effect) {
  final intervals = effect.intervals;
  var patternLength = 0.0;
  for (final interval in intervals) {
    if (interval < 0 || !interval.isFinite) return source;
    patternLength += interval;
  }
  if (!(patternLength > 0) ||
      !patternLength.isFinite ||
      !effect.phase.isFinite) {
    return source;
  }

  // Normalize the phase into [0, patternLength) as Skia does.
  var phase = effect.phase;
  if (phase < 0) {
    phase = -phase;
    if (phase > patternLength) phase %= patternLength;
    phase = patternLength - phase;
    if (phase == patternLength) phase = 0;
  } else if (phase >= patternLength) {
    phase %= patternLength;
  }

  // Find the interval the phase falls into and how much of it is left.
  var initialIndex = 0;
  var initialRemaining = intervals[0];
  for (var i = 0; i < intervals.length; i++) {
    final interval = intervals[i];
    if (phase > interval || (phase == interval && interval != 0)) {
      phase -= interval;
    } else {
      initialIndex = i;
      initialRemaining = interval - phase;
      break;
    }
  }

  final result = ui.Path();
  for (final metric in source.computeMetrics()) {
    final length = metric.length;
    var distance = 0.0;
    var index = initialIndex;
    var remaining = initialRemaining;

    while (distance < length) {
      // A zero-length dash stays a zero-length line, which round and square caps draw as a dot, as in Skia.
      if (index.isEven) {
        final end = distance + remaining < length
            ? distance + remaining
            : length;
        result.addPath(metric.extractPath(distance, end), ui.Offset.zero);
      }
      distance += remaining;
      index = (index + 1) % intervals.length;
      remaining = intervals[index];
    }
  }
  return result;
}
