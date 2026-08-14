import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// A single recipe, rendered read-only: its core fields plus one row per schema
/// field its library declares, in schema order.
///
/// The library is passed at push time rather than read from the bloc, so the
/// schema on screen cannot change while the screen is open.
class RecipeDetailsPage extends StatefulWidget {
  /// Creates a [RecipeDetailsPage] for [recipe], described by [library]'s
  /// schema.
  const RecipeDetailsPage({
    required this.recipe,
    required this.library,
    super.key,
  });

  /// The route that pushes this page, re-providing [bloc].
  ///
  /// The pushed route sits above the provider `RecipesPage` created, so without
  /// re-providing it here the page would throw `ProviderNotFoundException`.
  static Route<void> route({
    required RecipesBloc bloc,
    required Recipe recipe,
    required Library library,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RecipeDetailsPage(recipe: recipe, library: library),
      ),
    );
  }

  /// The recipe this screen was opened on.
  final Recipe recipe;

  /// The library whose schema describes [recipe]'s field values.
  final Library library;

  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  var _deleteFailed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The pushed recipe is only the starting point: an edit saved from the
    // editor lands in the bloc, and this screen is what the editor pops back
    // to. Falling back to it covers the frame in which it has been deleted.
    final recipe = context.select<RecipesBloc, Recipe>(
      (bloc) => bloc.state.recipes.firstWhere(
        (it) => it.id == widget.recipe.id,
        orElse: () => widget.recipe,
      ),
    );

    final schemaFields = <(FieldDefinition, String)>[
      for (final field in widget.library.fields)
        if (schemaFieldText(context, field, recipe) case final value?)
          (field, value),
    ];

    return RecipesMutationListener(
      mutation: RecipesMutation.recipeDeleted,
      onSuccess: () => Navigator.of(context).pop(),
      onFailure: () => setState(() => _deleteFailed = true),
      child: FScaffold(
        header: FHeader.nested(
          title: Text(recipe.name),
          prefixes: [
            FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
          ],
          suffixes: [
            FHeaderAction(
              icon: const Icon(FLucideIcons.pencil),
              semanticsLabel: l10n.recipeEditLabel,
              onPress: () => RecipeEditorPage.open(
                context,
                widget.library,
                recipe: recipe,
              ),
            ),
            FHeaderAction(
              icon: const Icon(FLucideIcons.trash2),
              semanticsLabel: l10n.recipeDeleteLabel,
              onPress: () => unawaited(_delete(recipe)),
            ),
          ],
        ),
        child: ListView(
          children: [
            if (_deleteFailed) FailureBanner(l10n.recipeDeleteFailure),
            const Center(child: RecipePlaceholderImage(size: 120)),
            if (schemaFields.isNotEmpty)
              _Section(
                title: l10n.recipeDetailsSectionTitle,
                children: [
                  for (final (field, value) in schemaFields)
                    _LabelledValue(
                      label: field.label,
                      child: SchemaFieldValue(field: field, value: value),
                    ),
                ],
              ),
            if (recipe.ingredients.isNotEmpty)
              _Section(
                title: l10n.recipeIngredientsSectionTitle,
                children: [
                  for (final ingredient in recipe.ingredients)
                    Text(_ingredientLine(ingredient)),
                ],
              ),
            if (recipe.steps.isNotEmpty)
              _Section(
                title: l10n.recipeStepsSectionTitle,
                children: [
                  for (final (index, step) in recipe.steps.indexed)
                    Text('${index + 1}. $step'),
                ],
              ),
            if (recipe.tags.isNotEmpty)
              _Section(
                title: l10n.recipeTagsSectionTitle,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in recipe.tags) FBadge(child: Text(tag)),
                    ],
                  ),
                ],
              ),
            if (recipe.notes.isNotEmpty)
              _Section(
                title: l10n.recipeNotesSectionTitle,
                children: [Text(recipe.notes)],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Recipe recipe) async {
    final l10n = context.l10n;
    final confirmed = await showRecipeConfirmDialog(
      context: context,
      title: l10n.recipeDeleteDialogTitle(recipe.name),
      description: l10n.recipeDeleteDialogDescription,
      confirmLabel: l10n.recipeDeleteDialogConfirm,
      cancelLabel: l10n.recipeDeleteDialogCancel,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleteFailed = false);
    context.read<RecipesBloc>().add(RecipesRecipeDeleted(recipe.id));
  }

  String _ingredientLine(Ingredient ingredient) => [
    ingredient.quantity,
    ingredient.unit,
    ingredient.name,
  ].where((part) => part.isNotEmpty).join(' ');
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [RecipeSectionTitle(title), ...children],
      ),
    );
  }
}

class _LabelledValue extends StatelessWidget {
  const _LabelledValue({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          label,
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        child,
      ],
    );
  }
}
