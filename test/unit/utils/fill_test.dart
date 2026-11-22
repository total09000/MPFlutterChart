// Tests for the Fill port (Drawable → ChartDrawable, LinearGradient → ui.Gradient.linear); no Kotlin counterpart.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/utils/fill.dart';

const _red = ui.Color(0xFFFF0000);
const _blue = ui.Color(0xFF0000FF);

/// Draws [draw] into a [width]×[height] image and returns its RGBA bytes.
Future<ByteData> _render(
  int width,
  int height,
  void Function(ui.Canvas canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final image = recorder.endRecording().toImageSync(width, height);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  image.dispose();
  return bytes;
}

/// The RGBA pixel at ([x], [y]) of a [width]-wide image.
List<int> _pixel(ByteData bytes, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
    bytes.getUint8(i + 3),
  ];
}

void main() {
  test('constructors set the type and data', () {
    expect(Fill().type, FillType.EMPTY);
    final color = Fill.ofColor(_red);
    expect(color.type, FillType.COLOR);
    expect(color.color, _red);
    final two = Fill.ofColors(_red, _blue);
    expect(two.type, FillType.LINEAR_GRADIENT);
    expect(two.gradientColors, [_red, _blue]);
    final list = Fill.ofGradient([_red, _blue, _red], [0, 0.5, 1]);
    expect(list.type, FillType.LINEAR_GRADIENT);
    expect(list.gradientPositions, [0, 0.5, 1]);
    final drawable = PainterDrawable((c, s) {}, width: 1, height: 1);
    final d = Fill.ofDrawable(drawable);
    expect(d.type, FillType.DRAWABLE);
    expect(identical(d.drawable, drawable), isTrue);
    two.setGradientColors(_blue, _red);
    expect(two.gradientColors, [_blue, _red]);
    expect(two.type, FillType.LINEAR_GRADIENT);
  });

  test('EMPTY draws nothing', () async {
    final bytes = await _render(
      4,
      4,
      (c) => Fill().fillRect(c, ChartPaint(), 0, 0, 4, 4, FillDirection.DOWN),
    );
    expect(_pixel(bytes, 4, 1, 1)[3], 0);
  });

  test('COLOR fills only the rectangle, with alpha applied', () async {
    final fill = Fill.ofColor(_red);
    var bytes = await _render(
      10,
      10,
      (c) => fill.fillRect(c, ChartPaint(), 2, 2, 6, 6, FillDirection.DOWN),
    );
    expect(_pixel(bytes, 10, 2, 2), [255, 0, 0, 255]);
    expect(_pixel(bytes, 10, 5, 5), [255, 0, 0, 255]);
    expect(_pixel(bytes, 10, 6, 6)[3], 0);
    expect(_pixel(bytes, 10, 1, 1)[3], 0);

    fill.alpha = 128;
    bytes = await _render(
      10,
      10,
      (c) => fill.fillRect(c, ChartPaint(), 0, 0, 10, 10, FillDirection.DOWN),
    );
    expect(_pixel(bytes, 10, 5, 5)[3], closeTo(128, 1));

    // The alpha of the color and Fill.alpha multiply: 0x80 * 128 / 255 ≈ 64.
    fill.color = const ui.Color(0x80FF0000);
    bytes = await _render(
      10,
      10,
      (c) => fill.fillRect(c, ChartPaint(), 0, 0, 10, 10, FillDirection.DOWN),
    );
    expect(_pixel(bytes, 10, 5, 5)[3], closeTo(64, 1));
  });

  test(
    'LINEAR_GRADIENT DOWN runs from the top edge and keeps the shader on the paint',
    () async {
      final paint = ChartPaint();
      final bytes = await _render(
        10,
        20,
        (c) => Fill.ofColors(
          _red,
          _blue,
        ).fillRect(c, paint, 0, 0, 10, 20, FillDirection.DOWN),
      );
      final top = _pixel(bytes, 10, 5, 0);
      final bottom = _pixel(bytes, 10, 5, 19);
      expect(top[0], greaterThan(200));
      expect(top[2], lessThan(55));
      expect(bottom[2], greaterThan(200));
      expect(bottom[0], lessThan(55));
      expect(paint.shader, isNotNull);
    },
  );

  test(
    'LINEAR_GRADIENT RIGHT starts at the right edge, as the Kotlin code does',
    () async {
      final bytes = await _render(
        20,
        10,
        (c) => Fill.ofColors(
          _red,
          _blue,
        ).fillRect(c, ChartPaint(), 0, 0, 20, 10, FillDirection.RIGHT),
      );
      expect(_pixel(bytes, 20, 19, 5)[0], greaterThan(200));
      expect(_pixel(bytes, 20, 0, 5)[2], greaterThan(200));
    },
  );

  test('a single gradient color draws flat', () async {
    final bytes = await _render(
      10,
      10,
      (c) => Fill.ofGradient([
        _red,
      ]).fillRect(c, ChartPaint(), 0, 0, 10, 10, FillDirection.UP),
    );
    expect(_pixel(bytes, 10, 5, 0), [255, 0, 0, 255]);
    expect(_pixel(bytes, 10, 5, 9), [255, 0, 0, 255]);
  });

  test('DRAWABLE draws into the rectangle truncated to whole pixels', () async {
    final bounds = <ui.Size>[];
    final drawable = PainterDrawable(
      (c, size) {
        bounds.add(size);
        c.drawRect(
          ui.Offset.zero & size,
          ui.Paint()..color = const ui.Color(0xFF00FF00),
        );
      },
      width: 1,
      height: 1,
    );
    final bytes = await _render(
      10,
      10,
      (c) => Fill.ofDrawable(
        drawable,
      ).fillRect(c, ChartPaint(), 2.7, 3.2, 6.9, 7.5, FillDirection.DOWN),
    );
    expect(bounds, [const ui.Size(4, 4)]);
    expect(_pixel(bytes, 10, 2, 3), [0, 255, 0, 255]);
    expect(_pixel(bytes, 10, 5, 6), [0, 255, 0, 255]);
    expect(_pixel(bytes, 10, 6, 7)[3], 0);
  });

  test(
    'fillPath COLOR without clipRect draws the path and restores the paint',
    () async {
      final paint = ChartPaint()
        ..style = PaintStyle.STROKE
        ..color = _blue;
      final path = ui.Path()..addRect(const ui.Rect.fromLTRB(2, 2, 6, 6));
      final bytes = await _render(
        10,
        10,
        (c) => Fill.ofColor(
          _red,
        ).fillPath(c, path, paint, null, const ui.Size(10, 10)),
      );
      expect(_pixel(bytes, 10, 4, 4), [255, 0, 0, 255]);
      expect(_pixel(bytes, 10, 7, 7)[3], 0);
      expect(paint.style, PaintStyle.STROKE);
      expect(paint.color, _blue);
    },
  );

  test('fillPath COLOR with clipRect clips to the path', () async {
    final path = ui.Path()..addRect(const ui.Rect.fromLTRB(2, 2, 6, 6));
    final bytes = await _render(
      10,
      10,
      (c) => Fill.ofColor(_red).fillPath(
        c,
        path,
        ChartPaint(),
        MutableRect(0, 0, 10, 10),
        const ui.Size(10, 10),
      ),
    );
    expect(_pixel(bytes, 10, 4, 4), [255, 0, 0, 255]);
    expect(_pixel(bytes, 10, 7, 7)[3], 0);
  });

  test(
    'fillPath DRAWABLE without clipRect uses the canvas size as bounds',
    () async {
      final bounds = <ui.Size>[];
      final drawable = PainterDrawable(
        (c, size) => bounds.add(size),
        width: 1,
        height: 1,
      );
      await _render(
        10,
        10,
        (c) => Fill.ofDrawable(drawable).fillPath(
          c,
          ui.Path()..addRect(const ui.Rect.fromLTRB(0, 0, 5, 5)),
          ChartPaint(),
          null,
          const ui.Size(12, 8),
        ),
      );
      expect(bounds, [const ui.Size(12, 8)]);
    },
  );
}
