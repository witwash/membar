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
/// Every screen shares one bloc, and each cares about exactly one kind of
/// mutation. Naming the kind here is what lets each of them ignore the others
/// without keeping its own copy of "was that mine?" in widget state.
enum RecipesMutation {
  none,
  recipeSaved,
  recipeDeleted,
  librarySelected,
  librarySaved,
  libraryDeleted,
  fieldDeleted,
  fieldMoved,
  ingredientSaved,
  ingredientDeleted,
  starterRecipesImported,
}

final class RecipesState extends Equatable {
  const RecipesState({
    this.status = RecipesStatus.initial,
    this.mutation = RecipesMutation.none,
    this.mutationStatus = RecipesMutationStatus.initial,
    this.libraries = const [],
    this.recipes = const [],
    this.ingredientLibraries = const [],
    this.ingredients = const [],
    this.activeLibraryId = '',
    this.searchTerm = '',
    this.activeTags = const {},
    this.movedFieldId,
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

  /// Every ingredient library that exists, in creation order.
  final List<IngredientLibrary> ingredientLibraries;

  /// Every catalog entry that exists, across all ingredient libraries. Read
  /// [ingredientsIn] to offer them.
  final List<CatalogIngredient> ingredients;

  /// The id of the library being browsed. Blank until the first snapshot
  /// arrives.
  final String activeLibraryId;

  /// What the user has typed into the search field.
  final String searchTerm;

  /// The tags the list is filtered by. Selected tags are OR'd together.
  final Set<String> activeTags;

  /// The id of the field the latest [RecipesMutation.fieldMoved] emission
  /// reports on, or null before any move.
  ///
  /// Carried here rather than remembered by the screen that dispatched the
  /// move: moves queue, so by the time one reports back the screen may have
  /// dispatched another.
  final String? movedFieldId;

  /// The library being browsed, or null before the first snapshot arrives.
  ///
  /// A stored id that matches no library is the storage layer's problem — it
  /// falls back to the first library and rewrites the preference — so this is
  /// a plain lookup rather than a second fallback rule that could drift.
  Library? get activeLibrary => libraryById(activeLibraryId);

  /// The library carrying [id], or null when it resolves to nothing.
  Library? libraryById(String id) {
    for (final library in libraries) {
      if (library.id == id) return library;
    }
    return null;
  }

  /// The library whose name matches [name] without regard to case or
  /// surrounding whitespace, or null when none does or [name] is blank.
  ///
  /// Library names are unique on that same folding, so at most one can match.
  Library? libraryNamed(String name) {
    final folded = _fold(name);
    if (folded.isEmpty) return null;
    for (final library in libraries) {
      if (_fold(library.name) == folded) return library;
    }
    return null;
  }

  /// The recipe in the library carrying [libraryId] whose name matches [name]
  /// without regard to case or surrounding whitespace, or null when none does
  /// or [name] is blank.
  ///
  /// Recipe names are unique per library on that same folding, so at most one
  /// can match.
  Recipe? recipeNamed(String name, {required String libraryId}) {
    final folded = _fold(name);
    if (folded.isEmpty) return null;
    for (final recipe in recipes) {
      if (recipe.libraryId == libraryId && _fold(recipe.name) == folded) {
        return recipe;
      }
    }
    return null;
  }

  /// How many recipes the library carrying [libraryId] holds — the ones
  /// deleting it takes with it.
  int recipeCountIn(String libraryId) =>
      recipes.where((recipe) => recipe.libraryId == libraryId).length;

  /// How many recipes in the library carrying [libraryId] hold a value for
  /// the field carrying [fieldId] — the ones deleting the field clears.
  int fieldValueCount(String libraryId, String fieldId) => recipes
      .where(
        (recipe) =>
            recipe.libraryId == libraryId &&
            recipe.fieldValues.containsKey(fieldId),
      )
      .length;

  /// How many recipes in the library carrying [libraryId] hold one of
  /// [options] for the field carrying [fieldId] — the ones removing those
  /// options clears.
  ///
  /// The stored value is compared as it is, untrimmed: that is the comparison
  /// the storage layer makes when it clears them.
  int recipeCountUsingOptions(
    String libraryId,
    String fieldId,
    Set<String> options,
  ) => recipes
      .where(
        (recipe) =>
            recipe.libraryId == libraryId &&
            options.contains(recipe.fieldValues[fieldId]),
      )
      .length;

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

  /// The catalog entries in the ingredient library carrying
  /// [ingredientLibraryId], ordered case-insensitively.
  List<CatalogIngredient> ingredientsIn(String ingredientLibraryId) =>
      ingredients
          .where((entry) => entry.ingredientLibraryId == ingredientLibraryId)
          .toList()
        ..sort((a, b) => compareCaseInsensitive(a.name, b.name));

  /// How many recipes reference each entry, keyed by catalog id. Absent means
  /// zero.
  ///
  /// Counts distinct recipes across every library, because several libraries
  /// can share an ingredient library. This recomputes on each read, so read it
  /// once per build.
  Map<String, int> get ingredientUsage {
    final usage = <String, int>{};
    for (final recipe in recipes) {
      final ids = {for (final row in recipe.ingredients) row.catalogId};
      for (final id in ids) {
        usage[id] = (usage[id] ?? 0) + 1;
      }
    }
    return usage;
  }

  /// The recipes referencing the entry carrying [ingredientId], ordered by
  /// their library's creation order and then by name — the ones an edit to
  /// that entry reaches.
  ///
  /// [exceptLibraryId] leaves out one library's recipes, such as the one the
  /// user is looking at. A recipe whose library no longer exists is hidden
  /// everywhere else, so it is left out here too.
  List<Recipe> recipesUsingIngredient(
    String ingredientId, {
    String? exceptLibraryId,
  }) {
    final order = {
      for (final (index, library) in libraries.indexed) library.id: index,
    };
    return recipes
        .where(
          (recipe) =>
              recipe.libraryId != exceptLibraryId &&
              order.containsKey(recipe.libraryId) &&
              recipe.ingredients.any((row) => row.catalogId == ingredientId),
        )
        .toList()
      ..sort((a, b) {
        final byLibrary = order[a.libraryId]!.compareTo(order[b.libraryId]!);
        return byLibrary != 0
            ? byLibrary
            : compareCaseInsensitive(a.name, b.name);
      });
  }

  /// The entry in the ingredient library carrying [ingredientLibraryId] whose
  /// name matches [name] without regard to case or surrounding whitespace, or
  /// null when none does or [name] is blank.
  ///
  /// Names are unique within an ingredient library on that same folding, so
  /// at most one entry can match. This is the rule that links a recipe row to
  /// an entry, makes the create sheet reuse an entry rather than add a second,
  /// and refuses a rename onto another entry's name.
  CatalogIngredient? ingredientNamed(
    String name, {
    required String ingredientLibraryId,
  }) {
    final folded = _fold(name);
    if (folded.isEmpty) return null;
    for (final entry in ingredients) {
      if (entry.ingredientLibraryId == ingredientLibraryId &&
          _fold(entry.name) == folded) {
        return entry;
      }
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

  /// The ingredient library carrying [id], or null when it resolves to
  /// nothing.
  IngredientLibrary? ingredientLibraryById(String id) {
    for (final ingredientLibrary in ingredientLibraries) {
      if (ingredientLibrary.id == id) return ingredientLibrary;
    }
    return null;
  }

  /// The ingredient library whose name matches [name] without regard to case
  /// or surrounding whitespace, or null when none does or [name] is blank.
  ///
  /// Ingredient library names are unique on that same folding, so at most one
  /// can match.
  IngredientLibrary? ingredientLibraryNamed(String name) {
    final folded = _fold(name);
    if (folded.isEmpty) return null;
    for (final ingredientLibrary in ingredientLibraries) {
      if (_fold(ingredientLibrary.name) == folded) return ingredientLibrary;
    }
    return null;
  }

  static String _fold(String name) => name.trim().toLowerCase();

  RecipesState copyWith({
    RecipesStatus? status,
    RecipesMutation? mutation,
    RecipesMutationStatus? mutationStatus,
    List<Library>? libraries,
    List<Recipe>? recipes,
    List<IngredientLibrary>? ingredientLibraries,
    List<CatalogIngredient>? ingredients,
    String? activeLibraryId,
    String? searchTerm,
    Set<String>? activeTags,
    String? movedFieldId,
  }) {
    return RecipesState(
      status: status ?? this.status,
      mutation: mutation ?? this.mutation,
      mutationStatus: mutationStatus ?? this.mutationStatus,
      libraries: libraries ?? this.libraries,
      recipes: recipes ?? this.recipes,
      ingredientLibraries: ingredientLibraries ?? this.ingredientLibraries,
      ingredients: ingredients ?? this.ingredients,
      activeLibraryId: activeLibraryId ?? this.activeLibraryId,
      searchTerm: searchTerm ?? this.searchTerm,
      activeTags: activeTags ?? this.activeTags,
      movedFieldId: movedFieldId ?? this.movedFieldId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    mutation,
    mutationStatus,
    libraries,
    recipes,
    ingredientLibraries,
    ingredients,
    activeLibraryId,
    searchTerm,
    activeTags,
    movedFieldId,
  ];
}
