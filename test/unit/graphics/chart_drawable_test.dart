// Tests for the android.graphics.drawable.Drawable shim ChartDrawable; no Kotlin counterpart.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';

/// Draws [draw] into a [width]×[height] image and returns its RGBA bytes.
Future<ByteData> _render(int width, int height, void Function(ui.Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final image = recorder.endRecording().toImageSync(width, height);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  image.dispose();
  return bytes;
}

/// The RGBA pixel at ([x], [y]) of a [width]-wide image.
List<int> _pixel(ByteData bytes, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2), bytes.getUint8(i + 3)];
}

/// A [width]×[height] opaque red image.
ui.Image _redImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFF0000),
  );
  return recorder.endRecording().toImageSync(width, height);
}

void main() {
  group('PainterDrawable', () {
    test('draw calls the painter once with the bounds size, translated to the bounds origin', () async {
      final sizes = <ui.Size>[];
      final drawable = PainterDrawable(
        (canvas, size) {
          sizes.add(size);
          canvas.drawRect(
            ui.Rect.fromLTWH(0, 0, size.width, size.height),
            ui.Paint()..color = const ui.Color(0xFF00FF00),
          );
        },
        width: 24,
        height: 12,
      );

      final bytes = await _render(20, 20, (canvas) => drawable.draw(canvas, MutableRect(5, 6, 15, 10)));

      expect(sizes, [const ui.Size(10, 4)]);
      expect(_pixel(bytes, 20, 5, 6), [0, 255, 0, 255]);
      expect(_pixel(bytes, 20, 14, 9), [0, 255, 0, 255]);
      expect(_pixel(bytes, 20, 4, 6)[3], 0);
      expect(_pixel(bytes, 20, 15, 9)[3], 0);
      expect(_pixel(bytes, 20, 5, 10)[3], 0);
    });

    test('intrinsic size comes from the constructor', () {
      final drawable = PainterDrawable((_, _) {}, width: 24, height: 12);
      expect(drawable.intrinsicWidth, 24);
      expect(drawable.intrinsicHeight, 12);
    });

    test('draw restores the canvas transform', () async {
      final drawable = PainterDrawable((_, _) {}, width: 1, height: 1);
      final bytes = await _render(4, 4, (canvas) {
        drawable.draw(canvas, MutableRect(2, 2, 3, 3));
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint()..color = const ui.Color(0xFF0000FF));
      });
      expect(_pixel(bytes, 4, 0, 0), [0, 0, 255, 255]);
      expect(_pixel(bytes, 4, 2, 2)[3], 0);
    });

    test('alpha below 255 fades the painted content', () async {
      final drawable = PainterDrawable(
        (canvas, size) {
          canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = const ui.Color(0xFF00FF00));
        },
        width: 4,
        height: 4,
      )..alpha = 128;
      final bytes = await _render(4, 4, (canvas) => drawable.draw(canvas, MutableRect(0, 0, 4, 4)));
      expect(_pixel(bytes, 4, 1, 1)[3], closeTo(128, 1));
    });
  });

  group('ImageDrawable', () {
    test('intrinsic size is the image size', () {
      final image = _redImage(7, 3);
      final drawable = ImageDrawable(image);
      expect(drawable.intrinsicWidth, 7);
      expect(drawable.intrinsicHeight, 3);
      image.dispose();
    });

    test('scale divides the intrinsic size, for @2x/@3x asset images', () {
      final image = _redImage(48, 30);
      final drawable = ImageDrawable(image, scale: 3);
      expect(drawable.scale, 3);
      expect(drawable.intrinsicWidth, 16);
      expect(drawable.intrinsicHeight, 10);
      expect(ImageDrawable(image).scale, 1.0);
      final odd = _redImage(5, 3);
      expect(ImageDrawable(odd, scale: 2).intrinsicWidth, 3); // 2.5 rounds half up
      odd.dispose();
      image.dispose();
    });

    test('draw stretches the image over the bounds', () async {
      final image = _redImage(2, 2);
      final drawable = ImageDrawable(image);
      final bytes = await _render(20, 20, (canvas) => drawable.draw(canvas, MutableRect(2, 4, 18, 8)));
      expect(_pixel(bytes, 20, 2, 4), [255, 0, 0, 255]);
      expect(_pixel(bytes, 20, 17, 7), [255, 0, 0, 255]);
      expect(_pixel(bytes, 20, 1, 4)[3], 0);
      expect(_pixel(bytes, 20, 18, 7)[3], 0);
      expect(_pixel(bytes, 20, 10, 8)[3], 0);
      image.dispose();
    });

    test('alpha below 255 fades the image', () async {
      final image = _redImage(2, 2);
      final drawable = ImageDrawable(image)..alpha = 64;
      final bytes = await _render(4, 4, (canvas) => drawable.draw(canvas, MutableRect(0, 0, 4, 4)));
      expect(_pixel(bytes, 4, 1, 1)[3], closeTo(64, 1));
      image.dispose();
    });
  });

  test('alpha defaults to 255', () {
    expect(PainterDrawable((_, _) {}, width: 1, height: 1).alpha, 255);
  });
}
