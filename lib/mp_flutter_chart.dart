/// Default entry point: the widget layer plus every core type except the chart classes, which are
/// re-exposed as `*View` typedefs, as MPChartCompose calls the MPChartLib view classes.
///
/// `BarChart`, `BubbleChart`, `CandleStickChart`, `HorizontalBarChart`, `LineChart`, `PieChart`, `RadarChart` and
/// `ScatterChart` here are the widgets; the chart each one shows, the object `setup` and `update` get, is the matching
/// `*View`: a [BarChartView], [BubbleChartView], [CandleStickChartView], [HorizontalBarChartView], [LineChartView],
/// [PieChartView], [RadarChartView] or [ScatterChartView].
/// Import `package:mp_flutter_chart/core.dart` instead for the MPChartLib names only.
library;

import 'core.dart' as core;

export 'core.dart'
    hide
        LineChart,
        BarChart,
        HorizontalBarChart,
        ScatterChart,
        CandleStickChart,
        BubbleChart,
        PieChart,
        RadarChart;
export 'src/widgets/bar_chart_widget.dart';
export 'src/widgets/bubble_chart_widget.dart';
export 'src/widgets/candle_stick_chart_widget.dart';
export 'src/widgets/chart_controller.dart';
export 'src/widgets/chart_gesture_recognizer.dart';
export 'src/widgets/chart_host_widget.dart' hide CHANGE_ANIMATION_MILLIS;
export 'src/widgets/chart_render_box.dart';
export 'src/widgets/horizontal_bar_chart_widget.dart';
export 'src/widgets/line_chart_widget.dart';
export 'src/widgets/pie_chart_widget.dart';
export 'src/widgets/radar_chart_widget.dart';
export 'src/widgets/scatter_chart_widget.dart';
export 'src/widgets/widget_marker.dart';

/// The core bar chart that the `BarChart` widget shows, MPAndroidChart's `BarChart` view.
typedef BarChartView = core.BarChart;

/// The core bubble chart that the `BubbleChart` widget shows, MPAndroidChart's `BubbleChart` view.
typedef BubbleChartView = core.BubbleChart;

/// The core candle stick chart that the `CandleStickChart` widget shows, MPAndroidChart's `CandleStickChart` view.
typedef CandleStickChartView = core.CandleStickChart;

/// The core horizontal bar chart that the `HorizontalBarChart` widget shows, MPAndroidChart's `HorizontalBarChart`
/// view.
typedef HorizontalBarChartView = core.HorizontalBarChart;

/// The core line chart that the `LineChart` widget shows, MPAndroidChart's `LineChart` view.
typedef LineChartView = core.LineChart;

/// The core pie chart that the `PieChart` widget shows, MPAndroidChart's `PieChart` view.
typedef PieChartView = core.PieChart;

/// The core radar chart that the `RadarChart` widget shows, MPAndroidChart's `RadarChart` view.
typedef RadarChartView = core.RadarChart;

/// The core scatter chart that the `ScatterChart` widget shows, MPAndroidChart's `ScatterChart` view.
typedef ScatterChartView = core.ScatterChart;
