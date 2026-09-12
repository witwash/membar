import 'package:membar/logging/app_logs.dart';
import 'package:talker/talker.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';

/// Creates the [Talker] every layer of the app logs through.
///
/// [level] is the one knob each flavor turns. Bloc, route and lifecycle logs
/// sit at [LogLevel.debug], so a production build asking for
/// [LogLevel.warning] sheds them without having to name them.
Talker createTalker({required LogLevel level}) {
  return Talker(
    logger: TalkerLogger(settings: TalkerLoggerSettings(level: level)),
    settings: TalkerSettings(
      titles: {
        AppTalkerKey.storage: 'storage',
        TalkerKey.blocEvent: 'event',
        TalkerKey.blocTransition: 'transition',
      },
      colors: {AppTalkerKey.storage: AnsiPen()..xterm(214)},
    ),
  );
}

/// The bloc observer settings the app runs with.
///
/// States are logged by type, not in full: a `RecipesState` carries every
/// recipe of the active library, which would bury each transition under a
/// snapshot of the library on every keystroke of the search field.
const appBlocLoggerSettings = TalkerBlocLoggerSettings(
  printEventFullData: false,
  printStateFullData: false,
  printCreations: true,
  printClosings: true,
);

/// The app's own log categories, reached the same way as `talker.warning`.
extension AppTalkerLogs on Talker {
  /// Records a problem the storage layer recovered from.
  ///
  /// Shaped to match `LocalStorageRecipesApi`'s `onRecoveryError` so it can be
  /// passed as a tear-off.
  void storage(String message) => logCustom(StorageLog(message));

  /// Records a navigation change reported by `Navigator`.
  void route(String action, String? route, [String? previousRoute]) =>
      logCustom(RouteLog(action, route, previousRoute));
}
