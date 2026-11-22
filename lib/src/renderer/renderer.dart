// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/Renderer.kt
import 'package:flutter/foundation.dart' show protected;

import '../utils/view_port_handler.dart';

/// Base class of everything that draws onto a chart canvas.
abstract class Renderer {
  /// Creates a renderer drawing into the content rectangle of [viewPortHandler].
  Renderer(this.viewPortHandler);

  /// Holds the content rectangle and the current zoom and translation of the chart, in pixels.
  @protected
  final ViewPortHandler viewPortHandler;
}
