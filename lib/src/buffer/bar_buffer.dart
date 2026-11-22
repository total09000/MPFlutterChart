// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/buffer/BarBuffer.kt
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show protected;

import '../interfaces/datasets/i_bar_data_set.dart';
import 'abstract_buffer.dart';

/// Buffer of bar rectangles for one bar data set, in value space. Every bar takes four floats: left, top,
/// right, bottom. Left and right are x values (`x - barWidth / 2` and `x + barWidth / 2`), top and bottom are y
/// values between the bar value and 0. A stacked entry produces one rectangle per stack value. The renderer
/// converts the part of the buffer that was filled to pixels with a `Transformer` afterwards.
class BarBuffer extends AbstractBuffer<IBarDataSet> {
  /// Creates a buffer of [size] floats, `entryCount * 4` (times the stack size for stacked sets), for one of the
  /// [dataSetCount] sets of the bar data; [containsStacks] is true when the set is stacked.
  BarBuffer(super.size, this.dataSetCount, this.containsStacks);

  /// Number of data sets in the bar data.
  @protected
  final int dataSetCount;

  /// True when the data set is stacked, so an entry may produce several rectangles.
  final bool containsStacks;

  /// Index of the data set this buffer holds.
  int dataSetIndex = 0;

  /// True when the y axis of the data set is inverted; swaps top and bottom so the bar still grows from 0.
  bool isInverted = false;

  /// Width of a bar in x value units. Default 1.
  double barWidth = 1;

  /// Width of one pixel column in x value units, or 0 while every fed entry stands only for itself. A bar that
  /// stands for the other bars of its column is widened to the room they took together, at most this much, so it
  /// covers the ground they covered. Rectangles that pad a short stack keep no width at all.
  double columnWidth = 0;

  int _firstEntry = 0;

  /// Index of the entry the first rectangle of the last [feed] belongs to.
  int get firstEntry => _firstEntry;

  @protected
  set firstEntry(int value) => _firstEntry = value;

  int _barsPerEntry = 1;

  /// How many rectangles one entry takes in the buffer: the stack size of the data set for a stacked set, 1
  /// otherwise. An entry with fewer stack values than that is padded, so a bar sits at the same place in the
  /// buffer whichever entries were fed.
  int get barsPerEntry => _barsPerEntry;

  @protected
  set barsPerEntry(int value) => _barsPerEntry = value;

  int _filledSize = 0;

  /// Number of floats the last [feed] wrote, counted from the start of [buffer]. Whatever follows is left over
  /// from an earlier feed and must not be drawn.
  int get filledSize => _filledSize;

  @protected
  set filledSize(int value) => _filledSize = value;

  Int32List _fedEntries = Int32List(0);

  int _fedCount = 0;

  /// Index of the entry the rectangle at [bar] belongs to, where [bar] counts rectangles from the start of
  /// [buffer]. The entries of a feed need not follow one another, so this is the only way back from a rectangle
  /// to the entry it was built from.
  int entryOfBar(int bar) => _fedEntries[bar ~/ barsPerEntry];

  /// Place of the rectangle at [bar] among the bars of the whole data set, which is the index the per-bar
  /// settings of a data set are keyed by: the index of its entry times [barsPerEntry], plus its place inside
  /// that entry.
  int positionOfBar(int bar) =>
      entryOfBar(bar) * barsPerEntry + bar % barsPerEntry;

  /// Width in x value units of a bar that stands for [columnEntries] entries: the room their bars took together,
  /// at most [columnWidth], and never less than [barWidth]. The rule lives here so that everything drawing a
  /// widened bar, the bar shadows included, reads the same number.
  double widthOfBar(int columnEntries) =>
      math.max(barWidth, math.min(columnWidth, columnEntries * barWidth));

  /// Appends one rectangle (value space) at the write position.
  @protected
  void addBar(double left, double top, double right, double bottom) {
    buffer[index++] = left;
    buffer[index++] = top;
    buffer[index++] = right;
    buffer[index++] = bottom;
  }

