import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/l10n/l10n.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/starter_catalog/starter_catalog.dart';
import 'package:membar/ui/ui.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

/// The bundled starter recipes for [template], which the user searches, picks
/// from and imports into [library].
class StarterCatalogPage extends StatefulWidget {
  /// Creates a [StarterCatalogPage] importing into [library].
  const StarterCatalogPage({
    required this.library,
    required this.template,
    super.key,
  });

  /// The route that pushes this page, re-providing [bloc].
  static Route<void> route({
    required RecipesBloc bloc,
    required Library library,
    required LibraryTemplate template,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'starter-catalog'),
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: bloc),
          BlocProvider(
            create: (context) => StarterCatalogBloc(
              starterRecipesRepository: context
                  .read<StarterRecipesRepository>(),
              template: template,
            )..add(const StarterCatalogRequested()),
          ),
        ],
        child: StarterCatalogPage(library: library, template: template),
      ),
    );
  }

  /// The library the picked recipes are imported into.
  final Library library;

  /// Which bundled set is offered.
  final LibraryTemplate template;

  @override
  State<StarterCatalogPage> createState() => _StarterCatalogPageState();
}

class _StarterCatalogPageState extends State<StarterCatalogPage> {
  var _importFailed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<StarterCatalogBloc>().state;
    final importing = context.select<RecipesBloc, bool>(
      (bloc) =>
          bloc.state.mutation == RecipesMutation.starterRecipesImported &&
          bloc.state.mutationStatus == RecipesMutationStatus.loading,
    );
    final count = state.selectedKeys.length;

    return RecipesMutationListener(
      mutation: RecipesMutation.starterRecipesImported,
      onSuccess: (_) => Navigator.of(context).pop(),
      onFailure: () => setState(() => _importFailed = true),
      child: FScaffold(
        header: FHeader.nested(
          title: Text(l10n.starterCatalogTitle),
          prefixes: [
            FHeaderAction.back(onPress: () => Navigator.of(context).maybePop()),
          ],
        ),
        footer: state.status == StarterCatalogStatus.success
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.spacing200),
                child: FButton(
                  onPress: count == 0 || importing ? null : _import,
                  child: Text(l10n.starterCatalogImportLabel(count)),
                ),
              )
            : null,
        child: switch (state.status) {
          StarterCatalogStatus.success => _Catalog(
            state: state,
            library: widget.library,
            template: widget.template,
            importFailed: _importFailed,
          ),
          StarterCatalogStatus.failure => Center(
            child: Text(l10n.starterCatalogLoadFailure),
          ),
          _ => const Center(child: FProgress()),
        },
      ),
    );
  }

  Future<void> _import() async {
    final catalog = context.read<StarterCatalogBloc>().state;
    final recipesBloc = context.read<RecipesBloc>();
    final picked = catalog.selectedRecipes;
    final clashes = [
      for (final recipe in picked)
        if (recipesBloc.state.recipeNamed(
              recipe.name,
              libraryId: widget.library.id,
            ) !=
            null)
          recipe,
    ];

    final names = {for (final recipe in picked) recipe.key: recipe.name};
    if (clashes.isNotEmpty) {
      final renames = await StarterRenameSheet.show(
        context,
        library: widget.library,
        clashes: clashes,
        others: [
          for (final recipe in picked)
            if (!clashes.contains(recipe)) recipe,
        ],
      );
      if (renames == null) return;
      for (final MapEntry(:key, :value) in renames.entries) {
        if (value == null) {
          names.remove(key);
        } else {
          names[key] = value;
        }
      }
    }

    if (!mounted) return;
    setState(() => _importFailed = false);
    recipesBloc.add(
      RecipesStarterRecipesImported(
        libraryId: widget.library.id,
        set: catalog.set!,
        names: names,
        system: catalog.system,
      ),
    );
  }
}

