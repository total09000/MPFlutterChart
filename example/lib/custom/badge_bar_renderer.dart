// Ported from MPChartExample: custom/BadgeBarRenderer.kt
import 'dart:ui' as ui;

import 'package:mp_flutter_chart/core.dart';

/// Draws every bar value on a rounded badge. Only [drawValue] is replaced, so the bars, the stacked case, the icons
/// and the bounds checks stay as the built-in renderer does them.
class BadgeBarRenderer extends BarChartRenderer {
  BadgeBarRenderer(super.chart, super.animator, super.viewPortHandler, ui.Color badgeColor)
    : _badgePaint = ChartPaint()..color = badgeColor;

  final ChartPaint _badgePaint;

  final MutableRect _badge = MutableRect();

  @override
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
    final text = formatter.getFormattedValue(value, entry, dataSetIndex, viewPortHandler);
    final padding = Utils.convertDpToPixel(5);
    final halfWidth = paintValues.measureText(text) / 2 + padding;

    _badge.set(x - halfWidth, y - paintValues.textSize - padding / 2, x + halfWidth, y + padding / 2);
    final radius = _badge.height() / 2;
    c.drawRoundRectP(_badge, radius, radius, _badgePaint);

    super.drawValue(c, formatter, value, entry, dataSetIndex, x, y, color);
  }
}
