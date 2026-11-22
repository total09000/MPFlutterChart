// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/charts/Chart.kt
//
// Android's ViewGroup is a plain Dart object here. Whatever shows the chart implements ChartHost, assigns
// itself to [Chart.host] and calls onSizeChanged, onDraw, onTouchEvent and onDetachedFromWindow; the chart's
// invalidate(), post() and disableScroll()/enableScroll() go to the host. View.getWidth()/getHeight() are the
// [Chart.width] / [Chart.height] fields, View.onTouchEvent / computeScroll are members of Chart, postInvalidate() is
// invalidate() and postInvalidateOnAnimation() is post(invalidate) (the loading pulse never asks for a
// repaint while the chart is painted). Not ported (Android only): the Context/AttributeSet constructors,
// onMeasure/onLayout, saveToGallery, isHardwareAccelerationEnabled and unbindDrawables. toBitmap is toImage.
//
// Flutter additions (not in Kotlin): [Chart.afterDrawListeners], called at the end of every onDraw. MPChartCompose's
// ChartState observed the view with a ViewTreeObserver.OnDrawListener; a chart here is no View, so the widget layer's
// ChartController and WidgetMarker listen to the chart itself (api_parity whitelist). [Chart.onHostVsyncChanged], which
// the host calls when it lends the chart another vsync, so tickers on the previous one stop.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show debugPrint, internal, mustCallSuper, protected;

import '../animation/chart_animator.dart';
import '../animation/easing.dart';
import '../animation/value_transition.dart';
import '../components/description.dart';
import '../components/i_marker.dart';
import '../components/legend.dart';
import '../components/marker_image.dart';
import '../components/marker_view.dart';
import '../components/x_axis.dart';
import '../data/bar_entry.dart';
import '../data/candle_entry.dart';
import '../data/chart_data.dart';
import '../data/entry.dart';
import '../formatter/default_value_formatter.dart';
import '../formatter/i_value_formatter.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_drawable.dart';
import '../graphics/chart_paint.dart';
import '../graphics/mutable_rect.dart';
import '../graphics/typeface.dart';
import '../highlight/highlight.dart';
import '../highlight/i_highlighter.dart';
import '../interfaces/dataprovider/chart_interface.dart';
import '../interfaces/datasets/i_data_set.dart';
import '../jobs/animated_view_port_job.dart';
import '../listener/chart_touch_listener.dart';
import '../listener/on_chart_gesture_listener.dart';
import '../listener/on_chart_value_selected_listener.dart';
import '../renderer/data_renderer.dart';
import '../renderer/legend_renderer.dart';
import '../utils/chart_invalidator.dart';
import '../utils/float_math.dart';
import '../utils/mp_point_f.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import '../widgets/chart_touch_event.dart';
import 'chart_host.dart';
import 'empty_state_layout.dart';

