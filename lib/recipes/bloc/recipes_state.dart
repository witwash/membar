part of 'recipes_bloc.dart';

/// The state of the subscription to the repository.
enum RecipesStatus { initial, loading, success, failure }

/// The state of the mutation currently in flight.
///
/// Kept separate from [RecipesStatus] so a failed save in the editor cannot
/// flash a banner over the list screen.
enum RecipesMutationStatus { initial, loading, success, failure }

/// Which mutation [RecipesState.mutationStatus] is reporting on.
///
/// Three screens share one bloc, and each cares about exactly one kind of
/// mutation. Naming the kind here is what lets each of them ignore the others
/// without keeping its own copy of "was that mine?" in widget state.
enum RecipesMutation {
  none,
  recipeSaved,
  recipeDeleted,
  librarySelected,
  ingredientSaved,
  ingredientDeleted,
  ingredientsImported,
}

/// A catalog entry the import would create from the ingredient rows of saved
/// recipes.
///
/// It carries no id: the entry's id is minted when the import is written, so
/// reading [RecipesState.importableIngredients] twice yields equal values.
final class ImportableIngredient extends Equatable {
  ImportableIngredient({
    required this.name,
    required Set<String> libraryIds,
    this.defaultUnit,
  }) : libraryIds = Set.unmodifiable(libraryIds);

  /// The first spelling of the name seen across the recipes using it.
  final String name;

  /// The unit spelled most often on those rows, or null when none carries one.
  final Unit? defaultUnit;

  /// Every library holding a recipe that uses the name.
  final Set<String> libraryIds;

  @override
  List<Object?> get props => [name, defaultUnit, libraryIds];
}

final class RecipesState extends Equatable {
  const RecipesState({
    this.status = RecipesStatus.initial,
    this.mutation = RecipesMutation.none,
    this.mutationStatus = RecipesMutationStatus.initial,
    this.libraries = const [],
    this.recipes = const [],
    this.ingredients = const [],
    this.activeLibraryId = '',
    this.searchTerm = '',
    this.activeTags = const {},
    this.ingredientsImported = false,
  });

  /// How the subscription to the repository is faring.
  final RecipesStatus status;

  /// The kind of mutation [mutationStatus] describes.
  final RecipesMutation mutation;

  /// How the mutation currently in flight is faring.
  final RecipesMutationStatus mutationStatus;

  /// Every library that exists, in creation order.
  final List<Library> libraries;

  /// Every recipe that exists, across all libraries. Read [visibleRecipes] to
  /// render a list.
  final List<Recipe> recipes;

  /// Every catalog entry that exists, across all libraries. Read
  /// [libraryIngredients] and [otherLibraryIngredients] to offer them.
  final List<CatalogIngredient> ingredients;

  /// The id of the library being browsed. Blank until the first snapshot
  /// arrives.
  final String activeLibraryId;

  /// What the user has typed into the search field.
  final String searchTerm;

  /// The tags the list is filtered by. Selected tags are OR'd together.
  final Set<String> activeTags;

  /// Whether the one-time import of ingredient names from saved recipes has
  /// run. Once it has, [importableIngredients] offers nothing.
  final bool ingredientsImported;

  /// The library being browsed, or null before the first snapshot arrives.
  ///
  /// A stored id that matches no library is the storage layer's problem — it
  /// falls back to the first library and rewrites the preference — so this is
  /// a plain lookup rather than a second fallback rule that could drift.
  Library? get activeLibrary {
    for (final library in libraries) {
      if (library.id == activeLibraryId) return library;
    }
    return null;
  }

