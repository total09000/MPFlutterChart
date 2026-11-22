// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/listener/OnChartGestureListener.kt
import '../widgets/chart_touch_event.dart';
import 'chart_touch_listener.dart';

/// Receives the touch gestures performed on a chart. Register it as `chart.onChartGestureListener`
/// or add it to `chart.gestureListeners`.
///
/// Every method has an empty default body, so implement only the callbacks you need: extend this class and override
/// them, or pass just those callbacks to [OnChartGestureListener.fromFunction] where Kotlin would write an
/// `object : OnChartGestureListener { ... }` expression. Android's `MotionEvent` is a [ChartTouchEvent].
abstract class OnChartGestureListener {
  /// Lets subclasses be constant.
  const OnChartGestureListener();

  /// Creates a listener that calls the given callbacks; the ones left out do nothing.
  const factory OnChartGestureListener.fromFunction({
    void Function(ChartTouchEvent me, ChartGesture lastPerformedGesture)?
    onChartGestureStart,
    void Function(ChartTouchEvent me, ChartGesture lastPerformedGesture)?
    onChartGestureEnd,
    void Function(ChartTouchEvent me)? onChartLongPressed,
    void Function(ChartTouchEvent me)? onChartDoubleTapped,
    void Function(ChartTouchEvent me)? onChartSingleTapped,
    void Function(
      ChartTouchEvent? me1,
      ChartTouchEvent me2,
      double velocityX,
      double velocityY,
    )?
    onChartFling,
    void Function(ChartTouchEvent me, double scaleX, double scaleY)?
    onChartScale,
    void Function(ChartTouchEvent me, double dX, double dY)? onChartTranslate,
  }) = _FunctionGestureListener;

  /// Called when a finger touches the chart.
  ///
  /// [lastPerformedGesture] is the gesture recognised before this touch began.
  void onChartGestureStart(
    ChartTouchEvent me,
    ChartGesture lastPerformedGesture,
  ) {}

  /// Called when the touch ends or is cancelled.
  ///
  /// [lastPerformedGesture] is the gesture that was recognised during this touch.
  void onChartGestureEnd(
    ChartTouchEvent me,
    ChartGesture lastPerformedGesture,
  ) {}

  /// Called when the chart is long pressed.
  void onChartLongPressed(ChartTouchEvent me) {}

  /// Called when the chart is double tapped, before the double tap zoom is applied.
  void onChartDoubleTapped(ChartTouchEvent me) {}

  /// Called when the chart is single tapped, before the tap highlight is applied.
  void onChartSingleTapped(ChartTouchEvent me) {}

  /// Called when a fast swipe is made on the chart.
  ///
  /// [me1] is the down event that started the fling, may be null; [me2] the move event that triggered the fling;
  /// [velocityX] the horizontal velocity in pixels per second; [velocityY] the vertical velocity in pixels per
  /// second.
  void onChartFling(
    ChartTouchEvent? me1,
    ChartTouchEvent me2,
    double velocityX,
    double velocityY,
  ) {}

  /// Called when the chart is zoomed by pinch or double tap.
  ///
  /// [scaleX] is the scale factor applied on the x axis, 1 when the axis was not zoomed; [scaleY] the scale factor
  /// applied on the y axis, 1 when the axis was not zoomed.
  void onChartScale(ChartTouchEvent me, double scaleX, double scaleY) {}

  /// Called while the chart is dragged, including deceleration after a fling.
  ///
  /// [dX] is the horizontal drag distance in pixels since the drag started; [dY] the vertical drag distance in pixels
  /// since the drag started.
  void onChartTranslate(ChartTouchEvent me, double dX, double dY) {}
}

class _FunctionGestureListener extends OnChartGestureListener {
  const _FunctionGestureListener({
    void Function(ChartTouchEvent me, ChartGesture lastPerformedGesture)?
    onChartGestureStart,
    void Function(ChartTouchEvent me, ChartGesture lastPerformedGesture)?
    onChartGestureEnd,
    void Function(ChartTouchEvent me)? onChartLongPressed,
    void Function(ChartTouchEvent me)? onChartDoubleTapped,
    void Function(ChartTouchEvent me)? onChartSingleTapped,
    void Function(
      ChartTouchEvent? me1,
      ChartTouchEvent me2,
      double velocityX,
      double velocityY,
    )?
    onChartFling,
    void Function(ChartTouchEvent me, double scaleX, double scaleY)?
    onChartScale,
    void Function(ChartTouchEvent me, double dX, double dY)? onChartTranslate,
  }) : _onChartGestureStart = onChartGestureStart,
       _onChartGestureEnd = onChartGestureEnd,
       _onChartLongPressed = onChartLongPressed,
       _onChartDoubleTapped = onChartDoubleTapped,
       _onChartSingleTapped = onChartSingleTapped,
       _onChartFling = onChartFling,
       _onChartScale = onChartScale,
       _onChartTranslate = onChartTranslate;

  final void Function(ChartTouchEvent me, ChartGesture lastPerformedGesture)?
  _onChartGestureStart;
  final void Function(ChartTouchEvent me, ChartGesture lastPerformedGesture)?
  _onChartGestureEnd;
  final void Function(ChartTouchEvent me)? _onChartLongPressed;
  final void Function(ChartTouchEvent me)? _onChartDoubleTapped;
  final void Function(ChartTouchEvent me)? _onChartSingleTapped;
  final void Function(
    ChartTouchEvent? me1,
    ChartTouchEvent me2,
    double velocityX,
    double velocityY,
  )?
  _onChartFling;
  final void Function(ChartTouchEvent me, double scaleX, double scaleY)?
  _onChartScale;
  final void Function(ChartTouchEvent me, double dX, double dY)?
  _onChartTranslate;

  @override
  void onChartGestureStart(
    ChartTouchEvent me,
    ChartGesture lastPerformedGesture,
  ) => _onChartGestureStart?.call(me, lastPerformedGesture);

  @override
  void onChartGestureEnd(
    ChartTouchEvent me,
    ChartGesture lastPerformedGesture,
  ) => _onChartGestureEnd?.call(me, lastPerformedGesture);

  @override
  void onChartLongPressed(ChartTouchEvent me) => _onChartLongPressed?.call(me);

  @override
  void onChartDoubleTapped(ChartTouchEvent me) =>
      _onChartDoubleTapped?.call(me);

  @override
  void onChartSingleTapped(ChartTouchEvent me) =>
      _onChartSingleTapped?.call(me);

  @override
  void onChartFling(
    ChartTouchEvent? me1,
    ChartTouchEvent me2,
    double velocityX,
    double velocityY,
  ) => _onChartFling?.call(me1, me2, velocityX, velocityY);

  @override
  void onChartScale(ChartTouchEvent me, double scaleX, double scaleY) =>
      _onChartScale?.call(me, scaleX, scaleY);

  @override
  void onChartTranslate(ChartTouchEvent me, double dX, double dY) =>
      _onChartTranslate?.call(me, dX, dY);
}
