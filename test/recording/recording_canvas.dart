// Test shim standing in for the device tests' RecordingCanvas (MPChartDeviceTest, an android.graphics.Canvas
// subclass): a ui.Canvas that records the draw calls of the renderers instead of painting, so tests can assert on
// what was drawn without pixels.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextStyle;
import 'package:mp_flutter_chart/src/graphics/text_measure.dart';

/// The parts of a [ui.Paint] the tests assert on, copied when the call is recorded: renderers reuse and change their
/// paints, so keeping the paint itself would show the values of the last draw, not of this one.
class PaintSnapshot {
  PaintSnapshot.of(ui.Paint p)
    : color = p.color,
      style = p.style,
      strokeWidth = p.strokeWidth,
      blendMode = p.blendMode,
      isAntiAlias = p.isAntiAlias,
      hasShader = p.shader != null,
      strokeCap = p.strokeCap;

  final ui.Color color;
  final ui.PaintingStyle style;
  final double strokeWidth;
  final ui.BlendMode blendMode;
  final bool isAntiAlias;

  /// Whether the paint had a shader (a gradient fill), whatever it was.
  final bool hasShader;
  final ui.StrokeCap strokeCap;

  @override
  String toString() =>
      'PaintSnapshot($color, $style, $strokeWidth, $blendMode, antiAlias: $isAntiAlias, shader: $hasShader, '
      '$strokeCap)';
}

/// One recorded call that has a typed record, in [RecordingCanvas.records].
abstract class CanvasRecord {
  /// [saveCount] defaults to 1, the save count of a new canvas, for records built by hand (in a test, say);
  /// [RecordingCanvas] always passes its current count.
  CanvasRecord({this.saveCount = 1});

  /// The name of the canvas method, as it appears in [RecordingCanvas.calls].
  String get method;

  /// [RecordingCanvas.getSaveCount] when the call was recorded. For `saveLayer` it is the count before the layer was
  /// pushed, the value a matching `restoreToCount` takes.
  final int saveCount;
}

/// One circle a renderer drew: its center, radius and the color and style of its paint.
class CircleDraw extends CanvasRecord {
  CircleDraw(
    this.x,
    this.y,
    this.radius,
    this.color,
    this.style,
    this.paint, {
    super.saveCount,
  });

  final double x;
  final double y;
  final double radius;
  final ui.Color color;
  final ui.PaintingStyle style;
  final PaintSnapshot paint;

  @override
  String get method => 'drawCircle';

  @override
  String toString() => 'CircleDraw($x, $y, r: $radius, $color, $style)';
}

/// One path a renderer drew, with the bounds it had at the time and the paint's color and style.
class PathDraw extends CanvasRecord {
  PathDraw(
    this.bounds,
    this.color,
    this.style,
    this.strokeWidth,
    this.fillType,
    this.paint, {
    super.saveCount,
  });

  final ui.Rect bounds;
  final ui.PathFillType fillType;
  final ui.Color color;
  final ui.PaintingStyle style;
  final double strokeWidth;
  final PaintSnapshot paint;

  @override
  String get method => 'drawPath';
}

/// One `drawRawPoints` call: the point mode, a copy of the floats and the paint's color.
class RawPointsDraw extends CanvasRecord {
  RawPointsDraw(
    this.mode,
    this.points,
    this.color,
    this.paint, {
    super.saveCount,
  });

  final ui.PointMode mode;
  final Float32List points;
  final ui.Color color;
  final PaintSnapshot paint;

  @override
  String get method => 'drawRawPoints';
}

/// One `drawLine` call: its end points and the paint's color and stroke width.
class LineDraw extends CanvasRecord {
  LineDraw(
    this.p1,
    this.p2,
    this.color,
    this.strokeWidth,
    this.paint, {
    super.saveCount,
  });

  final ui.Offset p1;
  final ui.Offset p2;
  final ui.Color color;
  final double strokeWidth;
  final PaintSnapshot paint;

  @override
  String get method => 'drawLine';

  @override
  String toString() => 'LineDraw($p1, $p2, $color, $strokeWidth)';
}

/// One rectangle a renderer drew and the paint's color.
class RectDraw extends CanvasRecord {
  RectDraw(this.rect, this.color, this.paint, {super.saveCount});

  final ui.Rect rect;
  final ui.Color color;
  final PaintSnapshot paint;

