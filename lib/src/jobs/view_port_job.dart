// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/jobs/ViewPortJob.kt
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show internal, protected;

import '../utils/chart_invalidator.dart';
import '../utils/object_pool.dart';
import '../utils/transformer.dart';
import '../utils/view_port_handler.dart';

/// Base class of the jobs that move or zoom the viewport of a chart to a position given in value space.
///
/// Jobs are pooled: obtain one with the `getInstance` of a subclass instead of constructing it. Pass its [run] to
/// `chart.addViewportJob`, which runs it right away when the chart has been laid out and otherwise after the
/// first layout, so it can be created before the chart has a size.
///
/// Kotlin's `Runnable` is the [run] method; Android's `View` is the chart as a [ChartInvalidator].
abstract class ViewPortJob extends Poolable {
  /// Creates a job for [viewPortHandler] that converts [xValue] and [yValue] with [transformer] and refreshes
  /// [view].
  ViewPortJob(
    this.viewPortHandler,
    double xValue,
    double yValue,
    this.transformer,
    this.view,
  ) : _xValue = xValue,
      _yValue = yValue;

  /// Viewport of the chart to change.
  @protected
  ViewPortHandler? viewPortHandler;

  /// Converts [xValue] and [yValue] to pixels.
  @protected
  Transformer? transformer;

  /// The chart to refresh.
  @protected
  ChartInvalidator? view;

  /// Buffer for the target point, filled in value space and converted to pixels in place.
  @protected
  final Float32List pts = Float32List(2);

  double _xValue;

  /// Target x value of the job.
  double get xValue => _xValue;

  @protected
  set xValue(double value) => _xValue = value;

  double _yValue;

  /// Target y value of the job.
  double get yValue => _yValue;

  @protected
  set yValue(double value) => _yValue = value;

  /// Does the job, Kotlin's `Runnable.run()`.
  void run();

  /// Drops the references to the chart, so a pooled job does not keep it alive. Internal API.
  @internal
  void releaseChart() {
    viewPortHandler = null;
    transformer = null;
    view = null;
  }
}
