import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:membar/logging/logging.dart';
import 'package:talker/talker.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';

/// Starts the app with logging and error handling installed.
///
/// [builder] is handed the [Talker] every layer logs through, so the objects
/// it constructs report through the same logger rather than making their own.
Future<void> bootstrap(
  FutureOr<Widget> Function(Talker talker) builder, {
  required LogLevel logLevel,
}) async {
  final talker = createTalker(level: logLevel);

  await runZonedGuarded(
    () async {
      // The binding must exist before the builder touches a plugin channel —
      // shared_preferences, in every flavor — and must be created inside this
      // zone, or the errors it forwards escape the guard.
      final binding = WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        talker.handle(
          details.exception,
          details.stack,
          'Unhandled error in the ${details.library ?? 'Flutter framework'}',
        );
      };

      binding.platformDispatcher.onError = (error, stackTrace) {
        talker.handle(error, stackTrace, 'Unhandled platform error');
        return true;
      };

      Bloc.observer = TalkerBlocObserver(
        talker: talker,
        settings: appBlocLoggerSettings,
      );

      talker.info('Starting membar at log level ${logLevel.name}');

      runApp(await builder(talker));
    },
    (error, stackTrace) {
      talker.handle(error, stackTrace, 'Unhandled error outside the framework');
    },
  );
}
