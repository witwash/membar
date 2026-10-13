import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage_recipes_api/local_storage_recipes_api.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A store whose every write fails, so the persistence failure paths can be
/// driven without mocking the `shared_preferences` surface itself.
class _FailingStore extends SharedPreferencesStorePlatform {
  _FailingStore({this.throws = false});

  /// Whether a write throws rather than reporting failure by returning false.
  final bool throws;

  @override
  Future<bool> clear() async => false;

  @override
  Future<Map<String, Object>> getAll() async => {};

  @override
  Future<bool> remove(String key) async => false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (throws) throw Exception('the disk is on fire');
    return false;
  }
}

/// An in-memory store that records the order keys are written in.
class _RecordingStore extends InMemorySharedPreferencesStore {
  _RecordingStore(super.data) : super.withData();

  /// Every key written, without the platform prefix, in write order.
  final writtenKeys = <String>[];

  /// A key whose writes report failure, so a sequence of writes can be made
  /// to fail part-way.
  String? failingKey;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final written = key.replaceFirst('flutter.', '');
    if (written == failingKey) return false;
    writtenKeys.add(written);
    return super.setValue(valueType, key, value);
  }
}

/// Builds `id_0`, `id_1`, … so a seeded library's ids can be named in a test.
String Function() _counterIds() {
  var next = 0;
  return () => 'id_${next++}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageRecipesApi', () {
    late SharedPreferences plugin;
    late List<String> reported;
    final templates = LibraryTemplates(idBuilder: _counterIds());
    final seeded = templates.all();
    final cocktails = seeded.first;
    final coffee = seeded.last;

    /// The api under test, closed in `tearDown` so no subject outlives its
    /// test.
    late LocalStorageRecipesApi api;
    final opened = <LocalStorageRecipesApi>[];

    LocalStorageRecipesApi buildApi() {
      final built = LocalStorageRecipesApi(
        plugin: plugin,
        templates: LibraryTemplates(idBuilder: _counterIds()),
        onRecoveryError: reported.add,
      );
      opened.add(built);
      return built;
    }

    /// Prefs holding an already-seeded install: both templates, no recipes,
    /// an empty catalog, Cocktails active.
    Map<String, Object> seededPrefs({
      List<Library>? libraries,
      List<Recipe>? recipes,
      List<CatalogIngredient>? ingredients,
      String? activeLibraryId,
    }) {
      return {
        LocalStorageRecipesApi.kSchemaVersionKey:
            LocalStorageRecipesApi.kSchemaVersion,
        LocalStorageRecipesApi.kLibrariesKey: jsonEncode([
          for (final library in libraries ?? seeded) library.toJson(),
        ]),
        LocalStorageRecipesApi.kRecipesKey: jsonEncode([
          for (final recipe in recipes ?? const <Recipe>[]) recipe.toJson(),
        ]),
        LocalStorageRecipesApi.kIngredientsKey: jsonEncode([
          for (final ingredient in ingredients ?? const <CatalogIngredient>[])
            ingredient.toJson(),
        ]),
        LocalStorageRecipesApi.kActiveLibraryIdKey:
            activeLibraryId ?? cocktails.id,
      };
    }

    Future<void> setUpPrefs(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      plugin = await SharedPreferences.getInstance();
    }

    /// Like [setUpPrefs], but returns a store that records every write.
    Future<_RecordingStore> setUpRecordingPrefs(
      Map<String, Object> values,
    ) async {
      final store = _RecordingStore({
        for (final entry in values.entries) 'flutter.${entry.key}': entry.value,
      });
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance = store;
      plugin = await SharedPreferences.getInstance();
      return store;
    }

    setUp(() async {
      reported = [];
      await setUpPrefs({});
    });

    tearDown(() async {
      for (final open in opened) {
        await open.close();
      }
      opened.clear();
    });

    group('on a fresh install', () {
      setUp(() async {
        api = buildApi();
        await api.initialWrite;
      });

      test('seeds every template and opens on the first one', () async {
        final snapshot = await api.watch().first;

        expect(
          snapshot.libraries.map((library) => library.name),
          equals(['Cocktails', 'Coffee']),
        );
        expect(snapshot.recipes, isEmpty);
        expect(snapshot.activeLibraryId, equals(snapshot.libraries.first.id));
      });

      test('writes the libraries, the active id and the schema version', () {
        expect(
          plugin.getInt(LocalStorageRecipesApi.kSchemaVersionKey),
          equals(LocalStorageRecipesApi.kSchemaVersion),
        );
        expect(
          plugin.getString(LocalStorageRecipesApi.kActiveLibraryIdKey),
          equals(cocktails.id),
        );

        final stored = jsonDecode(
          plugin.getString(LocalStorageRecipesApi.kLibrariesKey)!,
        ) as List<dynamic>;
        expect(
          [
            for (final library in stored)
              Library.fromJson(library as Map<String, dynamic>).name,
          ],
          equals(['Cocktails', 'Coffee']),
        );
      });

      test('starts with an empty catalog', () async {
        expect((await api.watch().first).ingredients, isEmpty);
        expect(
          plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
          equals('[]'),
        );
      });

      test('reports nothing', () {
        expect(reported, isEmpty);
      });
    });

    group('schema migration', () {
      /// Prefs as a version 1 install left them: no catalog key.
      Map<String, Object> v1Prefs({List<Recipe> recipes = const []}) =>
          seededPrefs(recipes: recipes)
            ..remove(LocalStorageRecipesApi.kIngredientsKey)
            ..[LocalStorageRecipesApi.kSchemaVersionKey] = 1;

      test(
        'a fresh install writes the catalog before the version, at 2',
        () async {
          final store = await setUpRecordingPrefs({});

          api = buildApi();
          await api.initialWrite;

          expect(
            store.writtenKeys,
            equals([
              LocalStorageRecipesApi.kLibrariesKey,
              LocalStorageRecipesApi.kActiveLibraryIdKey,
              LocalStorageRecipesApi.kIngredientsKey,
              LocalStorageRecipesApi.kSchemaVersionKey,
            ]),
          );
          expect(
            plugin.getInt(LocalStorageRecipesApi.kSchemaVersionKey),
            equals(2),
          );
        },
      );

      test(
        'a version 1 install gains an empty catalog without rewriting '
        'recipes or libraries',
        () async {
          final negroni = Recipe(
            id: 'r1',
            libraryId: cocktails.id,
            name: 'Negroni',
            ingredients: [Ingredient(name: 'Gin', quantity: '30', unit: 'ml')],
          );
          final prefs = v1Prefs(recipes: [negroni]);
          final store = await setUpRecordingPrefs(prefs);

          api = buildApi();
          await api.initialWrite;

          expect(
            store.writtenKeys,
            equals([
              LocalStorageRecipesApi.kIngredientsKey,
              LocalStorageRecipesApi.kSchemaVersionKey,
            ]),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kRecipesKey),
            equals(prefs[LocalStorageRecipesApi.kRecipesKey]),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kLibrariesKey),
            equals(prefs[LocalStorageRecipesApi.kLibrariesKey]),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
            equals('[]'),
          );
          expect(
            plugin.getInt(LocalStorageRecipesApi.kSchemaVersionKey),
            equals(2),
          );

          final snapshot = await api.watch().first;
          expect(snapshot.recipes, equals([negroni]));
          expect(snapshot.ingredients, isEmpty);
          expect(reported, isEmpty);
        },
      );

      test(
        'a version 1 install with unreadable libraries re-seeds and still '
        'writes the catalog',
        () async {
          final store = await setUpRecordingPrefs(
            v1Prefs()..[LocalStorageRecipesApi.kLibrariesKey] = 'not json',
          );

          api = buildApi();
          await api.initialWrite;

          expect(
            store.writtenKeys,
            containsAllInOrder([
              LocalStorageRecipesApi.kLibrariesKey,
              LocalStorageRecipesApi.kIngredientsKey,
              LocalStorageRecipesApi.kSchemaVersionKey,
            ]),
          );
          expect(
            store.writtenKeys.last,
            LocalStorageRecipesApi.kSchemaVersionKey,
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
            equals('[]'),
          );
        },
      );

      test('a migration finding the catalog present keeps it', () async {
        // A version write that failed last launch leaves a v1 install whose
        // catalog the user may have built on since.
        final gin = CatalogIngredient(
          id: 'i1',
          name: 'Gin',
          libraryIds: {cocktails.id},
        );
        final store = await setUpRecordingPrefs(
          v1Prefs()
            ..[LocalStorageRecipesApi.kIngredientsKey] = jsonEncode([
              gin.toJson(),
            ]),
        );

        api = buildApi();
        await api.initialWrite;

        expect(
          store.writtenKeys,
          equals([LocalStorageRecipesApi.kSchemaVersionKey]),
        );
        expect((await api.watch().first).ingredients, equals([gin]));
      });

      test('a version 2 install writes nothing', () async {
        final store = await setUpRecordingPrefs(seededPrefs());

        api = buildApi();
        await api.initialWrite;

        expect(store.writtenKeys, isEmpty);
        expect(reported, isEmpty);
      });
    });

    test('seeds the subject synchronously', () async {
      // A subscriber attached in the same tick as construction must reach the
      // seeded snapshot without waiting on disk: an api that seeded from an
      // awaited read would still be empty a microtask later, and the app would
      // render an empty first frame.
      api = buildApi();

      RecipesSnapshot? observed;
      api.watch().listen((snapshot) => observed = snapshot);
      await Future<void>.microtask(() {});

      expect(observed?.libraries, hasLength(2));
      await api.initialWrite;
    });

    test(
      'does not re-seed a second construction over the same prefs',
      () async {
        final first = buildApi();
        await first.initialWrite;
        final firstIds = (await first.watch().first).libraries.map(
          (library) => library.id,
        );

        final second = buildApi();
        await second.initialWrite;

        expect(
          (await second.watch().first).libraries.map((library) => library.id),
          equals(firstIds),
        );
        expect(reported, isEmpty);
      },
    );

    test('preserves an explicitly empty libraries list', () async {
      await setUpPrefs({
        LocalStorageRecipesApi.kSchemaVersionKey:
            LocalStorageRecipesApi.kSchemaVersion,
        LocalStorageRecipesApi.kLibrariesKey: '[]',
        LocalStorageRecipesApi.kActiveLibraryIdKey: '',
      });

      api = buildApi();
      await api.initialWrite;

      // A deliberately emptied library list is a PR2 state; it must not
      // resurrect on the next launch.
      final snapshot = await api.watch().first;
      expect(snapshot.libraries, isEmpty);
      expect(snapshot.activeLibraryId, isEmpty);
      expect(reported, isEmpty);
    });

    group('recovery', () {
      test(
        're-seeds an unreadable libraries blob, keeping the recipes',
        () async {
          // Re-seeded libraries carry fresh ids, so a recipe written against
          // the unreadable ones is orphaned — kept, not deleted.
          final orphan = Recipe(id: 'r1', libraryId: 'gone', name: 'Sour');
          await setUpPrefs({
            LocalStorageRecipesApi.kSchemaVersionKey:
                LocalStorageRecipesApi.kSchemaVersion,
            LocalStorageRecipesApi.kLibrariesKey: 'not json at all',
            LocalStorageRecipesApi.kRecipesKey: jsonEncode([orphan.toJson()]),
          });

          api = buildApi();
          await api.initialWrite;

          final snapshot = await api.watch().first;
          expect(snapshot.libraries, hasLength(2));
          expect(snapshot.recipes, equals([orphan]));
          expect(
            reported,
            equals([
              contains('libraries could not be read'),
              contains('belong to a library that no longer exists'),
            ]),
          );
        },
      );

      test('re-seeds when the libraries key is missing entirely', () async {
        await setUpPrefs({
          LocalStorageRecipesApi.kSchemaVersionKey:
              LocalStorageRecipesApi.kSchemaVersion,
        });

        api = buildApi();
        await api.initialWrite;

        expect((await api.watch().first).libraries, hasLength(2));
        expect(reported.single, contains('No libraries were stored'));
      });

      test('recovers an unreadable recipes blob as an empty list', () async {
        await setUpPrefs(
          seededPrefs()
            ..[LocalStorageRecipesApi.kRecipesKey] = '{"not":"a list"}',
        );

        api = buildApi();
        await api.initialWrite;

        final snapshot = await api.watch().first;
        expect(snapshot.recipes, isEmpty);
        expect(snapshot.libraries, hasLength(2), reason: 'left intact');
        expect(reported.single, contains('recipes could not be read'));
      });

      test(
        'recovers an unreadable catalog as empty, keeping the recipes',
        () async {
          final negroni = Recipe(
            id: 'r1',
            libraryId: cocktails.id,
            name: 'Negroni',
          );
          await setUpPrefs(
            seededPrefs(recipes: [negroni])
              ..[LocalStorageRecipesApi.kIngredientsKey] = 'not json at all',
          );

          api = buildApi();
          await api.initialWrite;

          final snapshot = await api.watch().first;
          expect(snapshot.ingredients, isEmpty);
          expect(snapshot.recipes, equals([negroni]));
          expect(reported.single, contains('ingredients could not be read'));
        },
      );

      test(
        'keeps rows whose catalog entry is gone, and reports them',
        () async {
          final negroni = Recipe(
            id: 'r1',
            libraryId: cocktails.id,
            name: 'Negroni',
            ingredients: [
              Ingredient(name: 'Gin', catalogId: 'gone'),
              Ingredient(name: 'Campari', catalogId: 'i1'),
              Ingredient(name: 'Vermouth'),
            ],
          );
          await setUpPrefs(
            seededPrefs(
              recipes: [negroni],
              ingredients: [
                CatalogIngredient(
                  id: 'i1',
                  name: 'Campari',
                  libraryIds: {cocktails.id},
                ),
              ],
            ),
          );

          api = buildApi();
          await api.initialWrite;

          expect((await api.watch().first).recipes, equals([negroni]));
          expect(
            reported.single,
            allOf(
              startsWith('1 ingredient row(s)'),
              contains('catalog entry that no longer exists'),
            ),
          );
        },
      );

      test('falls back to the first library for a stale active id', () async {
        await setUpPrefs(seededPrefs(activeLibraryId: 'gone'));

        api = buildApi();
        await api.initialWrite;

        expect((await api.watch().first).activeLibraryId, equals(cocktails.id));
        expect(
          plugin.getString(LocalStorageRecipesApi.kActiveLibraryIdKey),
          equals(cocktails.id),
          reason: 'the fallback is rewritten, so it settles after one launch',
        );
      });

      test('keeps a recipe whose library is gone, and reports it', () async {
        final orphan = Recipe(id: 'r1', libraryId: 'gone', name: 'Sour');
        await setUpPrefs(seededPrefs(recipes: [orphan]));

        api = buildApi();
        await api.initialWrite;

        expect((await api.watch().first).recipes, equals([orphan]));
        expect(
          reported.single,
          contains('belong to a library that no longer exists'),
        );
      });

      test(
        'keeps running on the in-memory snapshot when seeding fails',
        () async {
          SharedPreferencesStorePlatform.instance = _FailingStore();

          api = buildApi();
          await api.initialWrite;

          expect((await api.watch().first).libraries, hasLength(2));
          expect(reported.single, contains('running on unsaved data'));
        },
      );

      test('reports through debugPrint by default', () async {
        await setUpPrefs({
          LocalStorageRecipesApi.kSchemaVersionKey:
              LocalStorageRecipesApi.kSchemaVersion,
          LocalStorageRecipesApi.kLibrariesKey: 'not json at all',
        });
        final printed = <String?>[];
        final previous = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message);
        addTearDown(() => debugPrint = previous);

        final defaulted = LocalStorageRecipesApi(plugin: plugin);
        opened.add(defaulted);
        await defaulted.initialWrite;

        expect(printed.single, contains('libraries could not be read'));
      });
    });

    group('saveRecipe', () {
      late Recipe negroni;

      setUp(() async {
        negroni = Recipe(id: 'r1', libraryId: cocktails.id, name: 'Negroni');
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;
      });

      test('adds a recipe and re-emits the snapshot', () async {
        await api.saveRecipe(negroni);

        expect((await api.watch().first).recipes, equals([negroni]));
        expect(
          plugin.getString(LocalStorageRecipesApi.kRecipesKey),
          equals(jsonEncode([negroni.toJson()])),
        );
      });

      test('replaces a recipe that already carries the id', () async {
        await api.saveRecipe(negroni);
        final renamed = Recipe(
          id: negroni.id,
          libraryId: cocktails.id,
          name: 'Boulevardier',
        );

        await api.saveRecipe(renamed);

        expect((await api.watch().first).recipes, equals([renamed]));
      });

      test('leaves the libraries and the active library alone', () async {
        await api.saveRecipe(negroni);

        final snapshot = await api.watch().first;
        expect(snapshot.libraries, hasLength(2));
        expect(snapshot.activeLibraryId, equals(cocktails.id));
      });

      test('throws when the write fails', () async {
        SharedPreferencesStorePlatform.instance = _FailingStore();

        expect(
          () => api.saveRecipe(negroni),
          throwsA(isA<RecipesPersistenceException>()),
        );
      });

      test('throws when the write itself throws', () async {
        SharedPreferencesStorePlatform.instance = _FailingStore(throws: true);

        await expectLater(
          () => api.saveRecipe(negroni),
          throwsA(
            isA<RecipesPersistenceException>().having(
              (exception) => exception.message,
              'message',
              contains('the disk is on fire'),
            ),
          ),
        );
      });
    });

    group('deleteRecipe', () {
      late Recipe negroni;

      setUp(() async {
        negroni = Recipe(id: 'r1', libraryId: cocktails.id, name: 'Negroni');
        await setUpPrefs(seededPrefs(recipes: [negroni]));
        api = buildApi();
        await api.initialWrite;
      });

      test('removes the recipe and re-emits the snapshot', () async {
        await api.deleteRecipe(negroni.id);

        expect((await api.watch().first).recipes, isEmpty);
        expect(
          plugin.getString(LocalStorageRecipesApi.kRecipesKey),
          equals('[]'),
        );
      });

      test('throws RecipeNotFoundException for an id that is gone', () async {
        await expectLater(
          () => api.deleteRecipe('nope'),
          throwsA(
            isA<RecipeNotFoundException>().having(
              (exception) => exception.id,
              'id',
              equals('nope'),
            ),
          ),
        );
      });
    });

    group('saveIngredient', () {
      late CatalogIngredient gin;

      setUp(() async {
        gin = CatalogIngredient(
          id: 'i1',
          name: 'Gin',
          libraryIds: {cocktails.id},
          defaultUnit: const KnownUnit(StandardUnit.ml),
        );
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;
      });

      test('adds an entry and re-emits the snapshot', () async {
        await api.saveIngredient(gin);

        expect((await api.watch().first).ingredients, equals([gin]));
        expect(
          plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
          equals(jsonEncode([gin.toJson()])),
        );
      });

      test('replaces an entry that already carries the id', () async {
        await api.saveIngredient(gin);
        final renamed = CatalogIngredient(
          id: gin.id,
          name: 'GIN',
          libraryIds: {cocktails.id, coffee.id},
        );

        // Folding onto its own name is a rename, not a collision.
        await api.saveIngredient(renamed);

        expect((await api.watch().first).ingredients, equals([renamed]));
      });

      test('leaves recipes and libraries alone', () async {
        await api.saveIngredient(gin);

        final snapshot = await api.watch().first;
        expect(snapshot.libraries, hasLength(2));
        expect(snapshot.recipes, isEmpty);
      });

      test(
        'throws IngredientNameTakenException for a name another entry '
        'carries',
        () async {
          await api.saveIngredient(gin);

          await expectLater(
            () => api.saveIngredient(
              CatalogIngredient(name: ' gin ', libraryIds: {coffee.id}),
            ),
            throwsA(
              isA<IngredientNameTakenException>().having(
                (exception) => exception.name,
                'name',
                equals('gin'),
              ),
            ),
          );
          expect((await api.watch().first).ingredients, equals([gin]));
        },
      );

      test('throws when the write fails', () async {
        SharedPreferencesStorePlatform.instance = _FailingStore();

        await expectLater(
          () => api.saveIngredient(gin),
          throwsA(isA<RecipesPersistenceException>()),
        );
      });
    });

    group('importIngredients', () {
      final gin = CatalogIngredient(
        id: 'i1',
        name: 'Gin',
        libraryIds: {cocktails.id},
      );
      final campari = CatalogIngredient(
        id: 'i2',
        name: 'Campari',
        libraryIds: {cocktails.id},
      );
      final sugar = CatalogIngredient(
        id: 'i3',
        name: 'Sugar',
        libraryIds: {coffee.id},
      );

      test('opens an install that never imported as not imported', () async {
        await setUpPrefs(seededPrefs());
        api = buildApi();

        expect((await api.watch().first).ingredientsImported, isFalse);
      });

      test('opens an install that already imported as imported', () async {
        await setUpPrefs({
          ...seededPrefs(),
          LocalStorageRecipesApi.kIngredientsImportVersionKey:
              LocalStorageRecipesApi.kIngredientsImportVersion,
        });
        api = buildApi();

        expect((await api.watch().first).ingredientsImported, isTrue);
      });

      test(
        'writes the catalog, the recipes, then the import version, and '
        'emits one snapshot',
        () async {
          final store = await setUpRecordingPrefs(
            seededPrefs(ingredients: [gin]),
          );
          api = buildApi();
          await api.initialWrite;
          store.writtenKeys.clear();
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);

          await api.importIngredients([campari, sugar]);
          await pumpEventQueue();

          expect(
            store.writtenKeys,
            equals([
              LocalStorageRecipesApi.kIngredientsKey,
              LocalStorageRecipesApi.kRecipesKey,
              LocalStorageRecipesApi.kIngredientsImportVersionKey,
            ]),
          );
          expect(emitted, hasLength(1));
          expect(emitted.single.ingredients, equals([gin, campari, sugar]));
          expect(emitted.single.ingredientsImported, isTrue);
          expect(
            plugin.getInt(LocalStorageRecipesApi.kIngredientsImportVersionKey),
            equals(LocalStorageRecipesApi.kIngredientsImportVersion),
          );
        },
      );

      test('links every row whose name matches an entry', () async {
        await setUpPrefs(
          seededPrefs(
            ingredients: [gin],
            recipes: [
              Recipe(
                id: 'r1',
                libraryId: cocktails.id,
                name: 'Negroni',
                tags: const ['Bitter'],
                notes: 'Stir.',
                ingredients: [
                  Ingredient(name: 'gin', quantity: '30', unit: 'ml'),
                  Ingredient(name: 'CAMPARI'),
                  Ingredient(name: 'Vermouth'),
                  Ingredient(name: 'Old Tom', catalogId: 'gone'),
                ],
              ),
              Recipe(
                id: 'r2',
                libraryId: coffee.id,
                name: 'Cortado',
                ingredients: [Ingredient(name: 'Sugar', catalogId: gin.id)],
              ),
            ],
          ),
        );
        api = buildApi();
        await api.initialWrite;

        await api.importIngredients([campari]);

        final recipes = (await api.watch().first).recipes;
        expect(
          recipes.first,
          Recipe(
            id: 'r1',
            libraryId: cocktails.id,
            name: 'Negroni',
            tags: const ['Bitter'],
            notes: 'Stir.',
            ingredients: [
              Ingredient(
                name: 'gin',
                quantity: '30',
                unit: 'ml',
                catalogId: gin.id,
              ),
              Ingredient(name: 'CAMPARI', catalogId: campari.id),
              Ingredient(name: 'Vermouth'),
              Ingredient(name: 'Old Tom', catalogId: 'gone'),
            ],
          ),
        );
        // A link that resolves is kept even when the row's name no longer
        // matches its entry: that is what a rename looks like.
        expect(recipes.last.ingredients.single.catalogId, equals(gin.id));
        expect(
          plugin.getString(LocalStorageRecipesApi.kRecipesKey),
          equals(jsonEncode([for (final recipe in recipes) recipe.toJson()])),
        );
      });

      test('replaces entries that already carry their ids', () async {
        await setUpPrefs(seededPrefs(ingredients: [gin, campari]));
        api = buildApi();
        await api.initialWrite;
        final renamed = CatalogIngredient(
          id: gin.id,
          name: 'London Dry Gin',
          libraryIds: gin.libraryIds,
        );

        await api.importIngredients([renamed]);

        expect(
          (await api.watch().first).ingredients,
          equals([renamed, campari]),
        );
      });

      test('stores nothing when an entry folds onto a stored one', () async {
        final store = await setUpRecordingPrefs(
          seededPrefs(ingredients: [gin]),
        );
        api = buildApi();
        await api.initialWrite;
        store.writtenKeys.clear();

        await expectLater(
          () => api.importIngredients([
            campari,
            CatalogIngredient(name: 'GIN', libraryIds: {coffee.id}),
          ]),
          throwsA(isA<IngredientNameTakenException>()),
        );
        final snapshot = await api.watch().first;
        expect(snapshot.ingredients, equals([gin]));
        expect(snapshot.ingredientsImported, isFalse);
        expect(store.writtenKeys, isEmpty);
      });

      test('throws when two entries in the batch fold together', () async {
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;

        await expectLater(
          () => api.importIngredients([
            campari,
            CatalogIngredient(name: 'campari', libraryIds: {coffee.id}),
          ]),
          throwsA(isA<IngredientNameTakenException>()),
        );
        expect((await api.watch().first).ingredients, isEmpty);
      });

      test('leaves the import on offer when a write fails', () async {
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;
        SharedPreferencesStorePlatform.instance = _FailingStore();

        await expectLater(
          () => api.importIngredients([gin]),
          throwsA(isA<RecipesPersistenceException>()),
        );
        expect((await api.watch().first).ingredientsImported, isFalse);
      });
    });

    group('deleteIngredient', () {
      late CatalogIngredient gin;

      setUp(() {
        gin = CatalogIngredient(
          id: 'i1',
          name: 'Gin',
          libraryIds: {cocktails.id},
        );
      });

      test('removes the entry and re-emits the snapshot', () async {
        await setUpPrefs(seededPrefs(ingredients: [gin]));
        api = buildApi();
        await api.initialWrite;

        await api.deleteIngredient(gin.id);

        expect((await api.watch().first).ingredients, isEmpty);
        expect(
          plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
          equals('[]'),
        );
      });

      test(
        'throws IngredientNotFoundException for an id that is gone',
        () async {
          await setUpPrefs(seededPrefs());
          api = buildApi();
          await api.initialWrite;

          await expectLater(
            () => api.deleteIngredient('nope'),
            throwsA(
              isA<IngredientNotFoundException>().having(
                (exception) => exception.id,
                'id',
                equals('nope'),
              ),
            ),
          );
        },
      );

      test(
        'throws IngredientInUseException counting recipes in every library',
        () async {
          await setUpPrefs(
            seededPrefs(
              ingredients: [gin],
              recipes: [
                Recipe(
                  id: 'r1',
                  libraryId: cocktails.id,
                  name: 'Negroni',
                  ingredients: [Ingredient(name: 'Gin', catalogId: gin.id)],
                ),
                Recipe(
                  id: 'r2',
                  libraryId: coffee.id,
                  name: 'Gin tonic espresso',
                  ingredients: [Ingredient(name: 'Gin', catalogId: gin.id)],
                ),
                Recipe(id: 'r3', libraryId: cocktails.id, name: 'Daiquiri'),
              ],
            ),
          );
          api = buildApi();
          await api.initialWrite;

          await expectLater(
            () => api.deleteIngredient(gin.id),
            throwsA(
              isA<IngredientInUseException>()
                  .having((exception) => exception.id, 'id', equals(gin.id))
                  .having(
                    (exception) => exception.recipeCount,
                    'recipeCount',
                    equals(2),
                  ),
            ),
          );
          expect((await api.watch().first).ingredients, equals([gin]));
        },
      );
    });

    group('saveLibrary', () {
      final glassware = cocktails.fields.first;
      final garnish = cocktails.fields.last;
      final tea = Library(id: 'tea', name: 'Tea');

      FieldDefinition glasswareWith(List<String> options) => FieldDefinition(
        id: glassware.id,
        label: glassware.label,
        type: FieldType.select,
        options: options,
      );

      Library cocktailsWith(List<FieldDefinition> fields) =>
          Library(id: cocktails.id, name: cocktails.name, fields: fields);

      Recipe cocktail(String id, Map<String, Object?> fieldValues) => Recipe(
        id: id,
        libraryId: cocktails.id,
        name: 'Cocktail $id',
        fieldValues: fieldValues,
      );

      Future<_RecordingStore> open({List<Recipe> recipes = const []}) async {
        final store = await setUpRecordingPrefs(seededPrefs(recipes: recipes));
        api = buildApi();
        await api.initialWrite;
        store.writtenKeys.clear();
        return store;
      }

      Future<Map<String, Object?>> valuesOf(String recipeId) async {
        final snapshot = await api.watch().first;
        return snapshot.recipes
            .singleWhere((recipe) => recipe.id == recipeId)
            .fieldValues;
      }

      test('appends a library whose id is unknown', () async {
        final store = await open();

        await api.saveLibrary(tea);

        final snapshot = await api.watch().first;
        expect(snapshot.libraries, equals([cocktails, coffee, tea]));
        expect(snapshot.activeLibraryId, equals(cocktails.id));
        expect(
          plugin.getString(LocalStorageRecipesApi.kLibrariesKey),
          equals(
            jsonEncode([cocktails.toJson(), coffee.toJson(), tea.toJson()]),
          ),
        );
        expect(
          store.writtenKeys,
          equals([LocalStorageRecipesApi.kLibrariesKey]),
        );
      });

      test('replaces a library whose id is known at the same index', () async {
        await open();
        final renamed = Library(
          id: cocktails.id,
          name: 'Drinks',
          fields: cocktails.fields,
        );

        await api.saveLibrary(renamed);

        expect(
          (await api.watch().first).libraries,
          equals([renamed, coffee]),
        );
      });

      test(
        'throws LibraryNameTakenException for a name another library carries',
        () async {
          final store = await open();

          await expectLater(
            () => api.saveLibrary(Library(name: ' coffee ')),
            throwsA(
              isA<LibraryNameTakenException>().having(
                (exception) => exception.name,
                'name',
                equals('coffee'),
              ),
            ),
          );
          expect(
            (await api.watch().first).libraries,
            equals([cocktails, coffee]),
          );
          expect(store.writtenKeys, isEmpty);
        },
      );

      test('accepts a library saved under its own name', () async {
        await open();
        final recased = Library(
          id: cocktails.id,
          name: 'COCKTAILS',
          fields: cocktails.fields,
        );

        // Folding onto its own name is a rename, not a collision.
        await api.saveLibrary(recased);

        expect((await api.watch().first).libraries.first, equals(recased));
      });

      test('writes only the libraries key when no recipe changed', () async {
        final store = await open(
          recipes: [
            cocktail('r1', {glassware.id: 'Coupe', garnish.id: 'Lemon twist'}),
          ],
        );

        await api.saveLibrary(
          Library(id: cocktails.id, name: 'Drinks', fields: cocktails.fields),
        );

        expect(
          store.writtenKeys,
          equals([LocalStorageRecipesApi.kLibrariesKey]),
        );
      });

      test('stores a new field order without touching any recipe', () async {
        final recipes = [
          cocktail('r1', {glassware.id: 'Coupe', garnish.id: 'Lemon twist'}),
          cocktail('r2', {garnish.id: 'Orange'}),
        ];
        final store = await open(recipes: recipes);
        final storedRecipes = plugin.getString(
          LocalStorageRecipesApi.kRecipesKey,
        );
        final reordered = cocktailsWith(cocktails.fields.reversed.toList());

        await api.saveLibrary(reordered);

        final snapshot = await api.watch().first;
        expect(
          snapshot.libraries.first.fields.map((field) => field.id),
          equals(cocktails.fields.reversed.map((field) => field.id)),
        );
        expect(snapshot.recipes, equals(recipes));
        expect(
          plugin.getString(LocalStorageRecipesApi.kLibrariesKey),
          equals(jsonEncode([reordered.toJson(), coffee.toJson()])),
        );
        expect(
          plugin.getString(LocalStorageRecipesApi.kRecipesKey),
          equals(storedRecipes),
        );
        expect(
          store.writtenKeys,
          equals([LocalStorageRecipesApi.kLibrariesKey]),
        );
      });

      test(
        'delivers the snapshot to a listener within a microtask of the save '
        'returning',
        () async {
          await open();
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);
          await pumpEventQueue();
          final reordered = cocktailsWith(cocktails.fields.reversed.toList());

          await api.saveLibrary(reordered);
          // One microtask, not a pumped queue: a caller that acts on what it
          // was last handed, in work it schedules once the save returns, has
          // to find the new order already there.
          await Future<void>.microtask(() {});

          expect(emitted.single.libraries.first, equals(reordered));
        },
      );

      test(
        "drops a removed field's values from that library's recipes only",
        () async {
          // The coffee recipe carries the same key, so only the library id
          // can be what spares it.
          final v60 = Recipe(
            id: 'r2',
            libraryId: coffee.id,
            name: 'V60',
            fieldValues: {garnish.id: 'None', 'unknown': 1},
          );
          await open(
            recipes: [
              cocktail('r1', {glassware.id: 'Rocks', garnish.id: 'Orange'}),
              v60,
              // Not a string: the key being present is all that counts.
              cocktail('r3', {garnish.id: 3}),
            ],
          );

          await api.saveLibrary(cocktailsWith([glassware]));

          expect(await valuesOf('r1'), equals({glassware.id: 'Rocks'}));
          expect(await valuesOf('r3'), isEmpty);
          final stored = jsonDecode(
            plugin.getString(LocalStorageRecipesApi.kRecipesKey)!,
          ) as List<dynamic>;
          expect(jsonEncode(stored[1]), equals(jsonEncode(v60.toJson())));
        },
      );

      test('leaves a key that matched no stored field in place', () async {
        await open(
          recipes: [
            cocktail('r1', {'unknown': 'kept', garnish.id: 'Orange'}),
          ],
        );

        await api.saveLibrary(cocktailsWith([glassware]));

        expect(await valuesOf('r1'), equals({'unknown': 'kept'}));
      });

      test('applies an option rename to the values holding it', () async {
        await open(
          recipes: [
            cocktail('r1', {glassware.id: 'Coupe', garnish.id: 'Lemon twist'}),
            cocktail('r2', {glassware.id: 'Rocks'}),
          ],
        );

        await api.saveLibrary(
          cocktailsWith([
            glasswareWith(const ['Coupe glass', 'Rocks']),
            garnish,
          ]),
          optionRenames: {
            glassware.id: const {'Coupe': 'Coupe glass'},
          },
        );

        expect(
          await valuesOf('r1'),
          equals({glassware.id: 'Coupe glass', garnish.id: 'Lemon twist'}),
        );
        expect(await valuesOf('r2'), equals({glassware.id: 'Rocks'}));
      });

      test('swaps the values of two options renamed onto each other', () async {
        await open(
          recipes: [
            cocktail('r1', {glassware.id: 'Coupe'}),
            cocktail('r2', {glassware.id: 'Rocks'}),
          ],
        );

        await api.saveLibrary(
          cocktailsWith([
            glasswareWith(const ['Rocks', 'Coupe']),
            garnish,
          ]),
          optionRenames: {
            glassware.id: const {'Coupe': 'Rocks', 'Rocks': 'Coupe'},
          },
        );

        expect(await valuesOf('r1'), equals({glassware.id: 'Rocks'}));
        expect(await valuesOf('r2'), equals({glassware.id: 'Coupe'}));
      });

      test('clears the values of a removed option', () async {
        await open(
          recipes: [
            cocktail('r1', {glassware.id: 'Flute'}),
            cocktail('r2', {glassware.id: 'Rocks'}),
          ],
        );

        await api.saveLibrary(
          cocktailsWith([
            glasswareWith(const ['Coupe', 'Rocks']),
            garnish,
          ]),
        );

        expect(await valuesOf('r1'), isEmpty);
        expect(await valuesOf('r2'), equals({glassware.id: 'Rocks'}));
      });

      test(
        'clears a removed option only where the stored value equals it '
        "exactly, and only in that library's recipes",
        () async {
          await open(
            recipes: [
              // Padded: the confirmation does not count it, so the save must
              // not clear it.
              cocktail('r1', {glassware.id: 'Flute '}),
              Recipe(
                id: 'r2',
                libraryId: coffee.id,
                name: 'V60',
                fieldValues: {glassware.id: 'Flute'},
              ),
            ],
          );

          await api.saveLibrary(
            cocktailsWith([
              glasswareWith(const ['Coupe', 'Rocks']),
              garnish,
            ]),
          );

          expect(await valuesOf('r1'), equals({glassware.id: 'Flute '}));
          expect(await valuesOf('r2'), equals({glassware.id: 'Flute'}));
        },
      );

      test(
        'merges an option renamed onto one that was deleted, clearing '
        'nothing',
        () async {
          await open(
            recipes: [
              cocktail('r1', {glassware.id: 'Coupe'}),
              cocktail('r2', {glassware.id: 'Rocks'}),
            ],
          );

          await api.saveLibrary(
            cocktailsWith([
              glasswareWith(const ['Rocks']),
              garnish,
            ]),
            optionRenames: {
              glassware.id: const {'Coupe': 'Rocks'},
            },
          );

          expect(await valuesOf('r1'), equals({glassware.id: 'Rocks'}));
          expect(await valuesOf('r2'), equals({glassware.id: 'Rocks'}));
        },
      );

      test(
        'leaves a value that was already outside the stored options alone',
        () async {
          await open(
            recipes: [
              cocktail('r1', {glassware.id: 'Tiki mug'}),
              cocktail('r2', {glassware.id: 7}),
            ],
          );

          await api.saveLibrary(
            cocktailsWith([
              glasswareWith(const ['Coupe']),
              garnish,
            ]),
          );

          expect(await valuesOf('r1'), equals({glassware.id: 'Tiki mug'}));
          expect(await valuesOf('r2'), equals({glassware.id: 7}));
        },
      );

      test(
        'leaves a value alone when its field stops being a select',
        () async {
          await open(
            recipes: [
              cocktail('r1', {glassware.id: 'Coupe'}),
            ],
          );

          await api.saveLibrary(
            cocktailsWith([
              FieldDefinition(
                id: glassware.id,
                label: glassware.label,
                type: FieldType.text,
              ),
              garnish,
            ]),
          );

          expect(await valuesOf('r1'), equals({glassware.id: 'Coupe'}));
        },
      );

      test(
        'writes the recipes, then the libraries, and emits one snapshot',
        () async {
          final store = await open(
            recipes: [
              cocktail('r1', {garnish.id: 'Orange'}),
            ],
          );
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);

          await api.saveLibrary(cocktailsWith([glassware]));
          await pumpEventQueue();

          expect(
            store.writtenKeys,
            equals([
              LocalStorageRecipesApi.kRecipesKey,
              LocalStorageRecipesApi.kLibrariesKey,
            ]),
          );
          expect(emitted, hasLength(1));
          expect(
            emitted.single.libraries.map((library) => library.id),
            contains(emitted.single.activeLibraryId),
          );
        },
      );

      test(
        'a failed libraries write throws and emits nothing, and a retry '
        'completes the save',
        () async {
          final store = await open(
            recipes: [
              cocktail('r1', {garnish.id: 'Orange'}),
            ],
          );
          final withoutGarnish = cocktailsWith([glassware]);
          final before = await api.watch().first;
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);
          store.failingKey = LocalStorageRecipesApi.kLibrariesKey;

          await expectLater(
            () => api.saveLibrary(withoutGarnish),
            throwsA(isA<RecipesPersistenceException>()),
          );
          await pumpEventQueue();

          expect(emitted, isEmpty);
          expect(await api.watch().first, equals(before));
          expect(
            store.writtenKeys,
            equals([LocalStorageRecipesApi.kRecipesKey]),
          );

          store.failingKey = null;
          await api.saveLibrary(withoutGarnish);

          expect(
            (await api.watch().first).libraries.first,
            equals(withoutGarnish),
          );
          expect(await valuesOf('r1'), isEmpty);
        },
      );
    });

    group('deleteLibrary', () {
      final tea = Library(id: 'tea', name: 'Tea');
      final gin = CatalogIngredient(
        id: 'i1',
        name: 'Gin',
        libraryIds: {cocktails.id},
      );
      final sugar = CatalogIngredient(
        id: 'i2',
        name: 'Sugar',
        libraryIds: {cocktails.id, coffee.id},
      );
      final cinnamon = CatalogIngredient(
        id: 'i3',
        name: 'Cinnamon',
        libraryIds: {coffee.id},
      );
      final negroni = Recipe(
        id: 'r1',
        libraryId: cocktails.id,
        name: 'Negroni',
      );
      final v60 = Recipe(id: 'r2', libraryId: coffee.id, name: 'V60');

      Future<_RecordingStore> open({
        List<Library>? libraries,
        List<CatalogIngredient>? ingredients,
      }) async {
        final store = await setUpRecordingPrefs(
          seededPrefs(
            libraries: libraries,
            recipes: [negroni, v60],
            ingredients: ingredients ?? [gin, sugar, cinnamon],
          ),
        );
        api = buildApi();
        await api.initialWrite;
        store.writtenKeys.clear();
        return store;
      }

      test('removes the library along with its recipes', () async {
        await open();

        await api.deleteLibrary(cocktails.id, successorId: coffee.id);

        final snapshot = await api.watch().first;
        expect(snapshot.libraries, equals([coffee]));
        expect(snapshot.recipes, equals([v60]));
        expect(
          plugin.getString(LocalStorageRecipesApi.kLibrariesKey),
          equals(jsonEncode([coffee.toJson()])),
        );
        expect(
          plugin.getString(LocalStorageRecipesApi.kRecipesKey),
          equals(jsonEncode([v60.toJson()])),
        );
      });

      test(
        'strips the id from a shared entry and moves an entry scoped only '
        'to it to the successor',
        () async {
          await open();

          await api.deleteLibrary(cocktails.id, successorId: coffee.id);

          final moved = [
            CatalogIngredient(
              id: gin.id,
              name: gin.name,
              libraryIds: {coffee.id},
            ),
            CatalogIngredient(
              id: sugar.id,
              name: sugar.name,
              libraryIds: {coffee.id},
            ),
            cinnamon,
          ];
          expect((await api.watch().first).ingredients, equals(moved));
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
            equals(jsonEncode([for (final entry in moved) entry.toJson()])),
          );
        },
      );

      test(
        'leaves a shared entry in its other libraries rather than moving it '
        'to the successor',
        () async {
          final lime = CatalogIngredient(
            id: 'i4',
            name: 'Lime',
            libraryIds: {cocktails.id, tea.id},
          );
          await open(
            libraries: [cocktails, coffee, tea],
            ingredients: [gin, sugar, cinnamon, lime],
          );

          await api.deleteLibrary(cocktails.id, successorId: tea.id);

          final scopes = {
            for (final entry in (await api.watch().first).ingredients)
              entry.name: entry.libraryIds,
          };
          expect(
            scopes,
            equals({
              'Gin': {tea.id},
              'Sugar': {coffee.id},
              'Cinnamon': {coffee.id},
              'Lime': {tea.id},
            }),
          );
        },
      );

      test(
        'makes the successor active when the deleted library was',
        () async {
          await open();

          await api.deleteLibrary(cocktails.id, successorId: coffee.id);

          expect(
            (await api.watch().first).activeLibraryId,
            equals(coffee.id),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kActiveLibraryIdKey),
            equals(coffee.id),
          );
        },
      );

      test(
        'leaves the active library alone when another one is deleted',
        () async {
          final store = await open();

          await api.deleteLibrary(coffee.id, successorId: cocktails.id);

          expect(
            (await api.watch().first).activeLibraryId,
            equals(cocktails.id),
          );
          expect(
            store.writtenKeys,
            isNot(contains(LocalStorageRecipesApi.kActiveLibraryIdKey)),
          );
        },
      );

      for (final (reason, id, successorId, missing) in [
        ('an unknown id', 'nope', coffee.id, 'nope'),
        ('an unknown successor', cocktails.id, 'nope', 'nope'),
        (
          'a successor equal to the id',
          cocktails.id,
          cocktails.id,
          cocktails.id,
        ),
      ]) {
        test('throws LibraryNotFoundException for $reason', () async {
          final store = await open();

          await expectLater(
            () => api.deleteLibrary(id, successorId: successorId),
            throwsA(
              isA<LibraryNotFoundException>().having(
                (exception) => exception.id,
                'id',
                equals(missing),
              ),
            ),
          );
          expect(
            (await api.watch().first).libraries,
            equals([cocktails, coffee]),
          );
          expect(store.writtenKeys, isEmpty);
        });
      }

      test('throws LibraryNotFoundException for the only library', () async {
        final store = await open(libraries: [cocktails]);

        await expectLater(
          () => api.deleteLibrary(cocktails.id, successorId: cocktails.id),
          throwsA(isA<LibraryNotFoundException>()),
        );
        expect((await api.watch().first).libraries, equals([cocktails]));
        expect(store.writtenKeys, isEmpty);
      });

      test(
        'writes the ingredients, the active id, the recipes, then the '
        'libraries, and emits one snapshot',
        () async {
          final store = await open();
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);

          await api.deleteLibrary(cocktails.id, successorId: coffee.id);
          await pumpEventQueue();

          expect(
            store.writtenKeys,
            equals([
              LocalStorageRecipesApi.kIngredientsKey,
              LocalStorageRecipesApi.kActiveLibraryIdKey,
              LocalStorageRecipesApi.kRecipesKey,
              LocalStorageRecipesApi.kLibrariesKey,
            ]),
          );
          expect(emitted, hasLength(1));
          expect(
            emitted.single.libraries.map((library) => library.id),
            contains(emitted.single.activeLibraryId),
          );
        },
      );

      test('writes only the libraries key when nothing else changed', () async {
        final store = await open(libraries: [cocktails, coffee, tea]);

        await api.deleteLibrary(tea.id, successorId: coffee.id);

        expect(
          store.writtenKeys,
          equals([LocalStorageRecipesApi.kLibrariesKey]),
        );
        expect(
          (await api.watch().first).ingredients,
          equals([gin, sugar, cinnamon]),
        );
      });

      test(
        'a write failing part-way throws and emits nothing, and a retry '
        'completes the delete',
        () async {
          final store = await open();
          final before = await api.watch().first;
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);
          store.failingKey = LocalStorageRecipesApi.kRecipesKey;

          await expectLater(
            () => api.deleteLibrary(cocktails.id, successorId: coffee.id),
            throwsA(isA<RecipesPersistenceException>()),
          );
          await pumpEventQueue();

          expect(emitted, isEmpty);
          expect(await api.watch().first, equals(before));
          expect(
            store.writtenKeys,
            equals([
              LocalStorageRecipesApi.kIngredientsKey,
              LocalStorageRecipesApi.kActiveLibraryIdKey,
            ]),
          );

          store.failingKey = null;
          await api.deleteLibrary(cocktails.id, successorId: coffee.id);

          final snapshot = await api.watch().first;
          expect(snapshot.libraries, equals([coffee]));
          expect(snapshot.recipes, equals([v60]));
          expect(snapshot.activeLibraryId, equals(coffee.id));
        },
      );
    });

    group('serialization', () {
      test(
        'a library save queued behind a recipe save conforms that recipe',
        () async {
          await setUpPrefs(seededPrefs());
          api = buildApi();
          await api.initialWrite;
          final garnish = cocktails.fields.last;
          final negroni = Recipe(
            id: 'r1',
            libraryId: cocktails.id,
            name: 'Negroni',
            fieldValues: {garnish.id: 'Orange'},
          );

          await Future.wait([
            api.saveRecipe(negroni),
            api.saveLibrary(
              Library(
                id: cocktails.id,
                name: cocktails.name,
                fields: [cocktails.fields.first],
              ),
            ),
          ]);

          expect(
            (await api.watch().first).recipes.single.fieldValues,
            isEmpty,
          );
        },
      );

      test(
        'a library delete queued behind a recipe save removes that recipe',
        () async {
          await setUpPrefs(seededPrefs());
          api = buildApi();
          await api.initialWrite;
          final v60 = Recipe(id: 'r1', libraryId: coffee.id, name: 'V60');

          await Future.wait([
            api.saveRecipe(v60),
            api.deleteLibrary(coffee.id, successorId: cocktails.id),
          ]);

          expect((await api.watch().first).recipes, isEmpty);
          expect(
            plugin.getString(LocalStorageRecipesApi.kRecipesKey),
            equals('[]'),
          );
        },
      );

      test('two overlapping mutations both land', () async {
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;
        final negroni = Recipe(
          id: 'r1',
          libraryId: cocktails.id,
          name: 'Negroni',
        );
        final daiquiri = Recipe(
          id: 'r2',
          libraryId: cocktails.id,
          name: 'Daiquiri',
        );

        await Future.wait([api.saveRecipe(negroni), api.saveRecipe(daiquiri)]);

        expect(
          (await api.watch().first).recipes,
          equals([negroni, daiquiri]),
        );
        expect(
          plugin.getString(LocalStorageRecipesApi.kRecipesKey),
          equals(jsonEncode([negroni.toJson(), daiquiri.toJson()])),
        );
      });

      test('a failed mutation does not stall the ones behind it', () async {
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;
        final negroni = Recipe(
          id: 'r1',
          libraryId: cocktails.id,
          name: 'Negroni',
        );

        final failed = api.deleteRecipe('nope');
        final saved = api.saveRecipe(negroni);

        await expectLater(failed, throwsA(isA<RecipeNotFoundException>()));
        await saved;
        expect((await api.watch().first).recipes, equals([negroni]));
      });

      test(
        'a mutation dispatched before the initial write lands after it',
        () async {
          final store = await setUpRecordingPrefs({});
          final gin = CatalogIngredient(
            id: 'i1',
            name: 'Gin',
            libraryIds: {cocktails.id},
          );

          api = buildApi();
          // Not awaiting the initial write: the migration's empty catalog must
          // not overtake this save and wipe the entry it wrote.
          await api.saveIngredient(gin);

          expect(
            store.writtenKeys.last,
            equals(LocalStorageRecipesApi.kIngredientsKey),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
            equals(jsonEncode([gin.toJson()])),
          );
        },
      );
    });

    group('setActiveLibraryId', () {
      setUp(() async {
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;
      });

      test('persists the id and re-emits the snapshot', () async {
        await api.setActiveLibraryId(coffee.id);

        expect((await api.watch().first).activeLibraryId, equals(coffee.id));
        expect(
          plugin.getString(LocalStorageRecipesApi.kActiveLibraryIdKey),
          equals(coffee.id),
        );
      });

      test('throws when the write fails', () async {
        SharedPreferencesStorePlatform.instance = _FailingStore();

        await expectLater(
          () => api.setActiveLibraryId(coffee.id),
          throwsA(isA<RecipesPersistenceException>()),
        );
      });
    });

    test('close ends the stream', () async {
      api = buildApi();
      await api.initialWrite;

      final stream = api.watch();
      await api.close();

      // The last snapshot is still replayed to a late subscriber; what closing
      // guarantees is that nothing follows it.
      await expectLater(
        stream,
        emitsInOrder(<Object>[isA<RecipesSnapshot>(), emitsDone]),
      );
    });
  });
}
