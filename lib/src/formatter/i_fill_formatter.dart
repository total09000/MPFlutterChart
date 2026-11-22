// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/formatter/IFillFormatter.kt
import '../interfaces/dataprovider/line_data_provider.dart';
import '../interfaces/datasets/i_line_data_set.dart';

/// Decides the y value, in value space, down or up to which a line data set is filled. Only used when the data set
/// draws a fill. Usage: `IFillFormatter.fromFunction((dataSet, dataProvider) => 0)` fills to the zero line.
///
/// Kotlin's `fun interface`; a lambda is wrapped with [IFillFormatter.fromFunction].
abstract class IFillFormatter {
  /// Lets subclasses be constant.
  const IFillFormatter();

  /// Wraps [getFillLinePosition] in a formatter.
  const factory IFillFormatter.fromFunction(
    double Function(ILineDataSet dataSet, LineDataProvider dataProvider)
    getFillLinePosition,
  ) = _FunctionFillFormatter;

  /// Returns the y value in value space the fill extends to.
  ///
  /// [dataSet] is the line data set being drawn and [dataProvider] the chart drawing it, giving the axis range and
  /// the whole line data.
  double getFillLinePosition(
    ILineDataSet dataSet,
    LineDataProvider dataProvider,
  );
}

class _FunctionFillFormatter extends IFillFormatter {
  const _FunctionFillFormatter(this._getFillLinePosition);

  final double Function(ILineDataSet dataSet, LineDataProvider dataProvider)
  _getFillLinePosition;

  @override
  double getFillLinePosition(
    ILineDataSet dataSet,
    LineDataProvider dataProvider,
  ) => _getFillLinePosition(dataSet, dataProvider);
}
