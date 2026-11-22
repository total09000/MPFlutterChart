// Ported from MPAndroidChart v4.0.1: MPChartCompose/src/main/kotlin/com/github/mikephil/charting/compose/ChartState.kt
//
// Compose's snapshot state is a ChangeNotifier here: the fields are plain getters, and listeners are
// notified once per batch of changes, in a microtask (see [ChartController]). rememberChartState() and its Saver are
// [ChartController.toJson] / [ChartController.restoreFrom] / [ChartController.fromJson]: a map with one key per value
// of the Saver's list, null where Kotlin saves NaN. The draw listener on the view's ViewTreeObserver is a listener in
// Chart.afterDrawListeners; the window attach listener is not needed, since a chart is drawn only while it is shown.
// Kotlin's `internal` attach / detach / syncSelection / refresh are public and @internal (Dart has no module
// visibility).
import 'dart:async' show scheduleMicrotask;

import 'package:flutter/foundation.dart';

import '../animation/easing.dart';
import '../charts/bar_line_chart_base.dart';
import '../charts/chart.dart';
import '../charts/pie_radar_chart_base.dart';
import '../components/y_axis_dependency.dart';
import '../data/chart_data.dart';
import '../data/entry.dart';
import '../highlight/highlight.dart';
import '../jobs/move_view_job.dart';
import '../listener/on_chart_gesture_listener.dart';
import '../listener/on_chart_value_selected_listener.dart';
import '../utils/mp_point_d.dart';

/// Exposes what the user selects and where the viewport is as listenable state, and lets widgets drive the chart.
/// Create it in a `State` (and dispose it there) and pass it to one chart widget; one controller belongs to one chart at
/// a time, and passing it to a second chart moves it there. Listeners set on the chart itself keep working, the
/// controller observes alongside them. All members are main-thread only.
///
/// The functions do nothing while [isAttached] is false, that is before the chart widget has been built and after it
/// left the tree. The viewport functions [fitScreen], [zoomIn], [zoomOut], [resetZoom] and [moveViewToX] only affect
/// line, bar, scatter, candle, bubble and combined charts; the viewport properties reflect them after the next frame.
///
/// The properties change while the chart is drawn, laid out or built, when Flutter does not allow widgets to be
/// marked for a rebuild. So listeners are not called synchronously: they are called once, in a microtask, after one
/// or more properties changed, and only when one of them did change. Listen with a `ListenableBuilder`.
class ChartController extends ChangeNotifier {
  /// Creates a controller that is not attached to a chart yet.
  ChartController();

  /// Creates a controller that applies the values [json] holds, as [restoreFrom] does. Rebuilds `rememberChartState`'s
  /// state from the Saver's saved values.
  factory ChartController.fromJson(Map<String, Object?> json) =>
      ChartController()..restoreFrom(json);

  Entry? _selectedEntry;

  /// Entry the user tapped or [highlight] selected, null while nothing is highlighted. Every chart type updates it.
  Entry? get selectedEntry => _selectedEntry;

  Highlight? _selectedHighlight;

  /// Highlight of [selectedEntry] with its data set, data and stack index, null while nothing is highlighted.
  Highlight? get selectedHighlight => _selectedHighlight;

  double _lowestVisibleX = 0;

  /// Lowest x value visible after dragging or zooming, in value space. Only line, bar, scatter, candle, bubble and
  /// combined charts update it.
  double get lowestVisibleX => _lowestVisibleX;

  double _highestVisibleX = 0;

  /// Highest x value visible after dragging or zooming, in value space. Only line, bar, scatter, candle, bubble and
  /// combined charts update it.
  double get highestVisibleX => _highestVisibleX;

  double _zoomX = 1;

  /// Horizontal zoom factor of the viewport, 1 when not zoomed. Only line, bar, scatter, candle, bubble and combined
  /// charts update it.
  double get zoomX => _zoomX;

  double _zoomY = 1;

  /// Vertical zoom factor of the viewport, 1 when not zoomed. Only line, bar, scatter, candle, bubble and combined
  /// charts update it.
  double get zoomY => _zoomY;

  double _rotationAngle = 270;

