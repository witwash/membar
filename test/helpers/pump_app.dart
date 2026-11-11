import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] inside a tree mirroring the real app's: the forui theme,
  /// toaster and tooltip group, both sets of localization delegates, and the
  /// repository and bloc a recipe screen expects above it.
  Future<void> pumpApp(
    Widget widget, {
    RecipesRepository? recipesRepository,
    StarterRecipesRepository? starterRecipesRepository,
    RecipesBloc? recipesBloc,
  }) {
    final home = recipesBloc == null
        ? widget
        : BlocProvider.value(value: recipesBloc, child: widget);
    Widget app = MaterialApp(
      theme: FTheme.neutral.light.touch.toApproximateMaterialTheme(),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        ...FLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => FTheme(
        data: FTheme.neutral.light.touch,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      home: home,
    );
    // Above the navigator, as in `App`, so a pushed route can read them too.
    if (recipesRepository != null) {
      app = RepositoryProvider.value(value: recipesRepository, child: app);
    }
    if (starterRecipesRepository != null) {
      app = RepositoryProvider.value(
        value: starterRecipesRepository,
        child: app,
      );
    }

    return pumpWidget(app);
  }
}
