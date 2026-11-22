// A canvas that draws a core chart in a test the way Flutter's debug canvas does, and records what it drew.
//
// The package's test/unit/support/strict_canvas.dart is not importable from the example's tests, so this is the
// example's version: every call goes on to a real `ui.Canvas`, whose debug asserts reject NaN geometry, and a draw or
// clip with a NaN in it throws a StateError first, naming the call. A canvas call it does not forward throws an
// UnimplementedError, so a chart that starts using a new one fails loudly instead of drawing nothing.
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A rounded rectangle drawn with [color].
typedef RRectDraw = ({ui.RRect rrect, ui.Color color});

/// A circle drawn with [color].
typedef CircleDraw = ({ui.Offset center, double radius, ui.Color color});

/// A [ui.Canvas] that throws a [StateError] on NaN geometry and records the shapes and text it draws.
class StrictCanvas implements ui.Canvas {
  final ui.PictureRecorder _recorder = ui.PictureRecorder();
  late final ui.Canvas _canvas = ui.Canvas(_recorder);

  /// Every `drawRRect`, in order.
  final List<RRectDraw> rrects = [];

  /// Every `drawCircle`, in order.
  final List<CircleDraw> circles = [];

  /// The offset of every `drawParagraph`, in order.
  final List<ui.Offset> paragraphs = [];

  /// Every `drawRect`, `drawPath`, `drawLine` and `drawRawPoints`, by method name.
  final Map<String, int> otherDraws = {};

  /// Ends the recording and frees the picture.
  void dispose() => _recorder.endRecording().dispose();

  static void _check(bool hasNaN, String call, Object geometry) {
    if (hasNaN) throw StateError('$call with NaN geometry: $geometry');
  }

  static bool _nan(ui.Offset o) => o.dx.isNaN || o.dy.isNaN;

  void _count(String call) => otherDraws[call] = (otherDraws[call] ?? 0) + 1;

  @override
  void save() => _canvas.save();

  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    if (bounds != null) _check(bounds.hasNaN, 'saveLayer', bounds);
    _canvas.saveLayer(bounds, paint);
  }

  @override
  void restore() => _canvas.restore();

  @override
  void restoreToCount(int count) => _canvas.restoreToCount(count);

  @override
  int getSaveCount() => _canvas.getSaveCount();

  @override
  void translate(double dx, double dy) {
    _check(dx.isNaN || dy.isNaN, 'translate', (dx, dy));
    _canvas.translate(dx, dy);
  }

  @override
  void scale(double sx, [double? sy]) => _canvas.scale(sx, sy);

  @override
  void rotate(double radians) => _canvas.rotate(radians);

  @override
  void transform(Float64List matrix4) => _canvas.transform(matrix4);

  @override
  void clipRect(
    ui.Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    _check(rect.hasNaN, 'clipRect', rect);
    _canvas.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) {
    _check(rrect.hasNaN, 'clipRRect', rrect);
    _canvas.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    _check(path.getBounds().hasNaN, 'clipPath', path.getBounds());
    _canvas.clipPath(path, doAntiAlias: doAntiAlias);
  }

  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) =>
      _canvas.drawColor(color, blendMode);

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    _check(_nan(p1) || _nan(p2), 'drawLine', (p1, p2));
    _count('drawLine');
    _canvas.drawLine(p1, p2, paint);
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    _check(rect.hasNaN, 'drawRect', rect);
    _count('drawRect');
    _canvas.drawRect(rect, paint);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    _check(rrect.hasNaN, 'drawRRect', rrect);
    rrects.add((rrect: rrect, color: paint.color));
    _canvas.drawRRect(rrect, paint);
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    _check(_nan(c) || radius.isNaN, 'drawCircle', (c, radius));
    circles.add((center: c, radius: radius, color: paint.color));
    _canvas.drawCircle(c, radius, paint);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    _check(path.getBounds().hasNaN, 'drawPath', path.getBounds());
    _count('drawPath');
    _canvas.drawPath(path, paint);
  }

  @override
  void drawRawPoints(
    ui.PointMode pointMode,
    Float32List points,
    ui.Paint paint,
  ) {
    _check(points.any((v) => v.isNaN), 'drawRawPoints', points);
    _count('drawRawPoints');
    _canvas.drawRawPoints(pointMode, points, paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    _check(_nan(offset), 'drawParagraph', offset);
    paragraphs.add(offset);
    _canvas.drawParagraph(paragraph, offset);
  }

  @override
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    _check(dst.hasNaN, 'drawImageRect', dst);
    _canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'StrictCanvas does not forward ${invocation.memberName}',
  );
}