  /// The paint's style: a hollow candle body is a stroked rectangle.
  ui.PaintingStyle get style => paint.style;

  /// The paint's stroke width.
  double get strokeWidth => paint.strokeWidth;

  @override
  String get method => 'drawRect';
}

/// One paragraph (text drawn through a TextPainter) and where it was drawn.
///
/// [offset] is the argument of `drawParagraph`, in the coordinates of the current transform; [deviceOffset] is that
/// point through the transform ([RecordingCanvas.toDevice]). Which text the paragraph holds is asked of the canvas:
/// see [RecordingCanvas.paragraphsWithText].
class ParagraphDraw extends CanvasRecord {
  ParagraphDraw(
    this.offset,
    this.width,
    this.paragraph,
    this.deviceOffset,
    this.height, {
    super.saveCount,
  });

  final ui.Offset offset;

  /// [ui.Paragraph.width], the width the paragraph was laid out with, not the width of its text: `double.infinity`
  /// for a label laid out without a max width (`ChartCanvas.drawText`), the max width for text laid out with one
  /// (`Utils.drawMultilineText`). For the text's own width ask `TextMeasure.layout(...).width`.
  final double width;

  /// The paragraph that was drawn (the instance, which the text queries compare by identity).
  final ui.Paragraph paragraph;
  final ui.Offset deviceOffset;
  final double height;

  @override
  String get method => 'drawParagraph';
}

/// One `drawArc` call: the oval's bounds, the angles in radians, whether the center is included, and the paint.
class ArcDraw extends CanvasRecord {
  ArcDraw(
    this.rect,
    this.startAngle,
    this.sweepAngle,
    this.useCenter,
    this.paint, {
    super.saveCount,
  });

  final ui.Rect rect;
  final double startAngle;
  final double sweepAngle;
  final bool useCenter;
  final PaintSnapshot paint;

  @override
  String get method => 'drawArc';
}

/// One `drawRRect` call: the rounded rectangle and the paint.
class RRectDraw extends CanvasRecord {
  RRectDraw(this.rrect, this.paint, {super.saveCount});

  final ui.RRect rrect;
  final PaintSnapshot paint;

  /// The paint's color.
  ui.Color get color => paint.color;

  @override
  String get method => 'drawRRect';
}

/// One `drawOval` call: the bounds of the oval and the paint.
class OvalDraw extends CanvasRecord {
  OvalDraw(this.rect, this.paint, {super.saveCount});

  final ui.Rect rect;
  final PaintSnapshot paint;

  @override
  String get method => 'drawOval';
}

/// One `saveLayer` call: the bounds (null for an unbounded layer) and the paint the layer is composited with.
class LayerDraw extends CanvasRecord {
  LayerDraw(this.bounds, this.paint, {super.saveCount});

  final ui.Rect? bounds;
  final PaintSnapshot paint;

  /// The blend mode the layer is composited with.
  ui.BlendMode get blendMode => paint.blendMode;

  /// The opacity the layer is composited with, 0 to 255 like `Paint.getAlpha()`.
  int get alpha => (paint.color.a * 255).round();

  @override
  String get method => 'saveLayer';
}

/// The shape a [ClipDraw] clipped to.
enum ClipKind { rect, rrect, path }

/// One `clipRect`, `clipRRect` or `clipPath` call. [bounds] is the rectangle, the rounded rectangle's outer rect or
/// the path's bounds; `clipRRect` and `clipPath` have no clip op and record [ui.ClipOp.intersect].
class ClipDraw extends CanvasRecord {
  ClipDraw(
    this.kind,
    this.bounds,
    this.clipOp,
    this.doAntiAlias, {
    super.saveCount,
  });

  final ClipKind kind;
  final ui.Rect bounds;
  final ui.ClipOp clipOp;
  final bool doAntiAlias;

  @override
  String get method => switch (kind) {
    ClipKind.rect => 'clipRect',
    ClipKind.rrect => 'clipRRect',
    ClipKind.path => 'clipPath',
  };
}

/// The canvas method of a [TransformDraw].
enum TransformKind { translate, scale, rotate, skew, transform }

/// One call that changed the transform, with its arguments: `[dx, dy]` for translate, `[sx, sy]` for scale (`sy` is
/// `sx` when it was omitted), `[radians]` for rotate, `[sx, sy]` for skew and the 16 values (column-major) for
/// transform.
class TransformDraw extends CanvasRecord {
  TransformDraw(this.kind, this.values, {super.saveCount});

