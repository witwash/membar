import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

class _MockRecipesRepository extends Mock implements RecipesRepository {}

class _FakeRecipe extends Fake implements Recipe {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
  });

  group('RecipesBloc', () {
    late RecipesRepository repository;

    final cocktails = Library(id: 'l1', name: 'Cocktails');
    final coffee = Library(id: 'l2', name: 'Coffee');
    final negroni = Recipe(id: 'r1', libraryId: 'l1', name: 'Negroni');
    final v60 = Recipe(id: 'r2', libraryId: 'l2', name: 'V60');
    final snapshot = RecipesSnapshot(
      libraries: [cocktails, coffee],
      recipes: [negroni, v60],
      activeLibraryId: 'l1',
    );

    RecipesBloc buildBloc() => RecipesBloc(recipesRepository: repository);

    setUp(() {
      repository = _MockRecipesRepository();
    });

    test('initial state has nothing loaded', () {
      expect(buildBloc().state, const RecipesState());
    });

    group('RecipesSubscriptionRequested', () {
      blocTest<RecipesBloc, RecipesState>(
        'emits loading then the snapshot',
        setUp: () => when(
          () => repository.watch(),
        ).thenAnswer((_) => Stream.value(snapshot)),
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesSubscriptionRequested()),
        expect: () => [
          const RecipesState(status: RecipesStatus.loading),
          RecipesState(
            status: RecipesStatus.success,
            libraries: snapshot.libraries,
            recipes: snapshot.recipes,
            activeLibraryId: 'l1',
          ),
        ],
      );

      blocTest<RecipesBloc, RecipesState>(
        'emits failure when the stream errors',
        setUp: () => when(
          () => repository.watch(),
        ).thenAnswer((_) => Stream.error(Exception('oops'))),
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesSubscriptionRequested()),
        expect: () => const [
          RecipesState(status: RecipesStatus.loading),
          RecipesState(status: RecipesStatus.failure),
        ],
      );
    });

    group('RecipesRecipeSaved', () {
      blocTest<RecipesBloc, RecipesState>(
        'emits loading then success and delegates to the repository',
        setUp: () =>
            when(() => repository.saveRecipe(any())).thenAnswer((_) async {}),
        build: buildBloc,
        act: (bloc) => bloc.add(RecipesRecipeSaved(negroni)),
        expect: () => const [
          RecipesState(saveStatus: RecipesSaveStatus.loading),
          RecipesState(saveStatus: RecipesSaveStatus.success),
        ],
        verify: (_) => verify(() => repository.saveRecipe(negroni)).called(1),
      );

      blocTest<RecipesBloc, RecipesState>(
        'emits failure when the write fails',
        setUp: () => when(() => repository.saveRecipe(any())).thenThrow(
          const RecipesPersistenceException('disk full'),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(RecipesRecipeSaved(negroni)),
        expect: () => const [
          RecipesState(saveStatus: RecipesSaveStatus.loading),
          RecipesState(saveStatus: RecipesSaveStatus.failure),
        ],
      );
    });

    group('RecipesRecipeDeleted', () {
      blocTest<RecipesBloc, RecipesState>(
        'emits loading then success and delegates to the repository',
        setUp: () =>
            when(() => repository.deleteRecipe(any())).thenAnswer((_) async {}),
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesRecipeDeleted('r1')),
        expect: () => const [
          RecipesState(saveStatus: RecipesSaveStatus.loading),
          RecipesState(saveStatus: RecipesSaveStatus.success),
        ],
        verify: (_) => verify(() => repository.deleteRecipe('r1')).called(1),
      );

      blocTest<RecipesBloc, RecipesState>(
        'emits failure when the recipe is already gone',
        setUp: () => when(
          () => repository.deleteRecipe(any()),
        ).thenThrow(const RecipeNotFoundException('r1')),
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesRecipeDeleted('r1')),
        expect: () => const [
          RecipesState(saveStatus: RecipesSaveStatus.loading),
          RecipesState(saveStatus: RecipesSaveStatus.failure),
        ],
      );

      blocTest<RecipesBloc, RecipesState>(
        'emits failure when the write fails',
        setUp: () => when(() => repository.deleteRecipe(any())).thenThrow(
          const RecipesPersistenceException('disk full'),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesRecipeDeleted('r1')),
        expect: () => const [
          RecipesState(saveStatus: RecipesSaveStatus.loading),
          RecipesState(saveStatus: RecipesSaveStatus.failure),
        ],
      );
    });

    group('RecipesLibrarySelected', () {
      blocTest<RecipesBloc, RecipesState>(
        'clears the search term and tag filter, and delegates',
        setUp: () => when(
          () => repository.setActiveLibraryId(any()),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        seed: () => const RecipesState(
          activeLibraryId: 'l1',
          searchTerm: 'neg',
          activeTags: {'Classic'},
        ),
        act: (bloc) => bloc.add(const RecipesLibrarySelected('l2')),
        expect: () => const [
          RecipesState(
            saveStatus: RecipesSaveStatus.loading,
            activeLibraryId: 'l1',
          ),
          RecipesState(
            saveStatus: RecipesSaveStatus.success,
            activeLibraryId: 'l1',
          ),
        ],
        verify: (_) =>
            verify(() => repository.setActiveLibraryId('l2')).called(1),
      );

      blocTest<RecipesBloc, RecipesState>(
        'is a no-op when the library is already active',
        build: buildBloc,
        seed: () => const RecipesState(
          activeLibraryId: 'l1',
          searchTerm: 'neg',
        ),
        act: (bloc) => bloc.add(const RecipesLibrarySelected('l1')),
        expect: () => const <RecipesState>[],
        verify: (_) => verifyNever(() => repository.setActiveLibraryId(any())),
      );

      blocTest<RecipesBloc, RecipesState>(
        'emits failure when the write fails',
        setUp: () => when(() => repository.setActiveLibraryId(any())).thenThrow(
          const RecipesPersistenceException('disk full'),
        ),
        build: buildBloc,
        seed: () => const RecipesState(activeLibraryId: 'l1'),
        act: (bloc) => bloc.add(const RecipesLibrarySelected('l2')),
        expect: () => const [
          RecipesState(
            saveStatus: RecipesSaveStatus.loading,
            activeLibraryId: 'l1',
          ),
          RecipesState(
            saveStatus: RecipesSaveStatus.failure,
            activeLibraryId: 'l1',
          ),
        ],
      );
    });

    group('RecipesSearchTermChanged', () {
      blocTest<RecipesBloc, RecipesState>(
        'stores the term',
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesSearchTermChanged('neg')),
        expect: () => const [RecipesState(searchTerm: 'neg')],
      );
    });

    group('RecipesTagFilterToggled', () {
      blocTest<RecipesBloc, RecipesState>(
        'selects a tag that is not selected',
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesTagFilterToggled('Classic')),
        expect: () => const [
          RecipesState(activeTags: {'Classic'}),
        ],
      );

      blocTest<RecipesBloc, RecipesState>(
        'deselects a tag that is selected, keeping the others',
        build: buildBloc,
        seed: () => const RecipesState(activeTags: {'Classic', 'Bitter'}),
        act: (bloc) => bloc.add(const RecipesTagFilterToggled('Classic')),
        expect: () => const [
          RecipesState(activeTags: {'Bitter'}),
        ],
      );
    });
  });
}
