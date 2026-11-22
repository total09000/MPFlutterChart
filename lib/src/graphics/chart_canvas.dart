// Android shim: android.graphics.Canvas drawing with a Paint for MPAndroidChart v4.0.1 port
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'chart_paint.dart';
import 'dash_path.dart';
import '../utils/utils.dart';
import 'mutable_rect.dart';
import 'text_measure.dart';

/// The effects of [_dashDevicePx] scaled to logical px, by the effect they were made from, with the ratio they were
/// made for.
final Expando<(double, DashPathEffect)> _logicalPxEffects = Expando();

/// Dashes [path] with [effect], whose lengths are device px as in Kotlin (Android hands `DashPathEffect` lengths to
/// the canvas in device px): the intervals and the phase are divided by [Utils.devicePixelRatio]. [effect] itself is
/// not changed; at a ratio of 1 it is used as it is.
ui.Path _dashDevicePx(ui.Path path, DashPathEffect effect) {
  final ratio = Utils.devicePixelRatio;
  if (ratio == 1.0 || !(ratio > 0) || !ratio.isFinite) {
    return dashPath(path, effect);
  }
  final cached = _logicalPxEffects[effect];
  var scaled = cached != null && cached.$1 == ratio ? cached.$2 : null;
  if (scaled == null) {
    scaled = DashPathEffect([
      for (final interval in effect.intervals) interval / ratio,
    ], effect.phase / ratio);
    _logicalPxEffects[effect] = (ratio, scaled);
  }
  return dashPath(path, scaled);
}

/// True if any of the four coordinates is NaN. Flutter's canvas asserts against NaN geometry in debug builds;
/// Skia draws nothing for it.
bool _hasNaN(double a, double b, double c, double d) =>
    a.isNaN || b.isNaN || c.isNaN || d.isNaN;

/// The `android.graphics.Canvas` calls of the renderers, drawing with a [ChartPaint].
///
/// [PaintStyle.FILL_AND_STROKE] draws a fill pass and then a stroke pass. A [ChartPaint.pathEffect] dashes lines
/// and strokes as Skia does; fills are never dashed. Its lengths are device px, as on Android: they are divided by
/// [Utils.devicePixelRatio] when the line is dashed. Android's `val n = c.save(); …; c.restoreToCount(n)` becomes
/// `final n = c.getSaveCount(); c.save(); …; c.restoreToCount(n)`.
///
/// A line, rectangle or circle with a NaN coordinate or radius, and text anchored at a NaN position, is not drawn:
/// Skia draws nothing for it, while Flutter's canvas asserts on it in debug builds. Infinite coordinates are drawn
/// as Flutter draws them. A circle with a radius of 0 or less is not drawn either, as Android's canvas does.
extension ChartCanvas on ui.Canvas {
  /// Draws [text] with its baseline at [y]; [ChartPaint.textAlign] says whether [x] is its left edge, center or
  /// right edge, like `Canvas.drawText(text, x, y, paint)`.
  ///
  /// The layout comes from [TextMeasure], so an unchanged label is not laid out again.
  void drawText(String text, double x, double y, ChartPaint paint) {
    if (text.isEmpty || x.isNaN || y.isNaN) return;
    final style = paint.style;

    TextPainter painter = TextMeasure.layout(text, paint.textStyle);
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final double left = switch (paint.textAlign) {
      PaintAlign.LEFT => x,
      PaintAlign.CENTER => x - painter.width / 2,
      PaintAlign.RIGHT => x - painter.width,
    };
    final offset = Offset(left, y - baseline);

    if (style != PaintStyle.STROKE) painter.paint(this, offset);
    if (style != PaintStyle.FILL) {
      painter = TextMeasure.layout(text, paint.textStrokeStyle);
      painter.paint(this, offset);
    }
  }

  /// Draws a line from ([x1], [y1]) to ([x2], [y2]), always stroked, like `Canvas.drawLine`.
  void drawLineP(double x1, double y1, double x2, double y2, ChartPaint paint) {
    if (_hasNaN(x1, y1, x2, y2)) return;
    final effect = paint.pathEffect;
    if (effect == null) {
      drawLine(Offset(x1, y1), Offset(x2, y2), paint.toPaint());
      return;
    }
    final path = ui.Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
    _drawStroked(_dashDevicePx(path, effect), paint.toPaint());
  }

  /// Draws [rect] in the style of [paint], like `Canvas.drawRect(RectF, Paint)`.
  void drawRectP(MutableRect rect, ChartPaint paint) {
    if (_hasNaN(rect.left, rect.top, rect.right, rect.bottom)) return;
    final r = rect.toRect();
    _shape(paint, () => ui.Path()..addRect(r), (p) => drawRect(r, p));
  }