  final TransformKind kind;
  final List<double> values;

  @override
  String get method => kind.name;
}

/// A [ui.Canvas] that records calls instead of painting. Counters and argument lists are public; the save stack is
/// tracked so `getSaveCount` / `restoreToCount` behave like a real canvas, and so is the transform (2D affine), so
/// [toDevice] and `getTransform` give where a point lands. Methods it does not record throw.
///
/// Each call that has a typed record is kept in its own list ([circles], [rects], [arcs], ...) and, in call order, in
/// [records]; [calls] has the names of every recorded call, including `save` and `restore`.
class RecordingCanvas implements ui.Canvas {
  int _saveCount = 1;

  // The current transform, device = (a·x + c·y + tx, b·x + d·y + ty), and the ones `save` / `saveLayer` pushed
  // (always _saveCount - 1 of them).
  double _a = 1;
  double _b = 0;
  double _c = 0;
  double _d = 1;
  double _tx = 0;
  double _ty = 0;
  final List<(double, double, double, double, double, double)>
  _savedTransforms = [];

  /// Every recorded call, by method name, in order.
  final List<String> calls = [];

  /// Every call that has a typed record, in order: the entries of the typed lists below. Not in it: `save`,
  /// `restore`, `restoreToCount`, `drawPicture` and the image draws, which only have their counters, and `drawColor`,
  /// whose colors are in [colors].
  final List<CanvasRecord> records = [];

  final List<CircleDraw> circles = [];
  final List<LineDraw> lines = [];
  final List<PathDraw> paths = [];
  final List<RawPointsDraw> rawPoints = [];
  final List<RectDraw> rects = [];
  final List<ParagraphDraw> paragraphs = [];
  final List<ui.Color> colors = [];
  final List<ui.Rect> clipRects = [];
  final List<ui.Path> clipPaths = [];
  final List<ArcDraw> arcs = [];
  final List<RRectDraw> rrects = [];
  final List<OvalDraw> ovals = [];
  final List<LayerDraw> layers = [];

  /// `clipRect`, `clipRRect` and `clipPath` calls together, in order.
  final List<ClipDraw> clips = [];

  /// `translate`, `scale`, `rotate`, `skew` and `transform` calls together, in order.
  final List<TransformDraw> transforms = [];

  int drawPictureCalls = 0;
  int translateCalls = 0;
  int rotateCalls = 0;

  /// `save` calls; `saveLayer` is not counted here (see [saveLayerCalls]).
  int saveCalls = 0;

  /// `restore` calls, plus each level that a `restoreToCount` call popped.
  int restoreCalls = 0;

  /// `drawImage`, `drawImageRect`, `drawImageNine`, `drawAtlas` and `drawRawAtlas` calls together.
  int drawImageCalls = 0;

  int get drawLineCalls => lines.length;
  int get drawPathCalls => paths.length;
  int get drawCircleCalls => circles.length;
  int get drawRawPointsCalls => rawPoints.length;
  int get drawRectCalls => rects.length;
  int get drawParagraphCalls => paragraphs.length;
  int get drawColorCalls => colors.length;
  int get drawRRectCalls => rrects.length;
  int get drawArcCalls => arcs.length;
  int get drawOvalCalls => ovals.length;
  int get saveLayerCalls => layers.length;
  int get clipCalls => clips.length;

  /// The number of calls of [method] (a name as in [calls], such as `'drawRect'` or `'save'`).
  ///
  /// It counts the direct calls of that method by name, so it can differ from the older counters: [restoreCalls]
  /// also counts each level popped by `restoreToCount` (where `count('restoreToCount')` counts the call once),
  /// [saveCalls] leaves out `saveLayer` (as does `count('save')`), and [drawImageCalls] sums the five image methods
  /// (`count('drawImage')` is `drawImage` alone).
  int count(String method) {
    var n = 0;
    for (final name in calls) {
      if (name == method) n++;
    }
    return n;
  }

