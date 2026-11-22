// A RecordingCanvas that fails like Flutter's debug-mode canvas on geometry with a NaN in it.
//
// Skia draws nothing for such geometry, which is what MPAndroidChart relies on; Flutter's `Canvas` asserts
// `!hasNaN` first and throws in debug builds. A renderer test drawing on this canvas fails with a [StateError] at
// the first NaN rectangle, rounded rectangle, circle, line, path, paragraph offset or clip, so a renderer has to
// leave such shapes out itself (ruling A11).
import 'dart:ui' as ui;

import '../../recording/recording_canvas.dart';

/// A [RecordingCanvas] that throws a [StateError] for any draw or clip whose geometry has a NaN, and records it like
/// [RecordingCanvas] otherwise. Infinite coordinates are accepted, as Flutter accepts them.
///
/// Paths are checked through [ui.Path.getBounds]. The engine reports the bounds of a path with a non-finite point
/// as empty, so a NaN that reached a path through `moveTo` / `lineTo` passes; `Path.addRect` and `Path.addRRect`
/// assert on NaN themselves.
class StrictCanvas extends RecordingCanvas {
  static void _check(bool hasNaN, String call, Object geometry) {
    if (hasNaN) throw StateError('$call with NaN geometry: $geometry');
  }

  static bool _offsetHasNaN(ui.Offset o) => o.dx.isNaN || o.dy.isNaN;

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    _check(rect.hasNaN, 'drawRect', rect);
    super.drawRect(rect, paint);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    _check(rrect.hasNaN, 'drawRRect', rrect);
    super.drawRRect(rrect, paint);
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    _check(_offsetHasNaN(c) || radius.isNaN, 'drawCircle', (c, radius));
    super.drawCircle(c, radius, paint);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    _check(_offsetHasNaN(p1) || _offsetHasNaN(p2), 'drawLine', (p1, p2));
    super.drawLine(p1, p2, paint);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    final bounds = path.getBounds();
    _check(bounds.hasNaN, 'drawPath', bounds);
    super.drawPath(path, paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    _check(_offsetHasNaN(offset), 'drawParagraph', offset);
    super.drawParagraph(paragraph, offset);
  }

  @override
  void clipRect(
    ui.Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    _check(rect.hasNaN, 'clipRect', rect);
    super.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    final bounds = path.getBounds();
    _check(bounds.hasNaN, 'clipPath', bounds);
    super.clipPath(path, doAntiAlias: doAntiAlias);
  }
}
