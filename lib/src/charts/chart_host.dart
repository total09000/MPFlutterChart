// Android shim: the parts of android.view.View / ViewParent a chart calls on itself (invalidate, post, the attached
// window's frame clock, requestDisallowInterceptTouchEvent) for MPAndroidChart v4.0.1 port
import 'package:flutter/scheduler.dart' show TickerProvider;

/// What a chart needs from whatever shows it on screen: the render object of the widget layer implements it and
/// assigns itself to `Chart.host`.
///
/// On Android a chart is a `View` and gets these from the view system. A chart built in code without a host (for
/// example to export an image with `Chart.toImage`) still works: redraw requests do nothing, posted jobs run at once
/// and animations end at once.
///
/// An implementation must set `Chart.host` back to null when it detaches or is disposed. The chart sends every
/// redraw request to its current host, so requests made after that, including those of jobs that were posted earlier
/// and run late, do nothing.
abstract class ChartHost {
  /// Schedules a repaint of the chart, `View.invalidate()`.
  ///
  /// The chart does not call it from `Chart.onDraw`: the empty state's pulse while `Chart.isLoading` is true asks for
  /// the next frame through [postFrame] (Android's `postInvalidateOnAnimation()`). An implementation that is a render
  /// object must ignore a request after it was disposed; while it is detached (before `Chart.host` was set back to
  /// null) it may only mark itself dirty, so that it repaints when it is attached again.
  void markNeedsPaint();

  /// Runs [job] after the current frame, `View.post(Runnable)`. The job may call [markNeedsPaint].
  void postFrame(void Function() job);

  /// The ticker provider that drives animations of the chart while it is shown, or null.
  ///
  /// An implementation whose vsync changes while it hosts a chart gives the chart's animator the new one, ends the
  /// running viewport animations and then calls `Chart.onHostVsyncChanged`, so tickers created from the previous
  /// provider stop.
  TickerProvider? get vsync;

  /// Keeps the current gesture with the chart, so that an enclosing scrollable does not take it over,
  /// `ViewParent.requestDisallowInterceptTouchEvent(true)`.
  void disableScroll();

  /// Lets an enclosing scrollable take over gestures again, `ViewParent.requestDisallowInterceptTouchEvent(false)`.
  void enableScroll();
}
