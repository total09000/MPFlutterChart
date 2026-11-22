// Ported from MPAndroidChart v4.0.1: MPChartCompose/src/main/kotlin/com/github/mikephil/charting/compose/ChartView.kt
//
// Compose's AndroidView(factory, update, onRelease) is a StatefulWidget here: the State is the
// ChartSlot, initState is the factory (create + setup), initState and didUpdateWidget run the update block, dispose
// is onRelease. The chart composables pass `create` (::LineChartView); the chart widgets own the chart instead and
// pass it as [ChartHostWidget.chart]. `modifier` has no counterpart (size the widget with its parent), the
// semantics modifier is a Semantics widget, and the Android Studio preview placeholder (LocalInspectionMode) is not
// ported: the chart draws in Flutter's previews and tests. Flutter additions: the State lends its vsync to the chart's
// animations and owns the gesture recognizer, and a change of the system fonts drops the cached text layouts.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../charts/chart.dart';
import '../data/chart_data.dart';
import '../data/entry.dart';
import '../graphics/text_measure.dart';
import '../highlight/highlight.dart';
import 'chart_controller.dart';
import 'chart_gesture_recognizer.dart';
import 'chart_render_box.dart';
import 'widget_marker.dart';

/// How long a chart widget with `animateChanges` animates a data change, in milliseconds.
@internal
const int CHANGE_ANIMATION_MILLIS = 300;

/// Shows a [chart] in the widget tree; the chart widgets such as `LineChart` delegate here.
///
/// [setup] runs once, before the chart is shown and before any data is set, so values it reads are frozen. [update]
/// runs on every build of this widget, the first one included, after the data and marker were applied and right
/// before the chart redraws. A new [data] instance is applied to the chart; the same instance is left alone, call
/// [ChartController.notifyDataChanged] after changing it in place. With [animateChanges] a new [data] instance
/// animates in through `Chart.animateDataChange` over 300 ms. [marker] is wrapped in a [WidgetMarker] that is reused
/// while the chart lives.
///
/// The chart is shown by a [ChartRenderBoxWidget] in a [Stack] that clips to the chart's bounds, with the marker's
/// overlay above it. The widget's `State` drives the chart's animations (it is their vsync) and owns the chart's
/// gesture recognizer. [C] is the chart class and [D] the data class it shows.
class ChartHostWidget<C extends Chart<D>, D extends ChartData>
    extends StatefulWidget {
  /// Creates a widget that shows [chart] with [data].
  const ChartHostWidget({
    super.key,
    required this.chart,
    required this.data,
    this.controller,
    this.contentDescription,
    this.marker,
    this.animateChanges = false,
    this.setup,
    this.update,
  });

  /// The chart to show. A new instance is set up again and replaces the chart shown before.
  final C chart;

  /// Data to show. A new instance is applied to the chart, the same instance is left alone. Null clears the chart.
  final D? data;

  /// Reports selection and viewport back to widgets and drives the chart, or null.
  final ChartController? controller;

  /// Text read by screen readers, null for none.
  final String? contentDescription;

  /// Builds the widget shown at the highlighted entry, null for no marker.
  final Widget Function(Entry entry, Highlight highlight)? marker;

  /// Whether a new [data] instance animates in from the values shown before, over 300 ms, instead of replacing them at
  /// once; see [ChartController.animateDataChange]. Charts without data and data of another shape are set without
  /// animation.
  final bool animateChanges;

  /// Runs once, before the chart is shown and before any data is set.
  final void Function(C chart)? setup;

  /// Runs on every build, after the data and marker were applied and right before the chart redraws.
  final void Function(C chart)? update;

  @override
  State<ChartHostWidget<C, D>> createState() => _ChartHostWidgetState<C, D>();
}

class _ChartHostWidgetState<C extends Chart<D>, D extends ChartData>
    extends State<ChartHostWidget<C, D>>
    with TickerProviderStateMixin {
  late ChartGestureRecognizer _recognizer;

  /// ChartSlot.state: the controller attached to the chart.
  ChartController? _controller;

  /// ChartSlot.marker: the marker this widget gave the chart.
  WidgetMarker? _marker;

  @override
  void initState() {
    super.initState();
    _create(widget.chart);
    _update();
    PaintingBinding.instance.systemFonts.addListener(_onSystemFontsChanged);
  }

  @override
  void didUpdateWidget(ChartHostWidget<C, D> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chart, widget.chart)) {
      _release(oldWidget.chart);
      _create(widget.chart);
    }
    _update();
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onSystemFontsChanged);
    _release(widget.chart);
    super.dispose();
  }

  /// The AndroidView factory: `create(context).apply(setup)`. The chart's animations run on this State from the start,
  /// so animations [ChartHostWidget.setup] starts keep running when the chart's render object takes the same vsync.
  void _create(C chart) {
    chart.animator.vsync = this;
    _recognizer = ChartGestureRecognizer(
      onTouch: chart.onTouchEvent,
      debugOwner: this,
    );
    widget.setup?.call(chart);
  }

  /// The AndroidView update block.
  void _update() {
    final chart = widget.chart;
    final controller = widget.controller;
    if (!identical(_controller, controller)) {
      _controller?.detach(chart);
      _controller = controller;
      controller?.attach(chart);
    }
    final data = widget.data;
    if (!identical(chart.data, data)) {
      if (widget.animateChanges && data != null) {
        chart.animateDataChange(
          data,
          CHANGE_ANIMATION_MILLIS,
          onEnd: () => controller?.syncSelection(),
        );
      } else {
        chart.data = data;
      }
      controller?.syncSelection();
    }
    _applyMarker(chart, widget.marker);
    widget.update?.call(chart);
    chart.invalidate();
    controller?.refresh();
  }

  void _applyMarker(
    C chart,
    Widget Function(Entry entry, Highlight highlight)? content,
  ) {
    final existing = _marker;
    if (content == null) {
      existing?.detach();
      _marker = null;
    } else if (existing != null && identical(chart.marker, existing)) {
      existing.content = content;
    } else {
      existing?.detach();
      final marker = WidgetMarker(chart, content);
      chart.marker = marker;
      _marker = marker;
    }
  }

  /// AndroidView's onRelease, plus what the widget lent the chart: the recognizer is disposed (which cancels a touch in
  /// progress, as Android's ViewGroup does for a removed child) and the chart's animations stop using this State as
  /// their vsync before it goes away. The chart's render object has already ended them when it left the tree.
  void _release(C chart) {
    _recognizer.dispose();
    _controller?.detach(chart);
    _controller = null;
    _marker?.detach();
    _marker = null;
    if (identical(chart.animator.vsync, this)) chart.animator.vsync = null;
  }

  /// Text measured with the previous fonts no longer fits: drop the cached layouts and lay the chart out again.
  void _onSystemFontsChanged() {
    TextMeasure.clearCache();
    final chart = widget.chart;
    chart.notifyDataSetChanged();
    chart.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final marker = _marker;
    final description = widget.contentDescription;
    return Semantics(
      container: description != null,
      label: description,
      child: Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.hardEdge,
        children: [
          ChartRenderBoxWidget(
            chart: widget.chart,
            recognizer: _recognizer,
            vsync: this,
          ),
          if (marker != null) Positioned.fill(child: marker.buildOverlay()),
        ],
      ),
    );
  }
}
