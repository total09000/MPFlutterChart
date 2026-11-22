// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/BarBufferReuseTest.kt,
// BarStackColorTest.kt and BarBoundsTest.kt
//
// Device tests run on the recording canvas instead of a bitmap. The charts are laid out at the
// 1080 x 1200 of the device fixtures, which the pixel pans are tuned to. `_CountingBarSet` subclasses `BarDataSet`
// where Kotlin delegates the whole `IBarDataSet` to a wrapped set.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/bar_chart.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/data_set.dart';

import 'support/bar_recording.dart';
import 'support/fixtures.dart';
import 'support/strict_canvas.dart';

const _red = ui.Color(0xFFFF0000);
const _green = ui.Color(0xFF00FF00);
const _blue = ui.Color(0xFF0000FF);
const _yellow = ui.Color(0xFFFFFF00);

/// Counts calls to [getEntryForIndex], the fetch the renderer makes once per bar it builds.
class _CountingBarSet extends BarDataSet {
  _CountingBarSet(super.entries, super.label);

  int _fetches = 0;

  int get fetches => _fetches;

  @override
  BarEntry getEntryForIndex(int index) {
    _fetches++;
    return super.getEntryForIndex(index);
  }
}

void main() {
  group('BarBufferReuseTest', () {
    BarDataSet set(List<BarEntry> entries) => BarDataSet(entries, 'bars')
      ..colors = [_red, _green, _blue]
      ..isDrawValuesEnabled = false
      ..isDrawIconsEnabled = false;

    Map<int, List<ui.Color>> draw(BarChart chart) {
      final canvas = StrictCanvas();
      chart.onDraw(canvas);
      return barColorsByX(canvas, chart);
    }

    test('stacksReplacingPlainBarsOfTheSameBufferSizeKeepTheirSections', () {
      final chart = lay(BarChart());
      chart.legend.isEnabled = false;

      // Twelve plain bars need 12 * 4 * 1 floats; four bars of three sections need 4 * 4 * 3, which is the same.
      chart.data = BarData([
        set([for (var i = 0; i < 12; i++) BarEntry(x: i.toDouble(), y: 9)]),
      ]);
      draw(chart);

      chart.data = BarData([
        set([
          for (var i = 0; i < 4; i++)
            BarEntry.stacked(x: i.toDouble(), stackValues: [3, 4, 5]),
        ]),
      ]);

      expect(draw(chart)[0], [
        _red,
        _green,
        _blue,
      ], reason: 'sections of the bar at x=0');
    });
  });

  group('BarStackColorTest', () {
    const total = 60;

    const stackSize = 3;

    // Four colors for a stack of three, so that a color counted from the wrong place does not land right anyway.
    const palette = [_red, _green, _blue, _yellow];

    // Entries carrying three, two and one value, so the stack size of the set is larger than most entries need.
    List<BarEntry> raggedStacks() => [
      for (var i = 0; i < total; i++)
        switch (i % stackSize) {
          0 => BarEntry.stacked(x: i.toDouble(), stackValues: [4, 6, 3]),
          1 => BarEntry.stacked(x: i.toDouble(), stackValues: [5, 7]),
          _ => BarEntry(x: i.toDouble(), y: 9),
        },
    ];

    // The colors each bar must paint, bottom section first, for the first sixteen entries. Colors cycle over the
    // sections of the whole set, so the section at index i of entry e takes the color at `e * 3 + i`, counted over
    // the set and not over whatever the viewport starts at; an entry carrying fewer than three values still takes
    // three places. Written out rather than computed, so the test does not restate the rule it checks.
    const expected = [
      [_red, _green, _blue],
      [_yellow, _red],
      [_blue],
      [_green, _blue, _yellow],
      [_red, _green],
      [_yellow],
      [_blue, _yellow, _red],
      [_green, _blue],
      [_red],
      [_yellow, _red, _green],
      [_blue, _yellow],
      [_green],
      [_red, _green, _blue],
      [_yellow, _red],
      [_blue],
      [_green, _blue, _yellow],
    ];

    // The colors each bar was painted with, keyed by the x value of the bar, after scrolling by [pan] pixels.
    Map<int, List<ui.Color>> colorsByBar(BarChart chart, double pan) {
      resetViewport(chart);
      zoomToVisiblePoints(chart, total, 15);
      panBy(chart, pan);

      final canvas = StrictCanvas();
      chart.onDraw(canvas);

      return barColorsByX(canvas, chart);
    }

    // The entry the renderer starts filling its buffer from, which is where a color counted over the viewport
    // instead of over the set would start counting. Worked out the way the renderer works out its visible range.
    int firstFedEntry(BarChart chart, BarDataSet set) {
      final index = set.getEntryIndex(
        chart.lowestVisibleX,
        double.nan,
        Rounding.DOWN,
      );
      return index < 0 ? 0 : index;
    }

    int assertPaintsExpectedColors(
      String where,
      Map<int, List<ui.Color>> bars,
    ) {
      var checked = 0;
      for (final MapEntry(key: x, value: colors) in bars.entries) {
        if (x < 0 || x >= expected.length) continue;
        expect(colors, expected[x], reason: 'colors of the bar at x=$x $where');
        checked++;
      }
      return checked;
    }

    test('aBarKeepsItsColorsWhereverTheChartIsScrolled', () {
      final set = BarDataSet(raggedStacks(), 'bars')
        ..colors = palette
        ..isDrawValuesEnabled = false
        ..isDrawIconsEnabled = false;
      final chart = lay(BarChart());
      // The legend draws a colored square of its own, which would land on a different bar in each viewport.
      chart.legend.isEnabled = false;
      chart.data = BarData([set]);

      final start = colorsByBar(chart, 0);
      final scrolled = colorsByBar(chart, -650);

      // Counting colors over the viewport instead of over the set shifts them by the first fed entry times the
      // stack size, which is invisible when that lands on a whole number of palettes. The scrolled viewport has to
      // avoid it or the rest of this test proves nothing; move the pan if this ever fails.
      final firstFed = firstFedEntry(chart, set);
      expect(
        firstFed * stackSize % palette.length,
        isNot(0),
        reason:
            'scrolled viewport is fed from entry $firstFed, where a color counted over the viewport comes out the same',
      );

      assertPaintsExpectedColors('at the start of the set', start);
      final checked = assertPaintsExpectedColors('after scrolling', scrolled);
      expect(
        checked,
        greaterThanOrEqualTo(3),
        reason:
            'bars of the scrolled viewport with an expectation of their own: $checked',
      );

      final shared = start.keys.toSet().intersection(scrolled.keys.toSet());
      expect(
        shared.length,
        greaterThanOrEqualTo(5),
        reason: 'bars visible from both scroll positions: $shared',
      );

      for (final x in shared) {
        expect(
          scrolled[x],
          start[x],
          reason: 'colors of the bar at x=$x after scrolling',
        );
      }
    });
  });

  group('BarBoundsTest', () {
    test('onlyFetchesTheBarsOnScreen', () {
      const total = 100000;
      final set = _CountingBarSet(barEntries(total), 'bar');
      quiet(set);
      final chart = lay(BarChart());
      chart.isDrawBarShadowEnabled = true;
      chart.data = BarData([set]);
      final canvas = StrictCanvas();

      resetViewport(chart);
      zoomToVisiblePoints(chart, total, 500);
      panBy(chart, -(total ~/ 2).toDouble());

      chart.onDraw(canvas);
      final before = set.fetches;
      chart.onDraw(canvas);

      expect(
        set.fetches - before,
        lessThan(total ~/ 10),
        reason: 'fetched ${set.fetches - before} of $total entries',
      );
      // The 500 or so bars on screen are drawn, so they are fetched (about 1,000 fetches here); the bound of 100 only
      // rules out a draw that fetches next to nothing.
      expect(
        set.fetches - before,
        greaterThanOrEqualTo(100),
        reason: 'fetched ${set.fetches - before} of $total entries',
      );
    });
  });
}
