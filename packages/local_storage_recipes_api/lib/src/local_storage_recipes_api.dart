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
/// Libraries, recipes and the active library id are stored under separate
/// keys, each rewritten in full on every mutation. That is O(n) per save,
/// which is the ceiling that motivates a real database once a library grows
/// past personal scale.
///
/// A fresh install — one with no stored schema version — is seeded from
/// [LibraryTemplates]. Seeding is driven by the schema version rather than by
/// "the libraries list is empty" so that a deliberately emptied library list
/// stays empty instead of resurrecting on the next launch.
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
    _initialWrite = _persistInitial(writes);
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

  /// The key the id of the library being browsed is stored under.
  @visibleForTesting
  static const kActiveLibraryIdKey = '__active_library_id_key__';

  /// The schema version a fresh install is seeded at.
  @visibleForTesting
  static const kSchemaVersion = 1;

  final SharedPreferences _plugin;
  final LibraryTemplates _templates;
  final void Function(String message) _onRecoveryError;

  late final BehaviorSubject<RecipesSnapshot> _subject;
  late final Future<void> _initialWrite;

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
  Future<void> saveRecipe(Recipe recipe) async {
    final snapshot = _subject.value;
    final recipes = [...snapshot.recipes];
    final index = recipes.indexWhere((stored) => stored.id == recipe.id);
    if (index == -1) {
      recipes.add(recipe);
    } else {
      recipes[index] = recipe;
    }

    await _write(kRecipesKey, _encodeRecipes(recipes));
    _emit(snapshot, recipes: recipes);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    final snapshot = _subject.value;
    final recipes = [...snapshot.recipes];
    final index = recipes.indexWhere((stored) => stored.id == id);
    if (index == -1) throw RecipeNotFoundException(id);
    recipes.removeAt(index);

    await _write(kRecipesKey, _encodeRecipes(recipes));
    _emit(snapshot, recipes: recipes);
  }

  @override
  Future<void> setActiveLibraryId(String id) async {
    final snapshot = _subject.value;

    await _write(kActiveLibraryIdKey, id);
    _emit(snapshot, activeLibraryId: id);
  }

  @override
  Future<void> close() => _subject.close();

  void _emit(
    RecipesSnapshot previous, {
    List<Recipe>? recipes,
    String? activeLibraryId,
  }) {
    _subject.add(
      RecipesSnapshot(
        libraries: previous.libraries,
        recipes: recipes ?? previous.recipes,
        activeLibraryId: activeLibraryId ?? previous.activeLibraryId,
      ),
    );
  }

  /// Composes the snapshot to start from, plus whatever has to be written back
  /// to bring storage in line with it.
  ({RecipesSnapshot snapshot, Map<String, Object> writes}) _restore() {
    final writes = <String, Object>{};

    var libraries = _plugin.getInt(kSchemaVersionKey) == null
        ? null
        : _readLibraries();
    if (libraries == null) {
      // Either a fresh install, or a libraries blob that cannot be read. PR1
      // has no way to create a library, so an empty switcher would be an
      // unrecoverable app: re-seed rather than start from nothing.
      libraries = _templates.all();
      writes[kLibrariesKey] = _encodeLibraries(libraries);
      writes[kSchemaVersionKey] = kSchemaVersion;
    }

    final recipes = _readRecipes();

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

    _reportDanglingRecipes(libraries, recipes);

    return (
      snapshot: RecipesSnapshot(
        libraries: libraries,
        recipes: recipes,
        activeLibraryId: activeLibraryId,
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
}
