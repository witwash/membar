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

  /// Emits a [RecipesSnapshot] whenever libraries, recipes, catalog entries,
  /// or the active library change.
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

  /// Stores [ingredient] in the catalog, replacing any entry that already
  /// carries its id.
  ///
  /// Throws an [IngredientNameTakenException] when a different entry already
  /// carries the same name without regard to case, and a
  /// [RecipesPersistenceException] when the write fails.
  Future<void> saveIngredient(CatalogIngredient ingredient);

  /// Runs the one-time import of ingredient names from saved recipes: stores
  /// [ingredients] in the catalog, links every recipe row whose name matches a
  /// catalog entry without regard to case, and records the import as done.
  ///
  /// Linking the rows is what lets a later rename reach those recipes, and
  /// what makes the usage guard count them.
  ///
  /// Nothing is stored when any entry is refused. Throws an
  /// [IngredientNameTakenException] when an entry's name, without regard to
  /// case, belongs to a different entry — stored or earlier in [ingredients] —
  /// and a [RecipesPersistenceException] when a write fails.
  Future<void> importIngredients(List<CatalogIngredient> ingredients);

  /// Removes the catalog entry carrying [id].
  ///
  /// Throws an [IngredientNotFoundException] when no such entry exists, an
  /// [IngredientInUseException] when any recipe in any library still
  /// references it, and a [RecipesPersistenceException] when the write fails.
  Future<void> deleteIngredient(String id);

  /// Marks the library carrying [id] as the one being browsed.
  ///
  /// Throws a [RecipesPersistenceException] when the write fails.
  Future<void> setActiveLibraryId(String id);

  /// Stores [library], replacing any library that already carries its id.
  ///
  /// Replacing a library rewrites its recipes to match: a value whose field
  /// [library] no longer declares is dropped, a Select value equal to a key of
  /// `optionRenames[fieldId]` becomes that key's value, and a Select value
  /// naming an option the field no longer offers is dropped.
  ///
  /// Throws a [LibraryNameTakenException] when a different library already
  /// carries the same name without regard to case, and a
  /// [RecipesPersistenceException] when a write fails.
  Future<void> saveLibrary(
    Library library, {
    Map<String, Map<String, String>> optionRenames = const {},
  });

  /// Removes the library carrying [id] along with every recipe in it.
  ///
  /// [successorId] names the library that inherits what cannot go with it:
  /// catalog entries visible only in [id] move there, and it becomes the
  /// active library when [id] was.
  ///
  /// Throws a [LibraryNotFoundException] when [id] matches no library or
  /// [successorId] matches no *other* library, and a
  /// [RecipesPersistenceException] when a write fails.
  Future<void> deleteLibrary(String id, {required String successorId});

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

/// {@template ingredient_not_found_exception}
/// Thrown when a catalog entry the caller asked for does not exist.
/// {@endtemplate}
class IngredientNotFoundException implements Exception {
  /// {@macro ingredient_not_found_exception}
  const IngredientNotFoundException(this.id);

  /// The id no catalog entry was found for.
  final String id;

  @override
  String toString() =>
      'IngredientNotFoundException: no catalog entry with id "$id".';
}

/// {@template ingredient_name_taken_exception}
/// Thrown when saving a catalog entry whose name, without regard to case,
/// already belongs to a different entry.
/// {@endtemplate}
class IngredientNameTakenException implements Exception {
  /// {@macro ingredient_name_taken_exception}
  const IngredientNameTakenException(this.name);

  /// The name another entry already carries.
  final String name;

  @override
  String toString() =>
      'IngredientNameTakenException: "$name" is already in the catalog.';
}

/// {@template ingredient_in_use_exception}
/// Thrown when deleting a catalog entry that recipes still reference.
/// {@endtemplate}
class IngredientInUseException implements Exception {
  /// {@macro ingredient_in_use_exception}
  const IngredientInUseException(this.id, this.recipeCount);

  /// The id of the entry that could not be deleted.
  final String id;

  /// How many recipes, across all libraries, reference the entry.
  final int recipeCount;

  @override
  String toString() =>
      'IngredientInUseException: catalog entry "$id" is used in '
      '$recipeCount recipe(s).';
}

/// {@template library_name_taken_exception}
/// Thrown when saving a library whose name, without regard to case, already
/// belongs to a different library.
/// {@endtemplate}
class LibraryNameTakenException implements Exception {
  /// {@macro library_name_taken_exception}
  const LibraryNameTakenException(this.name);

  /// The name another library already carries.
  final String name;

  @override
  String toString() =>
      'LibraryNameTakenException: a library named "$name" already exists.';
}

/// {@template library_not_found_exception}
/// Thrown when a library the caller asked for does not exist.
/// {@endtemplate}
class LibraryNotFoundException implements Exception {
  /// {@macro library_not_found_exception}
  const LibraryNotFoundException(this.id);

  /// The id no library was found for.
  final String id;

  @override
  String toString() => 'LibraryNotFoundException: no library with id "$id".';
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