  /// The number of calls of each method in [calls], in the order of their first call: [count] for every method
  /// called, with the same differences from the older counters.
  Map<String, int> get callCounts {
    final counts = <String, int>{};
    for (final name in calls) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  /// The records of type [T], in call order.
  List<T> recordsOf<T extends CanvasRecord>() =>
      records.whereType<T>().toList();

  /// The number of records of type [T].
  int countOf<T extends CanvasRecord>() => records.whereType<T>().length;

  /// The records of type [T] that pass [test], in call order.
  List<T> where<T extends CanvasRecord>(bool Function(T r) test) => [
    for (final r in records)
      if (r is T && test(r)) r,
  ];

  /// Where [local], in the coordinates of the current transform, lands on the device (the canvas origin).
  ui.Offset toDevice(ui.Offset local) => ui.Offset(
    _a * local.dx + _c * local.dy + _tx,
    _b * local.dx + _d * local.dy + _ty,
  );

  /// The [paragraphs] that show [text] laid out in [style] (and [maxWidth] / [maxLines]), in call order.
  ///
  /// A [ui.Paragraph] cannot give its text back, so this asks [TextMeasure.layout] for the cached layout of [text]
  /// and keeps the paragraphs that are that layout's paragraph instance: a cached `TextPainter` paints the same
  /// paragraph every time. So:
  ///
  /// * Query right after drawing. `TextMeasure.clearCache()`, or [TextMeasure.maxEntries] other texts laid out
  ///   since the draw, evicts the layout; the query then lays the text out again and finds nothing. A text that was
  ///   never drawn is laid out (and cached) by the query.
  /// * Pass the style and the layout arguments the drawing code used. Text drawn with `PaintStyle.STROKE` (and the
  ///   second pass of `PaintStyle.FILL_AND_STROKE`) is laid out in `ChartPaint.textStrokeStyle`, not
  ///   `ChartPaint.textStyle`. `Utils.drawMultilineText` lays out with `maxWidth: ceil(constrainedToSize.width)`.
  /// * `Utils.drawMultilineText` translates the canvas and paints at the origin: its paragraph's
  ///   [ParagraphDraw.offset] is `Offset.zero` and its position is [ParagraphDraw.deviceOffset].
  List<ParagraphDraw> paragraphsWithText(
    String text,
    TextStyle style, {
    double? maxWidth,
    int? maxLines,
  }) {
    final target = _paragraphOf(text, style, maxWidth, maxLines);
    if (target == null) return [];
    return [
      for (final draw in paragraphs)
        if (identical(draw.paragraph, target)) draw,
    ];
  }

  /// Whether [text] in [style] was drawn; see [paragraphsWithText] for when the answer holds.
  bool drewText(
    String text,
    TextStyle style, {
    double? maxWidth,
    int? maxLines,
  }) => paragraphsWithText(
    text,
    style,
    maxWidth: maxWidth,
    maxLines: maxLines,
  ).isNotEmpty;

  /// For each of the [paragraphs], in order, the one of [candidates] it shows in [style] (and [maxWidth] /
  /// [maxLines]), or null when it shows none of them; see [paragraphsWithText] for when the answer holds.
  ///
  /// Each candidate is laid out through [TextMeasure.layout], in order, and so counts toward
  /// [TextMeasure.maxEntries]: candidates that were never drawn are new layouts in the cache. With enough of them
  /// ahead of a drawn label to push the cache past [TextMeasure.maxEntries] (512 when the label was the last text
  /// laid out), that label's layout is evicted before it is looked up, and its paragraphs come back `null`.
  List<String?> textsOf(
    Iterable<String> candidates,
    TextStyle style, {
    double? maxWidth,
    int? maxLines,
  }) {
    final textByParagraph = Map<ui.Paragraph, String>.identity();
    for (final text in candidates) {
      final paragraph = _paragraphOf(text, style, maxWidth, maxLines);
      if (paragraph != null) textByParagraph.putIfAbsent(paragraph, () => text);
    }
    return [for (final draw in paragraphs) textByParagraph[draw.paragraph]];
  }

  /// The paragraph the cached layout of [text] paints.
  static ui.Paragraph? _paragraphOf(
    String text,
    TextStyle style,
    double? maxWidth,
    int? maxLines,
  ) {
    final probe = _ParagraphProbe();
    TextMeasure.layout(
      text,
      style,
      maxWidth: maxWidth,
      maxLines: maxLines,
    ).paint(probe, ui.Offset.zero);
    return probe.paragraph;
  }

  void _record(String name) => calls.add(name);

  /// Post-multiplies the current transform by (a, b, c, d, tx, ty), as every canvas transform call does.
  void _concat(double a, double b, double c, double d, double tx, double ty) {
    final na = _a * a + _c * b;
    final nb = _b * a + _d * b;
    final nc = _a * c + _c * d;
    final nd = _b * c + _d * d;
    _tx += _a * tx + _c * ty;
    _ty += _b * tx + _d * ty;
    _a = na;
    _b = nb;
    _c = nc;
    _d = nd;
  }

  void _recordTransform(TransformKind kind, List<double> values) {
    final draw = TransformDraw(kind, values, saveCount: _saveCount);
    transforms.add(draw);
    records.add(draw);
  }

  void _pushTransform() => _savedTransforms.add((_a, _b, _c, _d, _tx, _ty));

  void _popTransform() {
    final (a, b, c, d, tx, ty) = _savedTransforms.removeLast();
    _a = a;
    _b = b;
    _c = c;
    _d = d;
    _tx = tx;
    _ty = ty;
  }

  @override
  void save() {
    _record('save');
    saveCalls++;
    _saveCount++;
    _pushTransform();
  }

  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    _record('saveLayer');
    final draw = LayerDraw(
      bounds,
      PaintSnapshot.of(paint),
      saveCount: _saveCount,
    );
    layers.add(draw);
    records.add(draw);
    _saveCount++;
    _pushTransform();
  }

