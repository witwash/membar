import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _reportRecoveryError(String message) => debugPrint(message);

/// {@template local_storage_recipes_api}
/// A [RecipesApi] backed by `shared_preferences`.
///
/// Libraries, recipes, catalog entries and the active library id are stored
/// under separate keys, each rewritten in full on every mutation. That is O(n)
/// per save, which is the ceiling that motivates a real database once a library
/// grows past personal scale.
///
/// A fresh install — one with no stored schema version — is seeded from
/// [LibraryTemplates]. Seeding is driven by the schema version rather than by
/// "the libraries list is empty" so that a deliberately emptied library list
/// stays empty instead of resurrecting on the next launch.
///
/// Every mutation runs after the ones already queued, so two overlapping
/// callers cannot compute from the same snapshot and drop each other's write.
/// {@endtemplate}
class LocalStorageRecipesApi extends RecipesApi {
  /// {@macro local_storage_recipes_api}
  ///
  /// `templates` supplies the libraries a fresh install is seeded with.
  /// `onRecoveryError` reports every recovered-from problem — a corrupt blob,
  /// a stale active library id, a failed seed write — and defaults to
  /// [debugPrint]. Injecting it keeps the recovery branches assertable and
  /// leaves a seam for a real logger.
  LocalStorageRecipesApi({
    required this._plugin,
    this._templates = const LibraryTemplates(),
    this._onRecoveryError = _reportRecoveryError,
  }) {
    final (:snapshot, :writes) = _restore();
    _subject = BehaviorSubject<RecipesSnapshot>.seeded(snapshot);
    _initialWrite = _serialized(() => _persistInitial(writes));
  }

  /// The version of the stored schema. Its presence — not the libraries
  /// list — is what distinguishes a fresh install from an existing one.
  @visibleForTesting
  static const kSchemaVersionKey = '__schema_version_key__';

  /// The key the encoded list of libraries is stored under.
  @visibleForTesting
  static const kLibrariesKey = '__libraries_key__';

  /// The key the encoded list of recipes is stored under.
  @visibleForTesting
  static const kRecipesKey = '__recipes_key__';

  /// The key the encoded list of catalog entries is stored under.
  @visibleForTesting
  static const kIngredientsKey = '__ingredients_key__';

  /// The key the version of the completed ingredient import is stored under.
  /// Absent until the import has run.
  @visibleForTesting
  static const kIngredientsImportVersionKey =
      '__ingredients_import_version_key__';

  /// The key the id of the library being browsed is stored under.
  @visibleForTesting
  static const kActiveLibraryIdKey = '__active_library_id_key__';

  /// The schema version a fresh install is seeded at, and the one an older
  /// install is migrated to.
  ///
  /// Version 2 added [kIngredientsKey]. Migrating to it writes an empty
  /// catalog and leaves recipes and libraries untouched.
  @visibleForTesting
  static const kSchemaVersion = 2;

  /// The version [importIngredients] records. An install whose stored version
  /// is lower has not run this import, so it is offered again.
  @visibleForTesting
  static const kIngredientsImportVersion = 1;

  final SharedPreferences _plugin;
  final LibraryTemplates _templates;
  final void Function(String message) _onRecoveryError;

  late final BehaviorSubject<RecipesSnapshot> _subject;
  late final Future<void> _initialWrite;
  Future<void> _queue = Future<void>.value();

  /// Completes once the writes the constructor scheduled — seeding a fresh
  /// install, or rewriting a recovered value — have finished.
  ///
  /// The api is fully usable before it completes: the snapshot is composed in
  /// memory and seeded synchronously, so nothing waits on disk. Awaiting this
  /// is only useful to a test that asserts what landed in storage.
  @visibleForTesting
  Future<void> get initialWrite => _initialWrite;

  @override
  Stream<RecipesSnapshot> watch() => _subject.stream;

  @override
  Future<void> saveRecipe(Recipe recipe) => _serialized(() async {
    final recipes = [..._subject.value.recipes];
    final index = recipes.indexWhere((stored) => stored.id == recipe.id);
    if (index == -1) {
      recipes.add(recipe);
    } else {
      recipes[index] = recipe;
    }

    await _write(kRecipesKey, _encodeRecipes(recipes));
    _emit(recipes: recipes);
  });

