import 'package:flutter/widgets.dart';
import 'package:membar/logging/app_talker.dart';
import 'package:talker/talker.dart';

/// Reports every navigation change to [talker], by route name.
///
/// A route with no name logs as its type, which every screen in this app
/// shares — so the recipe screens name theirs.
class LoggingRouteObserver extends NavigatorObserver {
  /// Creates a [LoggingRouteObserver] logging through [talker].
  LoggingRouteObserver(this.talker);

  /// The logger every navigation change is reported to.
  final Talker talker;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    talker.route('pushed', route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    talker.route('popped', route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    talker.route('removed', route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    talker.route('replaced', newRoute?.settings.name, oldRoute?.settings.name);
  }
}
