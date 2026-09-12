import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/logging/logging.dart';
import 'package:talker/talker.dart';

Route<void> _route(String? name) => MaterialPageRoute<void>(
  settings: RouteSettings(name: name),
  builder: (_) => const SizedBox.shrink(),
);

void main() {
  group('LoggingRouteObserver', () {
    late Talker talker;
    late LoggingRouteObserver observer;

    setUp(() {
      talker = createTalker(level: LogLevel.verbose);
      observer = LoggingRouteObserver(talker);
    });

    test('logs a push by route name', () {
      observer.didPush(_route('recipe-editor'), _route('/'));

      expect(talker.history.single, isA<RouteLog>());
      expect(talker.history.single.message, 'pushed recipe-editor (from /)');
    });

    test('logs a pop', () {
      observer.didPop(_route('recipe-editor'), _route('/'));

      expect(talker.history.single.message, 'popped recipe-editor (from /)');
    });

    test('logs a removal', () {
      observer.didRemove(_route('recipe-editor'), _route('/'));

      expect(talker.history.single.message, 'removed recipe-editor (from /)');
    });

    test('logs a replacement', () {
      observer.didReplace(
        newRoute: _route('recipe-details'),
        oldRoute: _route('recipe-editor'),
      );

      expect(
        talker.history.single.message,
        'replaced recipe-details (from recipe-editor)',
      );
    });

    test('logs a replacement that came from nothing', () {
      observer.didReplace(newRoute: _route('recipe-details'));

      expect(talker.history.single.message, 'replaced recipe-details');
    });

    test('logs a push onto an empty navigator', () {
      observer.didPush(_route('/'), null);

      expect(talker.history.single.message, 'pushed /');
    });

    test('names an unnamed route rather than dropping the line', () {
      observer.didPush(_route(null), _route('/'));

      expect(
        talker.history.single.message,
        'pushed an unnamed route (from /)',
      );
    });

    testWidgets('logs what a real Navigator does', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const SizedBox.shrink(),
          onGenerateRoute: (settings) => _route(settings.name),
        ),
      );

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.pushNamed('recipe-editor'));
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();

      expect(
        talker.history.map((log) => log.message),
        containsAllInOrder([
          'pushed recipe-editor (from /)',
          'popped recipe-editor (from /)',
        ]),
      );
    });
  });
}
