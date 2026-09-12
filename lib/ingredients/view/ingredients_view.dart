import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/ingredients/ingredients.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// Every catalog entry, with its default unit, its libraries and how many
/// recipes use it, plus the import of ingredient names from saved recipes.
class IngredientsView extends StatefulWidget {
  /// Creates an [IngredientsView].
  const IngredientsView({super.key});

  @override
  State<IngredientsView> createState() => _IngredientsViewState();
}

class _IngredientsViewState extends State<IngredientsView> {
  String? _failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<RecipesBloc>().state;
    final usage = state.ingredientUsage;
    final importable = state.importableIngredients;
    final importing =
        state.mutation == RecipesMutation.ingredientsImported &&
        state.mutationStatus == RecipesMutationStatus.loading;
    final entries = [...state.ingredients]
      ..sort((a, b) => compareCaseInsensitive(a.name, b.name));
    final libraryNames = {
      for (final library in state.libraries) library.id: library.name,
    };

    return RecipesMutationListener(
      mutation: RecipesMutation.ingredientDeleted,
      onSuccess: () {},
      onFailure: () => setState(() => _failure = l10n.ingredientsDeleteFailure),
      child: RecipesMutationListener(
        mutation: RecipesMutation.ingredientsImported,
        onSuccess: () {},
        onFailure: () =>
            setState(() => _failure = l10n.ingredientsImportFailure),
        child: FScaffold(
          header: FHeader.nested(
            title: Text(l10n.ingredientsTitle),
            prefixes: [
              FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_failure case final failure?) FailureBanner(failure),
              // Offered whenever it would add something, not just on an empty
              // catalog: the import is idempotent, so a recipe saved later
              // can still contribute its names.
              if (importable.isNotEmpty) ...[
                FButton(
                  variant: FButtonVariant.outline,
                  prefix: const Icon(FLucideIcons.import),
                  onPress: importing ? null : _import,
                  child: Text(l10n.ingredientsImportLabel(importable.length)),
                ),
                const SizedBox(height: AppSpacing.spacing150),
              ],
              Expanded(
                child: entries.isEmpty
                    ? const _EmptyState()
                    : FTileGroup.builder(
                        count: entries.length,
                        tileBuilder: (context, index) {
                          final entry = entries[index];
                          final recipeCount = usage[entry.id] ?? 0;
                          return FTile(
                            title: Text(entry.name),
                            subtitle: Text(
                              _describe(entry, libraryNames),
                            ),
                            details: Text(
                              l10n.ingredientsUsageCount(recipeCount),
                            ),
                            suffix: FButton.icon(
                              variant: FButtonVariant.ghost,
                              semanticsLabel: l10n.ingredientsDeleteLabel(
                                entry.name,
                              ),
                              onPress: () =>
                                  unawaited(_delete(entry, recipeCount)),
                              child: const Icon(FLucideIcons.trash2),
                            ),
                            onPress: () => unawaited(
                              IngredientEditorSheet.show(context, entry: entry),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The entry's default unit, then its libraries ordered by name. A library
  /// id that resolves to nothing is left out rather than shown raw.
  String _describe(
    CatalogIngredient entry,
    Map<String, String> libraryNames,
  ) {
    final libraries = [
      for (final id in entry.libraryIds) ?libraryNames[id],
    ]..sort(compareCaseInsensitive);
    return [
      ?entry.defaultUnit?.label,
      if (libraries.isNotEmpty) libraries.join(', '),
    ].join(' · ');
  }

  void _import() {
    setState(() => _failure = null);
    context.read<RecipesBloc>().add(const RecipesIngredientsImported());
  }

  /// Refuses an entry in use before dispatching, which is how the refusal can
  /// name the count: a failed delete cannot say why it failed.
  Future<void> _delete(CatalogIngredient entry, int recipeCount) async {
    final l10n = context.l10n;
    if (recipeCount > 0) {
      setState(
        () => _failure = l10n.ingredientsDeleteRefusal(entry.name, recipeCount),
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.ingredientsDeleteDialogTitle(entry.name),
      description: l10n.ingredientsDeleteDialogDescription,
      confirmLabel: l10n.ingredientsDeleteDialogConfirm,
      cancelLabel: l10n.ingredientsDeleteDialogCancel,
    );
    if (!confirmed || !mounted) return;

    setState(() => _failure = null);
    context.read<RecipesBloc>().add(RecipesIngredientDeleted(entry.id));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.spacing100,
        children: [
          Text(l10n.ingredientsEmptyTitle, style: theme.typography.body.lg),
          Text(
            l10n.ingredientsEmptyDescription,
            textAlign: TextAlign.center,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
