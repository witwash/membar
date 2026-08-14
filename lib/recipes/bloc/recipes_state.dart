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
enum RecipesMutation { none, recipeSaved, recipeDeleted, librarySelected }

final class RecipesState extends Equatable {
  const RecipesState({
    this.status = RecipesStatus.initial,
    this.mutation = RecipesMutation.none,
    this.mutationStatus = RecipesMutationStatus.initial,
    this.libraries = const [],
    this.recipes = const [],
    this.activeLibraryId = '',
    this.searchTerm = '',
    this.activeTags = const {},
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

  /// The id of the library being browsed. Blank until the first snapshot
  /// arrives.
  final String activeLibraryId;

  /// What the user has typed into the search field.
  final String searchTerm;

  /// The tags the list is filtered by. Selected tags are OR'd together.
  final Set<String> activeTags;

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

  RecipesState copyWith({
    RecipesStatus? status,
    RecipesMutation? mutation,
    RecipesMutationStatus? mutationStatus,
    List<Library>? libraries,
    List<Recipe>? recipes,
    String? activeLibraryId,
    String? searchTerm,
    Set<String>? activeTags,
  }) {
    return RecipesState(
      status: status ?? this.status,
      mutation: mutation ?? this.mutation,
      mutationStatus: mutationStatus ?? this.mutationStatus,
      libraries: libraries ?? this.libraries,
      recipes: recipes ?? this.recipes,
      activeLibraryId: activeLibraryId ?? this.activeLibraryId,
      searchTerm: searchTerm ?? this.searchTerm,
      activeTags: activeTags ?? this.activeTags,
    );
  }

  @override
  List<Object?> get props => [
    status,
    mutation,
    mutationStatus,
    libraries,
    recipes,
    activeLibraryId,
    searchTerm,
    activeTags,
  ];
}
