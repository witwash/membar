import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

part 'recipes_event.dart';
part 'recipes_state.dart';

/// {@template recipes_bloc}
/// Holds everything the recipe screens render: the libraries, the recipes, the
/// ingredients catalog, and the search term and tag filter narrowing them.
///
/// One instance backs every screen, which is how an editor observes the
/// result of a save it dispatched.
/// {@endtemplate}
class RecipesBloc extends Bloc<RecipesEvent, RecipesState> {
  /// {@macro recipes_bloc}
  RecipesBloc({
    required this._recipesRepository,
    required this._starterRecipesRepository,
  }) : super(const RecipesState()) {
    on<RecipesSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    // Each kind of mutation runs one at a time. Two kinds can still overlap:
    // the storage layer queues their writes, but _onFieldDeleted and
    // _onFieldMoved build their write from the state, so each relies on no
    // other library edit being in flight. The sheets that edit a library are
    // modal. A move is not, but moves queue behind one another, and reorder
    // mode offers neither delete nor the field sheet. Leaving reorder mode
    // while a move is still being written reopens the overlap; nothing guards
    // that window.
    on<RecipesRecipeSaved>(_onRecipeSaved, transformer: sequential());
    on<RecipesRecipeDeleted>(_onRecipeDeleted, transformer: sequential());
    on<RecipesLibrarySelected>(_onLibrarySelected, transformer: sequential());
    on<RecipesLibrarySaved>(_onLibrarySaved, transformer: sequential());
    on<RecipesLibraryDeleted>(_onLibraryDeleted, transformer: sequential());
    on<RecipesFieldDeleted>(_onFieldDeleted, transformer: sequential());
    on<RecipesFieldMoved>(_onFieldMoved, transformer: sequential());
    on<RecipesIngredientSaved>(_onIngredientSaved, transformer: sequential());
    on<RecipesIngredientDeleted>(
      _onIngredientDeleted,
      transformer: sequential(),
    );
    on<RecipesStarterRecipesImported>(
      _onStarterRecipesImported,
      transformer: sequential(),
    );
    on<RecipesSearchTermChanged>(_onSearchTermChanged);
    on<RecipesTagFilterToggled>(_onTagFilterToggled);
  }

  final RecipesRepository _recipesRepository;

