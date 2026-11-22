// Chart stand-ins for the lane A data provider interfaces, shared by the highlighter and renderer tests.
//
// Built on the two P0 fakes: by default like the one in renderer_edge_case_test.dart (a ViewPortHandler without a
// size and unprepared transformers, so pixels equal values, as with the JVM transformers of the Kotlin tests); pass a
// sized `handler` with prepared `left` / `right` transformers for the style of the one in highlighter_test.dart.
//
// The knobs every BarLineScatterCandleBubbleDataProvider fake shares live in [FakeBarLineChart]; each chart type's
// fake adds its data and its own flags.
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_flutter_chart/src/data/bubble_data.dart';
import 'package:mp_flutter_chart/src/data/candle_data.dart';
import 'package:mp_flutter_chart/src/data/scatter_data.dart';
import 'package:mp_flutter_chart/src/formatter/default_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/bar_data_provider.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/bar_line_scatter_candle_bubble_data_provider.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/bubble_data_provider.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/candle_data_provider.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/scatter_data_provider.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

/// A [BarLineScatterCandleBubbleDataProvider] without a chart behind it: fixed ranges and flags, and one transformer
/// per axis. The base of the per-chart fakes, which add the data.
///
/// The defaults are those of the Kotlin `HighlighterTest.FakeChart`. Each axis gets its own [Transformer] over
/// [handler], unprepared unless one is passed in. The ranges and the flags are plain fields, so a test can flip one
/// without a notify call.
abstract class FakeBarLineChart extends BarLineScatterCandleBubbleDataProvider {
  /// [handler] defaults to a [ViewPortHandler] without a size; [left] / [right] default to unprepared transformers
  /// over it. [isInverted] applies to both axes.
  ///
  /// A test that passes its own [left] or [right] transformer must pass the [handler] it maps into as well:
  /// [contentRect] and the default transformer of the other axis read [handler], so without it they would read a
  /// viewport of their own, without a size, while the passed transformer maps into another one.
  FakeBarLineChart({
    ViewPortHandler? handler,
    Transformer? left,
    Transformer? right,
    bool isInverted = false,
    this.isDecimationEnabled = false,
    this.lowestVisibleX = 0,
    this.highestVisibleX = 10,
    this.xChartMin = 0,
    this.xChartMax = 10,
    this.yChartMin = 0,
    this.yChartMax = 10,
    this.maxHighlightDistance = 500,
    this.maxVisibleCount = 100,
  }) : assert(
         handler != null || (left == null && right == null),
         'pass the handler the left / right transformers map into',
       ),
       handler = handler ?? ViewPortHandler(),
       inverted = isInverted {
    _left = left ?? Transformer(this.handler);
    _right = right ?? Transformer(this.handler);
  }

  /// The viewport the default transformers map into; [contentRect] is its content rectangle.
  final ViewPortHandler handler;

  late final Transformer _left;
  late final Transformer _right;

  /// Returned by [isInverted] for both axes.
  bool inverted;

  @override
  BarLineScatterCandleBubbleData? get data;

  @override
  bool isDecimationEnabled;

  @override
  Transformer getTransformer(AxisDependency axis) =>
      axis == AxisDependency.LEFT ? _left : _right;

  @override
  bool isInverted(AxisDependency axis) => inverted;

  @override
  double lowestVisibleX;

  @override
  double highestVisibleX;

  @override
  double xChartMin;

  @override
  double xChartMax;

  @override
  double get xRange => xChartMax - xChartMin;

  @override
  double yChartMin;

  @override
  double yChartMax;

  @override
  double maxHighlightDistance;

  @override
  MPPointF get centerOfView => MPPointF.getInstance(0, 0);

  @override
  MPPointF get centerOffsets => MPPointF.getInstance(0, 0);

  @override
  MutableRect get contentRect => handler.contentRect;

  @override
  final IValueFormatter defaultValueFormatter = DefaultValueFormatter(0);

  @override
  int maxVisibleCount;
}

/// A [BarDataProvider] without a chart behind it: the knobs of [FakeBarLineChart] and the three bar flags. The data
/// is a plain field, so a test can swap it without a notify call.
class FakeBarChart extends FakeBarLineChart implements BarDataProvider {
  /// Creates a fake chart showing [barData].
  FakeBarChart(
    this.barData, {
    super.handler,
    super.left,
    super.right,
    this.isDrawBarShadowEnabled = false,
    this.isDrawValueAboveBarEnabled = true,
    this.isHighlightFullBarEnabled = false,
    super.isInverted,
    super.isDecimationEnabled,
    super.lowestVisibleX,
    super.highestVisibleX,
    super.xChartMin,
    super.xChartMax,
    super.yChartMin,
    super.yChartMax,
    super.maxHighlightDistance,
    super.maxVisibleCount,
  });

  @override
  BarData? barData;

  @override
  BarData? get data => barData;

  @override
  bool isDrawBarShadowEnabled;

  @override
  bool isDrawValueAboveBarEnabled;

  @override
  bool isHighlightFullBarEnabled;
}

/// A [ScatterDataProvider] without a chart behind it: the knobs of [FakeBarLineChart]. The data is a plain field, so
/// a test can swap it without a notify call.
class FakeScatterChart extends FakeBarLineChart implements ScatterDataProvider {
  /// Creates a fake chart showing [scatterData].
  FakeScatterChart(
    this.scatterData, {
    super.handler,
    super.left,
    super.right,
    super.isInverted,
    super.isDecimationEnabled,
    super.lowestVisibleX,
    super.highestVisibleX,
    super.xChartMin,
    super.xChartMax,
    super.yChartMin,
    super.yChartMax,
    super.maxHighlightDistance,
    super.maxVisibleCount,
  });

  @override
  ScatterData? scatterData;

  @override
  ScatterData? get data => scatterData;
}

/// A [CandleDataProvider] without a chart behind it: the knobs of [FakeBarLineChart]. The data is a plain field, so
/// a test can swap it without a notify call.
class FakeCandleChart extends FakeBarLineChart implements CandleDataProvider {
  /// Creates a fake chart showing [candleData].
  FakeCandleChart(
    this.candleData, {
    super.handler,
    super.left,
    super.right,
    super.isInverted,
    super.isDecimationEnabled,
    super.lowestVisibleX,
    super.highestVisibleX,
    super.xChartMin,
    super.xChartMax,
    super.yChartMin,
    super.yChartMax,
    super.maxHighlightDistance,
    super.maxVisibleCount,
  });

  @override
  CandleData? candleData;

  @override
  CandleData? get data => candleData;
}

/// A [BubbleDataProvider] without a chart behind it: the knobs of [FakeBarLineChart]. The data is a plain field, so
/// a test can swap it without a notify call.
class FakeBubbleChart extends FakeBarLineChart implements BubbleDataProvider {
  /// Creates a fake chart showing [bubbleData].
  FakeBubbleChart(
    this.bubbleData, {
    super.handler,
    super.left,
    super.right,
    super.isInverted,
    super.isDecimationEnabled,
    super.lowestVisibleX,
    super.highestVisibleX,
    super.xChartMin,
    super.xChartMax,
    super.yChartMin,
    super.yChartMax,
    super.maxHighlightDistance,
    super.maxVisibleCount,
  });

  @override
  BubbleData? bubbleData;

  @override
  BubbleData? get data => bubbleData;
}
