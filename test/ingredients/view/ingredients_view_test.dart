import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/ingredients/ingredients.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:membar/ui/ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('IngredientsView', () {
    late RecipesBloc recipesBloc;
    late StreamController<RecipesState> states;

    Recipe recipeUsing(
      String id,
      List<Ingredient> ingredients, {
      String? libraryId,
    }) => Recipe(
      id: id,
      libraryId: libraryId ?? cocktailsLibrary.id,
      name: id,
      ingredients: ingredients,
    );

    /// An entry in [cocktailsPantry] with no default unit, which no recipe
    /// uses.
    final ice = CatalogIngredient(
      id: 'ingredient-ice',
      name: 'Ice',
      ingredientLibraryId: cocktailsPantry.id,
    );

    final loaded = RecipesState(
      status: RecipesStatus.success,
      libraries: [cocktailsLibrary, coffeeLibrary],
      ingredientLibraries: [cocktailsPantry, coffeeShelf],
      ingredients: [
        ginIngredient,
        sugarIngredient,
        ice,
        coffeeSugarIngredient,
        cinnamonIngredient,
      ],
      recipes: [
        recipeUsing('Negroni', [Ingredient(catalogId: ginIngredient.id)]),
        recipeUsing('Martini', [
          Ingredient(catalogId: ginIngredient.id),
          Ingredient(catalogId: ginIngredient.id),
        ]),
        recipeUsing('Old Fashioned', [
          Ingredient(catalogId: sugarIngredient.id),
        ]),
      ],
      activeLibraryId: cocktailsLibrary.id,
    );

    setUpAll(
      () => registerFallbackValue(const RecipesSubscriptionRequested()),
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      states = StreamController<RecipesState>.broadcast();
      addTearDown(states.close);
    });

    Future<void> pumpView(WidgetTester tester, RecipesState state) async {
      whenListen(recipesBloc, states.stream, initialState: state);
      await tester.pumpApp(const IngredientsView(), recipesBloc: recipesBloc);
    }

    Future<void> emit(WidgetTester tester, RecipesState state) async {
      when(() => recipesBloc.state).thenReturn(state);
      states.add(state);
      await tester.pumpAndSettle();
    }

    Future<void> tapDelete(WidgetTester tester, String name) async {
      await tester.tap(find.bySemanticsLabel('Delete $name'));
      await tester.pumpAndSettle();
    }

    Finder tileOf(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(FTile));

    List<String?> tileNames(WidgetTester tester) => tester
        .widgetList<FTile>(find.byType(FTile))
        .map(
          (tile) => tester
              .widget<Text>(
                find
                    .descendant(
                      of: find.byWidget(tile),
                      matching: find.byType(Text),
                    )
                    .first,
              )
              .data,
        )
        .toList();

    testWidgets(
      "lists the active library's ingredient library by name with its unit",
      (tester) async {
        await pumpView(tester, loaded);

        expect(find.text('Ingredients'), findsOneWidget);
        expect(tileNames(tester), ['Gin', 'Ice', 'sugar']);
        expect(
          find.descendant(of: tileOf('Gin'), matching: find.text('ml')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tileOf('sugar'), matching: find.text('gram')),
          findsOneWidget,
        );
        expect(find.text('Cinnamon'), findsNothing);
      },
    );

    testWidgets('shows no unit for an entry without one', (tester) async {
      await pumpView(tester, loaded.copyWith(ingredients: [ice]));

      expect(
        find.descendant(of: tileOf('Ice'), matching: find.byType(Text)),
        findsNWidgets(2),
      );
    });

    testWidgets("follows the active library's ingredient library", (
      tester,
    ) async {
      await pumpView(
        tester,
        loaded.copyWith(activeLibraryId: coffeeLibrary.id),
      );

      expect(tileNames(tester), ['Cinnamon', 'sugar']);
      expect(find.text('pinch'), findsOneWidget);
    });

    testWidgets('counts the distinct recipes using each entry', (
      tester,
    ) async {
      await pumpView(tester, loaded);

      expect(
        find.descendant(of: tileOf('Gin'), matching: find.text('2 recipes')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tileOf('sugar'), matching: find.text('1 recipe')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tileOf('Ice'), matching: find.text('Not used')),
        findsOneWidget,
      );
    });

    testWidgets('does not count a same-named entry in another library', (
      tester,
    ) async {
      await pumpView(
        tester,
        loaded.copyWith(
          recipes: [
            ...loaded.recipes,
            recipeUsing('Latte', [
              Ingredient(catalogId: coffeeSugarIngredient.id),
            ], libraryId: coffeeLibrary.id),
          ],
        ),
      );

      expect(
        find.descendant(of: tileOf('sugar'), matching: find.text('1 recipe')),
        findsOneWidget,
      );
    });

    testWidgets('renders an empty state for an empty ingredient library', (
      tester,
    ) async {
      await pumpView(
        tester,
        loaded.copyWith(ingredients: [cinnamonIngredient]),
      );

      expect(find.text('No ingredients yet'), findsOneWidget);
      expect(find.byType(FTile), findsNothing);
    });

    testWidgets('renders an empty state before a library is active', (
      tester,
    ) async {
      await pumpView(tester, const RecipesState());

      expect(find.text('No ingredients yet'), findsOneWidget);
      expect(find.byType(FTile), findsNothing);
    });

    testWidgets('pops from the back action', (tester) async {
      whenListen(recipesBloc, states.stream, initialState: loaded);
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: recipesBloc,
                  child: const IngredientsView(),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FHeaderAction));
      await tester.pumpAndSettle();

      expect(find.byType(IngredientsView), findsNothing);
    });

    testWidgets('opens the editor sheet for a tapped entry', (tester) async {
      await pumpView(tester, loaded);

      await tester.tap(find.text('Gin'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<IngredientEditorSheet>(find.byType(IngredientEditorSheet))
            .entry,
        ginIngredient,
      );
    });

    testWidgets('dismisses a refusal once the editor sheet is opened', (
      tester,
    ) async {
      await pumpView(tester, loaded);
      await tapDelete(tester, 'Gin');
      expect(find.byType(FToast), findsOneWidget);

      await tester.tap(find.text('Ice'));
      await tester.pumpAndSettle();

      expect(find.byType(IngredientEditorSheet), findsOneWidget);
      expect(find.byType(FToast), findsNothing);
    });

    group('delete', () {
      Ingredient sugarRow() => Ingredient(catalogId: sugarIngredient.id);

      testWidgets('is refused for an entry in use, naming the count and the '
          'library, without dispatching', (tester) async {
        await pumpView(tester, loaded);

        await tapDelete(tester, 'Gin');

        expect(inToast('Gin cannot be deleted'), findsOneWidget);
        expect(
          inToast('Used in 2 recipes. Libraries: Cocktails.'),
          findsOneWidget,
        );
        expect(find.byType(FailureBanner), findsNothing);
        expect(find.byType(FDialog), findsNothing);
        verifyNever(() => recipesBloc.add(any()));
      });

      testWidgets('names every library using the entry, in library order', (
        tester,
      ) async {
        // Two libraries can share an ingredient library, so an entry can be
        // used from both.
        final tikiLibrary = Library(
          id: 'library-tiki',
          name: 'Tiki',
          ingredientLibraryId: cocktailsPantry.id,
        );
        await pumpView(
          tester,
          loaded.copyWith(
            libraries: [tikiLibrary, cocktailsLibrary, coffeeLibrary],
            recipes: [
              recipeUsing('Old Fashioned', [sugarRow()]),
              recipeUsing('Mai Tai', [sugarRow()], libraryId: tikiLibrary.id),
              recipeUsing('Zombie', [sugarRow()], libraryId: tikiLibrary.id),
            ],
          ),
        );

        await tapDelete(tester, 'sugar');

        expect(
          inToast('Used in 3 recipes. Libraries: Tiki, Cocktails.'),
          findsOneWidget,
        );
      });

      testWidgets('leaves out a recipe whose library is gone', (tester) async {
        await pumpView(
          tester,
          loaded.copyWith(
            recipes: [
              recipeUsing('Orphan', [sugarRow()], libraryId: 'library-gone'),
              recipeUsing('Old Fashioned', [sugarRow()]),
            ],
          ),
        );

        await tapDelete(tester, 'sugar');

        expect(
          inToast('Used in 1 recipe. Libraries: Cocktails.'),
          findsOneWidget,
        );
      });

      testWidgets('confirms an entry used only in a library that is gone', (
        tester,
      ) async {
        await pumpView(
          tester,
          loaded.copyWith(
            recipes: [
              recipeUsing('Orphan', [sugarRow()], libraryId: 'library-gone'),
            ],
          ),
        );

        await tapDelete(tester, 'sugar');

        expect(find.byType(FToast), findsNothing);
        expect(find.text('Delete sugar?'), findsOneWidget);
      });

      testWidgets('leaves one toast when it is refused twice', (tester) async {
        await pumpView(tester, loaded);

        await tapDelete(tester, 'Gin');
        await tapDelete(tester, 'sugar');

        expect(find.byType(FToast), findsOneWidget);
        expect(inToast('sugar cannot be deleted'), findsOneWidget);
      });

      testWidgets('dispatches after confirming for an unused entry', (
        tester,
      ) async {
        await pumpView(tester, loaded);

        await tapDelete(tester, 'Ice');
        expect(find.text('Delete Ice?'), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        verify(
          () => recipesBloc.add(RecipesIngredientDeleted(ice.id)),
        ).called(1);
      });

      testWidgets('dismisses a refusal once a delete reaches the dialog', (
        tester,
      ) async {
        await pumpView(tester, loaded);
        await tapDelete(tester, 'Gin');
        expect(find.byType(FToast), findsOneWidget);

        await tapDelete(tester, 'Ice');

        expect(find.byType(FDialog), findsOneWidget);
        expect(find.byType(FToast), findsNothing);
      });

      testWidgets('does nothing when the confirmation is cancelled', (
        tester,
      ) async {
        await pumpView(tester, loaded);

        await tapDelete(tester, 'Ice');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(() => recipesBloc.add(any()));
      });

      testWidgets('reports a failed delete', (tester) async {
        await pumpView(tester, loaded);

        await emit(
          tester,
          loaded.copyWith(
            mutation: RecipesMutation.ingredientDeleted,
            mutationStatus: RecipesMutationStatus.failure,
          ),
        );

        expect(
          find.text('Your ingredient could not be deleted.'),
          findsOneWidget,
        );
      });

      testWidgets('drops the entry once the delete succeeds', (tester) async {
        await pumpView(tester, loaded);

        await emit(
          tester,
          loaded.copyWith(
            ingredients: [ginIngredient, sugarIngredient],
            mutation: RecipesMutation.ingredientDeleted,
            mutationStatus: RecipesMutationStatus.success,
          ),
        );

        expect(find.text('Ice'), findsNothing);
        expect(find.byType(FailureBanner), findsNothing);
      });
    });
  });
}
