import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/ingredients/ingredients.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The catalog entries in the active library's ingredient library, with their
/// default unit and how many recipes use each.
class IngredientsView extends StatefulWidget {
  /// Creates an [IngredientsView].
  const IngredientsView({super.key});

  @override
  State<IngredientsView> createState() => _IngredientsViewState();
}

class _IngredientsViewState extends State<IngredientsView> {
  String? _failure;
  FToasterEntry? _refusalToast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<RecipesBloc>().state;
    final usage = state.ingredientUsage;
    final entries = switch (state.activeLibrary) {
      final library? => state.ingredientsIn(library.ingredientLibraryId),
      null => const <CatalogIngredient>[],
    };

    return RecipesMutationListener(
      mutation: RecipesMutation.ingredientDeleted,
      onSuccess: (_) {},
      onFailure: () => setState(() => _failure = l10n.ingredientsDeleteFailure),
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
                          subtitle: switch (entry.defaultUnit) {
                            final unit? => Text(unit.label),
                            null => null,
                          },
                          details: Text(
                            l10n.ingredientsUsageCount(recipeCount),
                          ),
                          suffix: FButton.icon(
                            variant: FButtonVariant.ghost,
                            semanticsLabel: l10n.ingredientsDeleteLabel(
                              entry.name,
                            ),
                            onPress: () => unawaited(_delete(entry)),
                            child: const Icon(FLucideIcons.trash2),
                          ),
                          onPress: () => _edit(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _edit(CatalogIngredient entry) {
    _refusalToast?.dismiss();
    unawaited(IngredientEditorSheet.show(context, entry: entry));
  }

  /// Refuses an entry in use before dispatching, which is how the refusal can
  /// name the count and the libraries to look in: a failed delete cannot say
  /// why it failed.
  // A stopgap until a used entry can be deleted through a dialog listing the
  // recipes it strips.
  Future<void> _delete(CatalogIngredient entry) async {
    final l10n = context.l10n;
    _refusalToast?.dismiss();
    final state = context.read<RecipesBloc>().state;
    final using = state.recipesUsingIngredient(entry.id);
    if (using.isNotEmpty) {
      final libraries = {
        for (final recipe in using) ?state.libraryById(recipe.libraryId)?.name,
      };
      _refusalToast = showRefusalToast(
        context,
        title: l10n.ingredientsDeleteRefusalTitle(entry.name),
        description: l10n.ingredientsDeleteRefusalDescription(
          using.length,
          libraries.join(', '),
        ),
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
