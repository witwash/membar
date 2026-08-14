import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Turns leak tracking on for the suite, then ignores it by default.
///
/// A test opts in with `experimentalLeakTesting:
/// LeakTesting.settings.withTrackedAll()`. Tracking every test instead would
/// report objects this app does not own, and the one thing worth proving here
/// is that the editor disposes a removed row's controllers.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnoredAll();
  await testMain();
}