  /// The recipes the list screen shows: those in the active library, narrowed
  /// by [searchTerm] and [activeTags], sorted alphabetically.
  ///
  /// A recipe whose `libraryId` matches no library is hidden by the same rule
  /// that hides the other libraries' recipes — hidden, never deleted.
  List<Recipe> get visibleRecipes {
    final term = searchTerm.trim().toLowerCase();
    final tags = {for (final tag in activeTags) tag.toLowerCase()};

    return recipes.where((recipe) {
      if (recipe.libraryId != activeLibraryId) return false;
      if (term.isNotEmpty && !recipe.name.toLowerCase().contains(term)) {
        return false;
      }
      if (tags.isNotEmpty &&
          !recipe.tags.any((tag) => tags.contains(tag.toLowerCase()))) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => compareCaseInsensitive(a.name, b.name));
  }

  /// The distinct tags used anywhere in the active library, in the spelling
  /// each was first given, ordered case-insensitively.
  ///
  /// Both the list's filter row and the editor's tag selector read this, so
  /// they cannot offer different tags — and a `blocTest` can reach it, which
  /// neither widget's own copy of the rule could.
  List<String> get libraryTags => foldCaseInsensitive(
    recipes
        .where((recipe) => recipe.libraryId == activeLibraryId)
        .expand((recipe) => recipe.tags),
  )..sort(compareCaseInsensitive);

  /// Catalog entries visible in the active library, ordered case-insensitively.
  List<CatalogIngredient> get libraryIngredients => _sortedIngredients(
    (entry) => entry.libraryIds.contains(activeLibraryId),
  );

  /// Catalog entries not visible in the active library — the picker's second
  /// section.
  List<CatalogIngredient> get otherLibraryIngredients => _sortedIngredients(
    (entry) => !entry.libraryIds.contains(activeLibraryId),
  );

  /// How many recipes reference each entry, keyed by catalog id. Absent means
  /// zero.
  ///
  /// Counts distinct recipes across every library, because deleting an entry
  /// is global. This recomputes on each read, so read it once per build.
  Map<String, int> get ingredientUsage {
    final usage = <String, int>{};
    for (final recipe in recipes) {
      final ids = {for (final row in recipe.ingredients) ?row.catalogId};
      for (final id in ids) {
        usage[id] = (usage[id] ?? 0) + 1;
      }
    }
    return usage;
  }

  /// The entries the import would create: one per ingredient name used in a
  /// saved recipe that no catalog entry claims, ordered case-insensitively.
  /// Empty once [ingredientsImported], so the import is offered only once.
  ///
  /// Names fold case-insensitively, keeping the first spelling seen. A row
  /// whose link resolves is already claimed, whatever name it stored, and a
  /// recipe whose library no longer exists contributes nothing, since an entry
  /// scoped only to it could never be picked. Each entry is scoped to every
  /// library using its name, and its default unit is the spelling used most
  /// often, with the first seen winning a tie.
  List<ImportableIngredient> get importableIngredients {
    if (ingredientsImported) return const [];

    final libraryIds = {for (final library in libraries) library.id};
    final catalogIds = {for (final entry in ingredients) entry.id};
    final claimed = {for (final entry in ingredients) _fold(entry.name)};
    final names = <String, String>{};
    final scopes = <String, Set<String>>{};
    final unitCounts = <String, Map<String, int>>{};

    for (final recipe in recipes) {
      if (!libraryIds.contains(recipe.libraryId)) continue;
      for (final row in recipe.ingredients) {
        final key = _fold(row.name);
        if (claimed.contains(key)) continue;
        if (catalogIds.contains(row.catalogId)) {
          continue;
        }

        names.putIfAbsent(key, () => row.name);
        (scopes[key] ??= {}).add(recipe.libraryId);
        final counts = unitCounts[key] ??= {};
        if (row.unit.isNotEmpty) counts[row.unit] = (counts[row.unit] ?? 0) + 1;
      }
    }

    return [
      for (final MapEntry(:key, value: name) in names.entries)
        ImportableIngredient(
          name: name,
          defaultUnit: _unitFromSpelling(_mostFrequent(unitCounts[key]!)),
          libraryIds: scopes[key]!,
        ),
    ]..sort((a, b) => compareCaseInsensitive(a.name, b.name));
  }

  /// The entry whose name matches [name] without regard to case or
  /// surrounding whitespace, or null when none does or [name] is blank.
  ///
  /// Catalog names are unique on that same folding, so at most one entry can
  /// match. This is the rule that links a saved ingredient row to an entry,
  /// makes the create sheet reuse an entry rather than add a second, and
  /// refuses a rename onto another entry's name.
  CatalogIngredient? ingredientNamed(String name) {
    final folded = _fold(name);
    if (folded.isEmpty) return null;
    for (final entry in ingredients) {
      if (_fold(entry.name) == folded) return entry;
    }
    return null;
  }

  /// The entry carrying [id], or null when it resolves to nothing.
  CatalogIngredient? ingredientById(String id) {
    for (final entry in ingredients) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static String _fold(String name) => name.trim().toLowerCase();

  /// The key counted most often. A map iterates in insertion order and only a
  /// strictly greater count replaces the leader, so the first seen wins a tie.
  static String? _mostFrequent(Map<String, int> counts) {
    String? leader;
    var most = 0;
    for (final MapEntry(:key, value: count) in counts.entries) {
      if (count > most) (leader, most) = (key, count);
    }
    return leader;
  }

  static Unit? _unitFromSpelling(String? spelling) {
    if (spelling == null) return null;
    final known = StandardUnit.values.asNameMap()[spelling.toLowerCase()];
    return known == null ? CustomUnit(spelling) : KnownUnit(known);
  }

  List<CatalogIngredient> _sortedIngredients(
    bool Function(CatalogIngredient entry) test,
  ) =>
      ingredients.where(test).toList()
        ..sort((a, b) => compareCaseInsensitive(a.name, b.name));

  RecipesState copyWith({
    RecipesStatus? status,
    RecipesMutation? mutation,
    RecipesMutationStatus? mutationStatus,
    List<Library>? libraries,
    List<Recipe>? recipes,
    List<CatalogIngredient>? ingredients,
    String? activeLibraryId,
    String? searchTerm,
    Set<String>? activeTags,
    bool? ingredientsImported,
  }) {
    return RecipesState(
      status: status ?? this.status,
      mutation: mutation ?? this.mutation,
      mutationStatus: mutationStatus ?? this.mutationStatus,
      libraries: libraries ?? this.libraries,
      recipes: recipes ?? this.recipes,
      ingredients: ingredients ?? this.ingredients,
      activeLibraryId: activeLibraryId ?? this.activeLibraryId,
      searchTerm: searchTerm ?? this.searchTerm,
      activeTags: activeTags ?? this.activeTags,
      ingredientsImported: ingredientsImported ?? this.ingredientsImported,
    );
  }

  @override
  List<Object?> get props => [
    status,
    mutation,
    mutationStatus,
    libraries,
    recipes,
    ingredients,
    activeLibraryId,
    searchTerm,
    activeTags,
    ingredientsImported,
  ];
}