  @override
  Future<void> deleteRecipe(String id) => _serialized(() async {
    final recipes = [..._subject.value.recipes];
    final index = recipes.indexWhere((stored) => stored.id == id);
    if (index == -1) throw RecipeNotFoundException(id);
    recipes.removeAt(index);

    await _write(kRecipesKey, _encodeRecipes(recipes));
    _emit(recipes: recipes);
  });

  @override
  Future<void> saveIngredient(CatalogIngredient ingredient) =>
      _serialized(() async {
        final catalog = _merged(_subject.value.ingredients, [ingredient]);

        await _write(kIngredientsKey, _encodeIngredients(catalog));
        _emit(ingredients: catalog);
      });

  @override
  Future<void> importIngredients(List<CatalogIngredient> ingredients) =>
      _serialized(() async {
        final current = _subject.value;
        final catalog = _merged(current.ingredients, ingredients);
        final recipes = _linked(current.recipes, catalog);

        // Catalog first, so no write can link a row to an entry that was never
        // stored; the version last, so a failure part-way leaves the import on
        // offer rather than recorded as done.
        await _write(kIngredientsKey, _encodeIngredients(catalog));
        await _write(kRecipesKey, _encodeRecipes(recipes));
        await _write(kIngredientsImportVersionKey, kIngredientsImportVersion);
        _emit(
          recipes: recipes,
          ingredients: catalog,
          ingredientsImported: true,
        );
      });

  @override
  Future<void> deleteIngredient(String id) => _serialized(() async {
    final current = _subject.value;
    final ingredients = [...current.ingredients];
    final index = ingredients.indexWhere((stored) => stored.id == id);
    if (index == -1) throw IngredientNotFoundException(id);

    final recipeCount = current.recipes
        .where(
          (recipe) => recipe.ingredients.any(
            (ingredient) => ingredient.catalogId == id,
          ),
        )
        .length;
    if (recipeCount > 0) throw IngredientInUseException(id, recipeCount);
    ingredients.removeAt(index);

    await _write(kIngredientsKey, _encodeIngredients(ingredients));
    _emit(ingredients: ingredients);
  });

  @override
  Future<void> setActiveLibraryId(String id) => _serialized(() async {
    await _write(kActiveLibraryIdKey, id);
    _emit(activeLibraryId: id);
  });

  @override
  Future<void> close() => _subject.close();

  /// [catalog] with [ingredients] merged in, each replacing any entry that
  /// carries its id.
  ///
  /// Each entry is checked against the ones merged before it, so two entries
  /// in one batch cannot fold onto each other either.
  static List<CatalogIngredient> _merged(
    List<CatalogIngredient> catalog,
    List<CatalogIngredient> ingredients,
  ) {
    final merged = [...catalog];
    for (final ingredient in ingredients) {
      final taken = merged.any(
        (stored) =>
            stored.id != ingredient.id &&
            compareCaseInsensitive(stored.name, ingredient.name) == 0,
      );
      if (taken) throw IngredientNameTakenException(ingredient.name);

      final index = merged.indexWhere((stored) => stored.id == ingredient.id);
      if (index == -1) {
        merged.add(ingredient);
      } else {
        merged[index] = ingredient;
      }
    }
    return merged;
  }

  /// [recipes] with every row whose link does not resolve pointed at the
  /// [catalog] entry its name matches.
  ///
  /// A row whose link already resolves keeps it, and a row matching nothing
  /// keeps whatever it stored — a dangling link is reported, never rewritten.
  static List<Recipe> _linked(
    List<Recipe> recipes,
    List<CatalogIngredient> catalog,
  ) {
    final ids = {for (final entry in catalog) entry.id};
    final idsByName = {
      for (final entry in catalog) entry.name.toLowerCase(): entry.id,
    };

    return [
      for (final recipe in recipes)
        Recipe(
          id: recipe.id,
          libraryId: recipe.libraryId,
          name: recipe.name,
          ingredients: [
            for (final row in recipe.ingredients)
              ids.contains(row.catalogId)
                  ? row
                  : Ingredient(
                      name: row.name,
                      quantity: row.quantity,
                      unit: row.unit,
                      catalogId:
                          idsByName[row.name.toLowerCase()] ?? row.catalogId,
                    ),
          ],
          steps: recipe.steps,
          tags: recipe.tags,
          notes: recipe.notes,
          fieldValues: recipe.fieldValues,
        ),
    ];
  }

