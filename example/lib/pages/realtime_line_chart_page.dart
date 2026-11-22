// Ported from MPChartExample: RealtimeLineChartActivity.kt, with res/layout/activity_realtime_linechart.xml and
// res/menu/realtime.xml.
//
// Line Charts / Realtime: a line chart on a light gray background that gets its entries from the menu, one by one or
// 1000 of them every 25 ms, and scrolls along so the newest 120 x values stay in sight. The Activity feeds the entries
// from a Thread that posts `addEntry` to the UI thread and sleeps 25 ms between them; the page runs a periodic
// [Timer] of 25 ms on the UI isolate that adds the first entry at once and stops after the 1000th. Not ported: the
// "View on GitHub" and "Save to Gallery" menu items (see notimportant/demo_base.dart); `thread?.interrupt()`, in
// `feedMultiple` and `onPause`, cuts only the current sleep short in Kotlin, because the loop catches the
// InterruptedException and goes on, so a second "Add Multiple" runs two feeders at once and the feed goes on in the
// background; here a new "Add Multiple" cancels the running feed before it starts the next 1000 entries, and the feed
// stops for good when the app becomes inactive (Flutter's counterpart of `onPause`), when the page's route starts to
// be popped and when the page is disposed. A route pushed above the page, the options menu included, leaves it running.
import 'dart:async';

import 'package:flutter/material.dart' hide Easing;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import '../notimportant/demo_base.dart';

/// RealtimeLineChartActivity.
class RealtimeLineChartPage extends StatefulWidget {
  const RealtimeLineChartPage({super.key});

  @override
  State<RealtimeLineChartPage> createState() => _RealtimeLineChartPageState();
}

class _RealtimeLineChartPageState extends State<RealtimeLineChartPage> with DemoBase {
  /// `binding.chart1`.
  final LineChartView _chart = LineChartView();

  /// Android's `Color.LTGRAY`, the background `setBackgroundColor` gives the chart.
  static const Color _lightGray = Color(0xFFCCCCCC);

  /// The number of entries `feedMultiple` adds.
  static const int _feedCount = 1000;

  /// `thread`: the timer of the running feed.
  Timer? _feed;

  /// `onPause`, as the app's lifecycle reports it.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onInactive: _stopFeed);

    _chart
      ..onChartValueSelectedListener = OnChartValueSelectedListener.fromFunction(
        onValueSelected: (e, h) => logI('Entry<*> selected', e.toString()),
        onNothingSelected: () => logI('Nothing selected', 'Nothing selected.'),
      )
      ..description.isEnabled = true
      ..isTouchEnabled = true
      ..isDragEnabled = true
      ..isScaleEnabled = true
      ..isDrawGridBackgroundEnabled = false
      ..isPinchZoomEnabled = true;

    final lineData = LineData()..setValueTextColor(const Color(0xFFFFFFFF));
    _chart.data = lineData;

    _chart.legend
      ..form = LegendForm.LINE
      ..typeface = tfLight
      ..textColor = const Color(0xFFFFFFFF);

    _chart.xAxis
      ..typeface = tfLight
      ..textColor = const Color(0xFFFFFFFF)
      ..isDrawGridLinesEnabled = false
      ..isAvoidFirstLastClippingEnabled = true
      ..isEnabled = true;

    _chart.axisLeft
      ..typeface = tfLight
      ..textColor = const Color(0xFFFFFFFF)
      ..axisMaximum = 100
      ..axisMinimum = 0
      ..isDrawGridLinesEnabled = true;

    _chart.axisRight.isEnabled = false;
  }

  @override
  void dispose() {
    _stopFeed();
    _lifecycle.dispose();
    super.dispose();
  }

  void _addEntry() {
    final data = _chart.data;
    if (data == null) return;

    var set = data.getDataSetByIndex(0);
    if (set == null) {
      set = _createSet();
      data.addDataSet(set);
    }

    data.addEntry(Entry(x: set.entryCount.toDouble(), y: mathRandom() * 40 + 30), 0);

    _chart.notifyDataSetChanged();
    _chart.setVisibleXRangeMaximum(120);
    _chart.moveViewToX(data.entryCount.toDouble());
  }

  LineDataSet _createSet() => LineDataSet(<Entry>[], 'Dynamic Data')
    ..axisDependency = AxisDependency.LEFT
    ..color = ColorTemplate.holoBlue
    ..circleColor = const Color(0xFFFFFFFF)
    ..lineWidth = 2
    ..circleRadius = 4
    ..fillAlpha = 65
    ..fillColor = ColorTemplate.holoBlue
    ..highlightColor = const Color.fromARGB(255, 244, 117, 117)
    ..valueTextColor = const Color(0xFFFFFFFF)
    ..valueTextSize = 9
    ..isDrawValuesEnabled = false;

  /// `feedMultiple()`: adds [_feedCount] entries, one every 25 ms.
  void _feedMultiple() {
    _stopFeed();

    _addEntry();
    var added = 1;
    _feed = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      // The page was left: its route is being popped, or the page is disposed. A route above it, such as the popup of
      // the options menu, does not stop the feed.
      if (!mounted || !(ModalRoute.of(context)?.isActive ?? true)) {
        timer.cancel();
        return;
      }
      _addEntry();
      if (++added >= _feedCount) timer.cancel();
    });
  }

  void _stopFeed() {
    _feed?.cancel();
    _feed = null;
  }

  /// res/menu/realtime.xml.
  List<DemoMenuItem> get _menu => [
    DemoMenuItem('Add Entry', _addEntry),
    DemoMenuItem('Clear chart', () {
      _chart.clearValues();
      toast('Chart cleared!');
    }),
    DemoMenuItem('Add Multiple', _feedMultiple),
  ];

  @override
  Widget build(BuildContext context) => DemoScaffold(
    title: 'Realtime',
    menu: _menu,
    body: ColoredBox(
      color: _lightGray,
      child: ChartHostWidget<LineChartView, LineData>(chart: _chart, data: _chart.data),
    ),
  );
}
