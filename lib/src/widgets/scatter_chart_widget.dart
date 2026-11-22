// Ported from MPAndroidChart v4.0.1: MPChartCompose/src/main/kotlin/com/github/mikephil/charting/compose/Charts.kt
//
// The ScatterChart composable, in the shape of line_chart_widget.dart. A composable remembers the view that AndroidView
// creates; a StatelessWidget would create a new chart on every build, so each chart widget is a StatefulWidget whose
// State owns the core chart. `state` is `controller` (null for none: there is no rememberChartState()
// default), `modifier` has no counterpart (size the widget with its parent), and setup/update take the chart as their
// argument instead of as their receiver.
import 'package:flutter/widgets.dart';

import '../charts/scatter_chart.dart' as core;
import '../data/entry.dart';
import '../data/scatter_data.dart';
import '../highlight/highlight.dart';
import 'chart_controller.dart';
import 'chart_host_widget.dart';

/// Shows a scatter chart backed by a core `ScatterChart` (`ScatterChartView` in
/// `package:mp_flutter_chart/mp_flutter_chart.dart`). Configure the chart once in [setup] and put anything derived from
/// the theme or other widget state into [update].
class ScatterChart extends StatefulWidget {
  /// Creates a scatter chart widget that shows [data].
  const ScatterChart({
    super.key,
    required this.data,
    this.controller,
    this.contentDescription,
    this.marker,
    this.animateChanges = false,
    this.setup,
    this.update,
  });

  /// [ScatterData] to show. A new instance is applied to the chart, the same instance is left alone; call
  /// [ChartController.notifyDataChanged] after changing it in place. Null clears the chart.
  final ScatterData? data;

  /// Reports selection and viewport back to widgets and drives the chart. Use one controller per chart; passing it to
  /// another chart moves it there.
  final ChartController? controller;

  /// Text read by screen readers, null for none.
  final String? contentDescription;

  /// Builds the widget shown at the highlighted entry, null for no marker.
  final Widget Function(Entry entry, Highlight highlight)? marker;

  /// Whether a new [data] instance animates in from the values shown before, over 300 ms, instead of replacing them at
  /// once; see [ChartController.animateDataChange]. Charts without data and data of another shape are set without
  /// animation.
  final bool animateChanges;

  /// Runs once, after the chart is created and before any data is set, so values it reads are frozen.
  final void Function(core.ScatterChart chart)? setup;

  /// Runs on every build of this widget, right before the chart redraws.
  final void Function(core.ScatterChart chart)? update;

  @override
  State<ScatterChart> createState() => _ScatterChartState();
}

class _ScatterChartState extends State<ScatterChart> {
  final core.ScatterChart _chart = core.ScatterChart();

  @override
  Widget build(BuildContext context) =>
      ChartHostWidget<core.ScatterChart, ScatterData>(
        chart: _chart,
        data: widget.data,
        controller: widget.controller,
        contentDescription: widget.contentDescription,
        marker: widget.marker,
        animateChanges: widget.animateChanges,
        setup: widget.setup,
        update: widget.update,
      );
}
