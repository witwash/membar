import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

class _MockRecipesRepository extends Mock implements RecipesRepository {}

class _FakeRecipe extends Fake implements Recipe {}

class _FakeCatalogIngredient extends Fake implements CatalogIngredient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
    registerFallbackValue(_FakeCatalogIngredient());
  });

  group('RecipesBloc', () {
    late RecipesRepository repository;

    final cocktails = Library(id: 'l1', name: 'Cocktails');
    final coffee = Library(id: 'l2', name: 'Coffee');
    final negroni = Recipe(id: 'r1', libraryId: 'l1', name: 'Negroni');
    final v60 = Recipe(id: 'r2', libraryId: 'l2', name: 'V60');
    final gin = CatalogIngredient(
      id: 'i1',
      name: 'Gin',
      defaultUnit: const KnownUnit(StandardUnit.ml),
      libraryIds: const {'l1'},
    );
    final snapshot = RecipesSnapshot(
      libraries: [cocktails, coffee],
      recipes: [negroni, v60],
      ingredients: [gin],
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
            ingredients: snapshot.ingredients,
            activeLibraryId: 'l1',
          ),
        ],
      );

      blocTest<RecipesBloc, RecipesState>(
        "carries the snapshot's catalog into the state",
        setUp: () => when(
          () => repository.watch(),
        ).thenAnswer((_) => Stream.value(snapshot)),
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesSubscriptionRequested()),
        skip: 1,
        verify: (bloc) => expect(bloc.state.ingredients, equals([gin])),
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
          RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.success,
          ),
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
          RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.failure,
          ),
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
          RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.success,
          ),
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
          RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.failure,
          ),
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
          RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.failure,
          ),
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
            mutation: RecipesMutation.librarySelected,
            mutationStatus: RecipesMutationStatus.loading,
            activeLibraryId: 'l1',
            searchTerm: 'neg',
            activeTags: {'Classic'},
          ),
          RecipesState(
            mutation: RecipesMutation.librarySelected,
            mutationStatus: RecipesMutationStatus.success,
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
        'keeps the search term and tag filter when the write fails',
        setUp: () => when(() => repository.setActiveLibraryId(any())).thenThrow(
          const RecipesPersistenceException('disk full'),
        ),
        build: buildBloc,
        seed: () => const RecipesState(
          activeLibraryId: 'l1',
          searchTerm: 'neg',
          activeTags: {'Classic'},
        ),
        act: (bloc) => bloc.add(const RecipesLibrarySelected('l2')),
        // Clearing the filters for a switch that never took effect would
        // leave the user in the library they started in, with the filters
        // they had chosen silently thrown away.
        expect: () => const [
          RecipesState(
            mutation: RecipesMutation.librarySelected,
            mutationStatus: RecipesMutationStatus.loading,
            activeLibraryId: 'l1',
            searchTerm: 'neg',
            activeTags: {'Classic'},
          ),
          RecipesState(
            mutation: RecipesMutation.librarySelected,
            mutationStatus: RecipesMutationStatus.failure,
            activeLibraryId: 'l1',
            searchTerm: 'neg',
            activeTags: {'Classic'},
          ),
        ],
      );
    });

    group('RecipesIngredientSaved', () {
      blocTest<RecipesBloc, RecipesState>(
        'emits loading then success and delegates to the repository',
        setUp: () => when(
          () => repository.saveIngredient(any()),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        act: (bloc) => bloc.add(RecipesIngredientSaved(gin)),
        expect: () => const [
          RecipesState(
            mutation: RecipesMutation.ingredientSaved,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.ingredientSaved,
            mutationStatus: RecipesMutationStatus.success,
          ),
        ],
        verify: (_) => verify(() => repository.saveIngredient(gin)).called(1),
      );

      for (final (reason, exception) in [
        ('the name is taken', const IngredientNameTakenException('Gin')),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure when $reason',
          setUp: () =>
              when(() => repository.saveIngredient(any())).thenThrow(exception),
          build: buildBloc,
          act: (bloc) => bloc.add(RecipesIngredientSaved(gin)),
          expect: () => const [
            RecipesState(
              mutation: RecipesMutation.ingredientSaved,
              mutationStatus: RecipesMutationStatus.loading,
            ),
            RecipesState(
              mutation: RecipesMutation.ingredientSaved,
              mutationStatus: RecipesMutationStatus.failure,
            ),
          ],
        );
      }
    });

    group('RecipesIngredientDeleted', () {
      blocTest<RecipesBloc, RecipesState>(
        'emits loading then success and delegates to the repository',
        setUp: () => when(
          () => repository.deleteIngredient(any()),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        act: (bloc) => bloc.add(const RecipesIngredientDeleted('i1')),
        expect: () => const [
          RecipesState(
            mutation: RecipesMutation.ingredientDeleted,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.ingredientDeleted,
            mutationStatus: RecipesMutationStatus.success,
          ),
        ],
        verify: (_) =>
            verify(() => repository.deleteIngredient('i1')).called(1),
      );

      for (final (reason, exception) in <(String, Exception)>[
        ('the entry is already gone', const IngredientNotFoundException('i1')),
        (
          'recipes still use the entry',
          const IngredientInUseException('i1', 2),
        ),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure when $reason',
          setUp: () => when(
            () => repository.deleteIngredient(any()),
          ).thenThrow(exception),
          build: buildBloc,
          act: (bloc) => bloc.add(const RecipesIngredientDeleted('i1')),
          expect: () => const [
            RecipesState(
              mutation: RecipesMutation.ingredientDeleted,
              mutationStatus: RecipesMutationStatus.loading,
            ),
            RecipesState(
              mutation: RecipesMutation.ingredientDeleted,
              mutationStatus: RecipesMutationStatus.failure,
            ),
          ],
        );
      }
    });

    group('RecipesIngredientsImported', () {
      final withRows = RecipesState(
        status: RecipesStatus.success,
        libraries: [cocktails, coffee],
        recipes: [
          Recipe(
            id: 'r1',
            libraryId: 'l1',
            name: 'Negroni',
            ingredients: [
              Ingredient(name: 'Gin', unit: 'ml', catalogId: 'i1'),
              Ingredient(name: 'Campari', unit: 'ml'),
            ],
          ),
        ],
        ingredients: [gin],
        activeLibraryId: 'l1',
      );

      blocTest<RecipesBloc, RecipesState>(
        'saves the importable entries in one call, with ids minted',
        setUp: () => when(
          () => repository.saveIngredients(any()),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        seed: () => withRows,
        act: (bloc) => bloc.add(const RecipesIngredientsImported()),
        expect: () => [
          withRows.copyWith(
            mutation: RecipesMutation.ingredientsImported,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          withRows.copyWith(
            mutation: RecipesMutation.ingredientsImported,
            mutationStatus: RecipesMutationStatus.success,
          ),
        ],
        verify: (_) {
          final saved =
              verify(
                    () => repository.saveIngredients(captureAny()),
                  ).captured.single
                  as List<CatalogIngredient>;
          final campari = saved.single;
          expect(campari.id, isNotEmpty);
          expect(campari.name, 'Campari');
          expect(campari.defaultUnit, const KnownUnit(StandardUnit.ml));
          expect(campari.libraryIds, {'l1'});
        },
      );

      blocTest<RecipesBloc, RecipesState>(
        'does nothing when there is nothing to import',
        build: buildBloc,
        seed: () => withRows.copyWith(recipes: const []),
        act: (bloc) => bloc.add(const RecipesIngredientsImported()),
        expect: () => const <RecipesState>[],
        verify: (_) => verifyNever(() => repository.saveIngredients(any())),
      );

      for (final (reason, exception) in <(String, Exception)>[
        ('a name is taken', const IngredientNameTakenException('Campari')),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure when $reason',
          setUp: () => when(
            () => repository.saveIngredients(any()),
          ).thenThrow(exception),
          build: buildBloc,
          seed: () => withRows,
          act: (bloc) => bloc.add(const RecipesIngredientsImported()),
          expect: () => [
            withRows.copyWith(
              mutation: RecipesMutation.ingredientsImported,
              mutationStatus: RecipesMutationStatus.loading,
            ),
            withRows.copyWith(
              mutation: RecipesMutation.ingredientsImported,
              mutationStatus: RecipesMutationStatus.failure,
            ),
          ],
        );
      }
    });

    group('RecipesIngredientScopeWidened', () {
      final loaded = RecipesState(
        status: RecipesStatus.success,
        libraries: [cocktails, coffee],
        ingredients: [gin],
        activeLibraryId: 'l2',
      );

      blocTest<RecipesBloc, RecipesState>(
        'adds the library to the entry and reports nothing',
        setUp: () => when(
          () => repository.saveIngredient(any()),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        seed: () => loaded,
        act: (bloc) =>
            bloc.add(const RecipesIngredientScopeWidened('i1', 'l2')),
        expect: () => const <RecipesState>[],
        verify: (_) => verify(
          () => repository.saveIngredient(
            CatalogIngredient(
              id: 'i1',
              name: 'Gin',
              defaultUnit: const KnownUnit(StandardUnit.ml),
              libraryIds: const {'l1', 'l2'},
            ),
          ),
        ).called(1),
      );

      for (final (reason, exception) in <(String, Exception)>[
        ('the name is taken', const IngredientNameTakenException('Gin')),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits no mutation state when $reason',
          setUp: () =>
              when(() => repository.saveIngredient(any())).thenThrow(exception),
          build: buildBloc,
          seed: () => loaded,
          act: (bloc) =>
              bloc.add(const RecipesIngredientScopeWidened('i1', 'l2')),
          expect: () => const <RecipesState>[],
        );
      }

      blocTest<RecipesBloc, RecipesState>(
        'writes nothing when the entry is already in the library',
        build: buildBloc,
        seed: () => loaded,
        act: (bloc) =>
            bloc.add(const RecipesIngredientScopeWidened('i1', 'l1')),
        expect: () => const <RecipesState>[],
        verify: (_) => verifyNever(() => repository.saveIngredient(any())),
      );

      blocTest<RecipesBloc, RecipesState>(
        'writes nothing when the entry no longer exists',
        build: buildBloc,
        seed: () => loaded,
        act: (bloc) =>
            bloc.add(const RecipesIngredientScopeWidened('gone', 'l2')),
        expect: () => const <RecipesState>[],
        verify: (_) => verifyNever(() => repository.saveIngredient(any())),
      );
    });

    group('overlapping mutations', () {
      late Completer<void> recipeWrite;

      blocTest<RecipesBloc, RecipesState>(
        'every emission carries the kind of the handler that emitted it',
        setUp: () {
          recipeWrite = Completer<void>();
          when(
            () => repository.saveRecipe(any()),
          ).thenAnswer((_) => recipeWrite.future);
          when(
            () => repository.saveIngredient(any()),
          ).thenAnswer((_) async {});
        },
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(RecipesRecipeSaved(negroni))
            ..add(RecipesIngredientSaved(gin));
          // The ingredient save completes while the recipe save is in flight.
          await Future<void>.delayed(Duration.zero);
          recipeWrite.complete();
        },
        expect: () => const [
          RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.ingredientSaved,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.ingredientSaved,
            mutationStatus: RecipesMutationStatus.success,
          ),
          RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.success,
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
