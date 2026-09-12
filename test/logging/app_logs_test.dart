import 'package:flutter_test/flutter_test.dart';
import 'package:membar/logging/logging.dart';
import 'package:talker/talker.dart';

void main() {
  group('StorageLog', () {
    test('carries the storage key so it reads as its own category', () {
      expect(StorageLog('recovered').key, AppTalkerKey.storage);
    });

    test('is a warning, not a debug line', () {
      expect(StorageLog('recovered').logLevel, LogLevel.warning);
    });

    test('keeps the message it was given', () {
      expect(
        StorageLog('the blob was unreadable').message,
        'the blob was unreadable',
      );
    });
  });

  group('RouteLog', () {
    test('carries the route key', () {
      expect(RouteLog('pushed', 'recipe-editor', null).key, AppTalkerKey.route);
    });

    test('names both routes when there is one to come from', () {
      expect(
        RouteLog('pushed', 'recipe-editor', '/').message,
        'pushed recipe-editor (from /)',
      );
    });

    test('omits the origin when there is none', () {
      expect(
        RouteLog('pushed', 'recipe-editor', null).message,
        'pushed recipe-editor',
      );
    });

    test('describes an unnamed route rather than logging nothing', () {
      expect(
        RouteLog('popped', null, 'recipe-details').message,
        'popped an unnamed route (from recipe-details)',
      );
    });
  });
}
