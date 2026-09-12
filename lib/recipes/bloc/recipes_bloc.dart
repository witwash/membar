import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:recipes_repository/recipes_repository.dart';

part 'recipes_event.dart';
part 'recipes_state.dart';

/// {@template recipes_bloc}
/// Holds everything the recipe screens render: the libraries, the recipes, the
/// ingredients catalog, and the search term and tag filter narrowing them.
///
/// One instance backs the list, details and editor screens, which is how the
/// editor observes the result of a save it dispatched.
/// {@endtemplate}
class RecipesBloc extends Bloc<RecipesEvent, RecipesState> {
  /// {@macro recipes_bloc}
  RecipesBloc({required this._recipesRepository})
    : super(const RecipesState()) {
    on<RecipesSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    // Mutations run one at a time, so a rapid delete-then-save cannot
    // interleave into a snapshot neither of them intended.
    on<RecipesRecipeSaved>(_onRecipeSaved, transformer: sequential());
    on<RecipesRecipeDeleted>(_onRecipeDeleted, transformer: sequential());
    on<RecipesLibrarySelected>(_onLibrarySelected, transformer: sequential());
    on<RecipesIngredientSaved>(_onIngredientSaved, transformer: sequential());
    on<RecipesIngredientDeleted>(
      _onIngredientDeleted,
      transformer: sequential(),
    );
    on<RecipesIngredientsImported>(
      _onIngredientsImported,
      transformer: sequential(),
    );
    on<RecipesIngredientScopeWidened>(
      _onIngredientScopeWidened,
      transformer: sequential(),
    );
    on<RecipesSearchTermChanged>(_onSearchTermChanged);
    on<RecipesTagFilterToggled>(_onTagFilterToggled);
  }

  final RecipesRepository _recipesRepository;

  Future<void> _onSubscriptionRequested(
    RecipesSubscriptionRequested event,
    Emitter<RecipesState> emit,
  ) async {
    emit(state.copyWith(status: RecipesStatus.loading));

    await emit.forEach<RecipesSnapshot>(
      _recipesRepository.watch(),
      onData: (snapshot) => state.copyWith(
        status: RecipesStatus.success,
        libraries: snapshot.libraries,
        recipes: snapshot.recipes,
        ingredients: snapshot.ingredients,
        activeLibraryId: snapshot.activeLibraryId,
      ),
      // Handling the error here is what turns a broken stream into a failure
      // state rather than an exception escaping the handler.
      onError: (_, _) => state.copyWith(status: RecipesStatus.failure),
    );
  }

  Future<void> _onRecipeSaved(
    RecipesRecipeSaved event,
    Emitter<RecipesState> emit,
  ) async {
    emit(
      state.copyWith(
        mutation: RecipesMutation.recipeSaved,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    try {
      await _recipesRepository.saveRecipe(event.recipe);
      // Every emission names its own mutation: another mutation may have taken
      // the slot while this one awaited, and a bare status would report on it.
      emit(
        state.copyWith(
          mutation: RecipesMutation.recipeSaved,
          mutationStatus: RecipesMutationStatus.success,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.recipeSaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  Future<void> _onRecipeDeleted(
    RecipesRecipeDeleted event,
    Emitter<RecipesState> emit,
  ) async {
    emit(
      state.copyWith(
        mutation: RecipesMutation.recipeDeleted,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    try {
      await _recipesRepository.deleteRecipe(event.id);
      emit(
        state.copyWith(
          mutation: RecipesMutation.recipeDeleted,
          mutationStatus: RecipesMutationStatus.success,
        ),
      );
    } on RecipeNotFoundException {
      // Deleting an already-deleted recipe — a double-tapped confirm dialog,
      // or a stale details route. Letting it escape would strand saveStatus on
      // loading and leave the user watching a spinner forever.
      emit(
        state.copyWith(
          mutation: RecipesMutation.recipeDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.recipeDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  Future<void> _onLibrarySelected(
    RecipesLibrarySelected event,
    Emitter<RecipesState> emit,
  ) async {
    if (event.libraryId == state.activeLibraryId) return;

    emit(
      state.copyWith(
        mutation: RecipesMutation.librarySelected,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    try {
      await _recipesRepository.setActiveLibraryId(event.libraryId);
      // The filters clear only once the switch has actually happened. A filter
      // carried into a library that never had that tag would strand the user
      // on "No results" with chips nothing can match — but clearing it for a
      // switch that never took effect is worse still.
      emit(
        state.copyWith(
          mutation: RecipesMutation.librarySelected,
          mutationStatus: RecipesMutationStatus.success,
          searchTerm: '',
          activeTags: const {},
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.librarySelected,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  Future<void> _onIngredientSaved(
    RecipesIngredientSaved event,
    Emitter<RecipesState> emit,
  ) async {
    emit(
      state.copyWith(
        mutation: RecipesMutation.ingredientSaved,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    try {
      await _recipesRepository.saveIngredient(event.ingredient);
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientSaved,
          mutationStatus: RecipesMutationStatus.success,
        ),
      );
    } on IngredientNameTakenException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientSaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientSaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  Future<void> _onIngredientDeleted(
    RecipesIngredientDeleted event,
    Emitter<RecipesState> emit,
  ) async {
    emit(
      state.copyWith(
        mutation: RecipesMutation.ingredientDeleted,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    try {
      await _recipesRepository.deleteIngredient(event.id);
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientDeleted,
          mutationStatus: RecipesMutationStatus.success,
        ),
      );
    } on IngredientNotFoundException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on IngredientInUseException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  Future<void> _onIngredientsImported(
    RecipesIngredientsImported event,
    Emitter<RecipesState> emit,
  ) async {
    final importable = state.importableIngredients;
    if (importable.isEmpty) return;

    emit(
      state.copyWith(
        mutation: RecipesMutation.ingredientsImported,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    try {
      await _recipesRepository.saveIngredients([
        for (final ingredient in importable)
          CatalogIngredient(
            name: ingredient.name,
            defaultUnit: ingredient.defaultUnit,
            libraryIds: ingredient.libraryIds,
          ),
      ]);
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientsImported,
          mutationStatus: RecipesMutationStatus.success,
        ),
      );
    } on IngredientNameTakenException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientsImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientsImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  /// Adds the event's library to an entry picked from outside it.
  ///
  /// Reports nothing, succeed or fail: the user never asked for this write,
  /// and the row that triggered it links by name, not by scope. A failed widen
  /// leaves the entry out of scope until the next pick.
  Future<void> _onIngredientScopeWidened(
    RecipesIngredientScopeWidened event,
    Emitter<RecipesState> emit,
  ) async {
    final entry = state.ingredientById(event.ingredientId);
    if (entry == null || entry.libraryIds.contains(event.libraryId)) return;

    try {
      await _recipesRepository.saveIngredient(
        CatalogIngredient(
          id: entry.id,
          name: entry.name,
          defaultUnit: entry.defaultUnit,
          libraryIds: {...entry.libraryIds, event.libraryId},
        ),
      );
    } on IngredientNameTakenException {
      // Swallowed; see the doc comment.
    } on RecipesPersistenceException {
      // Swallowed; see the doc comment.
    }
  }

  void _onSearchTermChanged(
    RecipesSearchTermChanged event,
    Emitter<RecipesState> emit,
  ) {
    emit(state.copyWith(searchTerm: event.term));
  }

  void _onTagFilterToggled(
    RecipesTagFilterToggled event,
    Emitter<RecipesState> emit,
  ) {
    final tags = {...state.activeTags};
    if (!tags.remove(event.tag)) tags.add(event.tag);
    emit(state.copyWith(activeTags: tags));
  }
}