  /// Runs [mutation] after every mutation already queued.
  ///
  /// Two overlapping callers would otherwise each compute a list from the same
  /// snapshot, and the second write would drop the first. Failures reach the
  /// caller without stalling the queue behind them.
  Future<void> _serialized(Future<void> Function() mutation) {
    final result = _queue.then((_) => mutation());
    _queue = result.then((_) {}, onError: (_, _) {});
    return result;
  }

  /// Emits whichever values are given over whatever the
  /// subject holds *now*.
  ///
  /// Reading the subject after the write rather than before it is what stops
  /// two overlapping mutations from reverting each other: the api owes its
  /// callers a consistent snapshot on its own, not one that depends on a
  /// caller two layers up serializing them.
  void _emit({
    List<Recipe>? recipes,
    List<CatalogIngredient>? ingredients,
    String? activeLibraryId,
    bool? ingredientsImported,
  }) {
    final current = _subject.value;
    _subject.add(
      RecipesSnapshot(
        libraries: current.libraries,
        recipes: recipes ?? current.recipes,
        ingredients: ingredients ?? current.ingredients,
        activeLibraryId: activeLibraryId ?? current.activeLibraryId,
        ingredientsImported: ingredientsImported ?? current.ingredientsImported,
      ),
    );
  }

  /// Composes the snapshot to start from, plus whatever has to be written back
  /// to bring storage in line with it.
  ({RecipesSnapshot snapshot, Map<String, Object> writes}) _restore() {
    // The insertion order of this map is the order the writes land in.
    final writes = <String, Object>{};

    final storedVersion = _plugin.getInt(kSchemaVersionKey);
    var libraries = storedVersion == null ? null : _readLibraries();
    if (libraries == null) {
      // Either a fresh install, or a libraries blob that cannot be read. PR1
      // has no way to create a library, so an empty switcher would be an
      // unrecoverable app: re-seed rather than start from nothing.
      libraries = _templates.all();
      writes[kLibrariesKey] = _encodeLibraries(libraries);
    }

    final recipes = _readRecipes();
    final ingredients = _readIngredients();

    final storedActiveId = _plugin.getString(kActiveLibraryIdKey);
    final String activeLibraryId;
    if (libraries.any((library) => library.id == storedActiveId)) {
      activeLibraryId = storedActiveId!;
    } else if (libraries.isNotEmpty) {
      // A fresh install, a partial write, or a library that no longer exists:
      // fall back to the first library and rewrite the preference. This rule
      // lives here alone, so no layer above needs a second one.
      activeLibraryId = libraries.first.id;
      writes[kActiveLibraryIdKey] = activeLibraryId;
    } else {
      activeLibraryId = storedActiveId ?? '';
    }

    // Decided apart from the re-seed above, so a v1 install with unreadable
    // libraries still gains its catalog. Written only when absent: a migration
    // re-run after a failed version write must not wipe a catalog the user has
    // built since.
    if (!_plugin.containsKey(kIngredientsKey)) {
      writes[kIngredientsKey] = _encodeIngredients(const []);
    }
    // Last, so a partial failure leaves an older install that already has its
    // catalog rather than a current one without it.
    if (storedVersion == null || storedVersion < kSchemaVersion) {
      writes[kSchemaVersionKey] = kSchemaVersion;
    }

    _reportDanglingRecipes(libraries, recipes);
    _reportDanglingIngredientRefs(ingredients, recipes);

    return (
      snapshot: RecipesSnapshot(
        libraries: libraries,
        recipes: recipes,
        ingredients: ingredients,
        activeLibraryId: activeLibraryId,
        ingredientsImported:
            (_plugin.getInt(kIngredientsImportVersionKey) ?? 0) >=
            kIngredientsImportVersion,
      ),
      writes: writes,
    );
  }

