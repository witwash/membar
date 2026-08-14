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

  /// Emits a [RecipesSnapshot] whenever libraries, recipes, or the active
  /// library change.
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
