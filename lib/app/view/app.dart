import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/logging/logging.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';
import 'package:talker/talker.dart';

/// The theme every screen renders under, and the repositories above it.
class App extends StatelessWidget {
  /// Creates an [App] backed by [recipesRepository] and
  /// [starterRecipesRepository], logging through [talker].
  const App({
    required this.recipesRepository,
    required this.starterRecipesRepository,
    this.talker,
    super.key,
  });

  /// The repository every recipe screen reads and writes through.
  final RecipesRepository recipesRepository;

  /// The repository the bundled starter recipes are read through.
  final StarterRecipesRepository starterRecipesRepository;

  /// The logger navigation changes are reported to.
  ///
  /// Null in a test that has no interest in them; `bootstrap` always supplies
  /// one.
  final Talker? talker;

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.neutral.light.touch;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: recipesRepository),
        RepositoryProvider.value(value: starterRecipesRepository),
      ],
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
