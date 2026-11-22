// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/renderer/DataRenderer.kt
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show protected;

import '../animation/chart_animator.dart';
import '../data/entry.dart';
import '../formatter/i_value_formatter.dart';
import '../graphics/chart_canvas.dart';
import '../graphics/chart_paint.dart';
import '../highlight/highlight.dart';
import '../interfaces/datasets/i_data_set.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'renderer.dart';

/// Base class of the renderers that draw chart data (bars, lines, slices, ...).
///
/// The chart calls [initBuffers] whenever its data changes and then, on every draw pass, [drawData],
/// [drawHighlighted], [drawExtras] and [drawValues] in that order. Subclass it and assign the instance to
/// `chart.renderer` to change how a chart draws. All canvas coordinates are pixels.
abstract class DataRenderer extends Renderer {
  /// Creates a renderer whose drawing follows the phases of [animator].
  DataRenderer(this.animator, ViewPortHandler viewPortHandler)
    : super(viewPortHandler);

  /// Supplies the animation phases (0 to 1) that scale the drawn entries.
  @protected
  final ChartAnimator animator;

  /// Main paint used to draw the data shapes (bars, lines, slices). Anti-aliased and filled by default; subclasses
  /// change its color, style and stroke width per data set.
  @protected
  final ChartPaint renderPaint = ChartPaint()..style = PaintStyle.FILL;

  /// Paint used to draw the highlight indicator of a selected entry. A 2 px orange stroke by default; subclasses
  /// restyle it.
  @protected
  final ChartPaint highlightPaint = ChartPaint()
    ..style = PaintStyle.STROKE
    ..strokeWidth = 2
    ..color = const ui.Color.fromARGB(255, 255, 187, 115);

  /// Paint used to draw the value labels of entries. Dark gray, centered, 9 dp by default; [applyValueTextStyle]
  /// copies the typeface and text size of a data set into it before its values are drawn.
  @protected
  final ChartPaint valuePaint = ChartPaint()
    ..color = const ui.Color.fromARGB(255, 63, 63, 63)
    ..textAlign = PaintAlign.CENTER
    ..textSize = Utils.convertDpToPixel(9);

  /// The paint used for value labels, see [valuePaint].
  ChartPaint get paintValues => valuePaint;

  /// The paint used for highlight indicators, see [highlightPaint].
  ChartPaint get paintHighlight => highlightPaint;

  /// The paint used for the data shapes, see [renderPaint].
  ChartPaint get paintRender => renderPaint;

  /// Draws one value label of a stacked bar entry, where [stackIndex] is the position of [value] in the stack.
  /// Same as [drawValue] otherwise.
  ///
  /// Kotlin's `drawValue(c, formatter, value, stackIndex, entry, dataSetIndex, x, y, color)` overload; renamed
  /// because Dart has no overloading.
  void drawStackedValue(
    ui.Canvas c,
    IValueFormatter formatter,
    double value,
    int stackIndex,
    Entry entry,
    int dataSetIndex,
    double x,
    double y,
    ui.Color color,
  ) {
    valuePaint.color = color;
    c.drawText(
      formatter.getStackedFormattedValue(
        value,
        stackIndex,
        entry,
        dataSetIndex,
        viewPortHandler,
      ),
      x,
      y,
      valuePaint,
    );
  }

  /// Copies the value typeface and value text size (dp, converted to pixels) of [set] into [valuePaint].
  @protected
  void applyValueTextStyle(IDataSet set) {
    valuePaint.typeface = set.valueTypeface;
    valuePaint.textSize = Utils.convertDpToPixel(set.valueTextSize);
  }

  /// Creates or resizes the buffers needed for the current data. Called by the chart whenever its data changes,
  /// before the next draw.
  void initBuffers();

  /// Draws the data of the chart (bars, lines, slices, ...) onto [c]. Called first in a draw pass, with the
  /// canvas clipped to the content rectangle when the chart clips data.
  void drawData(ui.Canvas c);

  /// Draws the formatted value labels and icons of all entries onto [c]. Called last in a draw pass, after the
  /// axes have been drawn.
  void drawValues(ui.Canvas c);

  /// Draws one value label with [valuePaint] in [color] at the pixel position ([x], [y]), where [y] is the text
  /// baseline.
  ///
  /// [formatter] formats [value] of [entry], which belongs to the data set at [dataSetIndex].
  void drawValue(
    ui.Canvas c,
    IValueFormatter formatter,
    double value,
    Entry entry,
    int dataSetIndex,
    double x,
    double y,
    ui.Color color,
  ) {
    valuePaint.color = color;
    c.drawText(
      formatter.getFormattedValue(value, entry, dataSetIndex, viewPortHandler),
      x,
      y,
      valuePaint,
    );
  }

  /// Draws whatever the data type needs in addition to the data, such as line circles, the radar web or the pie
  /// hole. Called after [drawHighlighted], without the content clip.
  void drawExtras(ui.Canvas c);

  /// Draws the highlight indicators for the given selections onto [c]. Called right after [drawData].
  ///
  /// [indices] are the highlights to draw; entries outside the visible range or in data sets with highlighting
  /// disabled are skipped.
  void drawHighlighted(ui.Canvas c, List<Highlight> indices);
}
