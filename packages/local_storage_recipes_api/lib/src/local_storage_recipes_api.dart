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
/// Libraries, recipes, ingredient libraries, catalog entries and the active
/// library id are stored under separate keys, each rewritten in full on every
/// mutation. That is O(n) per save, which is the ceiling that motivates a real
/// database once a library grows past personal scale.
///
/// A fresh install — or one stored below [kSchemaVersion] — is seeded from
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

  /// The key the encoded list of ingredient libraries is stored under.
  @visibleForTesting
  static const kIngredientLibrariesKey = '__ingredient_libraries_key__';

  /// The key the encoded list of catalog entries is stored under.
  @visibleForTesting
  static const kIngredientsKey = '__ingredients_key__';

  /// The key the id of the library being browsed is stored under.
  @visibleForTesting
  static const kActiveLibraryIdKey = '__active_library_id_key__';

  /// The schema version a fresh install is seeded at.
  ///
  /// Version 3 added [kIngredientLibrariesKey], version 4 added Cocktails
  /// glassware options, and version 5 added library templates. An install
  /// stored below it is not migrated: every key is re-seeded, discarding what
  /// it held.
  @visibleForTesting
  static const kSchemaVersion = 5;

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
    final current = _subject.value;
    final library = current.libraries
        .where((stored) => stored.id == recipe.libraryId)
        .firstOrNull;
    if (library == null) throw LibraryNotFoundException(recipe.libraryId);
    final offered = {
      for (final entry in current.ingredients)
        if (entry.ingredientLibraryId == library.ingredientLibraryId) entry.id,
    };
    for (final row in recipe.ingredients) {
      if (!offered.contains(row.catalogId)) {
        throw IngredientNotFoundException(row.catalogId);
      }
    }
    final taken = current.recipes.any(
      (stored) =>
          stored.id != recipe.id &&
          stored.libraryId == recipe.libraryId &&
          compareCaseInsensitive(stored.name, recipe.name) == 0,
    );
    if (taken) throw RecipeNameTakenException(recipe.name);

    final recipes = [...current.recipes];
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
        final current = _subject.value;
        final libraryExists = current.ingredientLibraries.any(
          (stored) => stored.id == ingredient.ingredientLibraryId,
        );
        if (!libraryExists) {
          throw IngredientLibraryNotFoundException(
            ingredient.ingredientLibraryId,
          );
        }
        final catalog = _merged(current.ingredients, ingredient);

        await _write(kIngredientsKey, _encodeIngredients(catalog));
        _emit(ingredients: catalog);
      });

  @override
  Future<void> deleteIngredient(String id) => _serialized(() async {
    final current = _subject.value;
    final ingredients = [...current.ingredients];
    final index = ingredients.indexWhere((stored) => stored.id == id);
    if (index == -1) throw IngredientNotFoundException(id);
    ingredients.removeAt(index);
    final recipes = _stripped(current.recipes, id);

    // Recipes first: a failure after it leaves the entry in place with no
    // rows using it, which renders. The reverse would leave rows referencing
    // an entry that is gone.
    if (!listEquals(recipes, current.recipes)) {
      await _write(kRecipesKey, _encodeRecipes(recipes));
    }
    await _write(kIngredientsKey, _encodeIngredients(ingredients));
    _emit(recipes: recipes, ingredients: ingredients);
  });

  @override
  Future<void> setActiveLibraryId(String id) => _serialized(() async {
    await _write(kActiveLibraryIdKey, id);
    _emit(activeLibraryId: id);
  });

  @override
  Future<void> saveLibrary(
    Library library, {
    IngredientLibrary? ingredientLibrary,
    Map<String, Map<String, String>> optionRenames = const {},
  }) => _serialized(() async {
    final current = _subject.value;
    final taken = current.libraries.any(
      (stored) =>
          stored.id != library.id &&
          compareCaseInsensitive(stored.name, library.name) == 0,
    );
    if (taken) throw LibraryNameTakenException(library.name);

    final ingredientLibraries = [...current.ingredientLibraries];
    if (ingredientLibrary != null) {
      final ingredientLibraryTaken = ingredientLibraries.any(
        (stored) =>
            compareCaseInsensitive(stored.name, ingredientLibrary.name) == 0,
      );
      if (ingredientLibraryTaken) {
        throw IngredientLibraryNameTakenException(ingredientLibrary.name);
      }
      ingredientLibraries.add(ingredientLibrary);
    }
    final resolves = ingredientLibraries.any(
      (stored) => stored.id == library.ingredientLibraryId,
    );
    if (!resolves) {
      throw IngredientLibraryNotFoundException(library.ingredientLibraryId);
    }

    final libraries = [...current.libraries];
    final index = libraries.indexWhere((stored) => stored.id == library.id);
    var recipes = current.recipes;
    if (index == -1) {
      libraries.add(library);
    } else {
      recipes = _conformed(recipes, libraries[index], library, optionRenames);
      libraries[index] = library;
    }

    // The ingredient library first, so no write can point a library at one
    // that was never stored. Then recipes: a failure after it leaves values
    // cleared under a schema that still declares them, which renders. The
    // reverse would leave values keyed to a field nothing declares, which is
    // invisible.
    if (ingredientLibrary != null) {
      await _write(
        kIngredientLibrariesKey,
        _encodeIngredientLibraries(ingredientLibraries),
      );
    }
    if (!listEquals(recipes, current.recipes)) {
      await _write(kRecipesKey, _encodeRecipes(recipes));
    }
    await _write(kLibrariesKey, _encodeLibraries(libraries));
    _emit(
      libraries: libraries,
      recipes: recipes,
      ingredientLibraries: ingredientLibraries,
    );
  });

  @override
  Future<void> importRecipes({
    required String libraryId,
    required List<CatalogIngredient> ingredients,
    required List<Recipe> recipes,
  }) => _serialized(() async {
    final current = _subject.value;
    final library = current.libraries
        .where((stored) => stored.id == libraryId)
        .firstOrNull;
    if (library == null) throw LibraryNotFoundException(libraryId);

    var catalog = current.ingredients;
    for (final ingredient in ingredients) {
      catalog = _merged(catalog, ingredient);
    }
    final offered = {
      for (final entry in catalog)
        if (entry.ingredientLibraryId == library.ingredientLibraryId) entry.id,
    };
    for (final row in recipes.expand((recipe) => recipe.ingredients)) {
      if (!offered.contains(row.catalogId)) {
        throw IngredientNotFoundException(row.catalogId);
      }
    }

    final names = [
      for (final stored in current.recipes)
        if (stored.libraryId == libraryId) stored.name,
    ];
    for (final recipe in recipes) {
      final taken = names.any(
        (name) => compareCaseInsensitive(name, recipe.name) == 0,
      );
      if (taken) throw RecipeNameTakenException(recipe.name);
      names.add(recipe.name);
    }

    final stored = [...current.recipes, ...recipes];

    // Ingredients first: a failure after it leaves entries no row uses, which
    // renders. The reverse would leave rows referencing entries that are gone.
    if (ingredients.isNotEmpty) {
      await _write(kIngredientsKey, _encodeIngredients(catalog));
    }
    await _write(kRecipesKey, _encodeRecipes(stored));
    _emit(recipes: stored, ingredients: catalog);
  });

  @override
  Future<void> deleteLibrary(String id, {required String successorId}) =>
      _serialized(() async {
        final current = _subject.value;
        final libraries = [...current.libraries];
        final index = libraries.indexWhere((stored) => stored.id == id);
        if (index == -1) throw LibraryNotFoundException(id);
        libraries.removeAt(index);
        // Looked up among the libraries that remain, so a successor equal to
        // [id] and deleting the only library both fail here.
        if (!libraries.any((stored) => stored.id == successorId)) {
          throw LibraryNotFoundException(successorId);
        }

        final recipes = [
          for (final recipe in current.recipes)
            if (recipe.libraryId != id) recipe,
        ];
        final wasActive = current.activeLibraryId == id;

        // Children before parents: every prefix of this sequence is a state
        // the app renders, ending with an emptied library that still exists.
        // The reverse would leave recipes pointing at a library that is gone.
        if (wasActive) await _write(kActiveLibraryIdKey, successorId);
        if (recipes.length != current.recipes.length) {
          await _write(kRecipesKey, _encodeRecipes(recipes));
        }
        await _write(kLibrariesKey, _encodeLibraries(libraries));
        // One emission, after the last write: emitting piecemeal would pass
        // through a snapshot whose active id matches no library.
        _emit(
          libraries: libraries,
          recipes: recipes,
          activeLibraryId: wasActive ? successorId : null,
        );
      });

  @override
  Future<void> close() => _subject.close();

  /// [catalog] with [ingredient] merged in, replacing any entry that carries
  /// its id.
  ///
  /// Names only clash within one ingredient library: the same name in two of
  /// them names two unrelated entries.
  static List<CatalogIngredient> _merged(
    List<CatalogIngredient> catalog,
    CatalogIngredient ingredient,
  ) {
    final taken = catalog.any(
      (stored) =>
          stored.id != ingredient.id &&
          stored.ingredientLibraryId == ingredient.ingredientLibraryId &&
          compareCaseInsensitive(stored.name, ingredient.name) == 0,
    );
    if (taken) throw IngredientNameTakenException(ingredient.name);

    final merged = [...catalog];
    final index = merged.indexWhere((stored) => stored.id == ingredient.id);
    if (index == -1) {
      merged.add(ingredient);
    } else {
      merged[index] = ingredient;
    }
    return merged;
  }

  /// [recipes] without the rows referencing [ingredientId]. A recipe with no
  /// such row is returned as it was.
  static List<Recipe> _stripped(List<Recipe> recipes, String ingredientId) => [
    for (final recipe in recipes)
      if (!recipe.ingredients.any((row) => row.catalogId == ingredientId))
        recipe
      else
        Recipe(
          id: recipe.id,
          libraryId: recipe.libraryId,
          name: recipe.name,
          ingredients: [
            for (final row in recipe.ingredients)
              if (row.catalogId != ingredientId) row,
          ],
          steps: recipe.steps,
          tags: recipe.tags,
          notes: recipe.notes,
          fieldValues: recipe.fieldValues,
        ),
  ];

  /// [recipes] with the field values of those in the [stored] library brought
  /// in line with its [replacement].
  ///
  /// A value is dropped only when [replacement] removed its field or its
  /// Select option. A key that matched no field of [stored], and a Select
  /// value that was already outside the stored options, survive: tidying up
  /// what this edit did not touch is not worth destroying data over.
  ///
  /// Each value is looked up in [optionRenames] once rather than the renames
  /// being applied in turn, which is what lets two options swap.
  static List<Recipe> _conformed(
    List<Recipe> recipes,
    Library stored,
    Library replacement,
    Map<String, Map<String, String>> optionRenames,
  ) {
    final storedFields = {for (final field in stored.fields) field.id: field};
    final replacements = {
      for (final field in replacement.fields) field.id: field,
    };

    Object? conformed(FieldDefinition before, Object? value) {
      final after = replacements[before.id];
      if (after == null) return null;
      if (before.type != FieldType.select || after.type != FieldType.select) {
        return value;
      }

      final renames = optionRenames[before.id] ?? const <String, String>{};
      final renamed = renames[value];
      if (renamed != null) return renamed;
      final removed = before.optionsRemovedBy(after, renames: renames);
      return removed.contains(value) ? null : value;
    }

    return [
      for (final recipe in recipes)
        if (recipe.libraryId != stored.id)
          recipe
        else
          Recipe(
            id: recipe.id,
            libraryId: recipe.libraryId,
            name: recipe.name,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            tags: recipe.tags,
            notes: recipe.notes,
            fieldValues: {
              for (final MapEntry(:key, :value) in recipe.fieldValues.entries)
                key: ?switch (storedFields[key]) {
                  null => value,
                  final field => conformed(field, value),
                },
            },
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
    List<Library>? libraries,
    List<Recipe>? recipes,
    List<IngredientLibrary>? ingredientLibraries,
    List<CatalogIngredient>? ingredients,
    String? activeLibraryId,
  }) {
    final current = _subject.value;
    _subject.add(
      RecipesSnapshot(
        libraries: libraries ?? current.libraries,
        recipes: recipes ?? current.recipes,
        ingredientLibraries: ingredientLibraries ?? current.ingredientLibraries,
        ingredients: ingredients ?? current.ingredients,
        activeLibraryId: activeLibraryId ?? current.activeLibraryId,
      ),
    );
  }

  /// Composes the snapshot to start from, plus whatever has to be written back
  /// to bring storage in line with it.
  ({RecipesSnapshot snapshot, Map<String, Object> writes}) _restore() {
    final storedVersion = _plugin.getInt(kSchemaVersionKey);
    if (storedVersion == null || storedVersion < kSchemaVersion) {
      return _seeded();
    }

    // The insertion order of this map is the order the writes land in.
    final writes = <String, Object>{};

    var libraries = _readLibraries();
    if (libraries == null) {
      // A libraries blob that cannot be read. The app always has at least one
      // library — deleting one needs a successor — so re-seed rather than
      // start from a state nothing else can produce. The ingredient libraries
      // the templates point at are recreated below, like any other missing
      // one.
      libraries = [for (final (library, _) in _templates.all()) library];
      writes[kLibrariesKey] = _encodeLibraries(libraries);
    }

    final recipes = _readRecipes();
    final ingredients = _readIngredients();
    final ingredientLibraries = _readIngredientLibraries();

    // Every library resolves its ingredient library: one that resolves to
    // nothing is recreated under the same id, so the entries still pointing
    // at it stay reachable and no library is rewritten. Names are unique on
    // save, not here, so a clashing name is tolerated until renamed.
    final ingredientLibraryIds = {
      for (final ingredientLibrary in ingredientLibraries) ingredientLibrary.id,
    };
    final recreated = [
      for (final library in libraries)
        if (ingredientLibraryIds.add(library.ingredientLibraryId))
          IngredientLibrary(
            id: library.ingredientLibraryId,
            name: library.name,
          ),
    ];
    if (recreated.isNotEmpty) {
      ingredientLibraries.addAll(recreated);
      writes[kIngredientLibrariesKey] = _encodeIngredientLibraries(
        ingredientLibraries,
      );
      _onRecoveryError(
        '${recreated.length} ingredient library(ies) were missing; recreated '
        'under their ids, named after the library using each.',
      );
    }

    final storedActiveId = _plugin.getString(kActiveLibraryIdKey);
    final String activeLibraryId;
    if (libraries.any((library) => library.id == storedActiveId)) {
      activeLibraryId = storedActiveId!;
    } else if (libraries.isNotEmpty) {
      // A partial write, or a library that no longer exists: fall back to the
      // first library and rewrite the preference. This rule lives here alone,
      // so no layer above needs a second one.
      activeLibraryId = libraries.first.id;
      writes[kActiveLibraryIdKey] = activeLibraryId;
    } else {
      activeLibraryId = storedActiveId ?? '';
    }

    _reportDanglingRecipes(libraries, recipes);
    _reportDanglingIngredients(ingredientLibraryIds, ingredients);
    _reportDanglingIngredientRefs(ingredients, recipes);

    return (
      snapshot: RecipesSnapshot(
        libraries: libraries,
        recipes: recipes,
        ingredientLibraries: ingredientLibraries,
        ingredients: ingredients,
        activeLibraryId: activeLibraryId,
      ),
      writes: writes,
    );
  }

  /// Every template paired with its own ingredient library, no recipes and no
  /// ingredients, opening on the first template.
  ({RecipesSnapshot snapshot, Map<String, Object> writes}) _seeded() {
    final pairs = _templates.all();
    final libraries = [for (final (library, _) in pairs) library];
    final ingredientLibraries = [
      for (final (_, ingredientLibrary) in pairs) ingredientLibrary,
    ];
    final activeLibraryId = libraries.first.id;

    return (
      snapshot: RecipesSnapshot(
        libraries: libraries,
        recipes: const [],
        ingredientLibraries: ingredientLibraries,
        ingredients: const [],
        activeLibraryId: activeLibraryId,
      ),
      // Children before parents, and the version last, so a failure part-way
      // re-seeds on the next launch instead of opening a half-written store.
      writes: {
        kIngredientLibrariesKey: _encodeIngredientLibraries(
          ingredientLibraries,
        ),
        kIngredientsKey: _encodeIngredients(const []),
        kRecipesKey: _encodeRecipes(const []),
        kLibrariesKey: _encodeLibraries(libraries),
        kActiveLibraryIdKey: activeLibraryId,
        kSchemaVersionKey: kSchemaVersion,
      },
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

  /// Reads the stored ingredient libraries, recovering as an empty list rather
  /// than throwing. The libraries pointing at them recreate what was lost.
  List<IngredientLibrary> _readIngredientLibraries() {
    final stored = _plugin.getString(kIngredientLibrariesKey);
    if (stored == null) return [];

    try {
      return _decodeList(stored, IngredientLibrary.fromJson);
    } on Object catch (error) {
      _onRecoveryError(
        'The stored ingredient libraries could not be read ($error); '
        'recovering as an empty list.',
      );
      return [];
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

  void _reportDanglingIngredients(
    Set<String> ingredientLibraryIds,
    List<CatalogIngredient> ingredients,
  ) {
    final dangling = ingredients
        .where(
          (entry) => !ingredientLibraryIds.contains(entry.ingredientLibraryId),
        )
        .length;
    if (dangling == 0) return;

    _onRecoveryError(
      '$dangling ingredient(s) belong to an ingredient library that no longer '
      'exists; they are hidden but kept.',
    );
  }

  void _reportDanglingIngredientRefs(
    List<CatalogIngredient> ingredients,
    List<Recipe> recipes,
  ) {
    final ingredientIds = {for (final entry in ingredients) entry.id};
    final dangling = recipes
        .expand((recipe) => recipe.ingredients)
        .where((row) => !ingredientIds.contains(row.catalogId))
        .length;
    if (dangling == 0) return;

    // Reported, never rewritten here: a row whose entry is gone has no name
    // to render, so it is hidden until the recipe is next saved.
    _onRecoveryError(
      '$dangling ingredient row(s) reference a catalog entry that no longer '
      'exists; they are hidden.',
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

  static String _encodeIngredientLibraries(
    List<IngredientLibrary> ingredientLibraries,
  ) => jsonEncode([
    for (final ingredientLibrary in ingredientLibraries)
      ingredientLibrary.toJson(),
  ]);

  static String _encodeIngredients(List<CatalogIngredient> ingredients) =>
      jsonEncode([for (final ingredient in ingredients) ingredient.toJson()]);
}
