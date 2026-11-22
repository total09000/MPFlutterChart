// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/Legend.kt
import 'dart:math' as math;
import 'dart:ui';

import '../graphics/chart_paint.dart';
import '../utils/color_template.dart';
import '../utils/f_size.dart';
import '../utils/utils.dart';
import '../utils/view_port_handler.dart';
import 'component_base.dart';
import 'legend_entry.dart';
import 'legend_form.dart';

export 'legend_form.dart';

/// Horizontal placement of the legend: at the left edge, centered, or at the right edge of the chart.
///
/// Kotlin's `Legend.LegendHorizontalAlignment`; a top-level enum because Dart has no nested types.
enum LegendHorizontalAlignment { LEFT, CENTER, RIGHT }

/// Vertical placement of the legend: at the top edge, centered, or at the bottom edge of the chart.
///
/// Kotlin's `Legend.LegendVerticalAlignment`; a top-level enum because Dart has no nested types.
enum LegendVerticalAlignment { TOP, CENTER, BOTTOM }

/// Layout of the entries: HORIZONTAL in rows, wrapping when `Legend.isWordWrapEnabled`, or VERTICAL in one column.
///
/// Kotlin's `Legend.LegendOrientation`; a top-level enum because Dart has no nested types.
enum LegendOrientation { HORIZONTAL, VERTICAL }

/// Order of form and label: LEFT_TO_RIGHT draws the form before the label and lays entries out to the right,
/// RIGHT_TO_LEFT draws the label before the form and lays entries out to the left.
///
/// Kotlin's `Legend.LegendDirection`; a top-level enum because Dart has no nested types.
enum LegendDirection { LEFT_TO_RIGHT, RIGHT_TO_LEFT }

const Color _COLOR_ZERO = Color(0x00000000);

/// The legend of a chart. By default it shows one entry per data set, or one per color for data sets with several
/// colors, recomputed whenever the chart data changes. Assign [entries] to show your own entries instead. Sizes and
/// spacings are in dp and converted to px in [calculateDimensions].
///
/// Kotlin's `Legend()` and `Legend(entries)` constructors are one constructor with an optional list.
class Legend extends ComponentBase {
  /// Creates a legend; with [entries] it is a custom legend that shows them.
  Legend([List<LegendEntry>? entries]) {
    textSize = 10;
    xOffset = 5;
    yOffset = 3;
    if (entries != null) this.entries = entries;
  }

  List<LegendEntry> _entries = const [];

  /// Entries to draw. Assigning them makes the legend custom, so it stops mirroring the data sets until
  /// [resetCustom]. An entry with a null label draws only its form, stacked with the next entry.
  List<LegendEntry> get entries => _entries;
  set entries(List<LegendEntry> value) {
    _entries = value;
    _isLegendCustom = true;
  }

  /// Sets [entries] to the entries computed from the data sets without changing [isLegendCustom].
  ///
  /// Kotlin `internal`: called by the legend renderer; not MPAndroidChart API.
  void setComputedEntries(List<LegendEntry> computed) {
    final custom = _isLegendCustom;
    entries = computed;
    _isLegendCustom = custom;
  }

  /// Entries appended after the computed ones the next time the chart data changes. Ignored by a custom legend. See
  /// [setExtra].
  List<LegendEntry> extraEntries = const [];

  bool _isLegendCustom = false;

  /// Whether [entries] were assigned rather than computed from the data sets. Default false.
  bool get isLegendCustom => _isLegendCustom;

  /// Horizontal placement of the legend. Default [LegendHorizontalAlignment.LEFT].
  LegendHorizontalAlignment horizontalAlignment =
      LegendHorizontalAlignment.LEFT;

  /// Vertical placement of the legend. Default [LegendVerticalAlignment.BOTTOM].
  LegendVerticalAlignment verticalAlignment = LegendVerticalAlignment.BOTTOM;

  /// Whether the entries are laid out in rows or in one column. Default [LegendOrientation.HORIZONTAL].
  LegendOrientation orientation = LegendOrientation.HORIZONTAL;

  /// Whether the legend is drawn over the content area instead of the chart reserving space for it. Default false.
  bool isDrawInsideEnabled = false;

  /// Order of form and label within an entry. Default [LegendDirection.LEFT_TO_RIGHT].
  LegendDirection direction = LegendDirection.LEFT_TO_RIGHT;

  /// Form drawn for entries whose own form is [LegendForm.DEFAULT]. Default [LegendForm.SQUARE].
  LegendForm form = LegendForm.SQUARE;

  /// Size of the forms in dp, used by entries whose own size is NaN. Default 8.
  double formSize = 8;

  /// Stroke width in dp of [LegendForm.LINE] forms, used by entries whose own width is NaN. Default 3.
  double formLineWidth = 3;

  /// Dash pattern of [LegendForm.LINE] forms, used by entries without their own; null draws solid lines.
  DashPathEffect? formLineDashEffect;

