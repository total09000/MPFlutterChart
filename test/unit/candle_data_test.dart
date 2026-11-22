// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for the candle data classes. Locks CandleEntry
// (its y in the middle of high and low, the two ranges, copy), the CandleDataSet defaults, the barSpace clamp, the y
// range taken from low and high, copy, and the CandleData constructor. The Kotlin HostileDataTest candle part (an
// infinite high is left out of the range) runs in hostile_data_test.dart.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/data/candle_data.dart';
import 'package:mp_flutter_chart/src/data/candle_data_set.dart';
import 'package:mp_flutter_chart/src/data/candle_entry.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/highlight/highlight_line_span.dart';
import 'package:mp_flutter_chart/src/utils/color_template.dart';

const _red = ui.Color(0xFFFF0000);
const _green = ui.Color(0xFF00FF00);
const _blue = ui.Color(0xFF0000FF);
const _gray = ui.Color(0xFF808080);
const _yellow = ui.Color(0xFFFFFF00);

class _Icon extends ChartDrawable {
  @override
  int get intrinsicWidth => 1;

  @override
  int get intrinsicHeight => 1;

  @override
  void draw(ui.Canvas canvas, MutableRect bounds) {}
}

CandleEntry _candle(
  double x,
  double high,
  double low,
  double open,
  double close,
) => CandleEntry(x: x, high: high, low: low, open: open, close: close);

