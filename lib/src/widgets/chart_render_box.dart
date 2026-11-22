// Android shim: the View that shows a chart (onMeasure/onLayout/onSizeChanged, onDraw, invalidate, post, the window's
// frame clock, onDetachedFromWindow, requestDisallowInterceptTouchEvent) for MPAndroidChart v4.0.1 port
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../charts/chart.dart';
import '../charts/chart_host.dart';
import '../utils/utils.dart';

/// A gesture recognizer that can claim its gesture at once, for [ChartRenderBox.disableScroll].
///
/// The chart's gesture recognizer, `ChartGestureRecognizer`, implements it next to [GestureRecognizer], so that the
/// touch listener's `chart.disableScroll()` (Android's `requestDisallowInterceptTouchEvent(true)`) makes the recognizer
/// win the gesture arena right then and an enclosing scrollable no longer gets the gesture. A recognizer
/// that does not implement it receives the pointers, but `disableScroll` does nothing for it.
abstract interface class ChartArenaRecognizer {
  /// Wins the gesture arena for the pointers this recognizer tracks, `GestureArenaEntry.resolve(accepted)`.
  void acceptNow();
}

/// Shows a [Chart] by creating a [ChartRenderBox] that lays it out, paints it and hosts it.
///
/// The render object takes the biggest size its constraints allow; a side without a bound is 300 logical pixels. It
/// rounds the chart's text and pixel lengths on the device pixel grid of the ratio of the nearest `MediaQuery`, or of
/// the `View` without one (see [ChartRenderBox.devicePixelRatio]).
class ChartRenderBoxWidget extends LeafRenderObjectWidget {
  /// Creates a widget that shows [chart], sends pointer downs to [recognizer] and lends [vsync] to its animations.
  const ChartRenderBoxWidget({
    super.key,
    required this.chart,
    this.recognizer,
    this.vsync,
  });

  /// The chart to show. A chart is shown by one render object at a time.
  final Chart chart;

  /// Receives every pointer down inside the chart, or null for a chart that ignores touches. Normally a
  /// `ChartGestureRecognizer` that passes the touches to `Chart.onTouchEvent`. The widget does not own it: whoever
  /// creates it disposes it.
  final GestureRecognizer? recognizer;

  /// Drives the animations of the chart while it is shown (normally the `State` of the widget that builds this one),
  /// or null to end every animation at once.
  final TickerProvider? vsync;

  /// The device pixel ratio the chart is shown at: the nearest `MediaQuery`'s, or the `View`'s without one.
  static double _devicePixelRatioOf(BuildContext context) =>
      MediaQuery.maybeDevicePixelRatioOf(context) ??
      View.of(context).devicePixelRatio;

  @override
  ChartRenderBox createRenderObject(BuildContext context) => ChartRenderBox(
    chart: chart,
    recognizer: recognizer,
    vsync: vsync,
    devicePixelRatio: _devicePixelRatioOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, ChartRenderBox renderObject) {
    renderObject
      ..chart = chart
      ..recognizer = recognizer
      ..vsync = vsync
      ..devicePixelRatio = _devicePixelRatioOf(context);
  }
}

