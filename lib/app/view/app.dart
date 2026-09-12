import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/logging/logging.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:talker/talker.dart';

/// The theme every screen renders under. There is one repository, so it is
/// provided with a single `RepositoryProvider.value`.
class App extends StatelessWidget {
  /// Creates an [App] backed by [recipesRepository], logging through [talker].
  const App({required this.recipesRepository, this.talker, super.key});

  /// The repository every recipe screen reads and writes through.
  final RecipesRepository recipesRepository;

  /// The logger navigation changes are reported to.
  ///
  /// Null in a test that has no interest in them; `bootstrap` always supplies
  /// one.
  final Talker? talker;

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.neutral.light.touch;

    return RepositoryProvider.value(
      value: recipesRepository,
      child: MaterialApp(
        theme: theme.toApproximateMaterialTheme(),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          ...FLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [
          if (talker case final talker?) LoggingRouteObserver(talker),
        ],
        builder: (context, child) => FTheme(
          data: theme,
          child: FToaster(child: FTooltipGroup(child: child!)),
        ),
        home: const RecipesPage(),
      ),
    );
  }
}
