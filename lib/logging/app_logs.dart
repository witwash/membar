import 'package:talker/talker.dart';

/// The [TalkerKey]s this app adds to the ones `talker` ships with.
///
/// A key is what carries a log's title and colour, so a category with its own
/// key reads as its own thing rather than as a generic `debug` line.
abstract final class AppTalkerKey {
  /// Storage recovered from a problem it could carry on past.
  static const String storage = 'storage';

  /// A navigation change.
  static const String route = TalkerKey.route;
}

/// A problem the storage layer recovered from: a corrupt blob, a stale active
/// library id, a seed write that failed.
///
/// None of these stop the app, which is why they are logged as warnings: the
/// user sees a working app while their data quietly changed shape.
class StorageLog extends TalkerLog {
  /// Creates a [StorageLog] describing [message].
  StorageLog(super.message) : super(logLevel: LogLevel.warning);

  @override
  String get key => AppTalkerKey.storage;
}

/// A push, pop, replace or remove reported by `Navigator`.
class RouteLog extends TalkerLog {
  /// Creates a [RouteLog] recording that [route] was [action]ed, optionally
  /// over or in place of [previousRoute].
  RouteLog(String action, String? route, String? previousRoute)
    : super(
        previousRoute == null
            ? '$action ${route ?? _unnamed}'
            : '$action ${route ?? _unnamed} (from $previousRoute)',
        logLevel: LogLevel.debug,
      );

  static const _unnamed = 'an unnamed route';

  @override
  String get key => AppTalkerKey.route;
}
