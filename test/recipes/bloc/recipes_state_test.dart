import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('RecipesState', () {
    final cocktails = Library(
      id: 'l1',
      name: 'Cocktails',
      ingredientLibraryId: 'il1',
    );
    final coffee = Library(
      id: 'l2',
      name: 'Coffee',
      ingredientLibraryId: 'il2',
    );

    final negroni = Recipe(
      id: 'r1',
      libraryId: 'l1',
      name: 'Negroni',
      tags: const ['Classic', 'Bitter'],
      ingredients: [Ingredient(catalogId: 'campari')],
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
      expect(
        RecipesState(ingredientLibraries: [cocktailsPantry]),
        isNot(RecipesState(ingredientLibraries: [coffeeShelf])),
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

    group('schema', () {
      Recipe recipe(String id, Library library, Map<String, Object?> values) =>
          Recipe(
            id: id,
            libraryId: library.id,
            name: 'Recipe $id',
            fieldValues: values,
          );

      final schema = RecipesState(
        libraries: [cocktailsLibrary, coffeeLibrary],
        recipes: [
          recipe('r1', cocktailsLibrary, {
            glasswareField.id: 'Rocks',
            garnishField.id: 'Orange',
          }),
          recipe('r2', cocktailsLibrary, {glasswareField.id: 'Coupe'}),
          recipe('r3', cocktailsLibrary, {glasswareField.id: ' Coupe '}),
          recipe('r4', cocktailsLibrary, {glasswareField.id: 7}),
          // The same key in another library, which no count may reach.
          recipe('r5', coffeeLibrary, {glasswareField.id: 'Coupe'}),
        ],
        activeLibraryId: cocktailsLibrary.id,
      );

      group('libraryById', () {
        test('is the library carrying the id', () {
          expect(schema.libraryById(coffeeLibrary.id), coffeeLibrary);
        });

        test('is null for an unknown id', () {
          expect(schema.libraryById('gone'), isNull);
        });
      });

      group('libraryNamed', () {
        test('is the library whose name matches, ignoring case and '
            'padding', () {
          expect(schema.libraryNamed('  cOFFEE '), coffeeLibrary);
        });

        test('is null for a name no library carries', () {
          expect(schema.libraryNamed('Tea'), isNull);
        });

        test('is null for a blank name', () {
          expect(schema.libraryNamed('   '), isNull);
        });
      });

      group('recipeCountIn', () {
        test('counts the recipes of that library alone', () {
          expect(schema.recipeCountIn(cocktailsLibrary.id), 4);
          expect(schema.recipeCountIn(coffeeLibrary.id), 1);
        });

        test('is zero for an unknown id', () {
          expect(schema.recipeCountIn('gone'), 0);
        });
      });

      group('fieldValueCount', () {
        test('counts the recipes of that library carrying the key, whatever '
            'the value', () {
          expect(
            schema.fieldValueCount(cocktailsLibrary.id, glasswareField.id),
            4,
          );
          expect(
            schema.fieldValueCount(cocktailsLibrary.id, garnishField.id),
            1,
          );
        });

        test('is zero for an unknown library or field', () {
          expect(schema.fieldValueCount('gone', glasswareField.id), 0);
          expect(schema.fieldValueCount(cocktailsLibrary.id, 'gone'), 0);
        });
      });

      group('recipeCountUsingOptions', () {
        int using(Set<String> options) => schema.recipeCountUsingOptions(
          cocktailsLibrary.id,
          glasswareField.id,
          options,
        );

        test('counts the recipes of that library holding one of the '
            'options', () {
          expect(using({'Coupe', 'Rocks'}), 2);
        });

        test('compares the stored value as it is, so padding and a number '
            'do not match', () {
          expect(using({'Coupe'}), 1);
          expect(using({'7'}), 0);
        });

        test('is zero for no options, and for an unknown library or '
            'field', () {
          expect(using(const {}), 0);
          expect(
            schema.recipeCountUsingOptions('gone', glasswareField.id, {
              'Coupe',
            }),
            0,
          );
          expect(
            schema.recipeCountUsingOptions(cocktailsLibrary.id, 'gone', {
              'Coupe',
            }),
            0,
          );
        });
      });
    });

    group('libraryTags', () {
      test("holds the active library's distinct tags in their first "
          'spelling, ordered case-insensitively', () {
        final spritz = Recipe(
          id: 'r6',
          libraryId: 'l1',
          name: 'Spritz',
          tags: const ['classic', 'aperitivo'],
        );
        final filter = Recipe(
          id: 'r7',
          libraryId: 'l2',
          name: 'Filter',
          tags: const ['Brewed'],
        );

        expect(
          loaded
              .copyWith(recipes: [...loaded.recipes, spritz, filter])
              .libraryTags,
          ['aperitivo', 'Bitter', 'Classic'],
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
      // Shares cocktailsPantry with cocktailsLibrary, and was created after
      // both fixtures.
      final barLibrary = Library(
        id: 'library-bar',
        name: 'Bar',
        ingredientLibraryId: cocktailsPantry.id,
      );
      final catalog = RecipesState(
        libraries: [cocktailsLibrary, coffeeLibrary, barLibrary],
        ingredientLibraries: [cocktailsPantry, coffeeShelf],
        ingredients: [
          ginIngredient,
          cinnamonIngredient,
          sugarIngredient,
          coffeeSugarIngredient,
        ],
        activeLibraryId: cocktailsLibrary.id,
      );

      Recipe recipeUsing(
        String id,
        String libraryId,
        List<String> catalogIds, {
        String? name,
      }) => Recipe(
        id: id,
        libraryId: libraryId,
        name: name ?? id,
        ingredients: [
          for (final catalogId in catalogIds) Ingredient(catalogId: catalogId),
        ],
      );

      group('ingredientsIn', () {
        test('holds the entries of that ingredient library alone', () {
          expect(catalog.ingredientsIn(cocktailsPantry.id), [
            ginIngredient,
            sugarIngredient,
          ]);
        });

        test('orders them case-insensitively', () {
          final apricot = CatalogIngredient(
            id: 'ingredient-apricot',
            name: 'apricot',
            ingredientLibraryId: coffeeShelf.id,
          );

          expect(
            catalog
                .copyWith(
                  ingredients: [
                    coffeeSugarIngredient,
                    cinnamonIngredient,
                    apricot,
                  ],
                )
                .ingredientsIn(coffeeShelf.id),
            [apricot, cinnamonIngredient, coffeeSugarIngredient],
          );
        });

        test('is empty for an unknown id', () {
          expect(catalog.ingredientsIn('gone'), isEmpty);
        });
      });

      group('ingredientUsage', () {
        test('is empty when no recipe has a row', () {
          expect(
            catalog
                .copyWith(
                  recipes: [recipeUsing('r1', cocktailsLibrary.id, [])],
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
                  recipeUsing('r2', barLibrary.id, [sugarIngredient.id]),
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

      group('recipesUsingIngredient', () {
        final aviation = recipeUsing(
          'r1',
          barLibrary.id,
          [ginIngredient.id],
          name: 'Aviation',
        );
        final negroni = recipeUsing(
          'r2',
          cocktailsLibrary.id,
          [ginIngredient.id],
          name: 'Negroni',
        );
        final martinez = recipeUsing(
          'r3',
          cocktailsLibrary.id,
          [ginIngredient.id, ginIngredient.id],
          name: 'martinez',
        );
        final daiquiri = recipeUsing(
          'r4',
          cocktailsLibrary.id,
          [sugarIngredient.id],
          name: 'Daiquiri',
        );
        final orphan = recipeUsing(
          'r5',
          'library-gone',
          [ginIngredient.id],
          name: 'Orphan',
        );
        final using = catalog.copyWith(
          recipes: [aviation, negroni, martinez, daiquiri, orphan],
        );

        test('orders by library creation order, then case-insensitively by '
            'name', () {
          expect(using.recipesUsingIngredient(ginIngredient.id), [
            martinez,
            negroni,
            aviation,
          ]);
        });

        test('leaves out the recipes of the excepted library', () {
          expect(
            using.recipesUsingIngredient(
              ginIngredient.id,
              exceptLibraryId: cocktailsLibrary.id,
            ),
            [aviation],
          );
        });

        test('leaves out a recipe whose library no longer exists', () {
          expect(
            using.recipesUsingIngredient(ginIngredient.id),
            isNot(contains(orphan)),
          );
        });

        test('is empty when no recipe uses the entry', () {
          expect(using.recipesUsingIngredient(cinnamonIngredient.id), isEmpty);
        });
      });

      group('ingredientNamed', () {
        test('is the entry whose name matches, ignoring case and padding', () {
          expect(
            catalog.ingredientNamed(
              '  gIN ',
              ingredientLibraryId: cocktailsPantry.id,
            ),
            ginIngredient,
          );
        });

        test('is the entry of the given ingredient library when two share '
            'the name', () {
          expect(
            catalog.ingredientNamed(
              'Sugar',
              ingredientLibraryId: cocktailsPantry.id,
            ),
            sugarIngredient,
          );
          expect(
            catalog.ingredientNamed(
              'Sugar',
              ingredientLibraryId: coffeeShelf.id,
            ),
            coffeeSugarIngredient,
          );
        });

        test('is null for a name only another ingredient library carries', () {
          expect(
            catalog.ingredientNamed('Gin', ingredientLibraryId: coffeeShelf.id),
            isNull,
          );
        });

        test('is null for a name no entry carries', () {
          expect(
            catalog.ingredientNamed(
              'Gin fizz',
              ingredientLibraryId: cocktailsPantry.id,
            ),
            isNull,
          );
        });

        test('is null for a blank name', () {
          expect(
            catalog.ingredientNamed(
              '   ',
              ingredientLibraryId: cocktailsPantry.id,
            ),
            isNull,
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

      group('ingredientLibraryById', () {
        test('is the ingredient library carrying the id', () {
          expect(catalog.ingredientLibraryById(coffeeShelf.id), coffeeShelf);
        });

        test('is null for an unknown id', () {
          expect(catalog.ingredientLibraryById('gone'), isNull);
        });
      });

      group('ingredientLibraryNamed', () {
        test('is the ingredient library whose name matches, ignoring case '
            'and padding', () {
          expect(catalog.ingredientLibraryNamed(' coffee SHELF '), coffeeShelf);
        });

        test('is null for a name no ingredient library carries', () {
          expect(catalog.ingredientLibraryNamed('Tea'), isNull);
        });

        test('is null for a blank name', () {
          expect(catalog.ingredientLibraryNamed('   '), isNull);
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
          mutation: RecipesMutation.fieldMoved,
          mutationStatus: RecipesMutationStatus.loading,
          libraries: [coffee],
          recipes: [v60],
          ingredientLibraries: [coffeeShelf],
          ingredients: [ginIngredient],
          activeLibraryId: 'l2',
          searchTerm: 'v60',
          activeTags: const {'Filter'},
          movedFieldId: 'f1',
        );

        expect(
          replaced,
          RecipesState(
            status: RecipesStatus.failure,
            mutation: RecipesMutation.fieldMoved,
            mutationStatus: RecipesMutationStatus.loading,
            libraries: [coffee],
            recipes: [v60],
            ingredientLibraries: [coffeeShelf],
            ingredients: [ginIngredient],
            activeLibraryId: 'l2',
            searchTerm: 'v60',
            activeTags: const {'Filter'},
            movedFieldId: 'f1',
          ),
        );
      });
    });
  });
}
