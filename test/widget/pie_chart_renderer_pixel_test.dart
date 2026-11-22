// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/
// PieRendererTest.kt (reversedRoundedSlicesBulgeTheOtherWay, aClippedTransparentCircleLeavesTheSliceSpaceClear and its
// pixelAt helper). aDonutHasAHole, aClippedTransparentCircleLeavesTheSliceSpaceClearWithAHighlight and
// theRingsAreEvenOddRings are not ports of a Kotlin test: they check the same way the hole, that the layer of decision
// D8 also spans drawHighlighted, and the even-odd rings of decision D9.
//
// Like Kotlin's `chart.draw(Canvas(bitmap))`, the chart is drawn with onDraw onto a canvas over a transparent image,
// not with Chart.toImage, which paints white first: the alpha checks need the transparent background. The pixels are
// read as raw RGBA, so the alpha is the fourth byte. aClippedTransparentCircleLeavesTheSliceSpaceClear is the pixel
// proof of decision D8: the transparent ring is drawn with BlendMode.srcATop into a layer that holds the
// slices, where Kotlin drew it with SRC_ATOP into its offscreen bitmap. Over a transparent image the slice space stays
// clear with or without that layer, so the test also draws the chart over an opaque background, which only the layer
// keeps untinted; pie_chart_renderer_test.dart pins when the layer opens and closes.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/pie_chart.dart';
import 'package:mp_flutter_chart/src/data/pie_data.dart';
import 'package:mp_flutter_chart/src/data/pie_data_set.dart';
import 'package:mp_flutter_chart/src/data/pie_entry.dart';
import 'package:mp_flutter_chart/src/utils/float_math.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

const int _size = 400;

const ui.Color _red = ui.Color(0xFFFF0000);
const ui.Color _blue = ui.Color(0xFF0000FF);
const ui.Color _teal = ui.Color(0xFF208080);

/// PieRendererTest.pie: a 400 x 400 pie chart without legend, description and center text, holding [entries].
/// [configure] runs before the data is set.
PieChart _pie(
  List<PieEntry> entries,
  void Function(PieChart chart, PieDataSet set) configure,
) {
  final chart = PieChart()..onSizeChanged(_size.toDouble(), _size.toDouble());
  chart.legend.isEnabled = false;
  chart.description.isEnabled = false;
  chart.isDrawCenterTextEnabled = false;
  final set = PieDataSet(entries, 'pie');
  configure(chart, set);
  chart.data = PieData(set);
  return chart;
}

/// The drawn pixels of a chart, read back as raw RGBA.
class _Pixels {
  _Pixels(this.chart, this.rgba);

  final PieChart chart;
  final ByteData rgba;

  /// PieRendererTest.pixelAt: the pixel drawn at [angle] degrees and [radiusPercent] of the pie radius from the
  /// center, as ARGB.
  int pixelAt(double angle, double radiusPercent) {
    final center = chart.centerCircleBox;
    final r = chart.radius * radiusPercent / 100;
    final radians = angle * Utils.DEG2RAD;
    final x = kotlinFloatToInt(center.x + r * math.cos(radians));
    final y = kotlinFloatToInt(center.y + r * math.sin(radians));
    final i = (y * _size + x) * 4;
    return ui.Color.fromARGB(
      rgba.getUint8(i + 3),
      rgba.getUint8(i),
      rgba.getUint8(i + 1),
      rgba.getUint8(i + 2),
    ).toARGB32();
  }
}

int _alpha(int argb) => argb >>> 24;

/// Draws [chart] onto a transparent 400 x 400 image, Kotlin's `chart.draw(Canvas(bitmap))`, or onto one filled with
/// [background] first, standing for whatever is painted behind the chart.
Future<_Pixels> _draw(
  WidgetTester tester,
  PieChart chart, {
  ui.Color? background,
}) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (background != null) canvas.drawColor(background, ui.BlendMode.src);
    chart.onDraw(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(_size, _size);
    picture.dispose();
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    } finally {
      image.dispose();
    }
  });
  return _Pixels(chart, bytes!);
}