  /// Current rotation of the chart in degrees clockwise from 3 o'clock, 270 (12 o'clock) until the user rotates. Only
  /// pie and radar charts update it.
  double get rotationAngle => _rotationAngle;

  WeakReference<Chart>? _chartRef;

  /// The values [restoreFrom] took, applied once the controller is attached to a chart that has its size.
  Map<String, Object?>? _pendingRestore;

  final MPPointD _topLeft = MPPointD(0.0, 0.0);
  double _topLeftX = double.nan;
  double _topLeftY = double.nan;

  /// Whether a property changed since listeners were last notified.
  bool _changed = false;
  bool _notificationScheduled = false;
  bool _disposed = false;

  Chart? get _chart => _chartRef?.target;

  /// False until the chart widget has been built, and again after it left the tree.
  bool get isAttached => _chart != null;

  /// Highlights the entry closest to x value [x] in the data set at [dataSetIndex], as if the user had tapped it, and
  /// updates [selectedEntry] and [selectedHighlight]. Clears the selection instead when the index is out of range or
  /// the data set has no entry near [x]. Does nothing before the chart is attached.
  ///
  /// [dataIndex] is, on a combined chart, the position of the data in `CombinedData.allData` that holds the data set,
  /// as `CombinedData.getDataIndex` returns it. Ignored by the other charts.
  ///
  /// As in Kotlin, the highlight's y is NaN, like Compose's `ChartState.highlight`. So on a `BubbleChart` no highlight
  /// or marker is drawn: `BubbleChartRenderer` skips a highlight whose y is not the entry's. Use
  /// `chart.highlightValue(x, dataSetIndex, y: …)` there.
  void highlight(double x, {int dataSetIndex = 0, int dataIndex = -1}) {
    _chart?.highlightValue(
      x,
      dataSetIndex,
      dataIndex: dataIndex,
      callListener: true,
    );
  }

  /// Removes the highlight and sets [selectedEntry] and [selectedHighlight] to null. Does nothing before the chart is
  /// attached.
  void clearHighlight() {
    _chart?.highlightValueOf(null, callListener: true);
  }

  /// Recomputes axes, legend and offsets and redraws after the data was changed in place, then refreshes the viewport
  /// properties. Does nothing before the chart is attached.
  void notifyDataChanged() {
    final chart = _chart;
    if (chart == null) return;
    chart.notifyDataSetChanged();
    syncSelection();
    refresh();
  }

  /// Animates the drawing along the x axis over [durationMillis] milliseconds. Does nothing before the chart is
  /// attached.
  ///
  /// [easing] is the curve of the animation, linear by default.
  void animateX(int durationMillis, {EasingFunction easing = Easing.Linear}) {
    _chart?.animateX(durationMillis, easing: easing);
  }

  /// Animates the drawing along the y axis over [durationMillis] milliseconds. Does nothing before the chart is
  /// attached.
  ///
  /// [easing] is the curve of the animation, linear by default.
  void animateY(int durationMillis, {EasingFunction easing = Easing.Linear}) {
    _chart?.animateY(durationMillis, easing: easing);
  }

  /// Animates the drawing along both axes at once, over [durationMillisX] and [durationMillisY] milliseconds. Does
  /// nothing before the chart is attached.
  ///
  /// [easingX] is the curve of the x animation, linear by default, and [easingY] the curve of the y animation, the
  /// same as [easingX] by default.
  void animateXY(
    int durationMillisX,
    int durationMillisY, {
    EasingFunction easingX = Easing.Linear,
    EasingFunction? easingY,
  }) {
    _chart?.animateXY(
      durationMillisX,
      durationMillisY,
      easingX: easingX,
      easingY: easingY ?? easingX,
    );
  }