  /// Reads the stored libraries, or null when there are none to read or they
  /// cannot be decoded.
  List<Library>? _readLibraries() {
    final stored = _plugin.getString(kLibrariesKey);
    if (stored == null) {
      _onRecoveryError(
        'No libraries were stored alongside the schema version; re-seeding '
        'from the built-in templates.',
      );
      return null;
    }

    try {
      return _decodeList(stored, Library.fromJson);
    } on Object catch (error) {
      _onRecoveryError(
        'The stored libraries could not be read ($error); re-seeding from the '
        'built-in templates.',
      );
      return null;
    }
  }

  /// Reads the stored recipes, recovering as an empty list rather than
  /// throwing — a bad recipes blob must not cost the user their libraries too.
  List<Recipe> _readRecipes() {
    final stored = _plugin.getString(kRecipesKey);
    if (stored == null) return const [];

    try {
      return _decodeList(stored, Recipe.fromJson);
    } on Object catch (error) {
      _onRecoveryError(
        'The stored recipes could not be read ($error); recovering as an '
        'empty list.',
      );
      return const [];
    }
  }

  /// Reads the stored catalog, recovering as an empty list rather than
  /// throwing — a bad catalog must not cost the user their recipes.
  List<CatalogIngredient> _readIngredients() {
    final stored = _plugin.getString(kIngredientsKey);
    if (stored == null) return const [];

    try {
      return _decodeList(stored, CatalogIngredient.fromJson);
    } on Object catch (error) {
      _onRecoveryError(
        'The stored ingredients could not be read ($error); recovering as an '
        'empty list.',
      );
      return const [];
    }
  }

  void _reportDanglingRecipes(List<Library> libraries, List<Recipe> recipes) {
    final libraryIds = {for (final library in libraries) library.id};
    final dangling = recipes
        .where((recipe) => !libraryIds.contains(recipe.libraryId))
        .length;
    if (dangling == 0) return;

    // Hidden from every list, but never deleted: tidying up a dangling
    // reference is not worth destroying a user's data over.
    _onRecoveryError(
      '$dangling recipe(s) belong to a library that no longer exists; they '
      'are hidden but kept.',
    );
  }

  void _reportDanglingIngredientRefs(
    List<CatalogIngredient> ingredients,
    List<Recipe> recipes,
  ) {
    final ingredientIds = {for (final entry in ingredients) entry.id};
    final dangling = recipes
        .expand((recipe) => recipe.ingredients)
        .where(
          (row) =>
              row.catalogId != null && !ingredientIds.contains(row.catalogId),
        )
        .length;
    if (dangling == 0) return;

    // Reported, never rewritten: a row whose entry is gone still renders the
    // name it was saved with.
    _onRecoveryError(
      '$dangling ingredient row(s) reference a catalog entry that no longer '
      'exists; they are shown as typed.',
    );
  }

  /// Writes what [_restore] recovered, keeping the api running on the
  /// in-memory snapshot if the write fails.
  ///
  /// Throwing here would crash `bootstrap()` before `runApp`, and surfacing a
  /// failure state would block a working app on a condition that heals itself:
  /// every mutation rewrites the whole key, so the first recipe the user saves
  /// persists the seed too.
  Future<void> _persistInitial(Map<String, Object> writes) async {
    try {
      for (final write in writes.entries) {
        await _write(write.key, write.value);
      }
    } on RecipesPersistenceException catch (error) {
      _onRecoveryError('$error The app is running on unsaved data.');
    }
  }

  Future<void> _write(String key, Object value) async {
    final bool written;
    try {
      written = value is int
          ? await _plugin.setInt(key, value)
          : await _plugin.setString(key, value as String);
    } on Object catch (error) {
      throw RecipesPersistenceException('could not write "$key" ($error).');
    }
    if (!written) {
      throw RecipesPersistenceException('could not write "$key".');
    }
  }

  static List<T> _decodeList<T>(
    String stored,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final decoded = jsonDecode(stored) as List<dynamic>;
    return [
      for (final entry in decoded) fromJson(entry as Map<String, dynamic>),
    ];
  }

  static String _encodeLibraries(List<Library> libraries) =>
      jsonEncode([for (final library in libraries) library.toJson()]);

  static String _encodeRecipes(List<Recipe> recipes) =>
      jsonEncode([for (final recipe in recipes) recipe.toJson()]);

  static String _encodeIngredients(List<CatalogIngredient> ingredients) =>
      jsonEncode([for (final ingredient in ingredients) ingredient.toJson()]);
}
