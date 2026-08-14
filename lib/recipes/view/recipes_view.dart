import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

/// The recipe list of the active library, with the library switcher in the
/// header and a search field and tag filter above the list.
class RecipesView extends StatelessWidget {
  /// Creates a [RecipesView].
  const RecipesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<RecipesBloc>().state;
    final library = state.activeLibrary;

    return FScaffold(
      header: FHeader(
        title: library == null
            ? Text(l10n.recipesTitle)
            : LibrarySwitcher(
                libraries: state.libraries,
                activeLibrary: library,
              ),
        suffixes: [
          if (library != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.plus),
              semanticsLabel: l10n.recipeAddLabel,
              onPress: () => RecipeEditorPage.open(context, library),
            ),
        ],
      ),
      child: switch ((state.status, library)) {
        (RecipesStatus.failure, _) => Center(
          child: Text(l10n.recipesLoadFailure),
        ),
        // Keying the subtree on the library is what resets forui's managed
        // search control and the scroll position when the library changes.
        (RecipesStatus.success, final Library library) => _RecipeList(
          key: ValueKey(library.id),
          state: state,
          library: library,
        ),
        _ => const Center(child: FProgress()),
      },
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.state, required this.library, super.key});

  final RecipesState state;
  final Library library;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final libraryRecipes = state.recipes
        .where((recipe) => recipe.libraryId == library.id)
        .toList();
    final tags = _distinctTags(libraryRecipes);
    final visible = state.visibleRecipes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FTextField(
          hint: l10n.recipesSearchHint,
          control: FTextFieldControl.managed(
            onChange: (value) => context.read<RecipesBloc>().add(
              RecipesSearchTermChanged(value.text),
            ),
          ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TagFilter(tags: tags, activeTags: state.activeTags),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(
                  title: libraryRecipes.isEmpty
                      ? l10n.recipesEmptyLibraryTitle(library.name)
                      : l10n.recipesNoResultsTitle,
                  description: libraryRecipes.isEmpty
                      ? l10n.recipesEmptyLibraryDescription
                      : l10n.recipesNoResultsDescription,
                  // A blank screen needs a stronger affordance than the
                  // header's `+`; a screen filtered down to nothing does not,
                  // and offering one there would misread as "nothing exists".
                  onAdd: libraryRecipes.isEmpty
                      ? () => RecipeEditorPage.open(context, library)
                      : null,
                )
              : FTileGroup.builder(
                  count: visible.length,
                  tileBuilder: (context, index) {
                    final recipe = visible[index];
                    return RecipeTile(
                      recipe: recipe,
                      onPress: () => Navigator.of(context).push(
                        RecipeDetailsPage.route(
                          bloc: context.read<RecipesBloc>(),
                          recipe: recipe,
                          library: library,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// The tags offered by the filter: every tag in the library, not just those
  /// on the recipes currently visible — otherwise selecting one would remove
  /// the rest from the row that offered it.
  List<String> _distinctTags(List<Recipe> recipes) {
    final seen = <String>{};
    final tags = <String>[];
    for (final recipe in recipes) {
      for (final tag in recipe.tags) {
        if (seen.add(tag.toLowerCase())) tags.add(tag);
      }
    }
    return tags..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}

class _TagFilter extends StatelessWidget {
  const _TagFilter({required this.tags, required this.activeTags});

  final List<String> tags;
  final Set<String> activeTags;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recipesTagFilterLabel,
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              FTappable(
                semanticsLabel: tag,
                selected: activeTags.contains(tag),
                onPress: () => context.read<RecipesBloc>().add(
                  RecipesTagFilterToggled(tag),
                ),
                child: FBadge(
                  variant: activeTags.contains(tag)
                      ? FBadgeVariant.primary
                      : FBadgeVariant.outline,
                  child: Text(tag),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.description,
    this.onAdd,
  });

  final String title;
  final String description;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.typography.body.lg),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          if (onAdd case final onAdd?) ...[
            const SizedBox(height: 16),
            FButton(
              mainAxisSize: MainAxisSize.min,
              prefix: const Icon(FLucideIcons.plus),
              onPress: onAdd,
              child: Text(context.l10n.recipeAddLabel),
            ),
          ],
        ],
      ),
    );
  }
}
