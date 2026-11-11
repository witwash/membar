import 'package:mocktail/mocktail.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:test/test.dart';

class _MockRecipesApi extends Mock implements RecipesApi {}

class _FakeRecipe extends Fake implements Recipe {}

class _FakeCatalogIngredient extends Fake implements CatalogIngredient {}

class _FakeLibrary extends Fake implements Library {}

class _FakeIngredientLibrary extends Fake implements IngredientLibrary {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
    registerFallbackValue(_FakeCatalogIngredient());
    registerFallbackValue(_FakeLibrary());
    registerFallbackValue(_FakeIngredientLibrary());
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
          ingredientLibraries: [],
          ingredients: [],
          activeLibraryId: 'l1',
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

      test('passes an IngredientNotFoundException through untranslated', () {
        when(
          () => api.saveRecipe(any()),
        ).thenThrow(const IngredientNotFoundException('i1'));

        expect(
          () => repository.saveRecipe(Recipe(libraryId: 'l1', name: 'Negroni')),
          throwsA(isA<IngredientNotFoundException>()),
        );
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
          ingredientLibraryId: 'il1',
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
            CatalogIngredient(name: 'Gin', ingredientLibraryId: 'il1'),
          ),
          throwsA(isA<IngredientNameTakenException>()),
        );
      });
    });

    group('deleteIngredient', () {
      test('delegates to the api', () async {
        when(() => api.deleteIngredient(any())).thenAnswer((_) async {});

        await repository.deleteIngredient('i1');

        verify(() => api.deleteIngredient('i1')).called(1);
      });

      test('passes an IngredientNotFoundException through untranslated', () {
        when(
          () => api.deleteIngredient(any()),
        ).thenThrow(const IngredientNotFoundException('i1'));

        expect(
          () => repository.deleteIngredient('i1'),
          throwsA(isA<IngredientNotFoundException>()),
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
      final teaShelf = IngredientLibrary(id: 'il3', name: 'Tea');
      final tea = Library(id: 'l3', name: 'Tea', ingredientLibraryId: 'il3');

      When<Future<void>> stubSaveLibrary() => when(
        () => api.saveLibrary(
          any(),
          ingredientLibrary: any(named: 'ingredientLibrary'),
          optionRenames: any(named: 'optionRenames'),
        ),
      );

      test('delegates to the api, renames included', () async {
        const renames = {
          'f1': {'Coupe': 'Coupe glass'},
        };
        stubSaveLibrary().thenAnswer((_) async {});

        await repository.saveLibrary(tea, optionRenames: renames);

        verify(() => api.saveLibrary(tea, optionRenames: renames)).called(1);
      });

      test('delegates a new ingredient library to the api', () async {
        stubSaveLibrary().thenAnswer((_) async {});

        await repository.saveLibrary(tea, ingredientLibrary: teaShelf);

        verify(
          () => api.saveLibrary(tea, ingredientLibrary: teaShelf),
        ).called(1);
      });

      test(
        'passes an IngredientLibraryNameTakenException through untranslated',
        () {
          stubSaveLibrary().thenThrow(
            const IngredientLibraryNameTakenException('Tea'),
          );

          expect(
            () => repository.saveLibrary(tea, ingredientLibrary: teaShelf),
            throwsA(isA<IngredientLibraryNameTakenException>()),
          );
        },
      );

      test('passes a LibraryNameTakenException through untranslated', () {
        stubSaveLibrary().thenThrow(const LibraryNameTakenException('Tea'));

        expect(
          () => repository.saveLibrary(tea),
          throwsA(isA<LibraryNameTakenException>()),
        );
      });
    });

    group('importRecipes', () {
      final campari = CatalogIngredient(
        name: 'Campari',
        ingredientLibraryId: 'il1',
      );
      final negroni = Recipe(libraryId: 'l1', name: 'Negroni');

      test('delegates to the api', () async {
        when(
          () => api.importRecipes(
            libraryId: any(named: 'libraryId'),
            ingredients: any(named: 'ingredients'),
            recipes: any(named: 'recipes'),
          ),
        ).thenAnswer((_) async {});

        await repository.importRecipes(
          libraryId: 'l1',
          ingredients: [campari],
          recipes: [negroni],
        );

        verify(
          () => api.importRecipes(
            libraryId: 'l1',
            ingredients: [campari],
            recipes: [negroni],
          ),
        ).called(1);
      });

      test('passes a RecipeNameTakenException through untranslated', () {
        when(
          () => api.importRecipes(
            libraryId: any(named: 'libraryId'),
            ingredients: any(named: 'ingredients'),
            recipes: any(named: 'recipes'),
          ),
        ).thenThrow(const RecipeNameTakenException('Negroni'));

        expect(
          () => repository.importRecipes(
            libraryId: 'l1',
            ingredients: const [],
            recipes: [negroni],
          ),
          throwsA(isA<RecipeNameTakenException>()),
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
