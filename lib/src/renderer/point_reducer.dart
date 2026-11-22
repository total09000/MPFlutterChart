// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/PointReducer.kt
//
// Kotlin declares ColumnValues and PointReducer `internal`; Dart has no module visibility, so they are public here
// (the renderers of other files and the ported test use them) and not exported from the library entry points.
import 'dart:math' as math;
import 'dart:typed_data';

import '../utils/float_math.dart';

/// The x position and the y range of the entries a [PointReducer] works on. Charts with one y value per entry
/// return that value from both [lowAt] and [highAt]; candle charts return the low and the high.
///
/// Kotlin `internal interface`; an abstract class here so implementations inherit the defaults of [hasSizes] and
/// [sizeAt].
abstract class ColumnValues {
  /// Constant constructor for subclasses.
  const ColumnValues();

  /// X value of the entry at [index], in value space.
  double xAt(int index);

  /// Bottom of the y range of the entry at [index], in value space.
  double lowAt(int index);

  /// Top of the y range of the entry at [index], in value space.
  double highAt(int index);

  /// True while the entries are drawn in sizes of their own, so that the reduction has to ask [sizeAt] and keep
  /// the largest of every column. False, the default, for charts whose entries all take the same room.
  bool get hasSizes => false;

  /// How much of the picture the entry at [index] takes, compared only with the other entries of its column.
  /// A bubble chart answers with the size of the bubble; every other chart leaves this at 0 and then nothing is
  /// kept for being large. Never read while [hasSizes] is false.
  double sizeAt(int index) => 0;
}

/// Picks the entries worth drawing when several of them fall into the same pixel column.
///
/// Per column it keeps the first entry, the lowest, the highest and the last, so the vertical extent survives
/// and the line enters and leaves the column where it really does. Above [COARSE_POINTS_PER_PIXEL] the column is
/// a solid smear and only the lowest and highest are kept. Below [ACTIVATION_POINTS_PER_PIXEL] nothing is
/// dropped. Where the entries carry sizes of their own, the largest of the column is kept as well, so a bubble
/// big enough to see is never dropped for sitting between two that reach further. An entry without a finite value
/// is always kept, and never counts as an extreme, so the gap it stands for survives. Every index returned is an
/// index of a real entry, so anything that looks entries up still works.
class PointReducer {
  Int32List _indices = Int32List(0);

  /// Entry indices to draw, ascending. Only the first [count] are meaningful; the array is reused.
  Int32List get indices => _indices;

  Int32List _columnCounts = Int32List(0);

  /// How many entries shared the pixel column of the entry at the same place in [indices], which is how many
  /// entries that one stands for. Only the first [count] are meaningful; the array is reused.
  Int32List get columnCounts => _columnCounts;

  int _count = 0;

  /// How many entries of [indices] the last [reduce] filled.
  int get count => _count;

  /// Fills [indices] with the entries between [from] and [to] that are worth drawing.
  ///
  /// [values] are the entries to reduce, indexed as the data set indexes them. [from] is the index of the first
  /// entry to consider, [to] the index of the last entry to consider, inclusive. [firstX] is the x value at the
  /// left edge of the content rectangle, where column 0 begins; entries left of it fall into the negative columns,
  /// one per pixel, and are reduced like any other. [valuesPerPixel] is the width of one pixel in value space and
  /// [pixelWidth] the width of the content rectangle in pixels.
  void reduce(
    ColumnValues values,
    int from,
    int to,
    double firstX,
    double valuesPerPixel,
    double pixelWidth,
  ) {
    _count = 0;
    if (to < from) return;

    final entryCount = to - from + 1;
    final pointsPerPixel = entryCount / math.max(pixelWidth, 1.0);

    if (pointsPerPixel <= ACTIVATION_POINTS_PER_PIXEL || valuesPerPixel <= 0) {
      _ensureCapacity(entryCount);
      for (var i = from; i <= to; i++) {
        _columnCounts[_count] = 1;
        _indices[_count++] = i;
      }
      return;
    }

    final keepEntryAndExit = pointsPerPixel <= COARSE_POINTS_PER_PIXEL;
    final hasSizes = values.hasSizes;
    var index = from;
    var indexColumn = _columnOf(values, index, firstX, valuesPerPixel);

    while (index <= to) {
      final columnStart = index;
      final column = indexColumn;
      var lowest = -1;
      var highest = -1;
      var biggest = -1;
      var lowestValue = 0.0;
      var highestValue = 0.0;
      var biggestSize = 0.0;
      var hasGap = false;

      // low and high are read once per index here, so the entries themselves need fetching only once.
      while (index <= to && indexColumn == column) {
        final low = values.lowAt(index);
        final high = values.highAt(index);

        if (low.isFinite && high.isFinite) {
          if (lowest < 0 || low < lowestValue) {
            lowest = index;
            lowestValue = low;
          }
          if (highest < 0 || high > highestValue) {
            highest = index;
            highestValue = high;
          }
          if (hasSizes) {
            final size = values.sizeAt(index);
            if (size > biggestSize) {
              biggest = index;
              biggestSize = size;
            }
          }
        } else {
          hasGap = true;
        }

        index++;
        if (index <= to) {
          indexColumn = _columnOf(values, index, firstX, valuesPerPixel);
        }
      }

      final columnEnd = index - 1;
      final columnEntries = columnEnd - columnStart + 1;

      if (hasGap) {
        _appendWithGaps(
          values,
          columnStart,
          columnEnd,
          lowest,
          highest,
          biggest,
          keepEntryAndExit,
        );
      } else {
        if (keepEntryAndExit) _append(columnStart, columnEntries);
        _appendExtremes(lowest, highest, biggest, columnEntries);
        if (keepEntryAndExit) _append(columnEnd, columnEntries);
      }
    }
  }

