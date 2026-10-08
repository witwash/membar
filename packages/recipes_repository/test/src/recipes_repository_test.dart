import 'package:mocktail/mocktail.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:test/test.dart';

class _MockRecipesApi extends Mock implements RecipesApi {}

class _FakeRecipe extends Fake implements Recipe {}

class _FakeCatalogIngredient extends Fake implements CatalogIngredient {}

class _FakeLibrary extends Fake implements Library {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
    registerFallbackValue(_FakeCatalogIngredient());
    registerFallbackValue(_FakeLibrary());
  });

  group('RecipesRepository', () {
    late RecipesApi api;
    late RecipesRepository repository;

    setUp(() {
      api = _MockRecipesApi();
      repository = RecipesRepository(recipesApi: api);
    });

    test('can be instantiated', () {
      expect(RecipesRepository(recipesApi: api), isNotNull);
    });

    group('watch', () {
      test('returns the api stream', () {
        const snapshot = RecipesSnapshot(
          libraries: [],
          recipes: [],
          ingredients: [],
          activeLibraryId: 'l1',
          ingredientsImported: false,
        );
        when(() => api.watch()).thenAnswer(
          (_) => Stream.value(snapshot),
        );

        expect(repository.watch(), emitsInOrder([snapshot, emitsDone]));
        verify(() => api.watch()).called(1);
      });
    });

    group('saveRecipe', () {
      test('delegates to the api', () async {
        final recipe = Recipe(libraryId: 'l1', name: 'Negroni');
        when(() => api.saveRecipe(any())).thenAnswer((_) async {});

        await repository.saveRecipe(recipe);

        verify(() => api.saveRecipe(recipe)).called(1);
      });
    });

    group('deleteRecipe', () {
      test('delegates to the api', () async {
        when(() => api.deleteRecipe(any())).thenAnswer((_) async {});

        await repository.deleteRecipe('r1');

        verify(() => api.deleteRecipe('r1')).called(1);
      });

      test('passes a RecipeNotFoundException through untranslated', () {
        when(
          () => api.deleteRecipe(any()),
        ).thenThrow(const RecipeNotFoundException('r1'));

        expect(
          () => repository.deleteRecipe('r1'),
          throwsA(isA<RecipeNotFoundException>()),
        );
      });
    });

    group('saveIngredient', () {
      test('delegates to the api', () async {
        final ingredient = CatalogIngredient(
          name: 'Gin',
          libraryIds: const {'l1'},
        );
        when(() => api.saveIngredient(any())).thenAnswer((_) async {});

        await repository.saveIngredient(ingredient);

        verify(() => api.saveIngredient(ingredient)).called(1);
      });

      test('passes an IngredientNameTakenException through untranslated', () {
        when(
          () => api.saveIngredient(any()),
        ).thenThrow(const IngredientNameTakenException('Gin'));

        expect(
          () => repository.saveIngredient(
            CatalogIngredient(name: 'Gin', libraryIds: const {'l1'}),
          ),
          throwsA(isA<IngredientNameTakenException>()),
        );
      });
    });

    group('importIngredients', () {
      test('delegates to the api', () async {
        final ingredients = [
          CatalogIngredient(name: 'Gin', libraryIds: const {'l1'}),
          CatalogIngredient(name: 'Campari', libraryIds: const {'l1'}),
        ];
        when(() => api.importIngredients(any())).thenAnswer((_) async {});

        await repository.importIngredients(ingredients);

        verify(() => api.importIngredients(ingredients)).called(1);
      });
    });

    group('deleteIngredient', () {
      test('delegates to the api', () async {
        when(() => api.deleteIngredient(any())).thenAnswer((_) async {});

        await repository.deleteIngredient('i1');

        verify(() => api.deleteIngredient('i1')).called(1);
      });

      test('passes an IngredientInUseException through untranslated', () {
        when(
          () => api.deleteIngredient(any()),
        ).thenThrow(const IngredientInUseException('i1', 2));

        expect(
          () => repository.deleteIngredient('i1'),
          throwsA(isA<IngredientInUseException>()),
        );
      });
    });

    group('setActiveLibraryId', () {
      test('delegates to the api', () async {
        when(() => api.setActiveLibraryId(any())).thenAnswer((_) async {});

        await repository.setActiveLibraryId('l2');

        verify(() => api.setActiveLibraryId('l2')).called(1);
      });
    });

    group('saveLibrary', () {
      final tea = Library(id: 'l3', name: 'Tea');

      test('delegates to the api, renames included', () async {
        const renames = {
          'f1': {'Coupe': 'Coupe glass'},
        };
        when(
          () => api.saveLibrary(
            any(),
            optionRenames: any(named: 'optionRenames'),
          ),
        ).thenAnswer((_) async {});

        await repository.saveLibrary(tea, optionRenames: renames);

        verify(() => api.saveLibrary(tea, optionRenames: renames)).called(1);
      });

      test('passes a LibraryNameTakenException through untranslated', () {
        when(
          () => api.saveLibrary(
            any(),
            optionRenames: any(named: 'optionRenames'),
          ),
        ).thenThrow(const LibraryNameTakenException('Tea'));

        expect(
          () => repository.saveLibrary(tea),
          throwsA(isA<LibraryNameTakenException>()),
        );
      });
    });

    group('deleteLibrary', () {
      test('delegates to the api', () async {
        when(
          () => api.deleteLibrary(
            any(),
            successorId: any(named: 'successorId'),
          ),
        ).thenAnswer((_) async {});

        await repository.deleteLibrary('l1', successorId: 'l2');

        verify(() => api.deleteLibrary('l1', successorId: 'l2')).called(1);
      });

      test('passes a LibraryNotFoundException through untranslated', () {
        when(
          () => api.deleteLibrary(
            any(),
            successorId: any(named: 'successorId'),
          ),
        ).thenThrow(const LibraryNotFoundException('l1'));

        expect(
          () => repository.deleteLibrary('l1', successorId: 'l2'),
          throwsA(isA<LibraryNotFoundException>()),
        );
      });
    });

    group('close', () {
      test('delegates to the api', () async {
        when(() => api.close()).thenAnswer((_) async {});

        await repository.close();

        verify(() => api.close()).called(1);
      });
    });
  });
}