  @override
  void restore() {
    _record('restore');
    restoreCalls++;
    if (_saveCount > 1) {
      _saveCount--;
      _popTransform();
    }
  }

  @override
  void restoreToCount(int count) {
    _record('restoreToCount');
    while (_saveCount > count && _saveCount > 1) {
      _saveCount--;
      _popTransform();
      restoreCalls++;
    }
  }

  @override
  int getSaveCount() => _saveCount;

  @override
  void translate(double dx, double dy) {
    _record('translate');
    translateCalls++;
    _recordTransform(TransformKind.translate, [dx, dy]);
    _concat(1, 0, 0, 1, dx, dy);
  }

  @override
  void rotate(double radians) {
    _record('rotate');
    rotateCalls++;
    _recordTransform(TransformKind.rotate, [radians]);
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    _concat(cos, sin, -sin, cos, 0, 0);
  }

  @override
  void scale(double sx, [double? sy]) {
    _record('scale');
    final y = sy ?? sx;
    _recordTransform(TransformKind.scale, [sx, y]);
    _concat(sx, 0, 0, y, 0, 0);
  }

  @override
  void skew(double sx, double sy) {
    _record('skew');
    _recordTransform(TransformKind.skew, [sx, sy]);
    _concat(1, sy, sx, 1, 0, 0);
  }

  /// Applies the 2D affine part of [matrix4] (x' = m0·x + m4·y + m12, y' = m1·x + m5·y + m13); its z and
  /// perspective entries are dropped. All 16 values are recorded.
  @override
  void transform(Float64List matrix4) {
    if (matrix4.length != 16) {
      throw ArgumentError('"matrix4" must have 16 entries.');
    }
    _record('transform');
    _recordTransform(TransformKind.transform, Float64List.fromList(matrix4));
    _concat(
      matrix4[0],
      matrix4[1],
      matrix4[4],
      matrix4[5],
      matrix4[12],
      matrix4[13],
    );
  }

  /// The current transform as a 4×4 matrix in column-major order (2D affine: z is left unchanged).
  @override
  Float64List getTransform() => Float64List.fromList([
    _a, _b, 0, 0, //
    _c, _d, 0, 0, //
    0, 0, 1, 0, //
    _tx, _ty, 0, 1, //
  ]);

  @override
  void clipRect(
    ui.Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    _record('clipRect');
    clipRects.add(rect);
    _recordClip(ClipKind.rect, rect, clipOp, doAntiAlias);
  }

