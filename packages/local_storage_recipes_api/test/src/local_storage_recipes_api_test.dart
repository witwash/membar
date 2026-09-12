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

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writtenKeys.add(key.replaceFirst('flutter.', ''));
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

        final stored =
            jsonDecode(
                  plugin.getString(LocalStorageRecipesApi.kLibrariesKey)!,
                )
                as List<dynamic>;
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

    group('saveIngredients', () {
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

      test('writes every entry once and emits one snapshot', () async {
        final store = await setUpRecordingPrefs(
          seededPrefs(ingredients: [gin]),
        );
        api = buildApi();
        await api.initialWrite;
        store.writtenKeys.clear();
        final emitted = <RecipesSnapshot>[];
        final subscription = api.watch().skip(1).listen(emitted.add);
        addTearDown(subscription.cancel);

        await api.saveIngredients([campari, sugar]);
        await pumpEventQueue();

        expect(
          store.writtenKeys,
          equals([LocalStorageRecipesApi.kIngredientsKey]),
        );
        expect(emitted, hasLength(1));
        expect(emitted.single.ingredients, equals([gin, campari, sugar]));
        expect(emitted.single.recipes, isEmpty);
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

        await api.saveIngredients([renamed]);

        expect(
          (await api.watch().first).ingredients,
          equals([renamed, campari]),
        );
      });

      test(
        'stores nothing when an entry folds onto a stored one',
        () async {
          await setUpPrefs(seededPrefs(ingredients: [gin]));
          api = buildApi();
          await api.initialWrite;

          await expectLater(
            () => api.saveIngredients([
              campari,
              CatalogIngredient(name: 'GIN', libraryIds: {coffee.id}),
            ]),
            throwsA(isA<IngredientNameTakenException>()),
          );
          expect((await api.watch().first).ingredients, equals([gin]));
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
            equals(jsonEncode([gin.toJson()])),
          );
        },
      );

      test('throws when two entries in the batch fold together', () async {
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;

        await expectLater(
          () => api.saveIngredients([
            campari,
            CatalogIngredient(name: 'campari', libraryIds: {coffee.id}),
          ]),
          throwsA(isA<IngredientNameTakenException>()),
        );
        expect((await api.watch().first).ingredients, isEmpty);
      });

      test('throws when the write fails', () async {
        await setUpPrefs(seededPrefs());
        api = buildApi();
        await api.initialWrite;
        SharedPreferencesStorePlatform.instance = _FailingStore();

        await expectLater(
          () => api.saveIngredients([gin]),
          throwsA(isA<RecipesPersistenceException>()),
        );
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

    group('serialization', () {
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
