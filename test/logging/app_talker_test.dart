import 'package:flutter_test/flutter_test.dart';
import 'package:membar/logging/logging.dart';
import 'package:talker/talker.dart';

void main() {
  group('createTalker', () {
    test('keeps every log at the most verbose level', () {
      final talker = createTalker(level: LogLevel.verbose)
        ..verbose('traced')
        ..debug('a bloc transition arrives at this level')
        ..info('started')
        ..warning('recovered');

      expect(talker.history, hasLength(4));
    });

    test('drops bloc-level chatter once the level is warning', () {
      final talker = createTalker(level: LogLevel.warning)
        ..debug('a bloc transition')
        ..info('started');

      expect(talker.history, isEmpty);
    });

    test('keeps warnings and errors at the quietest level', () {
      final talker = createTalker(level: LogLevel.warning)
        ..warning('recovered')
        ..error('failed');

      expect(talker.history, hasLength(2));
    });

    test('titles the app and bloc keys', () {
      final settings = createTalker(level: LogLevel.verbose).settings;

      expect(settings.getTitleByKey(AppTalkerKey.storage), 'storage');
      expect(settings.getTitleByKey(TalkerKey.blocEvent), 'event');
      expect(settings.getTitleByKey(TalkerKey.blocTransition), 'transition');
    });

    test('gives the storage key a colour of its own', () {
      final settings = createTalker(level: LogLevel.verbose).settings;

      expect(
        settings.getPenByKey(AppTalkerKey.storage),
        isNot(settings.getPenByKey(TalkerKey.warning)),
      );
    });
  });

  group('appBlocLoggerSettings', () {
    test('logs events and transitions', () {
      expect(appBlocLoggerSettings.printEvents, isTrue);
      expect(appBlocLoggerSettings.printTransitions, isTrue);
    });

    test('logs states by type rather than in full', () {
      expect(appBlocLoggerSettings.printEventFullData, isFalse);
      expect(appBlocLoggerSettings.printStateFullData, isFalse);
    });

    test('logs bloc creation and closure', () {
      expect(appBlocLoggerSettings.printCreations, isTrue);
      expect(appBlocLoggerSettings.printClosings, isTrue);
    });
  });

  group('AppTalkerLogs', () {
    late Talker talker;

    setUp(() => talker = createTalker(level: LogLevel.verbose));

    test('storage records a StorageLog', () {
      talker.storage('the blob was unreadable');

      expect(talker.history.single, isA<StorageLog>());
      expect(talker.history.single.message, 'the blob was unreadable');
    });

    test('storage can be handed over as a tear-off', () {
      void report(void Function(String message) onRecoveryError) =>
          onRecoveryError('recovered');
      report(talker.storage);

      expect(talker.history.single, isA<StorageLog>());
    });

    test('route records a RouteLog', () {
      talker.route('pushed', 'recipe-editor', '/');

      expect(talker.history.single, isA<RouteLog>());
      expect(talker.history.single.message, 'pushed recipe-editor (from /)');
    });

    test('route takes an origin optionally', () {
      talker.route('pushed', 'recipe-editor');

      expect(talker.history.single.message, 'pushed recipe-editor');
    });
  });
}
