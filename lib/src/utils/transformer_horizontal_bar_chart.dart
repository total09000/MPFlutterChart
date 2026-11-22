// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/utils/TransformerHorizontalBarChart.kt
import 'transformer.dart';

/// Transformer for the horizontal bar chart, where an inverted axis mirrors the values along the x axis instead of
/// the y axis.
class TransformerHorizontalBarChart extends Transformer {
  /// Creates a transformer that maps into the content rectangle of [viewPortHandler].
  TransformerHorizontalBarChart(super.viewPortHandler);

  @override
  void prepareMatrixOffset(bool inverted) {
    matrixOffset.reset();
    if (!inverted) {
      matrixOffset.postTranslate(
        viewPortHandler.offsetLeft,
        viewPortHandler.chartHeight - viewPortHandler.offsetBottom,
      );
    } else {
      matrixOffset.setTranslate(
        -(viewPortHandler.chartWidth - viewPortHandler.offsetRight),
        viewPortHandler.chartHeight - viewPortHandler.offsetBottom,
      );
      matrixOffset.postScale(-1.0, 1.0);
    }
  }
}