/// The render object that shows a [Chart], the Android `View` of the chart. It implements [ChartHost]
/// and is the chart's `host` while it is attached.
///
/// - Layout: the box takes the biggest size its constraints allow, 300 logical pixels on a side without a bound, and
///   calls `Chart.onSizeChanged` when that size differs from the chart's size. It sets `Utils.devicePixelRatio` to
///   [devicePixelRatio] first, and calls `Chart.notifyDataSetChanged` when the size is unchanged but the chart was
///   not yet laid out by this box at that ratio.
/// - Paint: the chart draws itself with `Chart.onDraw` onto the canvas, moved to the box's offset and clipped to the
///   box. The box is a repaint boundary, so the chart redraws alone.
/// - Redraw requests, `Chart.invalidate`, mark the box as needing paint. Flutter merges them per frame.
/// - Posted jobs, `Chart.post`, run after the current frame; a frame is scheduled when none is coming.
/// - The [vsync] drives the chart's animations, `Chart.animator` and the animated viewport jobs.
/// - Pointer downs go to the [recognizer] (normally a `ChartGestureRecognizer`, which follows the pointers from
///   there); `Chart.disableScroll` makes it win the gesture arena.
/// - Leaving the tree (detach, dispose) is `View.onDetachedFromWindow`: running animations end at their final state,
///   then the animator loses its vsync and the chart its host. The `onEnd` callbacks of those animations run
///   synchronously inside [detach], during the build phase, so one that calls `setState` on an ancestor must defer it
///   (for example with a post-frame callback).
class ChartRenderBox extends RenderBox implements ChartHost {
  /// Creates a render object that shows [chart]; see [ChartRenderBoxWidget] for the parameters.
  ChartRenderBox({
    required Chart chart,
    this.recognizer,
    TickerProvider? vsync,
    double? devicePixelRatio,
  }) : _chart = chart,
       _vsync = vsync,
       _devicePixelRatio = devicePixelRatio;

  /// The extent of a side whose constraints have no bound, in logical pixels.
  static const double _unboundedExtent = 300;

  Chart _chart;

  /// The chart shown. Setting another chart while attached releases the previous one as leaving the tree does and
  /// hosts the new one.
  Chart get chart => _chart;

  set chart(Chart value) {
    if (identical(value, _chart)) return;
    if (attached) _releaseChart();
    _chart = value;
    if (attached) _hostChart();
    _laidOutRatio = null;
    markNeedsLayout();
    markNeedsPaint();
  }

  double? _devicePixelRatio;

  /// The ratio of device pixels to logical pixels of the view the chart is shown in, or null to leave
  /// `Utils.devicePixelRatio` as it is.
  ///
  /// Layout and paint set `Utils.devicePixelRatio` to it before the chart computes its offsets or draws, so the
  /// chart's whole pixels are the device pixels of this view, as Kotlin's `Int` pixels are. `Utils.devicePixelRatio`
  /// is a global: with charts in views of different ratios, the chart laid out or painted last sets it. Setting
  /// another ratio lays the chart out again (`Chart.notifyDataSetChanged`) and repaints it.
  double? get devicePixelRatio => _devicePixelRatio;

  set devicePixelRatio(double? value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  /// The ratio this box last laid [chart] out with, null before its first layout of the chart.
  double? _laidOutRatio;

  /// Makes `Utils.devicePixelRatio` this box's [devicePixelRatio], when it has one.
  void _applyDevicePixelRatio() {
    final ratio = _devicePixelRatio;
    if (ratio != null) Utils.devicePixelRatio = ratio;
  }

  /// Receives every pointer down inside the box, or null. Not owned: the box does not dispose it.
  GestureRecognizer? recognizer;

  TickerProvider? _vsync;

  /// Drives the animations of the chart, or null to end them at once.
  ///
  /// Setting another one while attached ends the running animations at their final state, the viewport animations
  /// included, because they tick on the previous provider, which may be going away, and then calls
  /// `Chart.onHostVsyncChanged`, where the chart stops tickers of its own (a bar or line chart its fling
  /// deceleration); later animations and flings use the new one.
  @override
  TickerProvider? get vsync => _vsync;

  set vsync(TickerProvider? value) {
    if (identical(value, _vsync)) return;
    _vsync = value;
    final chart = _chart;
    if (attached && identical(chart.host, this)) {
      chart.animator.vsync = value;
      for (final job in chart.runningViewPortJobs.toList()) {
        job.endAnimation();
      }
      chart.onHostVsyncChanged();
    }
  }

  bool _disposed = false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _hostChart();
  }

  @override
  void detach() {
    // Detached first: the animations ending below redraw the chart, and a detached box only remembers that request
    // (see markNeedsPaint) instead of scheduling a frame for a box that left the tree.
    super.detach();
    _releaseChart();
  }

  @override
  void dispose() {
    _releaseChart();
    _disposed = true;
    super.dispose();
  }

