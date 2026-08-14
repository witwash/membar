import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:recipes_repository/recipes_repository.dart';

part 'recipes_event.dart';
part 'recipes_state.dart';

/// {@template recipes_bloc}
/// Holds everything the recipe screens render: the libraries, the recipes, and
/// the search term and tag filter narrowing them.
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
      emit(state.copyWith(mutationStatus: RecipesMutationStatus.success));
    } on RecipesPersistenceException {
      emit(state.copyWith(mutationStatus: RecipesMutationStatus.failure));
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
      emit(state.copyWith(mutationStatus: RecipesMutationStatus.success));
    } on RecipeNotFoundException {
      // Deleting an already-deleted recipe — a double-tapped confirm dialog,
      // or a stale details route. Letting it escape would strand saveStatus on
      // loading and leave the user watching a spinner forever.
      emit(state.copyWith(mutationStatus: RecipesMutationStatus.failure));
    } on RecipesPersistenceException {
      emit(state.copyWith(mutationStatus: RecipesMutationStatus.failure));
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
          mutationStatus: RecipesMutationStatus.success,
          searchTerm: '',
          activeTags: const {},
        ),
      );
    } on RecipesPersistenceException {
      emit(state.copyWith(mutationStatus: RecipesMutationStatus.failure));
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