class _Catalog extends StatelessWidget {
  const _Catalog({
    required this.state,
    required this.library,
    required this.template,
    required this.importFailed,
  });

  final StarterCatalogState state;
  final Library library;
  final LibraryTemplate template;
  final bool importFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<StarterCatalogBloc>();
    final recipesState = context.watch<RecipesBloc>().state;
    final visible = state.visibleRecipes;
    final ingredientNames = {
      for (final ingredient in state.set!.ingredients)
        ingredient.key: ingredient.name,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.spacing150,
      children: [
        if (importFailed) FailureBanner(l10n.starterCatalogImportFailure),
        // Coffee rows are all counted, so the system changes nothing there.
        if (template == LibraryTemplate.cocktails)
          FSelect<MeasureSystem>(
            label: Text(l10n.starterCatalogMeasureLabel),
            items: {
              l10n.starterCatalogMetricLabel: MeasureSystem.metric,
              l10n.starterCatalogImperialLabel: MeasureSystem.imperial,
            },
            control: FSelectControl.lifted(
              value: state.system,
              onChange: (value) => bloc.add(
                StarterCatalogMeasureSystemChanged(
                  value ?? MeasureSystem.metric,
                ),
              ),
            ),
          ),
        FTextField(
          hint: l10n.starterCatalogSearchHint,
          control: FTextFieldControl.managed(
            onChange: (value) =>
                bloc.add(StarterCatalogSearchChanged(value.text)),
          ),
        ),
        if (visible.isEmpty)
          Expanded(child: Center(child: Text(l10n.starterCatalogNoResults)))
        else ...[
          _SelectableTile(
            title: state.allVisibleSelected
                ? l10n.starterCatalogDeselectAllLabel
                : l10n.starterCatalogSelectAllLabel,
            selected: state.allVisibleSelected,
            onPress: () => bloc.add(const StarterCatalogVisibleToggled()),
          ),
          Expanded(
            child: FTileGroup.builder(
              count: visible.length,
              tileBuilder: (context, index) {
                final recipe = visible[index];
                return _SelectableTile(
                  title: recipe.name,
                  subtitle: _subtitle(recipe, ingredientNames),
                  badge:
                      recipesState.recipeNamed(
                            recipe.name,
                            libraryId: library.id,
                          ) ==
                          null
                      ? null
                      : l10n.starterCatalogInLibraryBadge,
                  selected: state.selectedKeys.contains(recipe.key),
                  onPress: () =>
                      bloc.add(StarterCatalogRecipeToggled(recipe.key)),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// What tells a row apart from its neighbours: a cocktail's first three
  /// ingredients, or a coffee's brew method, since most coffees share the
  /// same two ingredients.
  String? _subtitle(StarterRecipe recipe, Map<String, String> ingredients) =>
      switch (template) {
        LibraryTemplate.cocktails =>
          recipe.rows
              .take(3)
              .map((row) => ingredients[row.ingredient])
              .nonNulls
              .join(', '),
        LibraryTemplate.coffee => recipe.fields['Brew method']?.toString(),
      };
}

/// A tile carrying a checkbox, read out as one node: its title, subtitle and
/// badge, and whether it is selected.
class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.title,
    required this.selected,
    required this.onPress,
    this.subtitle,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final badge = this.badge;

    return FTile(
      semanticsLabel: [title, ?subtitle, ?badge].join(', '),
      selected: selected,
      // The tile is the one tap target; the checkbox only shows its state.
      prefix: IgnorePointer(
        child: ExcludeSemantics(child: FCheckbox(value: selected)),
      ),
      // The label above already reads these; left in, the tile would merge
      // them in a second time.
      title: ExcludeSemantics(child: Text(title)),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : ExcludeSemantics(child: Text(subtitle)),
      suffix: badge == null
          ? null
          : ExcludeSemantics(
              child: FBadge(variant: FBadgeVariant.outline, child: Text(badge)),
            ),
      onPress: onPress,
    );
  }
}