  @override
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) {
    _record('clipRRect');
    _recordClip(
      ClipKind.rrect,
      rrect.outerRect,
      ui.ClipOp.intersect,
      doAntiAlias,
    );
  }

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    _record('clipPath');
    clipPaths.add(path);
    _recordClip(
      ClipKind.path,
      path.getBounds(),
      ui.ClipOp.intersect,
      doAntiAlias,
    );
  }

  void _recordClip(
    ClipKind kind,
    ui.Rect bounds,
    ui.ClipOp clipOp,
    bool doAntiAlias,
  ) {
    final draw = ClipDraw(
      kind,
      bounds,
      clipOp,
      doAntiAlias,
      saveCount: _saveCount,
    );
    clips.add(draw);
    records.add(draw);
  }

  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    _record('drawColor');
    colors.add(color);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    _record('drawLine');
    final snapshot = PaintSnapshot.of(paint);
    final draw = LineDraw(
      p1,
      p2,
      snapshot.color,
      snapshot.strokeWidth,
      snapshot,
      saveCount: _saveCount,
    );
    lines.add(draw);
    records.add(draw);
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    _record('drawRect');
    final snapshot = PaintSnapshot.of(paint);
    final draw = RectDraw(
      rect,
      snapshot.color,
      snapshot,
      saveCount: _saveCount,
    );
    rects.add(draw);
    records.add(draw);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    _record('drawRRect');
    final draw = RRectDraw(
      rrect,
      PaintSnapshot.of(paint),
      saveCount: _saveCount,
    );
    rrects.add(draw);
    records.add(draw);
  }

  @override
  void drawOval(ui.Rect rect, ui.Paint paint) {
    _record('drawOval');
    final draw = OvalDraw(rect, PaintSnapshot.of(paint), saveCount: _saveCount);
    ovals.add(draw);
    records.add(draw);
  }

  @override
  void drawArc(
    ui.Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    ui.Paint paint,
  ) {
    _record('drawArc');
    final draw = ArcDraw(
      rect,
      startAngle,
      sweepAngle,
      useCenter,
      PaintSnapshot.of(paint),
      saveCount: _saveCount,
    );
    arcs.add(draw);
    records.add(draw);
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    _record('drawCircle');
    final snapshot = PaintSnapshot.of(paint);
    final draw = CircleDraw(
      c.dx,
      c.dy,
      radius,
      snapshot.color,
      snapshot.style,
      snapshot,
      saveCount: _saveCount,
    );
    circles.add(draw);
    records.add(draw);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    _record('drawPath');
    final snapshot = PaintSnapshot.of(paint);
    final draw = PathDraw(
      path.getBounds(),
      snapshot.color,
      snapshot.style,
      snapshot.strokeWidth,
      path.fillType,
      snapshot,
      saveCount: _saveCount,
    );
    paths.add(draw);
    records.add(draw);
  }

  @override
  void drawRawPoints(
    ui.PointMode pointMode,
    Float32List points,
    ui.Paint paint,
  ) {
    _record('drawRawPoints');
    final snapshot = PaintSnapshot.of(paint);
    final draw = RawPointsDraw(
      pointMode,
      Float32List.fromList(points),
      snapshot.color,
      snapshot,
      saveCount: _saveCount,
    );
    rawPoints.add(draw);
    records.add(draw);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    _record('drawParagraph');
    final draw = ParagraphDraw(
      offset,
      paragraph.width,
      paragraph,
      toDevice(offset),
      paragraph.height,
      saveCount: _saveCount,
    );
    paragraphs.add(draw);
    records.add(draw);
  }

  @override
  void drawPicture(ui.Picture picture) {
    _record('drawPicture');
    drawPictureCalls++;
  }

  @override
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) {
    _record('drawImage');
    drawImageCalls++;
  }

  @override
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    _record('drawImageRect');
    drawImageCalls++;
  }

  @override
  void drawImageNine(
    ui.Image image,
    ui.Rect center,
    ui.Rect dst,
    ui.Paint paint,
  ) {
    _record('drawImageNine');
    drawImageCalls++;
  }

  @override
  void drawAtlas(
    ui.Image atlas,
    List<ui.RSTransform> transforms,
    List<ui.Rect> rects,
    List<ui.Color>? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    _record('drawAtlas');
    drawImageCalls++;
  }

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    _record('drawRawAtlas');
    drawImageCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'RecordingCanvas does not record ${invocation.memberName}',
  );
}

/// The canvas the text queries paint a cached layout on to learn its paragraph instance (`TextPainter.paint` calls
/// `drawParagraph`); every other call, such as the boxes of `debugPaintTextLayoutBoxes`, is ignored.
class _ParagraphProbe implements ui.Canvas {
  ui.Paragraph? paragraph;

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    this.paragraph ??= paragraph;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
