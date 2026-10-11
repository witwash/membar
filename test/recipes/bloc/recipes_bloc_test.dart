import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

class _MockRecipesRepository extends Mock implements RecipesRepository {}

class _FakeRecipe extends Fake implements Recipe {}

class _FakeCatalogIngredient extends Fake implements CatalogIngredient {}

class _FakeLibrary extends Fake implements Library {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
    registerFallbackValue(_FakeCatalogIngredient());
    registerFallbackValue(_FakeLibrary());
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
      ingredientsImported: true,
    );

    RecipesBloc buildBloc() => RecipesBloc(recipesRepository: repository);

    setUp(() {
      repository = _MockRecipesRepository();
    });

    test('initial state has nothing loaded', () {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      expect(bloc.state, const RecipesState());
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
            ingredientsImported: true,
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

    group('RecipesLibrarySaved', () {
      final tea = Library(id: 'l3', name: 'Tea');
      const renames = {
        'f1': {'Coupe': 'Coupe glass'},
      };

      blocTest<RecipesBloc, RecipesState>(
        'emits loading then success and delegates, renames included',
        setUp: () => when(
          () => repository.saveLibrary(
            any(),
            optionRenames: any(named: 'optionRenames'),
          ),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        act: (bloc) =>
            bloc.add(RecipesLibrarySaved(tea, optionRenames: renames)),
        expect: () => const [
          RecipesState(
            mutation: RecipesMutation.librarySaved,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          RecipesState(
            mutation: RecipesMutation.librarySaved,
            mutationStatus: RecipesMutationStatus.success,
          ),
        ],
        verify: (_) => verify(
          () => repository.saveLibrary(tea, optionRenames: renames),
        ).called(1),
      );

      for (final (reason, exception) in [
        ('the name is taken', const LibraryNameTakenException('Tea')),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure when $reason',
          setUp: () => when(
            () => repository.saveLibrary(
              any(),
              optionRenames: any(named: 'optionRenames'),
            ),
          ).thenThrow(exception),
          build: buildBloc,
          act: (bloc) => bloc.add(RecipesLibrarySaved(tea)),
          expect: () => const [
            RecipesState(
              mutation: RecipesMutation.librarySaved,
              mutationStatus: RecipesMutationStatus.loading,
            ),
            RecipesState(
              mutation: RecipesMutation.librarySaved,
              mutationStatus: RecipesMutationStatus.failure,
            ),
          ],
        );
      }
    });

    group('RecipesLibraryDeleted', () {
      const filtered = RecipesState(
        activeLibraryId: 'l1',
        searchTerm: 'neg',
        activeTags: {'Classic'},
      );
      late StreamController<RecipesSnapshot> snapshots;

      blocTest<RecipesBloc, RecipesState>(
        'clears the search term and tag filter when the active library is '
        'deleted, and delegates',
        setUp: () => when(
          () => repository.deleteLibrary(
            any(),
            successorId: any(named: 'successorId'),
          ),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        seed: () => filtered,
        act: (bloc) =>
            bloc.add(const RecipesLibraryDeleted('l1', successorId: 'l2')),
        expect: () => const [
          RecipesState(
            mutation: RecipesMutation.libraryDeleted,
            mutationStatus: RecipesMutationStatus.loading,
            activeLibraryId: 'l1',
            searchTerm: 'neg',
            activeTags: {'Classic'},
          ),
          RecipesState(
            mutation: RecipesMutation.libraryDeleted,
            mutationStatus: RecipesMutationStatus.success,
            activeLibraryId: 'l1',
          ),
        ],
        verify: (_) => verify(
          () => repository.deleteLibrary('l1', successorId: 'l2'),
        ).called(1),
      );

      blocTest<RecipesBloc, RecipesState>(
        'clears the filters even though the snapshot has already made the '
        'successor active',
        setUp: () {
          snapshots = StreamController<RecipesSnapshot>();
          when(() => repository.watch()).thenAnswer((_) => snapshots.stream);
          when(
            () => repository.deleteLibrary(
              any(),
              successorId: any(named: 'successorId'),
            ),
          ).thenAnswer((_) async {
            // The storage layer emits before its future completes.
            snapshots.add(
              RecipesSnapshot(
                libraries: [coffee],
                recipes: [v60],
                ingredients: const [],
                activeLibraryId: 'l2',
                ingredientsImported: true,
              ),
            );
            await Future<void>.delayed(Duration.zero);
          });
        },
        build: buildBloc,
        seed: () => filtered,
        act: (bloc) => bloc
          ..add(const RecipesSubscriptionRequested())
          ..add(const RecipesLibraryDeleted('l1', successorId: 'l2')),
        wait: const Duration(milliseconds: 10),
        verify: (bloc) {
          expect(bloc.state.activeLibraryId, equals('l2'));
          expect(bloc.state.searchTerm, isEmpty);
          expect(bloc.state.activeTags, isEmpty);
        },
        tearDown: () => snapshots.close(),
      );

      blocTest<RecipesBloc, RecipesState>(
        'keeps the search term and tag filter when another library is deleted',
        setUp: () => when(
          () => repository.deleteLibrary(
            any(),
            successorId: any(named: 'successorId'),
          ),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        seed: () => filtered,
        act: (bloc) =>
            bloc.add(const RecipesLibraryDeleted('l2', successorId: 'l1')),
        expect: () => const [
          RecipesState(
            mutation: RecipesMutation.libraryDeleted,
            mutationStatus: RecipesMutationStatus.loading,
            activeLibraryId: 'l1',
            searchTerm: 'neg',
            activeTags: {'Classic'},
          ),
          RecipesState(
            mutation: RecipesMutation.libraryDeleted,
            mutationStatus: RecipesMutationStatus.success,
            activeLibraryId: 'l1',
            searchTerm: 'neg',
            activeTags: {'Classic'},
          ),
        ],
      );

      for (final (reason, exception) in <(String, Exception)>[
        ('a library is not there', const LibraryNotFoundException('l1')),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure and keeps the filters when $reason',
          setUp: () => when(
            () => repository.deleteLibrary(
              any(),
              successorId: any(named: 'successorId'),
            ),
          ).thenThrow(exception),
          build: buildBloc,
          seed: () => filtered,
          act: (bloc) =>
              bloc.add(const RecipesLibraryDeleted('l1', successorId: 'l2')),
          expect: () => const [
            RecipesState(
              mutation: RecipesMutation.libraryDeleted,
              mutationStatus: RecipesMutationStatus.loading,
              activeLibraryId: 'l1',
              searchTerm: 'neg',
              activeTags: {'Classic'},
            ),
            RecipesState(
              mutation: RecipesMutation.libraryDeleted,
              mutationStatus: RecipesMutationStatus.failure,
              activeLibraryId: 'l1',
              searchTerm: 'neg',
              activeTags: {'Classic'},
            ),
          ],
        );
      }
    });

    group('RecipesFieldDeleted', () {
      final glassware = FieldDefinition(
        id: 'f1',
        label: 'Glassware',
        type: FieldType.select,
        options: const ['Coupe'],
      );
      final garnish = FieldDefinition(
        id: 'f2',
        label: 'Garnish',
        type: FieldType.text,
      );
      final loaded = RecipesState(
        libraries: [
          Library(id: 'l1', name: 'Cocktails', fields: [glassware, garnish]),
          coffee,
        ],
        activeLibraryId: 'l1',
      );

      blocTest<RecipesBloc, RecipesState>(
        'emits loading then success and saves the library without the field',
        setUp: () => when(
          () => repository.saveLibrary(
            any(),
            optionRenames: any(named: 'optionRenames'),
          ),
        ).thenAnswer((_) async {}),
        build: buildBloc,
        seed: () => loaded,
        act: (bloc) => bloc.add(
          const RecipesFieldDeleted(libraryId: 'l1', fieldId: 'f2'),
        ),
        expect: () => [
          loaded.copyWith(
            mutation: RecipesMutation.fieldDeleted,
            mutationStatus: RecipesMutationStatus.loading,
          ),
          loaded.copyWith(
            mutation: RecipesMutation.fieldDeleted,
            mutationStatus: RecipesMutationStatus.success,
          ),
        ],
        verify: (_) => verify(
          () => repository.saveLibrary(
            Library(id: 'l1', name: 'Cocktails', fields: [glassware]),
          ),
        ).called(1),
      );

      for (final (reason, event) in [
        (
          'the library is not there',
          const RecipesFieldDeleted(libraryId: 'gone', fieldId: 'f2'),
        ),
        (
          'the field is not there',
          const RecipesFieldDeleted(libraryId: 'l1', fieldId: 'gone'),
        ),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure without calling the repository when $reason',
          build: buildBloc,
          seed: () => loaded,
          act: (bloc) => bloc.add(event),
          expect: () => [
            loaded.copyWith(
              mutation: RecipesMutation.fieldDeleted,
              mutationStatus: RecipesMutationStatus.loading,
            ),
            loaded.copyWith(
              mutation: RecipesMutation.fieldDeleted,
              mutationStatus: RecipesMutationStatus.failure,
            ),
          ],
          verify: (_) => verifyNever(
            () => repository.saveLibrary(
              any(),
              optionRenames: any(named: 'optionRenames'),
            ),
          ),
        );
      }

      for (final (reason, exception) in [
        ('the name is taken', const LibraryNameTakenException('Cocktails')),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure when $reason',
          setUp: () => when(
            () => repository.saveLibrary(
              any(),
              optionRenames: any(named: 'optionRenames'),
            ),
          ).thenThrow(exception),
          build: buildBloc,
          seed: () => loaded,
          act: (bloc) => bloc.add(
            const RecipesFieldDeleted(libraryId: 'l1', fieldId: 'f2'),
          ),
          expect: () => [
            loaded.copyWith(
              mutation: RecipesMutation.fieldDeleted,
              mutationStatus: RecipesMutationStatus.loading,
            ),
            loaded.copyWith(
              mutation: RecipesMutation.fieldDeleted,
              mutationStatus: RecipesMutationStatus.failure,
            ),
          ],
        );
      }
    });

    group('RecipesFieldMoved', () {
      final glassware = FieldDefinition(
        id: 'f1',
        label: 'Glassware',
        type: FieldType.select,
        options: const ['Coupe'],
      );
      final garnish = FieldDefinition(
        id: 'f2',
        label: 'Garnish',
        type: FieldType.text,
      );
      final method = FieldDefinition(
        id: 'f3',
        label: 'Method',
        type: FieldType.text,
      );

      Library cocktailsWith(List<FieldDefinition> fields) =>
          Library(id: 'l1', name: 'Cocktails', fields: fields);

      final loaded = RecipesState(
        libraries: [
          cocktailsWith([glassware, garnish, method]),
          coffee,
        ],
        activeLibraryId: 'l1',
      );

      for (final (direction, delta, fields) in [
        ('up', -1, [garnish, glassware, method]),
        ('down', 1, [glassware, method, garnish]),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits loading then success and saves the library with the field '
          'one place $direction',
          setUp: () => when(
            () => repository.saveLibrary(
              any(),
              optionRenames: any(named: 'optionRenames'),
            ),
          ).thenAnswer((_) async {}),
          build: buildBloc,
          seed: () => loaded,
          act: (bloc) => bloc.add(
            RecipesFieldMoved(libraryId: 'l1', fieldId: 'f2', delta: delta),
          ),
          expect: () => [
            loaded.copyWith(
              mutation: RecipesMutation.fieldMoved,
              mutationStatus: RecipesMutationStatus.loading,
              movedFieldId: 'f2',
            ),
            loaded.copyWith(
              mutation: RecipesMutation.fieldMoved,
              mutationStatus: RecipesMutationStatus.success,
              movedFieldId: 'f2',
            ),
          ],
          verify: (_) => verify(
            () => repository.saveLibrary(cocktailsWith(fields)),
          ).called(1),
        );
      }

      for (final (reason, event) in [
        (
          'the first field is moved up',
          const RecipesFieldMoved(libraryId: 'l1', fieldId: 'f1', delta: -1),
        ),
        (
          'the last field is moved down',
          const RecipesFieldMoved(libraryId: 'l1', fieldId: 'f3', delta: 1),
        ),
        (
          'the delta is zero',
          const RecipesFieldMoved(libraryId: 'l1', fieldId: 'f2', delta: 0),
        ),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits nothing and saves nothing when $reason',
          build: buildBloc,
          seed: () => loaded,
          act: (bloc) => bloc.add(event),
          expect: () => const <RecipesState>[],
          verify: (_) => verifyNever(
            () => repository.saveLibrary(
              any(),
              optionRenames: any(named: 'optionRenames'),
            ),
          ),
        );
      }

      for (final (reason, event) in [
        (
          'the library is not there',
          const RecipesFieldMoved(libraryId: 'gone', fieldId: 'f2', delta: 1),
        ),
        (
          'the field is not there',
          const RecipesFieldMoved(libraryId: 'l1', fieldId: 'gone', delta: 1),
        ),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure without calling the repository when $reason',
          build: buildBloc,
          seed: () => loaded,
          act: (bloc) => bloc.add(event),
          expect: () => [
            loaded.copyWith(
              mutation: RecipesMutation.fieldMoved,
              mutationStatus: RecipesMutationStatus.loading,
              movedFieldId: event.fieldId,
            ),
            loaded.copyWith(
              mutation: RecipesMutation.fieldMoved,
              mutationStatus: RecipesMutationStatus.failure,
              movedFieldId: event.fieldId,
            ),
          ],
          verify: (_) => verifyNever(
            () => repository.saveLibrary(
              any(),
              optionRenames: any(named: 'optionRenames'),
            ),
          ),
        );
      }

      for (final (reason, exception) in [
        ('the name is taken', const LibraryNameTakenException('Cocktails')),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure when $reason',
          setUp: () => when(
            () => repository.saveLibrary(
              any(),
              optionRenames: any(named: 'optionRenames'),
            ),
          ).thenThrow(exception),
          build: buildBloc,
          seed: () => loaded,
          act: (bloc) => bloc.add(
            const RecipesFieldMoved(libraryId: 'l1', fieldId: 'f2', delta: 1),
          ),
          expect: () => [
            loaded.copyWith(
              mutation: RecipesMutation.fieldMoved,
              mutationStatus: RecipesMutationStatus.loading,
              movedFieldId: 'f2',
            ),
            loaded.copyWith(
              mutation: RecipesMutation.fieldMoved,
              mutationStatus: RecipesMutationStatus.failure,
              movedFieldId: 'f2',
            ),
          ],
        );
      }

      group('queued behind another move', () {
        late StreamController<RecipesSnapshot> snapshots;

        RecipesSnapshot snapshotWith(Library library) => RecipesSnapshot(
          libraries: [library, coffee],
          recipes: const [],
          ingredients: const [],
          activeLibraryId: 'l1',
          ingredientsImported: true,
        );

        blocTest<RecipesBloc, RecipesState>(
          'moves the field on from where the first move left it',
          setUp: () {
            snapshots = StreamController<RecipesSnapshot>();
            addTearDown(snapshots.close);
            when(() => repository.watch()).thenAnswer((_) => snapshots.stream);
            when(
              () => repository.saveLibrary(
                any(),
                optionRenames: any(named: 'optionRenames'),
              ),
            ).thenAnswer((invocation) async {
              // As the storage layer does: the snapshot is out before the
              // save returns, which is what the second move relies on.
              snapshots.add(
                snapshotWith(invocation.positionalArguments.first as Library),
              );
            });
          },
          build: buildBloc,
          act: (bloc) async {
            final subscribed = bloc.stream.firstWhere(
              (state) => state.status == RecipesStatus.success,
            );
            bloc.add(const RecipesSubscriptionRequested());
            snapshots.add(
              snapshotWith(cocktailsWith([glassware, garnish, method])),
            );
            await subscribed;
            bloc
              ..add(
                const RecipesFieldMoved(
                  libraryId: 'l1',
                  fieldId: 'f3',
                  delta: -1,
                ),
              )
              ..add(
                const RecipesFieldMoved(
                  libraryId: 'l1',
                  fieldId: 'f3',
                  delta: -1,
                ),
              );
          },
          verify: (bloc) {
            verifyInOrder([
              () => repository.saveLibrary(
                cocktailsWith([glassware, method, garnish]),
              ),
              () => repository.saveLibrary(
                cocktailsWith([method, glassware, garnish]),
              ),
            ]);
            expect(
              bloc.state.libraryById('l1')!.fields,
              equals([method, glassware, garnish]),
            );
            expect(bloc.state.movedFieldId, equals('f3'));
          },
        );
      });
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
        'imports the importable entries in one call, with ids minted',
        setUp: () => when(
          () => repository.importIngredients(any()),
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
                    () => repository.importIngredients(captureAny()),
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
        verify: (_) => verifyNever(() => repository.importIngredients(any())),
      );

      for (final (reason, exception) in <(String, Exception)>[
        ('a name is taken', const IngredientNameTakenException('Campari')),
        ('the write fails', const RecipesPersistenceException('disk full')),
      ]) {
        blocTest<RecipesBloc, RecipesState>(
          'emits failure when $reason',
          setUp: () => when(
            () => repository.importIngredients(any()),
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
