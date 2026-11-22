// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/BarLineScatterCandleBubbleRenderer.kt
//
// Kotlin `internal` members (reducer, reducedColumnWidth, reduceVisible, reducedPositions, lowOf, highOf,
// hasSizes, sizeOf) are public here, since Dart has no module visibility and the renderers of other files use them.
// The `inner class XBounds` is the top-level [XBounds], which takes the animator its Kotlin outer class supplied.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show protected;

import '../animation/chart_animator.dart';
import '../data/data_set.dart';
import '../data/entry.dart';
import '../interfaces/dataprovider/bar_line_scatter_candle_bubble_data_provider.dart';
import '../interfaces/datasets/i_bar_line_scatter_candle_bubble_data_set.dart';
import '../interfaces/datasets/i_data_set.dart';
import '../utils/float_math.dart';
import '../utils/transformer.dart';
import 'data_renderer.dart';
import 'point_reducer.dart';

/// Base class of the renderers for charts with x and y axes (bar, line, scatter, candle, bubble). Adds helpers
/// that limit drawing to the entries visible on screen.
abstract class BarLineScatterCandleBubbleRenderer extends DataRenderer {
  /// Creates a renderer whose drawing follows the phases of [animator].
  BarLineScatterCandleBubbleRenderer(super.animator, super.viewPortHandler);

  /// Index range of the entries currently visible on screen; renderers update it per data set with [XBounds.set].
  @protected
  late final XBounds xBounds = XBounds(animator);

  /// Entries of the data set drawn last that are worth drawing, filled by [reduceVisible]. A renderer walks
  /// `indices` up to `count` instead of walking [xBounds].
  ///
  /// Kotlin `internal`.
  final PointReducer reducer = PointReducer();

  double _reducedColumnWidth = 0;

  /// Width in x value units of one pixel column of the last [reduceVisible], or 0 while decimation is off. A
  /// renderer that paints an entry as a shape with a width of its own widens that shape to the room the shapes
  /// of its column took together, at most this much, so it still covers the ground the entries left out covered.
  /// `reducer.columnCounts` says how many entries each kept one stands for.
  ///
  /// Kotlin `internal`.
  double get reducedColumnWidth => _reducedColumnWidth;

  /// How many pixels the x values are spread over, which is the width of the content rectangle for every chart
  /// but the horizontal bar chart, where the x values run down the screen.
  @protected
  double get xAxisPixels => viewPortHandler.contentWidth;

  late final _DataSetColumnValues _columnValues = _DataSetColumnValues(this);

  Float32List _reducedPositions = Float32List(0);

  /// Fills [reducer] with the entries of [dataSet] inside [xBounds] that are worth drawing in the viewport of
  /// [chart], or with all of them while [BarLineScatterCandleBubbleDataProvider.isDecimationEnabled] is off.
  /// Needs a preceding [XBounds.set].
  ///
  /// [reduceWhenCrowded] also reduces while decimation is off once more than two entries share a pixel column on
  /// average, for renderers whose every entry costs several draw calls.
  ///
  /// Kotlin `internal`.
  void reduceVisible(
    BarLineScatterCandleBubbleDataProvider chart,
    IBarLineScatterCandleBubbleDataSet dataSet, [
    bool reduceWhenCrowded = false,
  ]) {
    final from = xBounds.min;
    final to = xBounds.min + xBounds.range;
    final crowded = reduceWhenCrowded && xBounds.range + 1 > 2 * xAxisPixels;

    if (!chart.isDecimationEnabled && !crowded) {
      reducer.reduceNothing(from, to);
      _reducedColumnWidth = 0;
      return;
    }

    _columnValues.readFrom(dataSet);

    final pixelWidth = xAxisPixels;
    final valuesPerPixel = toKotlinFloat(
      toKotlinFloat(chart.highestVisibleX - chart.lowestVisibleX) /
          math.max(pixelWidth, 1.0),
    );
    reducer.reduce(
      _columnValues,
      from,
      to,
      chart.lowestVisibleX,
      valuesPerPixel,
      pixelWidth,
    );

    _reducedColumnWidth = valuesPerPixel;
  }

  /// Pixel positions of the entries [reduceVisible] picked, as x, y pairs, where y is [highOf] the entry
  /// multiplied by [phaseY]. Needs a preceding [reduceVisible].
  ///
  /// Returns a buffer reused between calls; only its first `reducer.count * 2` floats hold positions.
  ///
  /// Kotlin `internal`.
  Float32List reducedPositions(
    IBarLineScatterCandleBubbleDataSet dataSet,
    Transformer trans,
    double phaseY,
  ) {
    final floats = reducer.count * 2;
    if (_reducedPositions.length < floats) {
      _reducedPositions = Float32List(floats);
    }

    for (var k = 0; k < reducer.count; k++) {
      final entry = dataSet.getEntryForIndex(reducer.indices[k]);
      _reducedPositions[2 * k] = entry.x;
      _reducedPositions[2 * k + 1] = highOf(entry) * phaseY;
    }

    trans.pointValuesToPixel(_reducedPositions, floats);
    return _reducedPositions;
  }

  /// Bottom of the y range of [entry]. Charts with one y value per entry read it; candle charts read the low.
  ///
  /// Kotlin `internal open`.
  double lowOf(Entry entry) => entry.y;

  /// Top of the y range of [entry]. Charts with one y value per entry read it; candle charts read the high.
  ///
  /// Kotlin `internal open`.
  double highOf(Entry entry) => entry.y;