  final StarterRecipesRepository _starterRecipesRepository;

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
        ingredientLibraries: snapshot.ingredientLibraries,
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
    } on LibraryNotFoundException {
      // The recipe's library was deleted from another screen while the editor
      // was open.
      emit(
        state.copyWith(
          mutation: RecipesMutation.recipeSaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on IngredientNotFoundException {
      // A row's entry was deleted from another screen while the editor was
      // open.
      emit(
        state.copyWith(
          mutation: RecipesMutation.recipeSaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipeNameTakenException {
      // The editor refuses a taken name, so another recipe took this one
      // after the editor validated it.
      emit(
        state.copyWith(
          mutation: RecipesMutation.recipeSaved,
          mutationStatus: RecipesMutationStatus.failure,
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

  Future<void> _onLibrarySaved(
    RecipesLibrarySaved event,
    Emitter<RecipesState> emit,
  ) async {
    emit(
      state.copyWith(
        mutation: RecipesMutation.librarySaved,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    try {
      await _recipesRepository.saveLibrary(
        event.library,
        ingredientLibrary: event.ingredientLibrary,
        optionRenames: event.optionRenames,
      );
      emit(
        state.copyWith(
          mutation: RecipesMutation.librarySaved,
          mutationStatus: RecipesMutationStatus.success,
        ),
      );
    } on LibraryNameTakenException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.librarySaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on IngredientLibraryNameTakenException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.librarySaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on IngredientLibraryNotFoundException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.librarySaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.librarySaved,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  Future<void> _onLibraryDeleted(
    RecipesLibraryDeleted event,
    Emitter<RecipesState> emit,
  ) async {
    // Read before the write: by the time it returns, the snapshot has already
    // made the successor the active library.
    final wasActive = event.id == state.activeLibraryId;

    emit(
      state.copyWith(
        mutation: RecipesMutation.libraryDeleted,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    try {
      await _recipesRepository.deleteLibrary(
        event.id,
        successorId: event.successorId,
      );
      // Deleting the active library switches to its successor, so the filters
      // clear for the reason they do on a manual switch.
      emit(
        state.copyWith(
          mutation: RecipesMutation.libraryDeleted,
          mutationStatus: RecipesMutationStatus.success,
          searchTerm: wasActive ? '' : null,
          activeTags: wasActive ? const {} : null,
        ),
      );
    } on LibraryNotFoundException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.libraryDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.libraryDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  /// Saves the event's library without the event's field.
  ///
  /// Reported as its own kind rather than as a library save: the Fields
  /// screen deletes a field while the sheet above it saves one, and sharing a
  /// kind would raise one's failure on the other.
  Future<void> _onFieldDeleted(
    RecipesFieldDeleted event,
    Emitter<RecipesState> emit,
  ) async {
    emit(
      state.copyWith(
        mutation: RecipesMutation.fieldDeleted,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    final library = state.libraryById(event.libraryId);
    if (library == null ||
        library.fields.every((field) => field.id != event.fieldId)) {
      emit(
        state.copyWith(
          mutation: RecipesMutation.fieldDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
      return;
    }

    try {
      await _recipesRepository.saveLibrary(
        Library(
          id: library.id,
          name: library.name,
          ingredientLibraryId: library.ingredientLibraryId,
          template: library.template,
          fields: [
            for (final field in library.fields)
              if (field.id != event.fieldId) field,
          ],
        ),
      );
      emit(
        state.copyWith(
          mutation: RecipesMutation.fieldDeleted,
          mutationStatus: RecipesMutationStatus.success,
        ),
      );
    } on LibraryNameTakenException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.fieldDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.fieldDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  /// Saves the event's library with the event's field moved by its delta.
  ///
  /// The position is resolved here, against the state, rather than sent by
  /// the view: a second tap queued behind the first then moves the field on
  /// from where the first left it.
  Future<void> _onFieldMoved(
    RecipesFieldMoved event,
    Emitter<RecipesState> emit,
  ) async {
    final library = state.libraryById(event.libraryId);
    final index =
        library?.fields.indexWhere((field) => field.id == event.fieldId) ?? -1;
    final target = index + event.delta;
    // A tap on a field already at the end it was sent towards: nothing to do,
    // and nothing failed.
    final isStaleTap =
        library != null &&
        index != -1 &&
        (target == index || target < 0 || target >= library.fields.length);
    if (isStaleTap) return;

    emit(
      state.copyWith(
        mutation: RecipesMutation.fieldMoved,
        mutationStatus: RecipesMutationStatus.loading,
        movedFieldId: event.fieldId,
      ),
    );

    if (library == null || index == -1) {
      emit(
        state.copyWith(
          mutation: RecipesMutation.fieldMoved,
          mutationStatus: RecipesMutationStatus.failure,
          movedFieldId: event.fieldId,
        ),
      );
      return;
    }

    try {
      await _recipesRepository.saveLibrary(
        Library(
          id: library.id,
          name: library.name,
          ingredientLibraryId: library.ingredientLibraryId,
          template: library.template,
          fields: [...library.fields]
            ..removeAt(index)
            ..insert(target, library.fields[index]),
        ),
      );
      emit(
        state.copyWith(
          mutation: RecipesMutation.fieldMoved,
          mutationStatus: RecipesMutationStatus.success,
          movedFieldId: event.fieldId,
        ),
      );
    } on LibraryNameTakenException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.fieldMoved,
          mutationStatus: RecipesMutationStatus.failure,
          movedFieldId: event.fieldId,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.fieldMoved,
          mutationStatus: RecipesMutationStatus.failure,
          movedFieldId: event.fieldId,
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
    } on IngredientLibraryNotFoundException {
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
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.ingredientDeleted,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    }
  }

  /// Imports the event's picks into the event's library.
  ///
  /// The import is built here, against the state, so the picks link to the
  /// freshest catalog. Anything that changed since is caught by the
  /// repository's validation and reported as a failure.
  Future<void> _onStarterRecipesImported(
    RecipesStarterRecipesImported event,
    Emitter<RecipesState> emit,
  ) async {
    emit(
      state.copyWith(
        mutation: RecipesMutation.starterRecipesImported,
        mutationStatus: RecipesMutationStatus.loading,
      ),
    );

    final library = state.libraryById(event.libraryId);
    if (library == null) {
      emit(
        state.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
      return;
    }

    final ({List<CatalogIngredient> ingredients, List<Recipe> recipes}) import;
    try {
      import = _starterRecipesRepository.buildImport(
        set: event.set,
        names: event.names,
        library: library,
        entries: state.ingredientsIn(library.ingredientLibraryId),
        system: event.system,
      );
    } on Object catch (error, stackTrace) {
      // buildImport documents no failure, so a throw is a bug. Left uncaught
      // it would strand the catalog in loading with Import disabled.
      addError(error, stackTrace);
      emit(
        state.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
      return;
    }

    try {
      await _recipesRepository.importRecipes(
        libraryId: library.id,
        ingredients: import.ingredients,
        recipes: import.recipes,
      );
      // A filter left over from before would hide what was just imported.
      emit(
        state.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.success,
          searchTerm: '',
          activeTags: const {},
        ),
      );
    } on LibraryNotFoundException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on IngredientNameTakenException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on IngredientNotFoundException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipeNameTakenException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
    } on RecipesPersistenceException {
      emit(
        state.copyWith(
          mutation: RecipesMutation.starterRecipesImported,
          mutationStatus: RecipesMutationStatus.failure,
        ),
      );
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
