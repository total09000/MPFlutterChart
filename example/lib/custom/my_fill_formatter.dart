// Ported from MPChartExample: custom/MyFillFormatter.kt
import 'package:mp_flutter_chart/core.dart';

/// Fills a line down or up to a fixed y value.
class MyFillFormatter implements IFillFormatter {
  const MyFillFormatter(this._fillPos);

  final double _fillPos;

  @override
  double getFillLinePosition(ILineDataSet dataSet, LineDataProvider dataProvider) => _fillPos;
}
