import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

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

    group('catalog', () {
      final catalog = RecipesState(
        libraries: [cocktailsLibrary, coffeeLibrary],
        ingredients: [ginIngredient, cinnamonIngredient, sugarIngredient],
        activeLibraryId: cocktailsLibrary.id,
      );

      group('libraryIngredients', () {
        test('holds entries visible in the active library, ordered '
            'case-insensitively', () {
          expect(catalog.libraryIngredients, [ginIngredient, sugarIngredient]);
        });

        test('follows the active library', () {
          expect(
            catalog
                .copyWith(activeLibraryId: coffeeLibrary.id)
                .libraryIngredients,
            [cinnamonIngredient, sugarIngredient],
          );
        });
      });

      group('otherLibraryIngredients', () {
        test('holds the entries the active library does not see', () {
          expect(catalog.otherLibraryIngredients, [cinnamonIngredient]);
        });

        test('orders them case-insensitively', () {
          final apricot = CatalogIngredient(
            id: 'ingredient-apricot',
            name: 'apricot',
            libraryIds: {coffeeLibrary.id},
          );

          expect(
            catalog
                .copyWith(
                  ingredients: [cinnamonIngredient, apricot],
                )
                .otherLibraryIngredients,
            [apricot, cinnamonIngredient],
          );
        });
      });

      group('ingredientUsage', () {
        Recipe recipeUsing(String id, String libraryId, List<String?> links) =>
            Recipe(
              id: id,
              libraryId: libraryId,
              name: id,
              ingredients: [
                for (final link in links)
                  Ingredient(name: 'Row', catalogId: link),
              ],
            );

        test('is empty when no recipe links to the catalog', () {
          expect(
            catalog
                .copyWith(
                  recipes: [
                    recipeUsing('r1', cocktailsLibrary.id, [null]),
                  ],
                )
                .ingredientUsage,
            isEmpty,
          );
        });

        test('counts distinct recipes across every library', () {
          final usage = catalog
              .copyWith(
                recipes: [
                  recipeUsing('r1', cocktailsLibrary.id, [
                    ginIngredient.id,
                    sugarIngredient.id,
                  ]),
                  recipeUsing('r2', coffeeLibrary.id, [
                    sugarIngredient.id,
                    null,
                  ]),
                ],
              )
              .ingredientUsage;

          expect(usage, {ginIngredient.id: 1, sugarIngredient.id: 2});
        });

        test('counts a recipe using one entry on two rows once', () {
          expect(
            catalog
                .copyWith(
                  recipes: [
                    recipeUsing('r1', cocktailsLibrary.id, [
                      ginIngredient.id,
                      ginIngredient.id,
                    ]),
                  ],
                )
                .ingredientUsage,
            {ginIngredient.id: 1},
          );
        });
      });

      group('ingredientById', () {
        test('is the entry carrying the id', () {
          expect(catalog.ingredientById(sugarIngredient.id), sugarIngredient);
        });

        test('is null for an unknown id', () {
          expect(catalog.ingredientById('gone'), isNull);
        });
      });
    });

    group('copyWith', () {
      test('keeps every value when given nothing', () {
        expect(loaded.copyWith(), loaded);
      });

      test('replaces every value it is given', () {
        final replaced = loaded.copyWith(
          status: RecipesStatus.failure,
          mutationStatus: RecipesMutationStatus.loading,
          libraries: [coffee],
          recipes: [v60],
          ingredients: [ginIngredient],
          activeLibraryId: 'l2',
          searchTerm: 'v60',
          activeTags: const {'Filter'},
        );

        expect(
          replaced,
          RecipesState(
            status: RecipesStatus.failure,
            mutationStatus: RecipesMutationStatus.loading,
            libraries: [coffee],
            recipes: [v60],
            ingredients: [ginIngredient],
            activeLibraryId: 'l2',
            searchTerm: 'v60',
            activeTags: const {'Filter'},
          ),
        );
      });
    });
  });
}