  /// Appends the extremes of one column lowest index first, skipping the -1 of an extreme that has none.
  void _appendExtremes(
    int lowest,
    int highest,
    int biggest,
    int columnEntries,
  ) {
    var first = lowest;
    var second = highest;
    var third = biggest;

    if (first > second) {
      final swap = first;
      first = second;
      second = swap;
    }
    if (second > third) {
      final swap = second;
      second = third;
      third = swap;
    }
    if (first > second) {
      final swap = first;
      first = second;
      second = swap;
    }

    if (first >= 0) _append(first, columnEntries);
    if (second >= 0) _append(second, columnEntries);
    if (third >= 0) _append(third, columnEntries);
  }

  /// True while both ends of the y range of the entry at [index] are real numbers.
  bool _isFinite(ColumnValues values, int index) =>
      values.lowAt(index).isFinite && values.highAt(index).isFinite;

  /// Appends a column that holds an entry without a value. Every such entry is kept, so the gap it stands for
  /// still reaches the renderer, and the extremes are those of the entries around it.
  void _appendWithGaps(
    ColumnValues values,
    int columnStart,
    int columnEnd,
    int lowest,
    int highest,
    int biggest,
    bool keepEntryAndExit,
  ) {
    final columnEntries = columnEnd - columnStart + 1;

    for (var index = columnStart; index <= columnEnd; index++) {
      final isEdge =
          keepEntryAndExit && (index == columnStart || index == columnEnd);
      if (isEdge ||
          index == lowest ||
          index == highest ||
          index == biggest ||
          !_isFinite(values, index)) {
        _append(index, columnEntries);
      }
    }
  }

  /// Kotlin computes the column in Float: `floor((x - firstX) / valuesPerPixel).toInt()`.
  int _columnOf(
    ColumnValues values,
    int index,
    double firstX,
    double valuesPerPixel,
  ) => kotlinFloatToInt(
    toKotlinFloat(
      toKotlinFloat(values.xAt(index) - firstX) / valuesPerPixel,
    ).floorToDouble(),
  );

  /// Appends [index] unless it would repeat or precede the last one, which keeps the result ascending.
  void _append(int index, int columnEntries) {
    if (_count > 0 && _indices[_count - 1] >= index) return;
    _ensureCapacity(_count + 1);
    _columnCounts[_count] = columnEntries;
    _indices[_count++] = index;
  }

  /// Fills [indices] with every index from [from] to [to], as if no column held more than one entry.
  void reduceNothing(int from, int to) {
    _count = 0;
    if (to < from) return;
    _ensureCapacity(to - from + 1);
    for (var i = from; i <= to; i++) {
      _columnCounts[_count] = 1;
      _indices[_count++] = i;
    }
  }

  void _ensureCapacity(int needed) {
    if (_indices.length >= needed) return;
    final size = math.max(needed, _indices.length * 2);
    _indices = Int32List(size)..setAll(0, _indices);
    _columnCounts = Int32List(size)..setAll(0, _columnCounts);
  }

  /// Points per pixel below which every entry is kept.
  static const double ACTIVATION_POINTS_PER_PIXEL = 1;

  /// Points per pixel above which only the lowest and highest of a column are kept.
  static const double COARSE_POINTS_PER_PIXEL = 8;
}