  /// True while the entries of this renderer are drawn in sizes of their own, so that the reduction keeps the
  /// largest of every column as well as its extremes. Only the bubble chart says yes; for everyone else asking
  /// would cost a read per entry and answer 0 every time.
  ///
  /// Kotlin `internal open`.
  bool get hasSizes => false;

  /// How much of the picture [entry] takes, for renderers whose entries have sizes of their own.
  ///
  /// Kotlin `internal open`.
  double sizeOf(Entry entry) => 0;

  /// Returns true if [set] is visible and has value labels or icons enabled.
  ///
  /// Kotlin's `shouldDrawValues(set)` overload; the `(chart, set)` overload is [shouldDrawValues].
  @protected
  bool shouldDrawValuesOf(IDataSet set) {
    return set.isVisible && (set.isDrawValuesEnabled || set.isDrawIconsEnabled);
  }

  /// Returns true if [set] draws values or icons and has at most
  /// [BarLineScatterCandleBubbleDataProvider.maxVisibleCount] entries inside the visible x range of [chart], above
  /// which the labels would sit too close together to read.
  @protected
  bool shouldDrawValues(
    BarLineScatterCandleBubbleDataProvider chart,
    IBarLineScatterCandleBubbleDataSet set,
  ) {
    return shouldDrawValuesOf(set) &&
        visibleEntryCount(chart, set) <= chart.maxVisibleCount;
  }

  /// Number of entries of [set] that lie inside the visible x range of [chart].
  @protected
  int visibleEntryCount(
    BarLineScatterCandleBubbleDataProvider chart,
    IBarLineScatterCandleBubbleDataSet set,
  ) {
    if (set.entryCount == 0) return 0;

    final from = math.max(
      set.getEntryIndex(chart.lowestVisibleX, double.nan, Rounding.DOWN),
      0,
    );
    final to = math.max(
      set.getEntryIndex(chart.highestVisibleX, double.nan, Rounding.UP),
      0,
    );

    return math.max(0, to - from) + 1;
  }

  /// Returns true if [e] lies within the part of [set] that the x animation phase has already revealed, false for
  /// null.
  @protected
  bool isInBoundsX(Entry? e, IBarLineScatterCandleBubbleDataSet set) {
    if (e == null) return false;
    final entryIndex = set.getEntryIndexOf(e).toDouble();
    return entryIndex <
        toKotlinFloat(set.entryCount * toKotlinFloat(animator.phaseX));
  }
}

/// Index range of the entries of one data set that are currently visible. [min] and [max] are entry indices,
/// not x values; [range] is the number of indices to draw after applying the x animation phase.
///
/// Kotlin's `protected inner class BarLineScatterCandleBubbleRenderer.XBounds`; top level here, with the animator
/// of the renderer passed in.
class XBounds {
  /// Creates bounds that apply the x phase of [animator].
  XBounds(this._animator);

  final ChartAnimator _animator;

  /// Index of the first visible entry.
  int min = 0;

  /// Index of the last visible entry.
  int max = 0;

  /// Number of indices from [min] to [max], multiplied by the x animation phase.
  int range = 0;

  /// Recomputes the bounds of [dataSet] from the lowest and highest x value visible in [chart]. The start entry
  /// is rounded down and the end entry up, so the entries just outside the screen are included. Both indices are
  /// 0 when the data set is empty.
  void set(
    BarLineScatterCandleBubbleDataProvider chart,
    IBarLineScatterCandleBubbleDataSet dataSet,
  ) {
    final phaseX = math.max(
      0.0,
      math.min(1.0, toKotlinFloat(_animator.phaseX)),
    );

    final low = chart.lowestVisibleX;
    final high = chart.highestVisibleX;

    min = math.max(dataSet.getEntryIndex(low, double.nan, Rounding.DOWN), 0);
    max = math.max(dataSet.getEntryIndex(high, double.nan, Rounding.UP), 0);
    if (max < min) max = min;
    range = kotlinFloatToInt(toKotlinFloat((max - min) * phaseX));
  }
}

/// Reads the x value and the y range of the entries of one data set, keeping the entry it fetched last so the
/// several questions [PointReducer] asks about one index cost one fetch.
class _DataSetColumnValues extends ColumnValues {
  _DataSetColumnValues(this._renderer);

  final BarLineScatterCandleBubbleRenderer _renderer;

  late IBarLineScatterCandleBubbleDataSet _dataSet;
  int _cachedIndex = -1;
  Entry? _cachedEntry;

  /// Points this at [dataSet] and drops the entry memorized from the previous one.
  void readFrom(IBarLineScatterCandleBubbleDataSet dataSet) {
    _dataSet = dataSet;
    _cachedIndex = -1;
    _cachedEntry = null;
  }

  Entry _entryAt(int index) {
    final cached = _cachedEntry;
    if (cached != null && _cachedIndex == index) return cached;
    final entry = _dataSet.getEntryForIndex(index);
    _cachedIndex = index;
    _cachedEntry = entry;
    return entry;
  }

  @override
  double xAt(int index) => _entryAt(index).x;

  @override
  double lowAt(int index) => _renderer.lowOf(_entryAt(index));

  @override
  double highAt(int index) => _renderer.highOf(_entryAt(index));

  @override
  bool get hasSizes => _renderer.hasSizes;

  @override
  double sizeAt(int index) => _renderer.sizeOf(_entryAt(index));
}
