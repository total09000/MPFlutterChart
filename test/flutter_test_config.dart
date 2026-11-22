// Runs before every test file under test/: Utils.devicePixelRatio is a global that every chart widget sets from its
// view (flutter_test's default view has a ratio of 3), so it goes back to its default of 1.0 after each test and
// tests stay independent of the order they run in.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  tearDown(() => Utils.devicePixelRatio = 1.0);
  await testMain();
}
