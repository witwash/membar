import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

void main() {
  group('RecipesState', () {
    final cocktails = Library(id: 'l1', name: 'Cocktails');
    final coffee = Library(id: 'l2', name: 'Coffee');

    final negroni = Recipe(
      id: 'r1',
      libraryId: 'l1',
      name: 'Negroni',
      tags: const ['Classic', 'Bitter'],
      ingredients: [Ingredient(name: 'Campari')],
      notes: 'Stir, do not shake.',
      fieldValues: const {'f1': 'Rocks'},
    );
    final daiquiri = Recipe(
      id: 'r2',
      libraryId: 'l1',
      name: 'daiquiri',
      tags: const ['Classic'],
    );
    final americano = Recipe(id: 'r3', libraryId: 'l1', name: 'Americano');
    final v60 = Recipe(id: 'r4', libraryId: 'l2', name: 'V60');
    final orphan = Recipe(id: 'r5', libraryId: 'gone', name: 'Orphan');

    final loaded = RecipesState(
      status: RecipesStatus.success,
      libraries: [cocktails, coffee],
      recipes: [negroni, daiquiri, americano, v60, orphan],
      activeLibraryId: 'l1',
    );

    test('supports value equality', () {
      expect(const RecipesState(), const RecipesState());
      expect(
        const RecipesState(searchTerm: 'a'),
        isNot(const RecipesState(searchTerm: 'b')),
      );
    });

    group('activeLibrary', () {
      test('is null before the first snapshot arrives', () {
        expect(const RecipesState().activeLibrary, isNull);
      });

      test('is the library the active id points at', () {
        expect(loaded.activeLibrary, cocktails);
        expect(
          loaded.copyWith(activeLibraryId: 'l2').activeLibrary,
          coffee,
        );
      });
    });

    group('visibleRecipes', () {
      test("holds only the active library's recipes, sorted by name", () {
        expect(loaded.visibleRecipes, [americano, daiquiri, negroni]);
      });

      test('hides a recipe whose library no longer exists, without '
          'dropping it from the state', () {
        expect(loaded.visibleRecipes, isNot(contains(orphan)));
        expect(loaded.recipes, contains(orphan));
      });

      test('follows the active library', () {
        expect(loaded.copyWith(activeLibraryId: 'l2').visibleRecipes, [v60]);
      });

      test('narrows by name, case-insensitively', () {
        expect(loaded.copyWith(searchTerm: 'NEG').visibleRecipes, [negroni]);
      });

      test('ignores a blank search term', () {
        expect(loaded.copyWith(searchTerm: '   ').visibleRecipes.length, 3);
      });

      test('does not match ingredients, notes, or schema values', () {
        expect(loaded.copyWith(searchTerm: 'Campari').visibleRecipes, isEmpty);
        expect(loaded.copyWith(searchTerm: 'shake').visibleRecipes, isEmpty);
        expect(loaded.copyWith(searchTerm: 'Rocks').visibleRecipes, isEmpty);
      });

      test('matches any selected tag, case-insensitively', () {
        expect(
          loaded.copyWith(activeTags: const {'bitter'}).visibleRecipes,
          [negroni],
        );
        expect(
          loaded
              .copyWith(activeTags: const {'Bitter', 'Classic'})
              .visibleRecipes,
          [daiquiri, negroni],
        );
      });

      test('ANDs the tag filter with the search term', () {
        expect(
          loaded
              .copyWith(activeTags: const {'Classic'}, searchTerm: 'dai')
              .visibleRecipes,
          [daiquiri],
        );
      });
    });

    group('copyWith', () {
      test('keeps every value when given nothing', () {
        expect(loaded.copyWith(), loaded);
      });

      test('replaces every value it is given', () {
        final replaced = loaded.copyWith(
          status: RecipesStatus.failure,
          saveStatus: RecipesSaveStatus.loading,
          libraries: [coffee],
          recipes: [v60],
          activeLibraryId: 'l2',
          searchTerm: 'v60',
          activeTags: const {'Filter'},
        );

        expect(
          replaced,
          RecipesState(
            status: RecipesStatus.failure,
            saveStatus: RecipesSaveStatus.loading,
            libraries: [coffee],
            recipes: [v60],
            activeLibraryId: 'l2',
            searchTerm: 'v60',
            activeTags: const {'Filter'},
          ),
        );
      });
    });
  });
}