  /// Fills the buffer with the rectangles of every entry of [data].
  @override
  void feed(IBarDataSet data) => feedRange(data, 0, data.entryCount - 1);

  /// Fills the buffer with one rectangle per bar (or per stack value) of the entries of [data] from [from] to
  /// [to], writing from the start of the buffer. The y values are multiplied by the y phase; which entries are
  /// fed is up to the caller. Resets the write position afterwards.
  ///
  /// Kotlin's `feed(data, from, to)` overload. The bar renderers of this library feed only the entries worth drawing
  /// and so take [feedIndices]. A subclass that overrides this one for geometry of its own is therefore no longer
  /// reached; override [addEntry] instead.
  ///
  /// [from] is the index of the first entry to feed, [to] the index of the last entry to feed, inclusive.
  void feedRange(IBarDataSet data, int from, int to) {
    final first = math.max(from, 0);
    final last = math.min(to, data.entryCount - 1);

    _beginFeed(data, last - first + 1);
    firstEntry = first;

    for (var i = first; i <= last; i++) {
      _appendEntry(data, i, 1);
    }

    _endFeed();
  }

  /// Fills the buffer with the bars of the entries the first [count] values of [indices] name, which is how a
  /// renderer feeds only the entries worth drawing. The indices have to ascend.
  ///
  /// Kotlin's `feed(data, indices, columnEntries, count)` overload. [columnEntries] holds how many entries each of
  /// [indices] stands for, which is how wide its bar is drawn.
  void feedIndices(
    IBarDataSet data,
    Int32List indices,
    Int32List columnEntries,
    int count,
  ) {
    _beginFeed(data, count);
    firstEntry = count > 0 ? indices[0] : 0;

    for (var k = 0; k < count; k++) {
      _appendEntry(data, indices[k], columnEntries[k]);
    }

    _endFeed();
  }

  /// Appends the rectangles of the entry at [index] of [data]: one for a plain bar, one per stack value for a
  /// stacked entry, padded with rectangles without width up to [barsPerEntry] and never more than that.
  ///
  /// [barWidthHalf] is half the width the bar takes in x value units, which is wider than [barWidth] for a bar
  /// that stands for a whole pixel column.
  @protected
  void addEntry(IBarDataSet data, int index, double barWidthHalf) {
    final e = data.getEntryForIndex(index);

    final x = e.x;
    var y = e.y;
    final vals = e.stackValues;
    var bars = 0;

    if (!containsStacks || vals == null) {
      final left = x - barWidthHalf;
      final right = x + barWidthHalf;
      double bottom;
      double top;

      if (isInverted) {
        bottom = y >= 0 ? y : 0;
        top = y <= 0 ? y : 0;
      } else {
        top = y >= 0 ? y : 0;
        bottom = y <= 0 ? y : 0;
      }

      if (top > 0) {
        top *= phaseY;
      } else {
        bottom *= phaseY;
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

        final left = x - barWidthHalf;
        final right = x + barWidthHalf;
        double bottom;
        double top;

        if (isInverted) {
          bottom = y >= yStart ? y : yStart;
          top = y <= yStart ? y : yStart;
        } else {
          top = y >= yStart ? y : yStart;
          bottom = y <= yStart ? y : yStart;
        }

        top *= phaseY;
        bottom *= phaseY;

        addBar(left, top, right, bottom);
        bars++;
      }
    }

    while (bars < barsPerEntry) {
      addBar(x, 0, x, 0);
      bars++;
    }
  }

  void _beginFeed(IBarDataSet data, int entries) {
    barsPerEntry = containsStacks ? data.stackSize : 1;

    final needed = math.max(entries, 0);
    if (_fedEntries.length < needed) {
      _fedEntries = Int32List(math.max(needed, _fedEntries.length * 2));
    }

    reset();
    filledSize = 0;
    _fedCount = 0;
  }

  void _appendEntry(IBarDataSet data, int entry, int columnEntries) {
    _fedEntries[_fedCount++] = entry;
    addEntry(data, entry, widthOfBar(columnEntries) / 2);
  }

  void _endFeed() {
    filledSize = index;
    reset();
  }
}