  /// Sets [newData] and animates every entry from the value it replaces to its own value over [durationMillis]
  /// milliseconds, see `Chart.animateDataChange`. [selectedEntry] and [selectedHighlight] are refreshed when the
  /// animation ends. Does nothing before the chart is attached; [onEnd] is not called then.
  ///
  /// [newData] is data of the type the chart shows, for example `LineData` for a line chart (another type throws a
  /// `TypeError`). [easing] is the curve of the animation, linear by default. [onEnd] is called once when the
  /// animation ends.
  void animateDataChange(
    ChartData newData,
    int durationMillis, {
    EasingFunction easing = Easing.Linear,
    void Function() onEnd = _noop,
  }) {
    final chart = _chart;
    if (chart == null) return;
    chart.animateDataChange(
      newData,
      durationMillis,
      easing: easing,
      onEnd: () {
        syncSelection();
        refresh();
        onEnd();
      },
    );
  }

  /// Resets zoom and scroll position so that all data is visible.
  void fitScreen() => _withViewport((chart) => chart.fitScreen());

  /// Zooms in by a factor of 1.4 around the center of the content area.
  void zoomIn() => _withViewport((chart) => chart.zoomIn());

  /// Zooms out by a factor of 0.7 around the center of the content area.
  void zoomOut() => _withViewport((chart) => chart.zoomOut());

  /// Resets the zoom level to 1 without moving the scroll position; use [fitScreen] to reset both.
  void resetZoom() => _withViewport((chart) => chart.resetZoom());

  /// Scrolls so that x value [xValue] sits at the left edge of the content area, keeping the zoom.
  void moveViewToX(double xValue) =>
      _withViewport((chart) => chart.moveViewToX(xValue));

  void _withViewport(void Function(BarLineChartBase chart) action) {
    final chart = _chart;
    if (chart is! BarLineChartBase) return;
    action(chart);
    chart.invalidate();
    chart.post(refresh);
  }

