import 'package:recipes_api/recipes_api.dart';

/// {@template recipes_api}
/// The interface a recipes data source must implement.
///
/// Implementations own persistence and recovery; every layer above reaches
/// them only through this contract, so swapping local storage for a remote
/// source changes nothing upstream.
/// {@endtemplate}
abstract class RecipesApi {
  /// {@macro recipes_api}
  const RecipesApi();

  /// Emits a [RecipesSnapshot] whenever libraries, recipes, or the active
  /// library change.
  ///
  /// Whether the current snapshot is replayed to a late subscriber is an
  /// implementation detail, not part of this contract.
  Stream<RecipesSnapshot> watch();

  /// Stores [recipe], replacing any recipe that already carries its id.
  ///
  /// Throws a [RecipesPersistenceException] when the write fails.
  Future<void> saveRecipe(Recipe recipe);

  /// Removes the recipe carrying [id].
  ///
  /// Throws a [RecipeNotFoundException] when no such recipe exists, and a
  /// [RecipesPersistenceException] when the write fails.
  Future<void> deleteRecipe(String id);

  /// Marks the library carrying [id] as the one being browsed.
  ///
  /// Throws a [RecipesPersistenceException] when the write fails.
  Future<void> setActiveLibraryId(String id);

  /// Releases everything this api holds. It cannot be used afterwards.
  Future<void> close();
}

/// {@template recipe_not_found_exception}
/// Thrown when a recipe the caller asked for does not exist.
/// {@endtemplate}
class RecipeNotFoundException implements Exception {
  /// {@macro recipe_not_found_exception}
  const RecipeNotFoundException(this.id);

  /// The id no recipe was found for.
  final String id;

  @override
  String toString() => 'RecipeNotFoundException: no recipe with id "$id".';
}

/// {@template recipes_persistence_exception}
/// Thrown when writing to the underlying store fails.
/// {@endtemplate}
class RecipesPersistenceException implements Exception {
  /// {@macro recipes_persistence_exception}
  const RecipesPersistenceException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'RecipesPersistenceException: $message';
}
