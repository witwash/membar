import 'package:recipes_api/recipes_api.dart';

/// {@template recipes_repository}
/// A repository that exposes recipes, libraries, and the active library to the
/// app.
///
/// It owns no storage of its own: the [RecipesApi] handed to it decides where
/// the data lives, so swapping local storage for a remote source changes
/// nothing above this layer.
/// {@endtemplate}
class RecipesRepository {
  /// {@macro recipes_repository}
  const RecipesRepository({required this._recipesApi});

  final RecipesApi _recipesApi;

  /// Emits a [RecipesSnapshot] whenever libraries, recipes, ingredient
  /// libraries, catalog entries, or the active library change.
  Stream<RecipesSnapshot> watch() => _recipesApi.watch();

  /// Stores [recipe], replacing any recipe that already carries its id.
  ///
  /// Every row must reference a catalog entry in the ingredient library of
  /// the recipe's library, and no other recipe in that library may carry the
  /// same name without regard to case. Throws a [LibraryNotFoundException]
  /// when that library does not exist, an [IngredientNotFoundException] when a
  /// row references an entry that does not exist or belongs to another
  /// ingredient library, a [RecipeNameTakenException] when the name is taken,
  /// and a [RecipesPersistenceException] when the write fails.
  Future<void> saveRecipe(Recipe recipe) => _recipesApi.saveRecipe(recipe);

  /// Removes the recipe carrying [id].
  ///
  /// Throws a [RecipeNotFoundException] when no such recipe exists, and a
  /// [RecipesPersistenceException] when the write fails.
  Future<void> deleteRecipe(String id) => _recipesApi.deleteRecipe(id);

  /// Stores [ingredient] in the catalog, replacing any entry that already
  /// carries its id.
  ///
  /// Precondition: an entry that already exists keeps its
  /// `ingredientLibraryId`. Re-homing one would bypass the row removal a move
  /// performs.
  ///
  /// Throws an [IngredientLibraryNotFoundException] when its ingredient
  /// library does not exist, an [IngredientNameTakenException] when a
  /// different entry in the same ingredient library already carries the same
  /// name without regard to case, and a [RecipesPersistenceException] when
  /// the write fails.
  Future<void> saveIngredient(CatalogIngredient ingredient) =>
      _recipesApi.saveIngredient(ingredient);

  /// Removes the catalog entry carrying [id], along with every recipe row in
  /// every library that references it.
  ///
  /// Throws an [IngredientNotFoundException] when no such entry exists, and a
  /// [RecipesPersistenceException] when a write fails.
  Future<void> deleteIngredient(String id) => _recipesApi.deleteIngredient(id);

  /// Marks the library carrying [id] as the one being browsed.
  ///
  /// Throws a [RecipesPersistenceException] when the write fails.
  Future<void> setActiveLibraryId(String id) =>
      _recipesApi.setActiveLibraryId(id);

  /// Stores [library], replacing any library that already carries its id.
  ///
  /// A given [ingredientLibrary] is created alongside [library], which must
  /// point at it. Nothing is stored when either is refused.
  ///
  /// Replacing a library rewrites its recipes to match: a value whose field
  /// [library] no longer declares is dropped, a Select value equal to a key of
  /// `optionRenames[fieldId]` becomes that key's value, and a Select value
  /// naming an option the field no longer offers is dropped.
  ///
  /// Precondition: a replace keeps the stored `ingredientLibraryId` and
  /// `template`, and passes no [ingredientLibrary].
  ///
  /// Throws a [LibraryNameTakenException] when a different library already
  /// carries the same name without regard to case, an
  /// [IngredientLibraryNameTakenException] when an ingredient library already
  /// carries [ingredientLibrary]'s name without regard to case, an
  /// [IngredientLibraryNotFoundException] when the library's
  /// `ingredientLibraryId` resolves to neither a stored ingredient library nor
  /// [ingredientLibrary], and a [RecipesPersistenceException] when a write
  /// fails.
  Future<void> saveLibrary(
    Library library, {
    IngredientLibrary? ingredientLibrary,
    Map<String, Map<String, String>> optionRenames = const {},
  }) => _recipesApi.saveLibrary(
    library,
    ingredientLibrary: ingredientLibrary,
    optionRenames: optionRenames,
  );

  /// Adds [ingredients] and [recipes] together, all into the library carrying
  /// [libraryId]. Nothing is stored when any of them is refused.
  ///
  /// Every row must reference an entry in the library's ingredient library,
  /// stored or among [ingredients]. A new entry's name must be free in that
  /// ingredient library and among [ingredients], and a recipe's name must be
  /// free in the library and among [recipes], all without regard to case.
  ///
  /// Preconditions: no id in [ingredients] or [recipes] is already stored,
  /// every recipe's `libraryId` is [libraryId], and every entry's
  /// `ingredientLibraryId` is that library's. An import only adds.
  ///
  /// Throws a [LibraryNotFoundException] when [libraryId] matches no library,
  /// an [IngredientNameTakenException] when a new entry's name is taken, an
  /// [IngredientNotFoundException] when a row references no such entry, a
  /// [RecipeNameTakenException] when a recipe's name is taken, and a
  /// [RecipesPersistenceException] when a write fails.
  Future<void> importRecipes({
    required String libraryId,
    required List<CatalogIngredient> ingredients,
    required List<Recipe> recipes,
  }) => _recipesApi.importRecipes(
    libraryId: libraryId,
    ingredients: ingredients,
    recipes: recipes,
  );

  /// Removes the library carrying [id] along with every recipe in it.
  ///
  /// [successorId] names the library that becomes the active one when [id]
  /// was. The library's ingredient library and its entries stay.
  ///
  /// Throws a [LibraryNotFoundException] when [id] matches no library or
  /// [successorId] matches no *other* library, and a
  /// [RecipesPersistenceException] when a write fails.
  Future<void> deleteLibrary(String id, {required String successorId}) =>
      _recipesApi.deleteLibrary(id, successorId: successorId);

  /// Releases everything the underlying api holds. It cannot be used
  /// afterwards.
  ///
  /// The app never calls this — the repository lives for the process
  /// lifetime — but a test that constructs one must, or its api's stream
  /// outlives the test file.
  Future<void> close() => _recipesApi.close();
}