void main() {
  group('CandleEntry', () {
    test('y is the middle of high and low; the ranges are the shadow and the '
        'body heights', () {
      final candle = CandleEntry(x: 0, high: 20, low: 10, open: 12, close: 18);
      expect(candle.x, 0);
      expect(candle.y, 15);
      expect(candle.shadowRange, 10);
      expect(candle.bodyRange, 6);

      // Both ranges are distances, whichever end is larger.
      final upsideDown = _candle(1, 10, 20, 18, 12);
      expect(upsideDown.shadowRange, 10);
      expect(upsideDown.bodyRange, 6);
    });

    test('y is set once and does not follow later changes of high and low, '
        'the ranges do', () {
      final candle = _candle(0, 20, 10, 12, 18);
      candle.high = 40;
      candle.low = 0;
      candle.open = 1;
      candle.close = 30;
      expect(candle.y, 15);
      expect(candle.shadowRange, 40);
      expect(candle.bodyRange, 29);
    });

    test('copy keeps the values and shares the icon and the payload', () {
      final icon = _Icon();
      final payload = Object();
      final candle = CandleEntry<Object>(
        x: 3,
        high: 20,
        low: 10,
        open: 12,
        close: 18,
        icon: icon,
        data: payload,
      );

      final copied = candle.copy();
      expect(copied, isA<CandleEntry<Object>>());
      expect(identical(copied, candle), isFalse);
      expect(
        [copied.x, copied.high, copied.low, copied.open, copied.close],
        [3, 20, 10, 12, 18],
      );
      expect(copied.y, 15);
      expect(copied.icon, same(icon));
      expect(copied.data, same(payload));

      copied.high = 50;
      expect(candle.high, 20);
    });
  });

  group('CandleDataSet', () {
    test('defaults: 1.5 dp shadows, bodies drawn 0.1 in from each side, '
        'stroked when increasing and filled when decreasing, no colors', () {
      final set = CandleDataSet([_candle(0, 20, 10, 12, 18)], 'candles');
      expect(set.shadowWidth, 1.5);
      expect(set.showCandleBar, isTrue);
      expect(set.barSpace, 0.1);
      expect(set.shadowColorSameAsCandle, isFalse);
      expect(set.increasingPaintStyle, PaintStyle.STROKE);
      expect(set.decreasingPaintStyle, PaintStyle.FILL);
      expect(set.neutralColor, ColorTemplate.COLOR_NONE);
      expect(set.increasingColor, ColorTemplate.COLOR_NONE);
      expect(set.decreasingColor, ColorTemplate.COLOR_NONE);
      expect(set.shadowColor, ColorTemplate.COLOR_NONE);
    });

    test('barSpace is clamped to 0 to 0.45', () {
      final set = CandleDataSet([_candle(0, 20, 10, 12, 18)], 'candles');
      set.barSpace = 0.9;
      expect(set.barSpace, 0.45);
      set.barSpace = -1;
      expect(set.barSpace, 0);
      set.barSpace = 0.3;
      expect(set.barSpace, 0.3);
      // Kotlin's coerceIn lets NaN through: it is neither below 0 nor above 0.45.
      set.barSpace = double.nan;
      expect(set.barSpace, isNaN);
    });

    test('the y range runs from the lowest low to the highest high', () {
      final set = CandleDataSet([
        _candle(0, 20, 10, 12, 18),
        _candle(1, 25, 5, 20, 8),
        // High below low, as in the device EdgeCaseTest: both still count.
        _candle(2, 3, 22, 4, 5),
      ], 'candles');
      expect(set.yMin, 3);
      expect(set.yMax, 25);
      expect(set.xMin, 0);
      expect(set.xMax, 2);

      set.addEntry(_candle(3, 30, -1, 0, 1));
      expect(set.yMin, -1);
      expect(set.yMax, 30);
      expect(set.xMax, 3);
    });

    test('a candle with a NaN or infinite high or low is left out of the y '
        'range but not out of the x range', () {
      final set = CandleDataSet([
        _candle(0, 20, 10, 12, 18),
        _candle(1, double.nan, 0, 1, 1),
        _candle(2, 40, double.negativeInfinity, 1, 1),
        _candle(5, double.infinity, -5, 1, 1),
      ], 'candles');
      expect(set.yMin, 10);
      expect(set.yMax, 20);
      expect(set.xMin, 0);
      expect(set.xMax, 5);
      // As in Kotlin, the candle override does not flag the set as holding non-finite values.
      expect(set.hasNonFiniteY, isFalse);
    });

    test('copy copies the entries and every candle setting', () {
      final set =
          CandleDataSet([
              _candle(0, 20, 10, 12, 18),
              _candle(1, 25, 5, 20, 8),
            ], 'candles')
            ..shadowWidth = 3
            ..showCandleBar = false
            ..barSpace = 0.2
            ..shadowColorSameAsCandle = true
            ..highlightColor = _yellow
            ..increasingPaintStyle = PaintStyle.FILL
            ..decreasingPaintStyle = PaintStyle.FILL_AND_STROKE
            ..neutralColor = _blue
            ..increasingColor = _green
            ..decreasingColor = _red
            ..shadowColor = _gray
            ..highlightLineWidth = 2
            ..verticalHighlightIndicatorSpan = HighlightLineSpan.TO_ENTRY;

      final copied = set.copy() as CandleDataSet;

      expect(copied.label, 'candles');
      expect(copied.entryCount, 2);
      expect(
        identical(copied.getEntryForIndex(0), set.getEntryForIndex(0)),
        isFalse,
      );
      expect(copied.getEntryForIndex(1).high, 25);
      expect(copied.yMin, 5);
      expect(copied.yMax, 25);
      expect(copied.shadowWidth, 3);
      expect(copied.showCandleBar, isFalse);
      expect(copied.barSpace, 0.2);
      expect(copied.shadowColorSameAsCandle, isTrue);
      expect(copied.highlightColor, _yellow);
      expect(copied.increasingPaintStyle, PaintStyle.FILL);
      expect(copied.decreasingPaintStyle, PaintStyle.FILL_AND_STROKE);
      expect(copied.neutralColor, _blue);
      expect(copied.increasingColor, _green);
      expect(copied.decreasingColor, _red);
      expect(copied.shadowColor, _gray);
      // The highlight line settings come from the base class.
      expect(copied.highlightLineWidth, 2);
      expect(copied.verticalHighlightIndicatorSpan, HighlightLineSpan.TO_ENTRY);
    });
  });

  group('CandleData', () {
    test('holds the given sets or none', () {
      expect(CandleData().dataSetCount, 0);

      final sets = [
        CandleDataSet([_candle(0, 20, 10, 12, 18)], 'a'),
        CandleDataSet([_candle(1, 30, 2, 3, 4)], 'b'),
      ];
      final data = CandleData(sets);
      expect(data.dataSets, same(sets));
      expect(data.yMin, 2);
      expect(data.yMax, 30);
    });
  });
}
