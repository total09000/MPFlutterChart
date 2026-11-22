// Ported from MPAndroidChart v4.0.1: MPChartLib/src/main/kotlin/com/github/mikephil/charting/components/LegendEntry.kt
import 'dart:ui';

import '../graphics/chart_paint.dart';
import '../utils/color_template.dart';
import 'legend_form.dart';

/// One entry of a `Legend`: a form followed by a label. NaN sizes and a null dash effect fall back to the legend's
/// values.
///
/// Kotlin's constructor parameters all have defaults and may be passed by name; Dart cannot offer both positional and
/// named optional parameters, so they are optional positional in Kotlin's order:
/// `LegendEntry(label, form, formSize, formLineWidth, formLineDashEffect, formColor)`. Set the others afterwards
/// (`LegendEntry('Sales')..formColor = color`).
class LegendEntry {
  /// The text, or null to draw only the form, stacked with the next entry.
  String? label;

  /// The shape drawn in front of the label; [LegendForm.DEFAULT] uses the legend's `Legend.form`.
  LegendForm form;

  /// Size of the form in dp, or NaN for the legend's `Legend.formSize`.
  double formSize;

  /// Stroke width in dp of a line form, or NaN for the legend's `Legend.formLineWidth`.
  double formLineWidth;

  /// Dash pattern of a line form, or null for the legend's `Legend.formLineDashEffect`.
  DashPathEffect? formLineDashEffect;

  /// Color of the form; [ColorTemplate.COLOR_NONE], [ColorTemplate.COLOR_SKIP] and 0 draw no form.
  Color formColor;

  /// Creates an entry; every argument is optional.
  LegendEntry([
    this.label,
    this.form = LegendForm.DEFAULT,
    this.formSize = double.nan,
    this.formLineWidth = double.nan,
    this.formLineDashEffect,
    this.formColor = ColorTemplate.COLOR_NONE,
  ]);
}
