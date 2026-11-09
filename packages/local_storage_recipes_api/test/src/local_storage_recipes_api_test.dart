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
    final (cocktails, cocktailsIngredients) = seeded.first;
    final (coffee, coffeeIngredients) = seeded.last;

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

    /// Prefs holding an already-seeded install: both templates and their
    /// ingredient libraries, no recipes, an empty catalog, Cocktails active.
    Map<String, Object> seededPrefs({
      List<Library>? libraries,
      List<IngredientLibrary>? ingredientLibraries,
      List<Recipe>? recipes,
      List<CatalogIngredient>? ingredients,
      String? activeLibraryId,
    }) {
      return {
        LocalStorageRecipesApi.kSchemaVersionKey:
            LocalStorageRecipesApi.kSchemaVersion,
        LocalStorageRecipesApi.kLibrariesKey: jsonEncode([
          for (final library in libraries ?? [cocktails, coffee])
            library.toJson(),
        ]),
        LocalStorageRecipesApi.kIngredientLibrariesKey: jsonEncode([
          for (final ingredientLibrary
              in ingredientLibraries ??
                  [cocktailsIngredients, coffeeIngredients])
            ingredientLibrary.toJson(),
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

      test(
        'seeds every template with its own ingredient library and opens on '
        'the first one',
        () async {
          final snapshot = await api.watch().first;

          expect(snapshot.libraries, equals([cocktails, coffee]));
          expect(
            snapshot.ingredientLibraries,
            equals([cocktailsIngredients, coffeeIngredients]),
          );
          expect(snapshot.recipes, isEmpty);
          expect(snapshot.activeLibraryId, equals(cocktails.id));
        },
      );

      test(
        'writes the libraries, the ingredient libraries, the active id and '
        'the schema version',
        () {
          expect(
            plugin.getInt(LocalStorageRecipesApi.kSchemaVersionKey),
            equals(LocalStorageRecipesApi.kSchemaVersion),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kActiveLibraryIdKey),
            equals(cocktails.id),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kLibrariesKey),
            equals(jsonEncode([cocktails.toJson(), coffee.toJson()])),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientLibrariesKey),
            equals(
              jsonEncode([
                cocktailsIngredients.toJson(),
                coffeeIngredients.toJson(),
              ]),
            ),
          );
        },
      );

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

    group('reseed', () {
      const reseededKeys = [
        LocalStorageRecipesApi.kIngredientLibrariesKey,
        LocalStorageRecipesApi.kIngredientsKey,
        LocalStorageRecipesApi.kRecipesKey,
        LocalStorageRecipesApi.kLibrariesKey,
        LocalStorageRecipesApi.kActiveLibraryIdKey,
        LocalStorageRecipesApi.kSchemaVersionKey,
      ];

      Future<void> expectReseeded() async {
        final snapshot = await api.watch().first;
        expect(snapshot.libraries, equals([cocktails, coffee]));
        expect(
          snapshot.ingredientLibraries,
          equals([cocktailsIngredients, coffeeIngredients]),
        );
        expect(snapshot.recipes, isEmpty);
        expect(snapshot.ingredients, isEmpty);
        expect(snapshot.activeLibraryId, equals(cocktails.id));
        expect(
          plugin.getInt(LocalStorageRecipesApi.kSchemaVersionKey),
          equals(4),
        );
        expect(reported, isEmpty);
      }

      test(
        'a fresh install writes every key, the version last, at 4',
        () async {
          final store = await setUpRecordingPrefs({});

          api = buildApi();
          await api.initialWrite;

          expect(store.writtenKeys, equals(reseededKeys));
          await expectReseeded();
        },
      );

      test(
        'a version 2 install is discarded and reseeded with two pairs',
        () async {
          // Shaped as version 2 stored it: none of it decodes as version 3,
          // so a reseed that read any of it would fail.
          final store = await setUpRecordingPrefs({
            LocalStorageRecipesApi.kSchemaVersionKey: 2,
            LocalStorageRecipesApi.kLibrariesKey: jsonEncode([
              {'id': 'old', 'name': 'Bar', 'fields': <Object>[]},
            ]),
            LocalStorageRecipesApi.kRecipesKey: jsonEncode([
              {
                'id': 'r1',
                'libraryId': 'old',
                'name': 'Negroni',
                'ingredients': [
                  {'name': 'Gin'},
                ],
              },
            ]),
            LocalStorageRecipesApi.kIngredientsKey: jsonEncode([
              {
                'id': 'i1',
                'name': 'Gin',
                'libraryIds': ['old'],
              },
            ]),
            LocalStorageRecipesApi.kActiveLibraryIdKey: 'old',
            '__ingredients_import_version_key__': 1,
          });

          api = buildApi();
          await api.initialWrite;

          expect(store.writtenKeys, equals(reseededKeys));
          await expectReseeded();
          expect(
            plugin.getInt('__ingredients_import_version_key__'),
            equals(1),
            reason: 'nothing reads it, and there is no remove path',
          );
        },
      );

      test('a version 3 install is discarded and reseeded', () async {
        final store = await setUpRecordingPrefs({
          ...seededPrefs(
            recipes: [Recipe(libraryId: cocktails.id, name: 'Negroni')],
          ),
          LocalStorageRecipesApi.kSchemaVersionKey: 3,
        });

        api = buildApi();
        await api.initialWrite;

        expect(store.writtenKeys, equals(reseededKeys));
        await expectReseeded();
      });

      test('a version 4 install writes nothing', () async {
        final store = await setUpRecordingPrefs(seededPrefs());

        api = buildApi();
        await api.initialWrite;

        expect(store.writtenKeys, isEmpty);
        expect(
          (await api.watch().first).ingredientLibraries,
          equals([cocktailsIngredients, coffeeIngredients]),
        );
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
          expect(
            snapshot.ingredientLibraries.map((library) => library.id),
            equals(
              snapshot.libraries.map((library) => library.ingredientLibraryId),
            ),
          );
          expect(snapshot.recipes, equals([orphan]));
          expect(
            reported,
            equals([
              contains('libraries could not be read'),
              contains('were missing'),
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
        expect(
          reported,
          equals([
            contains('No libraries were stored'),
            contains('were missing'),
          ]),
        );
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
        'recreates each ingredient library an unreadable blob lost under its '
        'id, named after the first library using it',
        () async {
          final drinks = Library(
            id: cocktails.id,
            name: 'Drinks',
            ingredientLibraryId: cocktailsIngredients.id,
            fields: cocktails.fields,
          );
          final tiki = Library(
            id: 'tiki',
            name: 'Tiki',
            ingredientLibraryId: cocktailsIngredients.id,
          );
          final gin = CatalogIngredient(
            id: 'i1',
            name: 'Gin',
            ingredientLibraryId: cocktailsIngredients.id,
          );
          final store = await setUpRecordingPrefs(
            seededPrefs(libraries: [drinks, tiki, coffee], ingredients: [gin])
              ..[LocalStorageRecipesApi.kIngredientLibrariesKey] = 'not json',
          );

          api = buildApi();
          await api.initialWrite;

          final recreated = [
            IngredientLibrary(id: cocktailsIngredients.id, name: 'Drinks'),
            IngredientLibrary(id: coffeeIngredients.id, name: 'Coffee'),
          ];
          final snapshot = await api.watch().first;
          expect(snapshot.ingredientLibraries, equals(recreated));
          expect(snapshot.libraries, equals([drinks, tiki, coffee]));
          expect(snapshot.ingredients, equals([gin]));
          expect(
            store.writtenKeys,
            equals([LocalStorageRecipesApi.kIngredientLibrariesKey]),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientLibrariesKey),
            equals(jsonEncode([for (final entry in recreated) entry.toJson()])),
          );
          expect(
            reported,
            equals([
              contains('ingredient libraries could not be read'),
              startsWith('2 ingredient library(ies) were missing'),
            ]),
          );
        },
      );

      test(
        'recreates only the missing ingredient libraries, after the stored '
        'ones',
        () async {
          await setUpPrefs(
            seededPrefs(ingredientLibraries: [coffeeIngredients]),
          );

          api = buildApi();
          await api.initialWrite;

          expect(
            (await api.watch().first).ingredientLibraries,
            equals([coffeeIngredients, cocktailsIngredients]),
          );
          expect(
            reported.single,
            startsWith('1 ingredient library(ies) were missing'),
          );
        },
      );

      test(
        'keeps an ingredient whose ingredient library is gone, and reports it',
        () async {
          final stray = CatalogIngredient(
            id: 'i1',
            name: 'Gin',
            ingredientLibraryId: 'gone',
          );
          await setUpPrefs(seededPrefs(ingredients: [stray]));

          api = buildApi();
          await api.initialWrite;

          expect((await api.watch().first).ingredients, equals([stray]));
          expect(
            reported.single,
            allOf(
              startsWith('1 ingredient(s)'),
              contains('belong to an ingredient library that no longer exists'),
            ),
          );
        },
      );

      test(
        'keeps rows whose catalog entry is gone, and reports them as hidden',
        () async {
          final negroni = Recipe(
            id: 'r1',
            libraryId: cocktails.id,
            name: 'Negroni',
            ingredients: [
              Ingredient(catalogId: 'gone'),
              Ingredient(catalogId: 'i1'),
            ],
          );
          await setUpPrefs(
            seededPrefs(
              recipes: [negroni],
              ingredients: [
                CatalogIngredient(
                  id: 'i1',
                  name: 'Campari',
                  ingredientLibraryId: cocktailsIngredients.id,
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
              contains('they are hidden'),
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

        expect(printed.first, contains('libraries could not be read'));
      });
    });

    group('saveRecipe', () {
      final gin = CatalogIngredient(
        id: 'i1',
        name: 'Gin',
        ingredientLibraryId: cocktailsIngredients.id,
      );
      final milk = CatalogIngredient(
        id: 'i2',
        name: 'Milk',
        ingredientLibraryId: coffeeIngredients.id,
      );
      late Recipe negroni;

      setUp(() async {
        negroni = Recipe(id: 'r1', libraryId: cocktails.id, name: 'Negroni');
        await setUpPrefs(seededPrefs(ingredients: [gin, milk]));
        api = buildApi();
        await api.initialWrite;
      });

      Future<void> expectNothingStored() async {
        expect((await api.watch().first).recipes, isEmpty);
        expect(
          plugin.getString(LocalStorageRecipesApi.kRecipesKey),
          equals('[]'),
        );
      }

      test('adds a recipe and re-emits the snapshot', () async {
        await api.saveRecipe(negroni);

        expect((await api.watch().first).recipes, equals([negroni]));
        expect(
          plugin.getString(LocalStorageRecipesApi.kRecipesKey),
          equals(jsonEncode([negroni.toJson()])),
        );
      });

      test(
        "stores rows drawn from its library's ingredient library",
        () async {
          final withGin = Recipe(
            id: 'r1',
            libraryId: cocktails.id,
            name: 'Negroni',
            ingredients: [Ingredient(catalogId: gin.id, quantity: '30')],
          );

          await api.saveRecipe(withGin);

          expect((await api.watch().first).recipes, equals([withGin]));
        },
      );

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

      test(
        'throws LibraryNotFoundException for a library that is gone, storing '
        'nothing',
        () async {
          await expectLater(
            () => api.saveRecipe(
              Recipe(id: 'r1', libraryId: 'gone', name: 'Sour'),
            ),
            throwsA(
              isA<LibraryNotFoundException>().having(
                (exception) => exception.id,
                'id',
                equals('gone'),
              ),
            ),
          );
          await expectNothingStored();
        },
      );

      for (final (reason, catalogId) in [
        ('an unknown ingredient', 'nope'),
        ("another ingredient library's ingredient", milk.id),
      ]) {
        test(
          'throws IngredientNotFoundException for $reason, storing nothing',
          () async {
            await expectLater(
              () => api.saveRecipe(
                Recipe(
                  id: 'r1',
                  libraryId: cocktails.id,
                  name: 'Negroni',
                  ingredients: [
                    Ingredient(catalogId: gin.id),
                    Ingredient(catalogId: catalogId),
                  ],
                ),
              ),
              throwsA(
                isA<IngredientNotFoundException>().having(
                  (exception) => exception.id,
                  'id',
                  equals(catalogId),
                ),
              ),
            );
            await expectNothingStored();
          },
        );
      }

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
          ingredientLibraryId: cocktailsIngredients.id,
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
          ingredientLibraryId: cocktailsIngredients.id,
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
        'throws IngredientNameTakenException for a name another entry in the '
        'same ingredient library carries',
        () async {
          await api.saveIngredient(gin);

          await expectLater(
            () => api.saveIngredient(
              CatalogIngredient(
                name: ' gin ',
                ingredientLibraryId: cocktailsIngredients.id,
              ),
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

      test(
        'accepts a name an entry in another ingredient library carries',
        () async {
          await api.saveIngredient(gin);
          final coffeeGin = CatalogIngredient(
            id: 'i2',
            name: 'gin',
            ingredientLibraryId: coffeeIngredients.id,
          );

          await api.saveIngredient(coffeeGin);

          expect(
            (await api.watch().first).ingredients,
            equals([gin, coffeeGin]),
          );
        },
      );

      test(
        'throws IngredientLibraryNotFoundException for an unknown ingredient '
        'library, storing nothing',
        () async {
          await expectLater(
            () => api.saveIngredient(
              CatalogIngredient(name: 'Gin', ingredientLibraryId: 'nope'),
            ),
            throwsA(
              isA<IngredientLibraryNotFoundException>().having(
                (exception) => exception.id,
                'id',
                equals('nope'),
              ),
            ),
          );
          expect((await api.watch().first).ingredients, isEmpty);
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
            equals('[]'),
          );
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

    group('deleteIngredient', () {
      // Shares the Cocktails ingredient library, so a strip has to reach
      // past the one library the entry was picked from.
      final tiki = Library(
        id: 'tiki',
        name: 'Tiki',
        ingredientLibraryId: cocktailsIngredients.id,
      );
      final gin = CatalogIngredient(
        id: 'i1',
        name: 'Gin',
        ingredientLibraryId: cocktailsIngredients.id,
      );
      final campari = CatalogIngredient(
        id: 'i2',
        name: 'Campari',
        ingredientLibraryId: cocktailsIngredients.id,
      );
      final negroni = Recipe(
        id: 'r1',
        libraryId: cocktails.id,
        name: 'Negroni',
        ingredients: [
          Ingredient(catalogId: gin.id, quantity: '30', unit: 'ml'),
          Ingredient(catalogId: campari.id),
        ],
        steps: const ['Stir.'],
        tags: const ['Bitter'],
        notes: 'Classic.',
        fieldValues: {cocktails.fields.last.id: 'Orange'},
      );
      final zombie = Recipe(
        id: 'r2',
        libraryId: tiki.id,
        name: 'Zombie',
        ingredients: [Ingredient(catalogId: gin.id)],
      );
      final americano = Recipe(
        id: 'r3',
        libraryId: cocktails.id,
        name: 'Americano',
        ingredients: [Ingredient(catalogId: campari.id)],
      );
      final stripped = [
        Recipe(
          id: negroni.id,
          libraryId: negroni.libraryId,
          name: negroni.name,
          ingredients: [Ingredient(catalogId: campari.id)],
          steps: negroni.steps,
          tags: negroni.tags,
          notes: negroni.notes,
          fieldValues: negroni.fieldValues,
        ),
        Recipe(id: zombie.id, libraryId: zombie.libraryId, name: zombie.name),
        americano,
      ];

      Future<_RecordingStore> open({List<Recipe> recipes = const []}) async {
        final store = await setUpRecordingPrefs(
          seededPrefs(
            libraries: [cocktails, coffee, tiki],
            recipes: recipes,
            ingredients: [gin, campari],
          ),
        );
        api = buildApi();
        await api.initialWrite;
        store.writtenKeys.clear();
        return store;
      }

      test(
        'removes the entry, writing only the ingredients when no recipe '
        'uses it',
        () async {
          final store = await open(recipes: [americano]);

          await api.deleteIngredient(gin.id);

          final snapshot = await api.watch().first;
          expect(snapshot.ingredients, equals([campari]));
          expect(snapshot.recipes, equals([americano]));
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientsKey),
            equals(jsonEncode([campari.toJson()])),
          );
          expect(
            store.writtenKeys,
            equals([LocalStorageRecipesApi.kIngredientsKey]),
          );
        },
      );

      test(
        'strips its rows from every recipe in every library sharing the '
        'ingredient library',
        () async {
          await open(recipes: [negroni, zombie, americano]);

          await api.deleteIngredient(gin.id);

          expect((await api.watch().first).recipes, equals(stripped));
          expect(
            plugin.getString(LocalStorageRecipesApi.kRecipesKey),
            equals(
              jsonEncode([for (final recipe in stripped) recipe.toJson()]),
            ),
          );
        },
      );

      test(
        'writes the recipes, then the ingredients, and emits one snapshot',
        () async {
          final store = await open(recipes: [negroni, zombie, americano]);
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);

          await api.deleteIngredient(gin.id);
          await pumpEventQueue();

          expect(
            store.writtenKeys,
            equals([
              LocalStorageRecipesApi.kRecipesKey,
              LocalStorageRecipesApi.kIngredientsKey,
            ]),
          );
          expect(emitted, hasLength(1));
          expect(emitted.single.recipes, equals(stripped));
          expect(emitted.single.ingredients, equals([campari]));
        },
      );

      test(
        'a failed ingredients write throws and emits nothing, and a retry '
        'completes the delete',
        () async {
          final store = await open(recipes: [negroni, zombie, americano]);
          final before = await api.watch().first;
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);
          store.failingKey = LocalStorageRecipesApi.kIngredientsKey;

          await expectLater(
            () => api.deleteIngredient(gin.id),
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
          await api.deleteIngredient(gin.id);

          final snapshot = await api.watch().first;
          expect(snapshot.ingredients, equals([campari]));
          expect(snapshot.recipes, equals(stripped));
        },
      );

      test(
        'throws IngredientNotFoundException for an id that is gone',
        () async {
          final store = await open();

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
          expect(store.writtenKeys, isEmpty);
        },
      );
    });

    group('saveLibrary', () {
      final glassware = cocktails.fields.first;
      final garnish = cocktails.fields.last;
      final tea = Library(
        id: 'tea',
        name: 'Tea',
        ingredientLibraryId: coffeeIngredients.id,
      );

      FieldDefinition glasswareWith(List<String> options) => FieldDefinition(
        id: glassware.id,
        label: glassware.label,
        type: FieldType.select,
        options: options,
      );

      Library cocktailsWith(List<FieldDefinition> fields) => Library(
        id: cocktails.id,
        name: cocktails.name,
        ingredientLibraryId: cocktails.ingredientLibraryId,
        fields: fields,
      );

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

      test(
        'writes a new ingredient library before the library pointing at it, '
        'and emits one snapshot',
        () async {
          final store = await open();
          final emitted = <RecipesSnapshot>[];
          final subscription = api.watch().skip(1).listen(emitted.add);
          addTearDown(subscription.cancel);
          final teaIngredients = IngredientLibrary(
            id: 'tea-ingredients',
            name: 'Tea',
          );
          final ownTea = Library(
            id: 'tea',
            name: 'Tea',
            ingredientLibraryId: teaIngredients.id,
          );

          await api.saveLibrary(ownTea, ingredientLibrary: teaIngredients);
          await pumpEventQueue();

          expect(
            store.writtenKeys,
            equals([
              LocalStorageRecipesApi.kIngredientLibrariesKey,
              LocalStorageRecipesApi.kLibrariesKey,
            ]),
          );
          expect(emitted, hasLength(1));
          expect(
            emitted.single.libraries,
            equals([cocktails, coffee, ownTea]),
          );
          final ingredientLibraries = [
            cocktailsIngredients,
            coffeeIngredients,
            teaIngredients,
          ];
          expect(
            emitted.single.ingredientLibraries,
            equals(ingredientLibraries),
          );
          expect(
            plugin.getString(LocalStorageRecipesApi.kIngredientLibrariesKey),
            equals(
              jsonEncode([
                for (final entry in ingredientLibraries) entry.toJson(),
              ]),
            ),
          );
        },
      );

      test(
        'throws IngredientLibraryNameTakenException for a name another '
        'ingredient library carries, storing nothing',
        () async {
          final store = await open();
          final brunchIngredients = IngredientLibrary(name: ' coffee ');

          await expectLater(
            () => api.saveLibrary(
              Library(
                name: 'Brunch',
                ingredientLibraryId: brunchIngredients.id,
              ),
              ingredientLibrary: brunchIngredients,
            ),
            throwsA(
              isA<IngredientLibraryNameTakenException>().having(
                (exception) => exception.name,
                'name',
                equals('coffee'),
              ),
            ),
          );
          final snapshot = await api.watch().first;
          expect(snapshot.libraries, equals([cocktails, coffee]));
          expect(
            snapshot.ingredientLibraries,
            equals([cocktailsIngredients, coffeeIngredients]),
          );
          expect(store.writtenKeys, isEmpty);
        },
      );

      test(
        'throws IngredientLibraryNotFoundException for a library whose '
        'ingredient library is unknown, storing nothing',
        () async {
          final store = await open();

          await expectLater(
            () => api.saveLibrary(
              Library(name: 'Tea', ingredientLibraryId: 'nope'),
            ),
            throwsA(
              isA<IngredientLibraryNotFoundException>().having(
                (exception) => exception.id,
                'id',
                equals('nope'),
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

      test('replaces a library whose id is known at the same index', () async {
        await open();
        final renamed = Library(
          id: cocktails.id,
          name: 'Drinks',
          ingredientLibraryId: cocktails.ingredientLibraryId,
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
            () => api.saveLibrary(
              Library(
                name: ' coffee ',
                ingredientLibraryId: coffeeIngredients.id,
              ),
            ),
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
          ingredientLibraryId: cocktails.ingredientLibraryId,
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
          Library(
            id: cocktails.id,
            name: 'Drinks',
            ingredientLibraryId: cocktails.ingredientLibraryId,
            fields: cocktails.fields,
          ),
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
      final tea = Library(
        id: 'tea',
        name: 'Tea',
        ingredientLibraryId: coffeeIngredients.id,
      );
      final gin = CatalogIngredient(
        id: 'i1',
        name: 'Gin',
        ingredientLibraryId: cocktailsIngredients.id,
      );
      final milk = CatalogIngredient(
        id: 'i2',
        name: 'Milk',
        ingredientLibraryId: coffeeIngredients.id,
      );
      final negroni = Recipe(
        id: 'r1',
        libraryId: cocktails.id,
        name: 'Negroni',
        ingredients: [Ingredient(catalogId: gin.id)],
      );
      final v60 = Recipe(id: 'r2', libraryId: coffee.id, name: 'V60');

      Future<_RecordingStore> open({List<Library>? libraries}) async {
        final store = await setUpRecordingPrefs(
          seededPrefs(
            libraries: libraries,
            recipes: [negroni, v60],
            ingredients: [gin, milk],
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
        'leaves the ingredients and the ingredient libraries untouched',
        () async {
          final store = await open();

          await api.deleteLibrary(cocktails.id, successorId: coffee.id);

          final snapshot = await api.watch().first;
          expect(snapshot.ingredients, equals([gin, milk]));
          expect(
            snapshot.ingredientLibraries,
            equals([cocktailsIngredients, coffeeIngredients]),
          );
          expect(
            store.writtenKeys,
            isNot(
              anyOf(
                contains(LocalStorageRecipesApi.kIngredientsKey),
                contains(LocalStorageRecipesApi.kIngredientLibrariesKey),
              ),
            ),
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
        'writes the active id, the recipes, then the libraries, and emits '
        'one snapshot',
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
            equals([LocalStorageRecipesApi.kActiveLibraryIdKey]),
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
                ingredientLibraryId: cocktails.ingredientLibraryId,
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
            ingredientLibraryId: cocktailsIngredients.id,
          );

          api = buildApi();
          // Not awaiting the initial write: the seed's empty catalog must not
          // overtake this save and wipe the entry it wrote.
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