  /// Horizontal space in dp between two entries in a row. Default 6.
  double xEntrySpace = 6;

  /// Vertical space in dp between two entries in a column, or between wrapped rows. Default 0.
  double yEntrySpace = 0;

  /// Space in dp between a form and its label. Default 5.
  double formToTextSpace = 5;

  /// Space in dp between stacked forms, that is entries without a label. Default 3.
  double stackSpace = 3;

  /// Largest share of the chart the legend may take, 0..1: of the width for a vertical legend at the side, of the
  /// height for a horizontal one. A wrapping horizontal legend breaks its rows at this share of the content width.
  /// Default 0.95.
  double maxSizePercent = 0.95;

  /// Whether a horizontal legend breaks into several rows instead of being cut off. Costs performance. Default false.
  bool isWordWrapEnabled = false;

  /// Total width in px the legend needs, including [xOffset]. Set by [calculateDimensions].
  ///
  /// Kotlin `internal set`: written by [calculateDimensions]; do not change it.
  double neededWidth = 0;

  /// Total height in px the legend needs, including [yOffset]. Set by [calculateDimensions].
  ///
  /// Kotlin `internal set`: written by [calculateDimensions]; do not change it.
  double neededHeight = 0;

  /// Height in px of the tallest label. Set by [calculateDimensions].
  ///
  /// Kotlin `internal set`: written by [calculateDimensions]; do not change it.
  double textHeightMax = 0;

  /// Width in px of the widest entry, form and spacing included. Set by [calculateDimensions].
  ///
  /// Kotlin `internal set`: written by [calculateDimensions]; do not change it.
  double textWidthMax = 0;

  /// Label size in px per entry, in entry order. Filled by [calculateDimensions] for a horizontal legend.
  final List<FSize> calculatedLabelSizes = [];

  /// Per entry, whether a new row starts with it. Filled by [calculateDimensions] for a horizontal legend.
  final List<bool> calculatedLabelBreakPoints = [];

  /// Size in px of each row. Filled by [calculateDimensions] for a horizontal legend.
  final List<FSize> calculatedLineSizes = [];

  /// Width in px of the widest entry: the longest label plus the largest form size and [formToTextSpace].
  ///
  /// [p] is the paint used to measure the labels.
  double getMaximumEntryWidth(ChartPaint p) {
    var max = 0.0;
    var maxFormSize = 0.0;
    final formToTextSpace = Utils.convertDpToPixel(this.formToTextSpace);

    for (final entry in entries) {
      final formSize = Utils.convertDpToPixel(
        entry.formSize.isNaN ? this.formSize : entry.formSize,
      );
      if (formSize > maxFormSize) maxFormSize = formSize;

      final label = entry.label;
      if (label == null) continue;
      final length = Utils.calcTextWidth(p, label);
      if (length > max) max = length;
    }

    return max + maxFormSize + formToTextSpace;
  }

  /// Height in px of the tallest label.
  ///
  /// [p] is the paint used to measure the labels.
  double getMaximumEntryHeight(ChartPaint p) {
    var max = 0.0;
    for (final entry in entries) {
      final label = entry.label;
      if (label == null) continue;
      final length = Utils.calcTextHeight(p, label);
      if (length > max) max = length;
    }
    return max;
  }

  /// Builds [extraEntries] from parallel lists of colors and labels; surplus items of the longer list are dropped.
  /// A color of [ColorTemplate.COLOR_SKIP] or 0 (`Color(0x00000000)`) gives the entry [LegendForm.NONE],
  /// [ColorTemplate.COLOR_NONE] gives it [LegendForm.EMPTY].
  ///
  /// [colors] holds the form color and [labels] the label text per entry.
  void setExtra(List<Color> colors, List<String> labels) {
    final result = <LegendEntry>[];
    for (var i = 0; i < math.min(colors.length, labels.length); i++) {
      final entry = LegendEntry();
      entry.formColor = colors[i];
      entry.label = labels[i];

      if (entry.formColor == ColorTemplate.COLOR_SKIP ||
          entry.formColor == _COLOR_ZERO) {
        entry.form = LegendForm.NONE;
      } else if (entry.formColor == ColorTemplate.COLOR_NONE) {
        entry.form = LegendForm.EMPTY;
      }

      result.add(entry);
    }
    extraEntries = result;
  }

  /// Makes the legend mirror the data sets again after [entries] were assigned. Applied when the chart data changes
  /// next.
  void resetCustom() {
    _isLegendCustom = false;
  }