void main() {
  group('PieChartRenderer pixels', () {
    testWidgets('reversedRoundedSlicesBulgeTheOtherWay', (tester) async {
      PieChart roundedPie(bool reversed) =>
          _pie([PieEntry(1), PieEntry(1)], (chart, set) {
            set.colors = [_red, _blue];
            set.isDrawValuesEnabled = false;
            chart.isDrawEntryLabelsEnabled = false;
            chart.isDrawRoundedSlicesEnabled = true;
            chart.isRoundedSlicesReversed = reversed;
            chart.rotationAngle = 270;
          });

      // The red slice starts at the top; the blue one ends there.
      final normal = await _draw(tester, roundedPie(false));
      expect(normal.pixelAt(262, 75), _blue.toARGB32());
      expect(normal.pixelAt(278, 75), _blue.toARGB32());

      final reversed = await _draw(tester, roundedPie(true));
      expect(reversed.pixelAt(262, 75), _red.toARGB32());
      expect(reversed.pixelAt(278, 75), _red.toARGB32());
    });

    testWidgets('aClippedTransparentCircleLeavesTheSliceSpaceClear', (
      tester,
    ) async {
      PieChart spacedPie(bool clipped) =>
          _pie([PieEntry(1), PieEntry(1)], (chart, set) {
            set.colors = [_red, _blue];
            set.sliceSpace = 12;
            set.isDrawValuesEnabled = false;
            chart.isDrawEntryLabelsEnabled = false;
            chart.transparentCircleRadius = 70;
            chart.isTransparentCircleClippedToSlices = clipped;
            chart.rotationAngle = 270;
          });

      // The space between the slices runs straight down from the center.
      final unclipped = await _draw(tester, spacedPie(false));
      expect(_alpha(unclipped.pixelAt(90, 60)), isNot(0));

      final clipped = await _draw(tester, spacedPie(true));
      expect(_alpha(clipped.pixelAt(90, 60)), 0);
      expect(clipped.pixelAt(0, 60), isNot(_red.toARGB32()));
      expect(clipped.pixelAt(0, 85), _red.toARGB32());

      // The layer holds only the slices, so the ring cannot tint what lies behind the chart in the slice space.
      // Without the layer, SRC_ATOP would tint the opaque background there.
      final overBackground = await _draw(
        tester,
        spacedPie(true),
        background: _teal,
      );
      expect(overBackground.pixelAt(90, 60), _teal.toARGB32());
      // The ring still tints the slices.
      expect(overBackground.pixelAt(0, 60), isNot(_red.toARGB32()));
      expect(overBackground.pixelAt(0, 85), _red.toARGB32());
    });

    testWidgets(
      'aClippedTransparentCircleLeavesTheSliceSpaceClearWithAHighlight',
      (tester) async {
        // The layer drawData opens spans drawHighlighted too: with slice 0 highlighted the slice space still shows the
        // opaque background untinted, and the ring still tints the slices.
        final chart = _pie([PieEntry(1), PieEntry(1)], (chart, set) {
          set.colors = [_red, _blue];
          set.sliceSpace = 12;
          set.isDrawValuesEnabled = false;
          chart.isDrawEntryLabelsEnabled = false;
          chart.transparentCircleRadius = 70;
          chart.isTransparentCircleClippedToSlices = true;
          chart.rotationAngle = 270;
        });
        chart.highlightValue(0, 0);
        expect(chart.highlighted, hasLength(1));

        final pixels = await _draw(tester, chart, background: _teal);
        expect(pixels.pixelAt(90, 60), _teal.toARGB32());
        expect(pixels.pixelAt(0, 60), isNot(_red.toARGB32()));
        expect(_alpha(pixels.pixelAt(0, 60)), 255);
        expect(pixels.pixelAt(0, 85), _red.toARGB32());
        expect(pixels.pixelAt(180, 60), isNot(_blue.toARGB32()));
      },
    );

    testWidgets('theRingsAreEvenOddRings', (tester) async {
      // The transparent ring and the single slice of a donut are two concentric circles filled even-odd,
      // so they leave the hole empty. An outer circle alone would cover the hole.
      PieChart singleSlice(ui.Color hole) => _pie([PieEntry(1)], (chart, set) {
        set.colors = [_red];
        set.isDrawValuesEnabled = false;
        chart.isDrawEntryLabelsEnabled = false;
        chart.holeColor = hole;
        chart.transparentCircleRadius = 70;
      });

      // An opaque hole under the white ring at alpha 105: the hole keeps its color, the ring tints the slice.
      final opaque = await _draw(tester, singleSlice(_blue));
      expect(opaque.pixelAt(0, 25), _blue.toARGB32());
      expect(opaque.pixelAt(135, 40), _blue.toARGB32());
      final tinted = opaque.pixelAt(0, 60);
      // White at 105 / 255 over red: (255, 105, 105).
      expect(_alpha(tinted), 255);
      expect((tinted >> 16) & 0xFF, 255);
      expect((tinted >> 8) & 0xFF, closeTo(105, 2));
      expect(tinted & 0xFF, closeTo(105, 2));
      expect(opaque.pixelAt(0, 85), _red.toARGB32());

      // A transparent hole: neither the slice nor the ring covers it.
      final hollow = await _draw(
        tester,
        singleSlice(const ui.Color(0x00000000)),
      );
      expect(_alpha(hollow.pixelAt(0, 25)), 0);
      expect(_alpha(hollow.pixelAt(225, 40)), 0);
      expect(hollow.pixelAt(0, 85), _red.toARGB32());
    });

    testWidgets('aDonutHasAHole', (tester) async {
      final donut = await _draw(
        tester,
        _pie([PieEntry(1), PieEntry(1)], (chart, set) {
          set.colors = [_red, _blue];
          set.isDrawValuesEnabled = false;
          chart.holeColor = const ui.Color(0x00000000);
        }),
      );
      expect(_alpha(donut.pixelAt(0, 20)), 0);
      expect(_alpha(donut.pixelAt(180, 20)), 0);
      expect(donut.pixelAt(0, 75), _red.toARGB32());
      expect(donut.pixelAt(180, 75), _blue.toARGB32());
    });
  });
}
