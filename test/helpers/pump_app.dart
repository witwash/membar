import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] inside a tree mirroring the real app's: the forui theme,
  /// toaster and tooltip group, both sets of localization delegates, and the
  /// repository and bloc a recipe screen expects above it.
  Future<void> pumpApp(
    Widget widget, {
    RecipesRepository? recipesRepository,
    RecipesBloc? recipesBloc,
  }) {
    var child = widget;
    if (recipesBloc != null) {
      child = BlocProvider.value(value: recipesBloc, child: child);
    }
    if (recipesRepository != null) {
      child = RepositoryProvider.value(value: recipesRepository, child: child);
    }

    return pumpWidget(
      MaterialApp(
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
        home: child,
      ),
    );
  }
}
