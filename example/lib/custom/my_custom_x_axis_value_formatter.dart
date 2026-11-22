// Ported from MPChartExample: custom/MyCustomXAxisValueFormatter.kt
import 'package:mp_flutter_chart/core.dart';

/// Formats an x value with one decimal while the chart is zoomed out, and as a fixed digit per zoom level beyond.
class MyCustomXAxisValueFormatter implements IAxisValueFormatter {
  MyCustomXAxisValueFormatter(this._viewPortHandler);

  final ViewPortHandler _viewPortHandler;

  final DecimalFormat _format = DecimalFormat('###,###,###,##0.0');

  @override
  String getFormattedValue(double value, AxisBase axis) {
    final xScale = _viewPortHandler.scaleX;
    if (xScale > 5) return '4';
    if (xScale > 3) return '3';
    if (xScale > 1) return '2';
    return _format.format(value);
  }
}