  /// Makes this box the chart's host, `View.onAttachedToWindow`. The box attached last hosts a chart.
  void _hostChart() {
    _chart.host = this;
    _chart.animator.vsync = _vsync;
  }

  /// Releases the chart when this box hosts it, `View.onDetachedFromWindow`: running animations end at their final
  /// state while the chart still has its host, then the animator loses the vsync and the chart the host, so that
  /// nothing the chart does later reaches this box.
  void _releaseChart() {
    final chart = _chart;
    if (!identical(chart.host, this)) return;
    chart.onDetachedFromWindow();
    chart.animator.vsync = null;
    chart.host = null;
  }

  @override
  bool get isRepaintBoundary => true;

  Size _sizeFor(BoxConstraints constraints) => constraints.constrain(
    Size(
      constraints.hasBoundedWidth ? constraints.maxWidth : _unboundedExtent,
      constraints.hasBoundedHeight ? constraints.maxHeight : _unboundedExtent,
    ),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  /// `View.onMeasure` / `onLayout`: sizes the box and calls `Chart.onSizeChanged` when the chart's size changes.
  @override
  void performLayout() {
    _applyDevicePixelRatio();
    final ratio = Utils.devicePixelRatio;
    size = _sizeFor(constraints);
    if (_chart.width != size.width || _chart.height != size.height) {
      _chart.onSizeChanged(size.width, size.height);
    } else if (_devicePixelRatio != null && _laidOutRatio != ratio) {
      // Same size, but the offsets were computed on another grid (or by another box).
      _chart.notifyDataSetChanged();
    }
    _laidOutRatio = ratio;
  }

  /// `View.onDraw`: the chart draws onto the canvas with its origin at the top left corner of the box, clipped to the
  /// box, as an Android parent view clips its children (`clipChildren`, on by default) and as `Chart.toImage` is.
  /// Labels that reach past the edges are cut off there; `XAxis.isAvoidFirstLastClippingEnabled` keeps the first and
  /// last x labels inside.
  @override
  void paint(PaintingContext context, Offset offset) {
    _applyDevicePixelRatio();
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);
    _chart.onDraw(canvas);
    canvas.restore();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  /// Hands every pointer down inside the box to the [recognizer], `View.dispatchTouchEvent`; the recognizer follows
  /// the pointer from there. A trackpad's pan and zoom gestures (`PointerPanZoomStartEvent`) are not handed on:
  /// MPAndroidChart has none and they are not in scope, so an enclosing scrollable gets them.
  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) recognizer?.addPointer(event);
  }

  /// Marks the box as needing paint, `View.invalidate()`.
  ///
  /// A request after [dispose] is ignored. One while the box is detached only remembers that the box must repaint,
  /// which it does when it is attached again (it no longer hosts the chart then, so only the animations that end
  /// while it is detached ask).
  @override
  void markNeedsPaint() {
    if (_disposed) return;
    super.markNeedsPaint();
  }

  /// Runs [job] after the current frame, `View.post(Runnable)`, and schedules a frame when none is coming.
  ///
  /// The job is dropped when this box no longer hosts the chart by then: the chart left the screen, which also drops
  /// its viewport jobs that wait for a size. On Android a runnable posted while the view is attached still runs. A
  /// job given to a disposed box is dropped at once.
  @override
  void postFrame(void Function() job) {
    if (_disposed) return;
    final chart = _chart;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      if (identical(chart.host, this)) job();
    }, debugLabel: 'ChartRenderBox.postFrame');
    binding.ensureVisualUpdate();
  }

  /// Makes the [recognizer] win the gesture arena, `requestDisallowInterceptTouchEvent(true)`, when it is a
  /// [ChartArenaRecognizer].
  @override
  void disableScroll() {
    if (recognizer case final ChartArenaRecognizer arena) arena.acceptNow();
  }

  /// Does nothing, `requestDisallowInterceptTouchEvent(false)`: Flutter's gesture arena has no way to hand a gesture
  /// back once it is won, and the next gesture starts a new arena anyway.
  @override
  void enableScroll() {}
}