  /// Measures the legend: the largest entry, [neededWidth] and [neededHeight], and for a horizontal legend the row
  /// layout. Converts the dp sizes to px. The chart calls this before it lays out its content area.
  ///
  /// [labelPaint] is the paint used to measure the labels; [viewPortHandler] supplies the content width that rows
  /// wrap at.
  void calculateDimensions(
    ChartPaint labelPaint,
    ViewPortHandler viewPortHandler,
  ) {
    final defaultFormSize = Utils.convertDpToPixel(formSize);
    final stackSpace = Utils.convertDpToPixel(this.stackSpace);
    final formToTextSpace = Utils.convertDpToPixel(this.formToTextSpace);
    final xEntrySpace = Utils.convertDpToPixel(this.xEntrySpace);
    final yEntrySpace = Utils.convertDpToPixel(this.yEntrySpace);
    final wordWrapEnabled = isWordWrapEnabled;
    final entries = this.entries;
    final entryCount = entries.length;

    textWidthMax = getMaximumEntryWidth(labelPaint);
    textHeightMax = getMaximumEntryHeight(labelPaint);

    switch (orientation) {
      case LegendOrientation.VERTICAL:
        var maxWidth = 0.0;
        var maxHeight = 0.0;
        var width = 0.0;
        final labelLineHeight = Utils.getLineHeight(labelPaint);
        var wasStacked = false;

        for (var i = 0; i < entryCount; i++) {
          final e = entries[i];
          final drawingForm = e.form != LegendForm.NONE;
          final formSize = e.formSize.isNaN
              ? defaultFormSize
              : Utils.convertDpToPixel(e.formSize);
          final label = e.label;

          if (!wasStacked) width = 0;

          if (drawingForm) {
            if (wasStacked) width += stackSpace;
            width += formSize;
          }

          if (label != null) {
            if (drawingForm && !wasStacked) {
              width += formToTextSpace;
            } else if (wasStacked) {
              maxWidth = math.max(maxWidth, width);
              maxHeight += labelLineHeight + yEntrySpace;
              width = 0;
              wasStacked = false;
            }

            width += Utils.calcTextWidth(labelPaint, label);
            maxHeight += labelLineHeight + yEntrySpace;
          } else {
            wasStacked = true;
            width += formSize;
            if (i < entryCount - 1) width += stackSpace;
          }

          maxWidth = math.max(maxWidth, width);
        }

        neededWidth = maxWidth;
        neededHeight = maxHeight;
      case LegendOrientation.HORIZONTAL:
        final labelLineHeight = Utils.getLineHeight(labelPaint);
        final labelLineSpacing = Utils.getLineSpacing(labelPaint) + yEntrySpace;
        final contentWidth = viewPortHandler.contentWidth * maxSizePercent;

        var maxLineWidth = 0.0;
        var currentLineWidth = 0.0;
        var requiredWidth = 0.0;
        var stackedStartIndex = -1;

        calculatedLabelBreakPoints.clear();
        calculatedLabelSizes.clear();
        calculatedLineSizes.clear();

        for (var i = 0; i < entryCount; i++) {
          final e = entries[i];
          final drawingForm = e.form != LegendForm.NONE;
          final formSize = e.formSize.isNaN
              ? defaultFormSize
              : Utils.convertDpToPixel(e.formSize);
          final label = e.label;

          calculatedLabelBreakPoints.add(false);

          if (stackedStartIndex == -1) {
            requiredWidth = 0;
          } else {
            requiredWidth += stackSpace;
          }

          if (label != null) {
            calculatedLabelSizes.add(Utils.calcTextSize(labelPaint, label));
            requiredWidth += drawingForm ? formToTextSpace + formSize : 0;
            requiredWidth += calculatedLabelSizes[i].width;
          } else {
            calculatedLabelSizes.add(FSize.getInstance(0, 0));
            requiredWidth += drawingForm ? formSize : 0;
            if (stackedStartIndex == -1) stackedStartIndex = i;
          }

          if (label != null || i == entryCount - 1) {
            final requiredSpacing = currentLineWidth == 0 ? 0.0 : xEntrySpace;

            if (!wordWrapEnabled ||
                currentLineWidth == 0 ||
                contentWidth - currentLineWidth >=
                    requiredSpacing + requiredWidth) {
              currentLineWidth += requiredSpacing + requiredWidth;
            } else {
              calculatedLineSizes.add(
                FSize.getInstance(currentLineWidth, labelLineHeight),
              );
              maxLineWidth = math.max(maxLineWidth, currentLineWidth);
              calculatedLabelBreakPoints[stackedStartIndex > -1
                      ? stackedStartIndex
                      : i] =
                  true;
              currentLineWidth = requiredWidth;
            }

            if (i == entryCount - 1) {
              calculatedLineSizes.add(
                FSize.getInstance(currentLineWidth, labelLineHeight),
              );
              maxLineWidth = math.max(maxLineWidth, currentLineWidth);
            }
          }

          stackedStartIndex = label != null ? -1 : stackedStartIndex;
        }

        neededWidth = maxLineWidth;
        neededHeight =
            labelLineHeight +
            (labelLineHeight + labelLineSpacing) *
                (calculatedLineSizes.isEmpty
                    ? 0
                    : calculatedLineSizes.length - 1);
    }

    neededHeight += Utils.convertDpToPixel(yOffset);
    neededWidth += Utils.convertDpToPixel(xOffset);
  }
}
