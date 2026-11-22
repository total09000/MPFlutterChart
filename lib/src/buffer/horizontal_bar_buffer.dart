// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/buffer/HorizontalBarBuffer.kt
import 'package:flutter/foundation.dart' show protected;

import '../interfaces/datasets/i_bar_data_set.dart';
import 'bar_buffer.dart';

/// [BarBuffer] for horizontal bar charts. The four floats per bar are still left, top, right, bottom, but here left
/// and right are y values (the bar value and 0) and top and bottom are x values (`x - barWidth / 2` and
/// `x + barWidth / 2`), matching the swapped axes of the chart.
class HorizontalBarBuffer extends BarBuffer {
  /// Creates a buffer of [size] floats for one of the [dataSetCount] sets of the bar data; [containsStacks] is true
  /// when the set is stacked. See [BarBuffer.new].
  HorizontalBarBuffer(super.size, super.dataSetCount, super.containsStacks);

  @override
  @protected
  void addEntry(IBarDataSet data, int index, double barWidthHalf) {
    final e = data.getEntryForIndex(index);

    final x = e.x;
    var y = e.y;
    final vals = e.stackValues;
    var bars = 0;

    if (!containsStacks || vals == null) {
      final bottom = x - barWidthHalf;
      final top = x + barWidthHalf;
      double left;
      double right;

      if (isInverted) {
        left = y >= 0 ? y : 0;
        right = y <= 0 ? y : 0;
      } else {
        right = y >= 0 ? y : 0;
        left = y <= 0 ? y : 0;
      }

      if (right > 0) {
        right *= phaseY;
      } else {
        left *= phaseY;
      }

      addBar(left, top, right, bottom);
      bars++;
    } else {
      var posY = 0.0;
      var negY = -e.negativeSum;
      double yStart;

      for (final value in vals) {
        if (bars >= barsPerEntry) break;
        if (value == 0.0 && (posY == 0.0 || negY == 0.0)) {
          y = value;
          yStart = y;
        } else if (value >= 0.0) {
          y = posY;
          yStart = posY + value;
          posY = yStart;
        } else {
          y = negY;
          yStart = negY + value.abs();
          negY += value.abs();
        }

        final bottom = x - barWidthHalf;
        final top = x + barWidthHalf;
        double left;
        double right;

        if (isInverted) {
          left = y >= yStart ? y : yStart;
          right = y <= yStart ? y : yStart;
        } else {
          right = y >= yStart ? y : yStart;
          left = y <= yStart ? y : yStart;
        }

        right *= phaseY;
        left *= phaseY;

        addBar(left, top, right, bottom);
        bars++;
      }
    }

    while (bars < barsPerEntry) {
      addBar(0, x, 0, x);
      bars++;
    }
  }
}