  late final OnChartValueSelectedListener _selectionListener =
      OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) => _setSelection(e, h),
        onNothingSelected: () => _setSelection(null, null),
      );

  late final OnChartGestureListener _gestureListener =
      OnChartGestureListener.fromFunction(
        onChartGestureEnd: (me, lastPerformedGesture) => refresh(),
        onChartDoubleTapped: (me) => refresh(),
        onChartScale: (me, scaleX, scaleY) => refresh(),
        onChartTranslate: (me, dX, dY) => refresh(),
      );

  late final void Function() _drawListener = refresh;

  /// Starts observing [chart] and driving it, after leaving the chart it was attached to. A value restored with
  /// [restoreFrom] is applied once [chart] has its size. Internal API: the chart widgets call it.
  @internal
  void attach(Chart chart) {
    final current = _chart;
    if (identical(current, chart)) return;
    if (current != null) detach(current);
    _chartRef = WeakReference(chart);
    chart.valueSelectedListeners.add(_selectionListener);
    chart.gestureListeners.add(_gestureListener);
    chart.afterDrawListeners.add(_drawListener);
    _scheduleRestore(chart);
    syncSelection();
    refresh();
  }

  void _scheduleRestore(Chart chart) {
    final saved = _pendingRestore;
    if (saved == null) return;
    chart.addViewportJob(() {
      if (identical(_chart, chart) && identical(_pendingRestore, saved)) {
        _pendingRestore = null;
        _restore(chart, saved);
      }
    });
  }

  void _restore(Chart chart, Map<String, Object?> saved) {
    final zoomX = _doubleOf(saved[_ZOOM_X]);
    final zoomY = _doubleOf(saved[_ZOOM_Y]);
    final lowestX = _doubleOf(saved[_LOWEST_VISIBLE_X]);
    final hasHighlight = saved[_HAS_HIGHLIGHT] == true;
    if (chart is BarLineChartBase) {
      chart.zoom(zoomX, zoomY, 0, 0);
      final topLeftX = _doubleOf(saved[_TOP_LEFT_X]);
      final topLeftY = _doubleOf(saved[_TOP_LEFT_Y]);
      if (topLeftX.isFinite && topLeftY.isFinite) {
        chart.addViewportJob(
          MoveViewJob.getInstance(
            chart.viewPortHandler,
            topLeftX,
            topLeftY,
            chart.getTransformer(AxisDependency.LEFT),
            chart,
          ).run,
        );
      } else {
        chart.moveViewToX(lowestX);
      }
    }
    if (chart is PieRadarChartBase) {
      chart.rotationAngle = _doubleOf(saved[_ROTATION_ANGLE]);
    }
    if (hasHighlight) {
      chart.highlightValue(
        _doubleOf(saved[_HIGHLIGHT_X]),
        saved[_HIGHLIGHT_DATA_SET_INDEX]! as int,
        y: _doubleOf(saved[_HIGHLIGHT_Y]),
        dataIndex: saved[_HIGHLIGHT_DATA_INDEX]! as int,
        stackIndex: saved[_HIGHLIGHT_STACK_INDEX]! as int,
        callListener: true,
      );
    }
    chart.invalidate();
    chart.post(refresh);
  }

  /// Stops observing [chart]. Does nothing when the controller is attached to another chart by now, so the widget of
  /// a chart the controller moved away from cannot detach it. Internal API: the chart widgets call it.
  @internal
  void detach(Chart chart) {
    if (!identical(_chart, chart)) return;
    chart.valueSelectedListeners.remove(_selectionListener);
    chart.gestureListeners.remove(_gestureListener);
    chart.afterDrawListeners.remove(_drawListener);
    _chartRef = null;
  }

  /// Reads [selectedEntry] and [selectedHighlight] from the chart's first highlight. Internal API.
  @internal
  void syncSelection() {
    final chart = _chart;
    if (chart == null) return;
    final highlight = chart.highlighted.firstOrNull;
    final entry = highlight == null
        ? null
        : chart.data?.getEntryForHighlight(highlight);
    _setSelection(entry, entry == null ? null : highlight);
  }

  /// Reads the viewport properties from the chart. Internal API.
  @internal
  void refresh() {
    final chart = _chart;
    if (chart is BarLineChartBase) {
      _setDouble(
        _lowestVisibleX,
        chart.lowestVisibleX,
        (v) => _lowestVisibleX = v,
      );
      _setDouble(
        _highestVisibleX,
        chart.highestVisibleX,
        (v) => _highestVisibleX = v,
      );
      _setDouble(_zoomX, chart.zoomX, (v) => _zoomX = v);
      _setDouble(_zoomY, chart.zoomY, (v) => _zoomY = v);
      final handler = chart.viewPortHandler;
      chart.getValuesByTouchPoint(
        handler.contentLeft,
        handler.contentTop,
        AxisDependency.LEFT,
        _topLeft,
      );
      // Not state in Kotlin either: saved, never observed.
      _topLeftX = _topLeft.x;
      _topLeftY = _topLeft.y;
    } else if (chart is PieRadarChartBase) {
      _setDouble(
        _rotationAngle,
        chart.rotationAngle,
        (v) => _rotationAngle = v,
      );
    }
  }

  void _setSelection(Entry? entry, Highlight? highlight) {
    if (identical(_selectedEntry, entry) &&
        identical(_selectedHighlight, highlight)) {
      return;
    }
    _selectedEntry = entry;
    _selectedHighlight = highlight;
    _markChanged();
  }

  void _setDouble(double current, double value, void Function(double) set) {
    if (current == value || (current.isNaN && value.isNaN)) return;
    set(value);
    _markChanged();
  }

  void _markChanged() {
    _changed = true;
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(_deliverNotification);
  }

  void _deliverNotification() {
    _notificationScheduled = false;
    if (_disposed || !_changed) return;
    _changed = false;
    notifyListeners();
  }

  /// Leaves the chart it is attached to and discards the listeners. The controller must not be used afterwards.
  @override
  void dispose() {
    final chart = _chart;
    if (chart != null) detach(chart);
    _disposed = true;
    super.dispose();
  }

  /// The values that `rememberChartState`'s Saver keeps: zoom, the x and y scroll position, rotation and the
  /// highlighted entry, as a map that `jsonEncode` accepts. Before a restored controller was applied to a chart,
  /// these are the restored values.
  ///
  /// Keys: `zoomX`, `zoomY`, `lowestVisibleX`, `rotationAngle` (numbers), `hasHighlight` (bool), `highlightX`,
  /// `highlightY` (numbers), `highlightDataSetIndex`, `highlightDataIndex`, `highlightStackIndex` (ints), `topLeftX`
  /// and `topLeftY` (numbers). A value that is not a finite number (Kotlin saves NaN for the y of a missing highlight
  /// and for the scroll position of a chart without a size) is null.
  Map<String, Object?> toJson() {
    final pending = _pendingRestore;
    if (pending != null) return Map.of(pending);
    final highlight = _selectedHighlight;
    return {
      _ZOOM_X: _jsonOf(_zoomX),
      _ZOOM_Y: _jsonOf(_zoomY),
      _LOWEST_VISIBLE_X: _jsonOf(_lowestVisibleX),
      _ROTATION_ANGLE: _jsonOf(_rotationAngle),
      _HAS_HIGHLIGHT: highlight != null,
      _HIGHLIGHT_X: _jsonOf(highlight?.x ?? 0),
      _HIGHLIGHT_Y: _jsonOf(highlight?.y ?? double.nan),
      _HIGHLIGHT_DATA_SET_INDEX: highlight?.dataSetIndex ?? 0,
      _HIGHLIGHT_DATA_INDEX: highlight?.dataIndex ?? -1,
      _HIGHLIGHT_STACK_INDEX: highlight?.stackIndex ?? -1,
      _TOP_LEFT_X: _jsonOf(_topLeftX),
      _TOP_LEFT_Y: _jsonOf(_topLeftY),
    };
  }

  /// Takes the values of [json], as [toJson] returns them, and applies them once the controller is attached to a chart
  /// that has its size (right away when it is attached already), so the data should be set by then; a highlight that
  /// no longer matches the data is dropped. Until then [toJson] returns these values.
  ///
  /// Values without `topLeftX` and `topLeftY` (Kotlin's 10-value form) scroll to `lowestVisibleX` instead. A map with
  /// a missing key or a value of the wrong type is ignored, and so are values a restore before took but did not apply.
  void restoreFrom(Map<String, Object?> json) {
    _pendingRestore = _isRestorable(json) ? Map.unmodifiable(json) : null;
    final chart = _chart;
    if (chart != null) _scheduleRestore(chart);
  }

  static bool _isRestorable(Map<String, Object?> json) {
    bool isNumber(String key) => json.containsKey(key) && json[key] is num?;
    bool isInt(String key) => json[key] is int;
    final hasTopLeft = json.containsKey(_TOP_LEFT_X);
    if (hasTopLeft != json.containsKey(_TOP_LEFT_Y)) return false;
    if (hasTopLeft && !(isNumber(_TOP_LEFT_X) && isNumber(_TOP_LEFT_Y))) {
      return false;
    }
    return isNumber(_ZOOM_X) &&
        isNumber(_ZOOM_Y) &&
        isNumber(_LOWEST_VISIBLE_X) &&
        isNumber(_ROTATION_ANGLE) &&
        json[_HAS_HIGHLIGHT] is bool &&
        isNumber(_HIGHLIGHT_X) &&
        isNumber(_HIGHLIGHT_Y) &&
        isInt(_HIGHLIGHT_DATA_SET_INDEX) &&
        isInt(_HIGHLIGHT_DATA_INDEX) &&
        isInt(_HIGHLIGHT_STACK_INDEX);
  }

  static Object? _jsonOf(double value) => value.isFinite ? value : null;

  static double _doubleOf(Object? value) =>
      value == null ? double.nan : (value as num).toDouble();

  static const String _ZOOM_X = 'zoomX';
  static const String _ZOOM_Y = 'zoomY';
  static const String _LOWEST_VISIBLE_X = 'lowestVisibleX';
  static const String _ROTATION_ANGLE = 'rotationAngle';
  static const String _HAS_HIGHLIGHT = 'hasHighlight';
  static const String _HIGHLIGHT_X = 'highlightX';
  static const String _HIGHLIGHT_Y = 'highlightY';
  static const String _HIGHLIGHT_DATA_SET_INDEX = 'highlightDataSetIndex';
  static const String _HIGHLIGHT_DATA_INDEX = 'highlightDataIndex';
  static const String _HIGHLIGHT_STACK_INDEX = 'highlightStackIndex';
  static const String _TOP_LEFT_X = 'topLeftX';
  static const String _TOP_LEFT_Y = 'topLeftY';

  static void _noop() {}
}
