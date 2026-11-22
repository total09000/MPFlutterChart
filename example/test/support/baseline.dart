// Where a laid-out text's baseline is, for the tests of the Android line boxes. RenderBox.getDistanceToBaseline may
// only be called by the parent during its layout or paint, so this measures the paragraph's position instead.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// How far below the top of [box] the alphabetic baseline of the one text inside it sits, in logical px: the laid-out
/// paragraph's offset in [box] plus the paragraph's own baseline.
double baselineIn(WidgetTester tester, Finder box) {
  final paragraph = find.descendant(of: box, matching: find.byType(RichText));
  final render = tester.renderObject<RenderBox>(paragraph);
  return tester.getTopLeft(paragraph).dy -
      tester.getTopLeft(box).dy +
      render.getDryBaseline(render.constraints, TextBaseline.alphabetic)!;
}
