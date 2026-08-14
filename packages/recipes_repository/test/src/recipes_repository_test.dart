import 'package:mocktail/mocktail.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:recipes_repository/recipes_repository.dart';
import 'package:test/test.dart';

class _MockRecipesApi extends Mock implements RecipesApi {}

class _FakeRecipe extends Fake implements Recipe {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
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

    group('setActiveLibraryId', () {
      test('delegates to the api', () async {
        when(() => api.setActiveLibraryId(any())).thenAnswer((_) async {});

        await repository.setActiveLibraryId('l2');

        verify(() => api.setActiveLibraryId('l2')).called(1);
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
