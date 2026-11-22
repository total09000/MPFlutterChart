// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/EmptyStateLayout.kt
//
// Kotlin `internal`: used by Chart.drawEmptyState, not part of the public API.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show internal;

import '../graphics/chart_paint.dart';
import '../utils/float_math.dart';

/// Places the empty state's icon above its text as one block: centered vertically in the view, and horizontally
/// at the left edge, in the middle or at the right edge depending on `align`. Sizes are in pixels.
@internal
class EmptyStateLayout {
  /// Lays out a block of an icon of [iconWidth] x [iconHeight], a [gap] and a text line of [textWidth] x
  /// [textHeight] in a view of [viewWidth] x [viewHeight], aligned by [align].
  EmptyStateLayout(
    double viewWidth,
    double viewHeight,
    double iconWidth,
    double iconHeight,
    double gap,
    double textWidth,
    double textHeight,
    PaintAlign align,
  ) : _blockWidth = math.max(iconWidth, textWidth) {
    centerX = switch (align) {
      PaintAlign.LEFT => _blockWidth / 2,
      PaintAlign.RIGHT => viewWidth - _blockWidth / 2,
      _ => viewWidth / 2,
    };
    top = (viewHeight - iconHeight - gap - textHeight) / 2;
    textTop = top + iconHeight + gap;
    textX = switch (align) {
      PaintAlign.LEFT => centerX - _blockWidth / 2,
      PaintAlign.RIGHT => centerX + _blockWidth / 2,
      _ => centerX,
    };
  }

  final double _blockWidth;

  /// Horizontal center of the block, which is where the icon is centered.
  late final double centerX;

  /// Top of the block and of the icon.
  late final double top;

  /// Top of the text line.
  late final double textTop;

  /// X to hand to `drawText` for a paint aligned with the layout's alignment.
  late final double textX;
}

/// Share of the icon's alpha while loading at [timeMillis]: it breathes between 30 and 100 percent every 1.4 seconds.
///
/// Computed with Kotlin's Float arithmetic.
@internal
double loadingPulse(int timeMillis) {
  final angle =
      timeMillis.remainder(LOADING_PULSE_MILLIS) /
      LOADING_PULSE_MILLIS.toDouble() *
      2 *
      math.pi;
  final pulse = toKotlinFloat(
    _PULSE_BASE +
        toKotlinFloat(_PULSE_AMPLITUDE * toKotlinFloat(math.sin(angle))),
  );
  // Kotlin's coerceIn(0.3f, 1f).
  if (pulse < _PULSE_MIN) return _PULSE_MIN;
  if (pulse > 1) return 1;
  return pulse;
}

/// Length in milliseconds of one breath of [loadingPulse].
@internal
const int LOADING_PULSE_MILLIS = 1400;

// The Float literals 0.65f, 0.35f and 0.3f.
final double _PULSE_BASE = toKotlinFloat(0.65);
final double _PULSE_AMPLITUDE = toKotlinFloat(0.35);
final double _PULSE_MIN = toKotlinFloat(0.3);
