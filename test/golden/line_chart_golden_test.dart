// Not a port of a Kotlin test: stands in for the screenshot checks of MPChartDeviceTest. A LineChart in
// its default style with three entries, rendered by the host at 400 x 300 with the flutter_test font, compared
// against goldens/macos/. Goldens are per host platform and only compared on macOS; regenerate with
// `tool/flutter.sh test --update-goldens test/golden`.
@Tags(['golden'])
library;

import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';

void main() {
  testWidgets(
    'LineChart in the default style, three entries, 400 x 300',
    (tester) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              // The chart itself has no background; white makes the golden readable.
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: SizedBox(
                  width: 400,
                  height: 300,
                  child: LineChart(
                    data: LineData([
                      LineDataSet([
                        Entry(x: 0, y: 1),
                        Entry(x: 1, y: 3),
                        Entry(x: 2, y: 2),
                      ], 'DataSet 1'),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Jobs posted before the first layout run after that frame.
      await tester.pump();

      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/macos/line_chart_default.png'),
      );
    },
    skip: !Platform.isMacOS,
  );
}
