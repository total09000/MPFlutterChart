// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/buffer/AbstractBuffer.kt
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show protected;

/// Reusable float buffer that holds the coordinates to draw, so drawing does not allocate: replace instead of
/// recreate. [feed] fills [buffer] from data of type [T]; the subclass defines the layout of the floats.
abstract class AbstractBuffer<T> {
  /// Creates a buffer of [size] floats.
  AbstractBuffer(int size) : buffer = Float32List(size);

  /// Write position of the next float in [buffer].
  @protected
  int index = 0;

  /// The coordinates to draw, in the layout defined by the subclass (see `BarBuffer`). Renderers fill it in value
  /// space and convert it to pixels in place.
  final Float32List buffer;

  /// Animation phase along x (0 to 1). Default 1.
  @protected
  double phaseX = 1;

  /// Animation phase along y (0 to 1); scales the fed values. Default 1.
  @protected
  double phaseY = 1;

  /// Moves the write position back to the start so the buffer can be fed again.
  void reset() {
    index = 0;
  }

  /// Number of floats in [buffer].
  int get size => buffer.length;

  /// Sets the x and y animation phases (0 to 1) used by the next [feed].
  void setPhases(double phaseX, double phaseY) {
    this.phaseX = phaseX;
    this.phaseY = phaseY;
  }

  /// Fills the buffer from [data], starting at the current write position.
  void feed(T data);
}