/// Base class of every chart. It owns the data, the axis, legend and description components,
/// the paints, highlighting, markers, animation and the viewport jobs that all chart types share.
///
/// [T] is the [ChartData] type this chart displays. Every concrete chart fixes it, for example
/// `LineChart` shows `LineData`.
///
/// A chart is a plain object: a widget shows it through a [ChartHost], and a chart built in code can be drawn with
/// [toImage] or onto any canvas with [onSizeChanged] and [onDraw].
abstract class Chart<T extends ChartData>
    implements ChartInterface, ChartInvalidator {
  /// Creates the chart and calls [init].
  Chart() {
    init();
  }

  /// What shows this chart on screen and receives its redraw, post and scroll requests, or null. The widget layer's
  /// render object assigns itself here while it is attached.
  ChartHost? host;

  /// Width of the chart in logical pixels, `View.getWidth()`. Set by [onSizeChanged].
  double width = 0;

  /// Height of the chart in logical pixels, `View.getHeight()`. Set by [onSizeChanged].
  double height = 0;

  /// Prints chart internals with `debugPrint` while true. Slows down drawing, so keep it off in production.
  bool isLogEnabled = false;

  T? _data;

  /// The data this chart displays, or null when nothing has been set.
  ///
  /// Setting a non-null value sizes the default value formatter to the data's y range, assigns that
  /// formatter to every data set that has none, and calls [notifyDataSetChanged], which recalculates
  /// and redraws the chart. Setting null removes the data and redraws; [clear] does the same and also
  /// clears highlights.
  ///
  /// Setting it ends running value animations from [animateValue] and [animateDataChange] first, so their entries
  /// hold their target values.
  @override
  T? get data => _data;

  set data(T? value) {
    animator.endValueAnimations();
    _data = value;
    _offsetsCalculated = false;

    if (value == null) {
      invalidate();
      return;
    }

    setupDefaultFormatter(value.yMin, value.yMax);

    for (final set in value.dataSets) {
      if (set.needsFormatter ||
          identical(set.valueFormatter, defaultValueFormatterInternal)) {
        set.valueFormatter = defaultValueFormatterInternal;
      }
    }

    notifyDataSetChanged();

    if (isLogEnabled) debugPrint('$LOG_TAG: Data is set.');
  }

  /// Whether a tap highlights the nearest value. Values can still be highlighted by drag or in code.
  bool isHighlightPerTapEnabled = true;

  /// Whether the chart keeps scrolling after the finger is lifted.
  bool isDragDecelerationEnabled = true;

  double _dragDecelerationFrictionCoef = 0.9;

  /// How slowly a deceleration scroll loses speed, between 0 (stops at once) and 0.999.
  /// Values outside that range are clamped. Default 0.9.
  double get dragDecelerationFrictionCoef => _dragDecelerationFrictionCoef;

  set dragDecelerationFrictionCoef(double value) {
    // Kotlin's coerceIn: NaN stays NaN.
    _dragDecelerationFrictionCoef = value < 0
        ? 0
        : value > 0.999
        ? 0.999
        : value;
  }

  /// Formatter used for data sets without their own. Its digit count follows the y range of the data.
  @protected
  final DefaultValueFormatter defaultValueFormatterInternal =
      DefaultValueFormatter(0);

  @override
  IValueFormatter get defaultValueFormatter => defaultValueFormatterInternal;

  /// Paint used for the description text.
  late ChartPaint descriptionPaint;

  /// Paint used for the no-data text.
  late ChartPaint infoPaint;

  late XAxis _xAxis;

  /// The x axis component: its labels, range, grid lines and position.
  XAxis get xAxis => _xAxis;

  @protected
  set xAxis(XAxis value) => _xAxis = value;

  /// Whether the chart reacts to touch at all. False disables tapping, dragging, scaling and rotating.
  bool isTouchEnabled = true;

  /// The description text drawn in the bottom right corner by default.
  late Description description;

  late Legend _legend;

  /// The legend component. It is filled from the data sets unless a custom legend is set on it.
  Legend get legend => _legend;

  @protected
  set legend(Legend value) => _legend = value;

  /// Single listener told when a value is selected or the selection is cleared.
  OnChartValueSelectedListener? onChartValueSelectedListener;

  /// Additional listeners, notified after [onChartValueSelectedListener] in list order.
  /// Meant for observers that must not replace the app's own listener, such as a widget's chart controller.
  final List<OnChartValueSelectedListener> valueSelectedListeners = [];

  /// Additional gesture listeners, notified after [onChartGestureListener] in list order.
  final List<OnChartGestureListener> gestureListeners = [];

  /// Called at the end of every [onDraw], in list order: after the markers, or after the empty state.
  ///
  /// Not in Kotlin: it stands in for the `ViewTreeObserver.OnDrawListener` that MPChartCompose's `ChartState` added to
  /// the chart's view. Meant for observers of what the chart shows, such as the widget layer's `ChartController` and
  /// `WidgetMarker`. A listener runs while the chart is being painted, so it must not change the chart or ask for a
  /// redraw; [toImage] draws the chart too and calls the listeners as well.
  final List<void Function()> afterDrawListeners = [];

  /// Calls each of [afterDrawListeners]. [onDraw] calls it once at its very end; a chart type that overrides [onDraw]
  /// and draws after `super.onDraw` calls it at the end of its own [onDraw] instead, as `BarLineChartBase`, `PieChart`
  /// and `RadarChart` do.
  @protected
  void notifyAfterDraw() {
    for (final listener in afterDrawListeners.toList()) {
      listener();
    }
  }

  /// Calls [block] with [onChartGestureListener] and then with each of [gestureListeners]. Internal API.
  @internal
  void notifyGesture(void Function(OnChartGestureListener listener) block) {
    final listener = onChartGestureListener;
    if (listener != null) block(listener);
    for (final listener in gestureListeners.toList()) {
      block(listener);
    }
  }

  /// Replaces [onChartValueSelectedListener] with functions.
  ///
  /// [onValueSelected] is called with the selected entry and its [Highlight]; [onNothingSelected] when the
  /// selection is cleared, and does nothing by default.
  ///
  /// Kotlin's `onValueSelected(onNothingSelected, onValueSelected)` takes the selection callback as its trailing
  /// lambda; here it is the positional argument and [onNothingSelected] is named.
  void onValueSelected(
    void Function(Entry entry, Highlight highlight) onValueSelected, {
    void Function() onNothingSelected = _noop,
  }) {
    onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
      onValueSelected: onValueSelected,
      onNothingSelected: onNothingSelected,
    );
  }

  ChartTouchListener? _chartTouchListener;

  /// Handles touch events for this chart. Replace it to customize gestures; [isTouchEnabled] must stay true.
  ChartTouchListener get chartTouchListener =>
      _chartTouchListener ??
      (throw StateError('chartTouchListener has not been initialized.'));

  set chartTouchListener(ChartTouchListener value) =>
      _chartTouchListener = value;

  /// Whether [chartTouchListener] has been assigned, Kotlin's `::chartTouchListener.isInitialized`.
  @protected
  bool get isChartTouchListenerInitialized => _chartTouchListener != null;

  String _noDataText = 'No data yet';

  /// Text of the empty state, drawn while the chart has no data or data without entries. An empty string draws
  /// only the icon.
  String get noDataText => _noDataText;

  set noDataText(String value) {
    _noDataText = value;
    invalidate();
  }

  String _loadingText = 'Loading…';

  /// Text of the empty state while [isLoading] is true.
  String get loadingText => _loadingText;

  set loadingText(String value) {
    _loadingText = value;
    invalidate();
  }

  bool _isLoading = false;

  /// Whether the data is on its way. While true and the chart has nothing to draw, the empty state shows
  /// [loadingText] and its icon pulses. Data that arrives is drawn as usual, so this can stay true until then.
  bool get isLoading => _isLoading;

  set isLoading(bool value) {
    _isLoading = value;
    invalidate();
  }

  bool _isNoDataIconEnabled = true;

  /// Whether the empty state draws an icon above its text: [noDataIcon], or a small outline of this chart type.
  bool get isNoDataIconEnabled => _isNoDataIconEnabled;

  set isNoDataIconEnabled(bool value) {
    _isNoDataIconEnabled = value;
    invalidate();
  }

  ChartDrawable? _noDataIcon;

  /// Icon drawn above the empty state text instead of the outline of this chart type, or null for the outline.
  ChartDrawable? get noDataIcon => _noDataIcon;

  set noDataIcon(ChartDrawable? value) {
    _noDataIcon = value;
    invalidate();
  }

  /// Color of the chart type outline in the empty state. Default a faint slate that reads on light and dark backgrounds.
  ui.Color get noDataIconColor => _noDataIconPaint.color;

  set noDataIconColor(ui.Color value) {
    _noDataIconPaint.color = value;
    invalidate();
  }

  final ChartPaint _noDataIconPaint = ChartPaint()
    ..color = const ui.Color.fromARGB(84, 138, 148, 166);
  final MutableRect _noDataIconBounds = MutableRect();

  /// Single listener told about gestures such as tap, double tap, drag, scale and fling.
  OnChartGestureListener? onChartGestureListener;

  late LegendRenderer _legendRenderer;

  /// Draws the [legend].
  LegendRenderer get legendRenderer => _legendRenderer;

  @protected
  set legendRenderer(LegendRenderer value) => _legendRenderer = value;

  /// Paint used for legend labels.
  ChartPaint get legendLabelPaint => legendRenderer.labelPaint;

  set legendLabelPaint(ChartPaint value) {
    legendRenderer.labelPaint = value;
  }

  DataRenderer? _renderer;

  /// Draws the data. Each chart type installs its own renderer; replace it for custom drawing.
  DataRenderer get renderer =>
      _renderer ?? (throw StateError('renderer has not been initialized.'));

  set renderer(DataRenderer value) => _renderer = value;

  /// Whether [renderer] has been assigned, Kotlin's `::renderer.isInitialized`.
  @protected
  bool get isRendererInitialized => _renderer != null;

  /// Turns a touch position into the [Highlight] of the nearest value.
  late IHighlighter highlighter;

  ViewPortHandler _viewPortHandler = ViewPortHandler();

  /// Holds the chart size, the content rectangle and the zoom and drag matrix.
  ViewPortHandler get viewPortHandler => _viewPortHandler;

  @protected
  set viewPortHandler(ViewPortHandler value) => _viewPortHandler = value;

  late ChartAnimator _animator;

  /// Runs the animations: the x and y phases of [animateX], [animateY] and [animateXY], and the value animations.
  ChartAnimator get animator => _animator;

  @protected
  set animator(ChartAnimator value) => _animator = value;

  /// Extra space in dp added above the content area on top of the calculated offsets.
  double extraTopOffset = 0;

  /// Extra space in dp added right of the content area on top of the calculated offsets.
  double extraRightOffset = 0;

  /// Extra space in dp added below the content area on top of the calculated offsets.
  double extraBottomOffset = 0;

  /// Extra space in dp added left of the content area on top of the calculated offsets.
  double extraLeftOffset = 0;

  bool _offsetsCalculated = false;

  List<Highlight> _highlighted = const [];

  /// The values currently highlighted. Empty, never null, when nothing is highlighted.
  List<Highlight> get highlighted => _highlighted;

  @protected
  set highlighted(List<Highlight> value) => _highlighted = value;

  /// Farthest distance in dp a touch may be from a value and still highlight it. Default 500.
  @override
  double maxHighlightDistance = 500;

  /// Whether the [marker] is drawn at highlighted values.
  bool isDrawMarkersEnabled = true;

  IMarker? _marker;

  /// Marker drawn at each highlighted value, or null for none.
  /// A [MarkerView] or [MarkerImage] is attached to this chart when set.
  IMarker? get marker => _marker;

  set marker(IMarker? value) {
    _marker = value;
    if (value is MarkerView) value.chartView = this;
    if (value is MarkerImage) value.chartView = this;
  }

  /// Viewport jobs waiting for the chart to get a size. They run once in [onSizeChanged].
  final List<void Function()> jobs = [];

  /// Kept for API parity; it has no effect. On Android it releases the background drawable and the child views when
  /// the chart leaves the window; a Flutter chart has neither.
  bool isUnbindEnabled = false;

  /// The animated viewport jobs of this chart whose animation is running; [onDetachedFromWindow] ends them.
  /// Internal API, maintained by [AnimatedViewPortJob].
  @internal
  final Set<AnimatedViewPortJob> runningViewPortJobs = Set.identity();

  /// Creates the components, paints and animator. Subclasses add their renderer, highlighter and touch listener.
  @protected
  @mustCallSuper
  void init() {
    // Kotlin's `ChartAnimator { postInvalidate() }`.
    animator = ChartAnimator(onUpdate: invalidate);

    // Kotlin's Utils.init(context) is not needed: dp are logical pixels.

    description = Description();
    legend = Legend();
    legendRenderer = LegendRenderer(viewPortHandler, legend);
    xAxis = XAxis();

    descriptionPaint = ChartPaint();

    infoPaint = ChartPaint()
      ..color = const ui.Color.fromARGB(255, 138, 148, 166)
      ..textAlign = PaintAlign.CENTER
      ..textSize = Utils.convertDpToPixel(13)
      // Android's Typeface.create("sans-serif-medium", Typeface.NORMAL).
      ..typeface = const Typeface(weight: ui.FontWeight.w500);

    if (isLogEnabled) debugPrint('$LOG_TAG: Chart.init()');
  }

  /// Sets [data] to null, clears the highlight and redraws, which shows [noDataText].
  void clear() {
    data = null;
    _offsetsCalculated = false;
    highlighted = const [];
    chartTouchListener.lastHighlighted = null;
    invalidate();
  }

  /// Removes all data sets from [data] but keeps the data object, then redraws. Does nothing without data.
  void clearValues() {
    data?.clearValues();
    invalidate();
  }

  /// True when there is no data or the data holds no entries.
  bool get isEmpty => (data?.entryCount ?? 0) <= 0;

  /// Refreshes the data, recalculates axis ranges, legend and offsets and redraws.
  /// Call it after changing entries or data sets in place. Does nothing while [data] is null.
  void notifyDataSetChanged();

  /// Computes the content rectangle from the legend, axis labels and extra offsets.
  @protected
  void calculateOffsets();

  /// Computes the axis ranges from the data.
  @protected
  void calcMinMax();

  /// Sets the digit count of the default value formatter from the value range.
  ///
  /// [min] is the smallest y value of the data, [max] the largest.
  @protected
  void setupDefaultFormatter(double min, double max) {
    final data = this.data;
    final double reference;
    if (data == null || data.entryCount < 2) {
      reference = math.max(min.abs(), max.abs());
    } else {
      reference = (max - min).abs();
    }

    final digits = Utils.getDecimals(reference);
    defaultValueFormatterInternal.setup(digits);
  }

  /// Draws the chart onto [canvas], whose origin is the top left corner of the chart, `View.onDraw`.
  ///
  /// The base draws the empty state while there is nothing to draw (and then calls [notifyAfterDraw]) and otherwise
  /// calculates the offsets once; subclasses draw the rest and call [notifyAfterDraw] at their end.
  void onDraw(ui.Canvas canvas) {
    if (showsEmptyState) {
      drawEmptyState(canvas);
      // Not in Kotlin, see afterDrawListeners.
      notifyAfterDraw();
      return;
    }

    if (!_offsetsCalculated) {
      calculateOffsets();
      _offsetsCalculated = true;
    }
  }

  /// Draws the [description] text at its position, or in the bottom right corner when it has none.
  @protected
  void drawDescription(ui.Canvas c) {
    final description = this.description;
    if (!description.isEnabled) return;

    final position = description.position;

    descriptionPaint.typeface = description.typeface;
    descriptionPaint.textSize = Utils.convertDpToPixel(description.textSize);
    descriptionPaint.color = description.textColor;
    descriptionPaint.textAlign = description.textAlign;

    final double x;
    final double y;

    if (position == null) {
      x =
          width -
          viewPortHandler.offsetRight -
          Utils.convertDpToPixel(description.xOffset);
      y =
          height -
          viewPortHandler.offsetBottom -
          Utils.convertDpToPixel(description.yOffset);
    } else {
      x = position.x;
      y = position.y;
    }

    c.drawText(description.text, x, y, descriptionPaint);
  }

  /// True when at least one value is highlighted.
  bool valuesToHighlight() {
    return highlighted.isNotEmpty;
  }

  /// Tells the touch listener which highlight a tap must toggle off next.
  @protected
  void setLastHighlighted(List<Highlight>? highs) {
    chartTouchListener.lastHighlighted = (highs == null || highs.isEmpty)
        ? null
        : highs.first;
  }

  /// Highlights all the given values at once and redraws. The list is taken as is, without checking that
  /// the entries exist, and no listener is called. An empty list clears the highlight.
  void highlightValues(List<Highlight> highs) {
    highlighted = highs;
    setLastHighlighted(highs);
    invalidate();
  }

  /// Highlights the entry closest to the given x value (and, when [y] is a number, closest to [y] among entries with
  /// the same x) in one data set and redraws.
  ///
  /// [x] is the x value to search for; [dataSetIndex] the index of the data set to search, where an index outside the
  /// data clears the highlight; [y] the y value to search for, NaN (the default) to accept any y value; [dataIndex]
  /// the index of the data object inside the data of a combined chart only; [stackIndex] the index inside a stacked
  /// bar, or -1 for the whole bar; [callListener] whether the value selected listeners are notified.
  ///
  /// Covers Kotlin's `highlightValue(x, dataSetIndex, ...)` and `highlightValue(x, y, dataSetIndex, ...)` overloads;
  /// the [Highlight] overload is [highlightValueOf].
  void highlightValue(
    double x,
    int dataSetIndex, {
    double y = double.nan,
    int dataIndex = -1,
    int stackIndex = -1,
    bool callListener = true,
  }) {
    final dataSetCount = data?.dataSetCount ?? 0;
    if (dataSetIndex < 0 || dataSetIndex >= dataSetCount) {
      highlightValueOf(null, callListener: callListener);
    } else {
      highlightValueOf(
        Highlight(x, y, dataSetIndex, dataIndex)..stackIndex = stackIndex,
        callListener: callListener,
      );
    }
  }

  /// Highlights the value described by [highlight] and redraws. This is what a tap calls.
  /// Null, or a highlight that matches no entry, clears the highlight instead.
  ///
  /// [highlight] says which data set and x value to highlight, or is null to clear. [callListener] is whether
  /// [onChartValueSelectedListener] and [valueSelectedListeners] are notified with `onValueSelected` or, when
  /// nothing ends up highlighted, `onNothingSelected`.
  ///
  /// Kotlin's `highlightValue(highlight, callListener)` overload.
  void highlightValueOf(Highlight? highlight, {bool callListener = true}) {
    var high = highlight;
    Entry? e;

    if (high == null) {
      highlighted = const [];
    } else {
      if (isLogEnabled) debugPrint('$LOG_TAG: Highlighted: $high');

      e = data?.getEntryForHighlight(high);
      if (e == null) {
        highlighted = const [];
        high = null;
      } else {
        highlighted = [high];
      }
    }

    setLastHighlighted(highlighted);

    if (callListener) {
      final single = onChartValueSelectedListener;
      final listeners = [?single, ...valueSelectedListeners];
      for (final listener in listeners) {
        if (!valuesToHighlight() || e == null || high == null) {
          listener.onNothingSelected();
        } else {
          listener.onValueSelected(e, high);
        }
      }
    }

    invalidate();
  }

  /// Finds the value nearest to a touch position.
  ///
  /// [x] and [y] are the touch position in pixels. Returns the [Highlight] of the nearest value, or null when there is
  /// no data or no value within [maxHighlightDistance].
  Highlight? getHighlightByTouchPoint(double x, double y) {
    if (data == null) {
      debugPrint("$LOG_TAG: Can't select by touch. No data set.");
      return null;
    }
    return highlighter.getHighlight(x, y);
  }

  /// Draws the [marker] at every highlighted value that lies inside the content area.
  @protected
  void drawMarkers(ui.Canvas canvas) {
    final marker = this.marker;
    if (marker == null) return;
    if (!isDrawMarkersEnabled || !valuesToHighlight()) return;

    final data = this.data;
    if (data == null) return;
    final highlighted = this.highlighted;

    for (final highlight in highlighted) {
      final set = data.getDataSetByIndex(highlight.dataSetIndex);
      if (set == null) continue;

      final e = data.getEntryForHighlight(highlight);
      if (e == null) continue;
      final entryIndex = set.getEntryIndexOf(e);

      if (entryIndex > set.entryCount * animator.phaseX) continue;

      final pos = getMarkerPosition(highlight);

      if (!viewPortHandler.isInBounds(pos[0], pos[1])) continue;

      marker.refreshContent(e, highlight);
      marker.draw(canvas, pos[0], pos[1]);
    }
  }

  /// Pixel position where the marker for [high] is drawn, as `[x, y]`.
  @protected
  Float32List getMarkerPosition(Highlight high) =>
      Float32List.fromList([high.drawX, high.drawY]);

  /// Animates the drawing of the data along both axes. The chart redraws itself while animating. Running x and y
  /// animations are cancelled first.
  ///
  /// [durationMillisX] and [durationMillisY] are the durations of the x and y animations in milliseconds, [easingX]
  /// the easing of the x animation and [easingY] the easing of the y animation, by default the same as [easingX].
  /// [onEnd] is called once after both animations have ended, see [animateX].
  void animateXY(
    int durationMillisX,
    int durationMillisY, {
    EasingFunction easingX = Easing.Linear,
    EasingFunction? easingY,
    void Function() onEnd = _noop,
  }) {
    animator.animateXY(
      durationMillisX,
      durationMillisY,
      easingX: easingX,
      easingY: easingY ?? easingX,
      onEnd: onEnd,
    );
  }

  /// Animates the drawing of the data along the x axis. The chart redraws itself while animating. A running x
  /// animation is cancelled first.
  ///
  /// [durationMillis] is the duration in milliseconds and [easing] the easing of the animation. [onEnd] is called once
  /// when the animation ends: when it finishes, when [stopAnimations] or leaving the window ends it, and when a new x
  /// animation cancels it.
  ///
  /// When the widget that shows the chart goes away, [onEnd] is called synchronously inside `RenderObject.detach`,
  /// during the build phase. An [onEnd] that calls `setState` on an ancestor widget then must defer it, for example
  /// with `SchedulerBinding.instance.addPostFrameCallback`. The same holds for every other `onEnd` of the chart.
  void animateX(
    int durationMillis, {
    EasingFunction easing = Easing.Linear,
    void Function() onEnd = _noop,
  }) {
    animator.animateX(durationMillis, easing: easing, onEnd: onEnd);
  }

  /// Animates the drawing of the data along the y axis. The chart redraws itself while animating. A running y
  /// animation is cancelled first.
  ///
  /// [durationMillis] is the duration in milliseconds and [easing] the easing of the animation. [onEnd] is called once
  /// when the animation ends, see [animateX].
  void animateY(
    int durationMillis, {
    EasingFunction easing = Easing.Linear,
    void Function() onEnd = _noop,
  }) {
    animator.animateY(durationMillis, easing: easing, onEnd: onEnd);
  }

  /// Animates the y value of one entry to [toY]. The axis ranges follow the value on every frame. Works for line,
  /// bar, scatter, bubble, pie and radar entries. A running animation of the same entry is cancelled first and the
  /// new one starts from the current value. Setting [data] ends the animation with the entry at [toY].
  ///
  /// [entry] is an entry of the current [data], [toY] the y value the entry ends with, [durationMillis] the duration in
  /// milliseconds and [easing] the easing of the animation. [onEnd] is called once when the animation ends: when it
  /// finishes, when it is ended early, and when a new animation of the same entry cancels it. It may run while the
  /// chart's widget goes away, see [animateX].
  ///
  /// Throws an [ArgumentError] when [entry] is not part of [data], is a stacked `BarEntry` (animate a stack with
  /// [animateDataChange]) or is a `CandleEntry`, which does not draw its y.
  void animateValue(
    Entry entry,
    double toY,
    int durationMillis, {
    EasingFunction easing = Easing.Linear,
    void Function() onEnd = _noop,
  }) {
    if (entry is BarEntry && entry.isStacked) {
      throw ArgumentError(
        'animateValue does not animate stacked bars, use animateDataChange.',
      );
    }
    if (entry is CandleEntry) {
      throw ArgumentError(
        'animateValue does not animate candle entries, use animateDataChange.',
      );
    }
    IDataSet? dataSet;
    for (final it in data?.dataSets ?? const <IDataSet>[]) {
      if (it.getEntryIndexOf(entry) >= 0) {
        dataSet = it;
        break;
      }
    }
    if (dataSet == null) {
      throw ArgumentError('The entry is not part of the chart data.');
    }

    _dataChange?.release(entry);
    final transition = ValueTransition.ofY(entry, toY, dataSet);
    animator.start(
      key: entry,
      from: 0,
      to: 1,
      durationMillis: durationMillis,
      easing: easing,
      onUpdate: (fraction) {
        transition.apply(fraction);
        refreshAfterValueChange(transition.dataSets);
      },
      onEnd: (cancelled) {
        // A cancelling animation of the same entry continues from the current value.
        if (!cancelled) {
          transition.finish();
          refreshAfterValueChange(transition.dataSets);
        }
        onEnd();
      },
    );
  }

  /// Sets [newData] and animates every entry from the value it replaces to its own value. Entries are paired by
  /// data set index and entry index; entries past the old end grow from 0, entries past the new end are gone at
  /// once. Stacked bars animate each stack value, candles open, high, low and close, bubbles their size and pie
  /// slices their value. The axis ranges follow on every frame and highlights stay on their x value.
  ///
  /// [newData] is set without animation, as if [data] were set, when the chart has no data, when [newData] is the
  /// current data, or when the shapes differ: another data class, another number of data sets or another data set
  /// class at the same index. A running data change or value animation ends first; the new one starts from the
  /// values shown at that moment.
  ///
  /// The entries of [newData] are moved on every frame and hold exactly their own values again when the animation
  /// ends, also when it is ended early by setting [data], by [stopAnimations] or by leaving the window.
  ///
  /// [newData] is the data to show: pass a new instance, not the current data changed in place. [durationMillis] is
  /// the duration in milliseconds and [easing] the easing of the animation. [onEnd] is called once when the animation
  /// ends, right away when nothing is animated. It may run while the chart's widget goes away, see [animateX].
  void animateDataChange(
    T newData,
    int durationMillis, {
    EasingFunction easing = Easing.Linear,
    void Function() onEnd = _noop,
  }) {
    final oldData = data;
    final transition = (oldData == null || identical(oldData, newData))
        ? null
        : ValueTransition.between(oldData, newData);
    data = newData;
    if (transition == null) {
      onEnd();
      return;
    }

    _dataChange = transition;
    transition.apply(0);
    refreshAfterValueChange(transition.dataSets);
    animator.start(
      key: ChartAnimator.DATA_CHANGE,
      from: 0,
      to: 1,
      durationMillis: durationMillis,
      easing: easing,
      onUpdate: (fraction) {
        transition.apply(fraction);
        refreshAfterValueChange(transition.dataSets);
      },
      onEnd: (_) {
        if (identical(_dataChange, transition)) _dataChange = null;
        transition.finish();
        refreshAfterValueChange(transition.dataSets);
        onEnd();
      },
    );
  }

  ValueTransition? _dataChange;

  /// True while any animation runs: [animateX], [animateY], [animateXY], a spin, [animateValue] or [animateDataChange].
  bool get isAnimating => animator.isAnimating;

  /// Ends every running animation at once at its final state: the drawing is complete, a spin stands at its end
  /// angle and animated values hold their targets. Each `onEnd` runs. Leaving the window does the same.
  void stopAnimations() {
    animator.stop();
  }

  /// Recomputes ranges, axes and offsets and redraws after the values of entries in [changedSets] changed in place.
  /// Only the changed data sets are walked, and legend and buffers are kept. Highlights follow the values they
  /// point at and are dropped when their entry is gone. Internal API.
  @internal
  void refreshAfterValueChange(List<IDataSet> changedSets) {
    final data = this.data;
    if (data == null) return;
    for (final set in changedSets) {
      set.calcMinMax();
    }
    data.notifyDataChanged();
    calcMinMax();
    computeAxes();
    calculateOffsets();
    _followHighlights(data);
    invalidate();
  }

  /// Computes the axis labels from the axis ranges. Charts with axes override it. Internal API.
  @internal
  void computeAxes() {}

  void _followHighlights(T data) {
    if (highlighted.isEmpty) return;
    final followed = <Highlight>[];
    for (final high in highlighted) {
      final entry =
          data.getEntryForHighlight(high) ??
          data.getEntryForHighlight(_withY(high, double.nan));
      if (entry == null) continue;
      followed.add(
        (high.y.isNaN || high.y == entry.y) ? high : _withY(high, entry.y),
      );
    }
    highlighted = followed;
    setLastHighlighted(highlighted);
  }

  static Highlight _withY(Highlight high, double y) =>
      Highlight.stackedWithPixels(
          high.x,
          y,
          high.xPx,
          high.yPx,
          high.dataSetIndex,
          high.stackIndex,
          high.axis,
        )
        ..dataIndex = high.dataIndex
        ..setDraw(high.drawX, high.drawY);

  /// Largest y value across all data sets, or 0 without data.
  double get yMax => data?.yMax ?? 0;

  /// Smallest y value across all data sets, or 0 without data.
  double get yMin => data?.yMin ?? 0;

  @override
  double get xChartMax => xAxis.axisMaximum;

  @override
  double get xChartMin => xAxis.axisMinimum;

  @override
  double get xRange => xAxis.axisRange;

  /// Center of the whole chart in pixels, ignoring offsets. See [centerOffsets] for the content center.
  MPPointF get center => MPPointF(width / 2, height / 2);

  @override
  MPPointF get centerOffsets => viewPortHandler.contentCenter;

  @override
  MPPointF get centerOfView => center;

  @override
  MutableRect get contentRect => viewPortHandler.contentRect;

  /// Sets all four extra offsets in dp at once. They apply on the next offset calculation.
  void setExtraOffsets(double left, double top, double right, double bottom) {
    extraLeftOffset = left;
    extraTopOffset = top;
    extraRightOffset = right;
    extraBottomOffset = bottom;
  }

  /// Whether the chart has no data or no entries and draws its empty state instead of the data.
  @protected
  bool get showsEmptyState => isEmpty;

  /// Draws the empty state: the icon and [noDataText], or [loadingText] while [isLoading], as one block centered
  /// vertically and placed horizontally by [noDataTextAlignment]. Override it to draw an empty state of your own.
  @protected
  void drawEmptyState(ui.Canvas canvas) {
    final text = isLoading ? loadingText : noDataText;
    final double iconHeight = isNoDataIconEnabled
        ? Utils.convertDpToPixel(24)
        : 0;
    final icon = noDataIcon;
    final double iconWidth;
    if (iconHeight == 0) {
      iconWidth = 0;
    } else if (icon != null && icon.intrinsicHeight > 0) {
      iconWidth = iconHeight * icon.intrinsicWidth / icon.intrinsicHeight;
    } else {
      iconWidth = Utils.convertDpToPixel(30);
    }
    final double textHeight = text.isEmpty
        ? 0
        : infoPaint.descent() - infoPaint.ascent();
    final double gap = (iconHeight > 0 && text.isNotEmpty)
        ? Utils.convertDpToPixel(10)
        : 0;
    if (iconHeight == 0 && textHeight == 0) return;

    final double textWidth = text.isEmpty ? 0 : infoPaint.measureText(text);
    final layout = EmptyStateLayout(
      width,
      height,
      iconWidth,
      iconHeight,
      gap,
      textWidth,
      textHeight,
      infoPaint.textAlign,
    );

    if (iconHeight > 0) {
      final pulse = isLoading
          ? loadingPulse(DateTime.now().millisecondsSinceEpoch)
          : 1.0;
      _noDataIconBounds.set(
        layout.centerX - iconWidth / 2,
        layout.top,
        layout.centerX + iconWidth / 2,
        layout.top + iconHeight,
      );
      if (icon != null) {
        // Drawable.setBounds takes whole (device) pixels.
        final bounds = MutableRect(
          truncateToDevicePx(_noDataIconBounds.left),
          truncateToDevicePx(_noDataIconBounds.top),
          truncateToDevicePx(_noDataIconBounds.right),
          truncateToDevicePx(_noDataIconBounds.bottom),
        );
        icon.alpha = kotlinFloatToInt(255 * pulse);
        icon.draw(canvas, bounds);
      } else {
        final color = _noDataIconPaint.color;
        _noDataIconPaint.alpha = kotlinFloatToInt(
          _noDataIconPaint.alpha * pulse,
        );
        drawNoDataIcon(canvas, _noDataIconBounds, _noDataIconPaint);
        _noDataIconPaint.color = color;
      }
      // Kotlin's postInvalidateOnAnimation(): redraw on the next frame while the icon pulses. Posted, so the host
      // never gets a repaint request while it paints.
      if (isLoading) post(invalidate);
    }

    if (text.isNotEmpty) {
      canvas.drawText(
        text,
        layout.textX,
        layout.textTop - infoPaint.ascent(),
        infoPaint,
      );
    }
  }

  /// Draws the outline of this chart type that the empty state shows above its text, inside [bounds], with
  /// [paint] in [noDataIconColor]. The default draws three bars; line, pie, radar, scatter and bubble charts draw
  /// their own shape.
  @protected
  void drawNoDataIcon(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) {
    paint.style = PaintStyle.FILL;
    final barWidth = bounds.width() / 4.5;
    final gap = (bounds.width() - 3 * barWidth) / 2;
    final heights = Float32List.fromList([0.55, 1, 0.75]);
    final radius = barWidth / 3.5;
    for (var i = 0; i <= 2; i++) {
      final left = bounds.left + i * (barWidth + gap);
      canvas.drawRoundRectP(
        MutableRect(
          left,
          bounds.bottom - bounds.height() * heights[i],
          left + barWidth,
          bounds.bottom,
        ),
        radius,
        radius,
        paint,
      );
    }
  }

  /// Color of [noDataText] and [loadingText].
  ui.Color get noDataTextColor => infoPaint.color;

  set noDataTextColor(ui.Color value) {
    infoPaint.color = value;
    invalidate();
  }

  /// Size of [noDataText] and [loadingText] in dp. Default 13.
  double get noDataTextSize => Utils.convertPixelsToDp(infoPaint.textSize);

  set noDataTextSize(double value) {
    infoPaint.textSize = Utils.convertDpToPixel(value);
    invalidate();
  }

  /// Typeface of [noDataText] and [loadingText]; null sets the default. Default sans serif medium.
  Typeface get noDataTextTypeface => infoPaint.typeface;

  set noDataTextTypeface(Typeface? value) {
    infoPaint.typeface = value;
  }

  /// Horizontal alignment of the empty state: at the left edge, in the center or at the right edge of the chart.
  PaintAlign get noDataTextAlignment => infoPaint.textAlign;

  set noDataTextAlignment(PaintAlign value) {
    infoPaint.textAlign = value;
  }

  /// Keeps the current gesture with the chart, so an enclosing scrollable does not take it over
  /// (`requestDisallowInterceptTouchEvent(true)` on Android).
  void disableScroll() {
    host?.disableScroll();
  }

  /// Lets an enclosing scrollable take over gestures again (`requestDisallowInterceptTouchEvent(false)` on Android).
  void enableScroll() {
    host?.enableScroll();
  }

  /// Draws the chart into a new image, over white. Kotlin's `toBitmap`.
  ///
  /// [width] and [height] are the size of the chart for the drawing in logical pixels, the units of [width] and
  /// [height] and of every size in the chart (Android's dp). They default to the chart's current size, rounded to
  /// whole pixels. When another size is asked for, the chart is laid out at that size for the drawing (through
  /// [onSizeChanged]) and put back to its previous size afterwards, so a chart that was never shown, for example one
  /// built in code only to export an image, can be drawn with `chart.toImage(width: 1200, height: 800)`. A chart
  /// without a size and without an asked for size is drawn at 1 x 1.
  ///
  /// The image has [pixelRatio] image pixels per logical pixel, `(width * pixelRatio).ceil()` x
  /// `(height * pixelRatio).ceil()`. Android's `toBitmap` has one bitmap pixel per device pixel; pass the device pixel
  /// ratio (`MediaQuery.devicePixelRatioOf(context)`) for an image as sharp as the chart on screen. The default of 1
  /// gives one image pixel per logical pixel. Throws an [ArgumentError] when [pixelRatio] is not a positive finite
  /// number.
  ///
  /// Animations of a chart without a host have already ended, so the image shows the final state.
  Future<ui.Image> toImage({
    int? width,
    int? height,
    double pixelRatio = 1.0,
  }) async {
    if (!(pixelRatio > 0) || !pixelRatio.isFinite) {
      throw ArgumentError.value(
        pixelRatio,
        'pixelRatio',
        'must be a positive finite number',
      );
    }
    final previousWidth = this.width;
    final previousHeight = this.height;
    final layoutWidth = math.max(width ?? previousWidth.round(), 1);
    final layoutHeight = math.max(height ?? previousHeight.round(), 1);
    final resize =
        layoutWidth != previousWidth || layoutHeight != previousHeight;
    if (resize) _layoutAt(layoutWidth.toDouble(), layoutHeight.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (pixelRatio != 1) canvas.scale(pixelRatio);
    canvas.drawColorP(const ui.Color(0xFFFFFFFF));
    onDraw(canvas);
    final picture = recorder.endRecording();

    if (resize && previousWidth > 0 && previousHeight > 0) {
      _layoutAt(previousWidth, previousHeight);
    }
    try {
      return await picture.toImage(
        math.max((layoutWidth * pixelRatio).ceil(), 1),
        math.max((layoutHeight * pixelRatio).ceil(), 1),
      );
    } finally {
      picture.dispose();
    }
  }

  /// Draws the chart like [toImage] and encodes the image as PNG.
  Future<Uint8List> toPngBytes({
    int? width,
    int? height,
    double pixelRatio = 1.0,
  }) async {
    final image = await toImage(
      width: width,
      height: height,
      pixelRatio: pixelRatio,
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    } finally {
      image.dispose();
    }
  }

  void _layoutAt(double width, double height) {
    onSizeChanged(width, height);
  }

  /// Removes a job from [jobs] before it has run.
  void removeViewportJob(void Function() job) {
    jobs.remove(job);
  }

  /// Drops all jobs waiting in [jobs].
  void clearAllViewportJobs() {
    jobs.clear();
  }

  /// Runs a viewport job once the chart has a size: posted right away when it already has one, otherwise stored
  /// in [jobs] until [onSizeChanged]. The zoom and move functions use this, passing a job's `run`. At most 64 jobs
  /// wait, because only the last position matters and a chart that never gets a size would otherwise collect them
  /// forever.
  void addViewportJob(void Function() job) {
    if (viewPortHandler.hasChartDimens()) {
      post(job);
    } else {
      while (jobs.length >= _MAX_WAITING_JOBS) {
        jobs.removeAt(0);
      }
      jobs.add(job);
    }
  }

  /// Sets the chart size to [w] x [h], `View.onSizeChanged`: the host calls it when the laid out size changes.
  ///
  /// A size between 0 and 10000 on both sides is handed to the [viewPortHandler]. Then the data is refreshed and the
  /// waiting [jobs] are posted.
  @mustCallSuper
  void onSizeChanged(double w, double h) {
    // View.setFrame stores the new size before it calls onSizeChanged.
    width = w;
    height = h;

    if (isLogEnabled) debugPrint('$LOG_TAG: OnSizeChanged()');

    if (w > 0 && h > 0 && w < 10000 && h < 10000) {
      if (isLogEnabled) {
        debugPrint('$LOG_TAG: Setting chart dimens, width: $w, height: $h');
      }
      viewPortHandler.setChartDimens(w, h);
    } else {
      if (isLogEnabled) {
        debugPrint(
          '$LOG_TAG: *Avoiding* setting chart dimens! width: $w, height: $h',
        );
      }
    }

    notifyDataSetChanged();

    // Kotlin posts every job and then clears the list; a post without a host runs the job at once, so the list is
    // cleared first and a job that adds a job does not change the list being walked.
    final waiting = jobs.toList();
    jobs.clear();
    for (final r in waiting) {
      post(r);
    }
  }

  /// Ends every running animation at its final state, see [stopAnimations], so no animation keeps the chart alive,
  /// `View.onDetachedFromWindow`. Running viewport animations end at their target too, and jobs still waiting for a
  /// size are dropped, and a pending long press of the touch listener is cancelled. The host calls it when
  /// the chart leaves the screen.
  @mustCallSuper
  void onDetachedFromWindow() {
    // Not in Kotlin: no gesture timer may outlive the host (Android's view system cancels the touch instead).
    _chartTouchListener?.cancelLongPress();
    stopAnimations();
    for (final job in runningViewPortJobs.toList()) {
      job.endAnimation();
    }
    clearAllViewportJobs();
  }

  /// Called by the [host] when its [ChartHost.vsync] changes while it shows this chart; the chart does not call it.
  /// By then the [animator] runs on the new vsync and the running viewport animations have ended at their target.
  ///
  /// Flutter addition, no Kotlin counterpart: an Android view keeps one frame clock for as long as it is attached. A
  /// chart type whose touch listener runs a ticker of its own from the host's vsync stops it here,
  /// because the previous provider may be going away, as `BarLineChartBase` stops a fling deceleration. The base does
  /// nothing.
  @mustCallSuper
  void onHostVsyncChanged() {}

  /// Requests a redraw from the [host], `View.invalidate()`. Does nothing without a host.
  @override
  void invalidate() {
    host?.markNeedsPaint();
  }

  /// Runs [job] after the current frame through the [host], `View.post(Runnable)`, or at once without a host.
  void post(void Function() job) {
    final host = this.host;
    if (host == null) {
      job();
    } else {
      host.postFrame(job);
    }
  }

  /// Handles a touch event and returns true if it was consumed, `View.onTouchEvent`. The base consumes nothing;
  /// charts with gestures pass the event to their [chartTouchListener].
  bool onTouchEvent(ChartTouchEvent event) => false;

  /// Advances a running scroll by one frame, `View.computeScroll()`. The base does nothing; charts that decelerate
  /// after a fling override it.
  ///
  /// On Android the view system calls it on every frame. Here the touch listener drives it: after a fling it runs a
  /// ticker from the host's vsync that calls it on every tick until the deceleration has stopped. The host does not
  /// call it. It may also be called by hand, for example in tests.
  void computeScroll() {}

  /// Tag of the chart log messages.
  static const String LOG_TAG = 'MPAndroidChart';

  /// How many viewport jobs wait for the chart to get a size before the oldest are dropped.
  static const int _MAX_WAITING_JOBS = 64;

  static void _noop() {}
}