  /// Draws a circle around ([cx], [cy]) with [radius] in the style of [paint], like `Canvas.drawCircle`.
  ///
  /// A [radius] of 0 or less draws nothing, as on Android, whose canvas returns early for it; Impeller, Flutter's
  /// renderer on Android and iOS, would stroke a dot as wide as the stroke there.
  void drawCircleP(double cx, double cy, double radius, ChartPaint paint) {
    if (cx.isNaN || cy.isNaN || radius.isNaN || radius <= 0) return;
    final center = Offset(cx, cy);
    _shape(
      paint,
      () => ui.Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      (p) => drawCircle(center, radius, p),
    );
  }

  /// Draws [path] in the style of [paint], its stroke dashed when [ChartPaint.pathEffect] is set, like
  /// `Canvas.drawPath`.
  void drawPathP(ui.Path path, ChartPaint paint) =>
      _shape(paint, () => path, (p) => drawPath(path, p));

  /// Draws [rect] with corners of radii [rx] and [ry] in the style of [paint], like `Canvas.drawRoundRect`.
  void drawRoundRectP(
    MutableRect rect,
    double rx,
    double ry,
    ChartPaint paint,
  ) {
    if (_hasNaN(rect.left, rect.top, rect.right, rect.bottom) ||
        rx.isNaN ||
        ry.isNaN) {
      return;
    }
    final rrect = RRect.fromLTRBXY(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      rx,
      ry,
    );
    _shape(paint, () => ui.Path()..addRRect(rrect), (p) => drawRRect(rrect, p));
  }

  /// Draws [count] floats of [pts] from [offset] as separate lines, four floats (x0, y0, x1, y1) per line, always
  /// stroked, like `Canvas.drawLines(pts, offset, count, paint)`. Floats past the last whole line are ignored. With
  /// a dash effect every line starts the pattern anew, as in Skia.
  void drawLinesP(Float32List pts, int offset, int count, ChartPaint paint) {
    final usable = count & ~3;
    if (usable < 4) return;
    final effect = paint.pathEffect;
    if (effect == null) {
      drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(pts, offset, offset + usable),
        paint.toPaint(),
      );
      return;
    }
    final path = ui.Path();
    for (var i = offset; i < offset + usable; i += 4) {
      path
        ..moveTo(pts[i], pts[i + 1])
        ..lineTo(pts[i + 2], pts[i + 3]);
    }
    _drawStroked(_dashDevicePx(path, effect), paint.toPaint());
  }

  /// Fills the clip with [color] blended source over, like `Canvas.drawColor(int)`.
  void drawColorP(Color color) => drawColor(color, BlendMode.srcOver);

  /// Intersects the clip with [rect], without antialiasing like Android's rectangle clip, like
  /// `Canvas.clipRect(RectF)`.
  void clipRectM(MutableRect rect) =>
      clipRect(rect.toRect(), doAntiAlias: false);

  /// The number of saved states on the stack, like `Canvas.getSaveCount()`.
  int saveCount() => getSaveCount();

  /// Draws a fill-capable shape in the style of [paint]: [plain] draws it with a `ui.Paint`, [outline] gives it as a
  /// path to dash.
  ///
  /// As in Skia, a dash effect applies to strokes only: a [PaintStyle.FILL] shape is filled whole, and a
  /// [PaintStyle.FILL_AND_STROKE] shape is filled whole and then stroked dashed.
  void _shape(
    ChartPaint paint,
    ui.Path Function() outline,
    void Function(ui.Paint p) plain,
  ) {
    final effect = paint.pathEffect;
    if (effect == null || paint.style == PaintStyle.FILL) {
      _styled(paint, plain);
      return;
    }
    final p = paint.toPaint();
    if (paint.style == PaintStyle.FILL_AND_STROKE) {
      p.style = PaintingStyle.fill;
      plain(p);
    }
    _drawStroked(_dashDevicePx(outline(), effect), p);
  }

  /// Draws a path that is always stroked (lines), whatever the style of [p].
  void _drawStroked(ui.Path path, ui.Paint p) {
    final style = p.style;
    p.style = PaintingStyle.stroke;
    drawPath(path, p);
    p.style = style;
  }

  /// Runs [draw] with the paint of [paint], twice for [PaintStyle.FILL_AND_STROKE]: filled, then stroked.
  void _styled(ChartPaint paint, void Function(ui.Paint p) draw) {
    final p = paint.toPaint();
    draw(p);
    if (paint.style == PaintStyle.FILL_AND_STROKE) {
      p.style = PaintingStyle.stroke;
      draw(p);
      p.style = PaintingStyle.fill;
    }
  }
}
