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

  /// Emits a [RecipesSnapshot] whenever libraries, recipes, catalog entries,
  /// or the active library change.
  Stream<RecipesSnapshot> watch() => _recipesApi.watch();

  /// Stores [recipe], replacing any recipe that already carries its id.
  ///
  /// Throws a [RecipesPersistenceException] when the write fails.
  Future<void> saveRecipe(Recipe recipe) => _recipesApi.saveRecipe(recipe);

  /// Removes the recipe carrying [id].
  ///
  /// Throws a [RecipeNotFoundException] when no such recipe exists, and a
  /// [RecipesPersistenceException] when the write fails.
  Future<void> deleteRecipe(String id) => _recipesApi.deleteRecipe(id);

  /// Stores [ingredient] in the catalog, replacing any entry that already
  /// carries its id.
  ///
  /// Throws an [IngredientNameTakenException] when a different entry already
  /// carries the same name without regard to case, and a
  /// [RecipesPersistenceException] when the write fails.
  Future<void> saveIngredient(CatalogIngredient ingredient) =>
      _recipesApi.saveIngredient(ingredient);

  /// Stores every entry in [ingredients] in one write, each replacing any
  /// entry that already carries its id.
  ///
  /// Nothing is stored when any of them fails. Throws an
  /// [IngredientNameTakenException] when an entry's name, without regard to
  /// case, belongs to a different entry — stored or earlier in [ingredients] —
  /// and a [RecipesPersistenceException] when the write fails.
  Future<void> saveIngredients(List<CatalogIngredient> ingredients) =>
      _recipesApi.saveIngredients(ingredients);

  /// Removes the catalog entry carrying [id].
  ///
  /// Throws an [IngredientNotFoundException] when no such entry exists, an
  /// [IngredientInUseException] when any recipe in any library still
  /// references it, and a [RecipesPersistenceException] when the write fails.
  Future<void> deleteIngredient(String id) => _recipesApi.deleteIngredient(id);

  /// Marks the library carrying [id] as the one being browsed.
  ///
  /// Throws a [RecipesPersistenceException] when the write fails.
  Future<void> setActiveLibraryId(String id) =>
      _recipesApi.setActiveLibraryId(id);

  /// Releases everything the underlying api holds. It cannot be used
  /// afterwards.
  ///
  /// The app never calls this — the repository lives for the process
  /// lifetime — but a test that constructs one must, or its api's stream
  /// outlives the test file.
  Future<void> close() => _recipesApi.close();
}
