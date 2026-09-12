import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
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

    Recipe recipeUsing(String id, List<Ingredient> ingredients) => Recipe(
      id: id,
      libraryId: cocktailsLibrary.id,
      name: id,
      ingredients: ingredients,
    );

    final loaded = RecipesState(
      status: RecipesStatus.success,
      libraries: [cocktailsLibrary, coffeeLibrary],
      ingredients: [ginIngredient, sugarIngredient, cinnamonIngredient],
      recipes: [
        recipeUsing('Negroni', [
          Ingredient(name: 'Gin', catalogId: ginIngredient.id),
        ]),
        recipeUsing('Martini', [
          Ingredient(name: 'Gin', catalogId: ginIngredient.id),
          Ingredient(name: 'Gin', catalogId: ginIngredient.id),
        ]),
        recipeUsing('Old Fashioned', [
          Ingredient(name: 'sugar', catalogId: sugarIngredient.id),
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

    testWidgets('lists every entry by name with its unit and libraries', (
      tester,
    ) async {
      await pumpView(tester, loaded);

      expect(find.text('Ingredients'), findsOneWidget);
      final names = tester
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
          );
      expect(names, ['Cinnamon', 'Gin', 'sugar']);
      expect(find.text('pinch · Coffee'), findsOneWidget);
      expect(find.text('ml · Cocktails'), findsOneWidget);
      expect(find.text('gram · Cocktails, Coffee'), findsOneWidget);
    });

    testWidgets('leaves out a missing unit and an unknown library', (
      tester,
    ) async {
      final ice = CatalogIngredient(
        id: 'ingredient-ice',
        name: 'Ice',
        libraryIds: {coffeeLibrary.id, 'library-gone'},
      );
      await pumpView(tester, loaded.copyWith(ingredients: [ice]));

      expect(find.text('Coffee'), findsOneWidget);
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
        find.descendant(
          of: tileOf('Cinnamon'),
          matching: find.text('Not used'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders an empty state for an empty catalog', (tester) async {
      await pumpView(tester, loaded.copyWith(ingredients: const []));

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

    group('import', () {
      final withFreeText = loaded.copyWith(
        recipes: [
          ...loaded.recipes,
          recipeUsing('Daiquiri', [
            Ingredient(name: 'Rum'),
            Ingredient(name: 'Lime'),
          ]),
        ],
      );

      testWidgets('is not offered when there is nothing to import', (
        tester,
      ) async {
        await pumpView(tester, loaded);

        expect(find.textContaining('Import'), findsNothing);
      });

      testWidgets('is offered with its count above a non-empty list', (
        tester,
      ) async {
        await pumpView(tester, withFreeText);

        expect(
          find.text('Import 2 ingredients from your recipes'),
          findsOneWidget,
        );
        expect(find.byType(FTile), findsNWidgets(3));
      });

      testWidgets('is offered on the empty state', (tester) async {
        await pumpView(
          tester,
          withFreeText.copyWith(
            ingredients: const [],
            recipes: [
              recipeUsing('Daiquiri', [Ingredient(name: 'Rum')]),
            ],
          ),
        );

        expect(
          find.text('Import 1 ingredient from your recipes'),
          findsOneWidget,
        );
        expect(find.text('No ingredients yet'), findsOneWidget);
      });

      testWidgets('dispatches the import', (tester) async {
        await pumpView(tester, withFreeText);

        await tester.tap(find.text('Import 2 ingredients from your recipes'));
        await tester.pumpAndSettle();

        verify(
          () => recipesBloc.add(const RecipesIngredientsImported()),
        ).called(1);
      });

      testWidgets('is disabled while the import is in flight', (tester) async {
        await pumpView(
          tester,
          withFreeText.copyWith(
            mutation: RecipesMutation.ingredientsImported,
            mutationStatus: RecipesMutationStatus.loading,
          ),
        );

        final button = tester.widget<FButton>(
          find.ancestor(
            of: find.text('Import 2 ingredients from your recipes'),
            matching: find.byType(FButton),
          ),
        );
        expect(button.onPress, isNull);
      });

      testWidgets('reports a failed import', (tester) async {
        await pumpView(tester, withFreeText);

        await emit(
          tester,
          withFreeText.copyWith(
            mutation: RecipesMutation.ingredientsImported,
            mutationStatus: RecipesMutationStatus.failure,
          ),
        );

        expect(
          find.text('Your ingredients could not be imported.'),
          findsOneWidget,
        );
      });

      testWidgets('clears the banner when the import is retried', (
        tester,
      ) async {
        await pumpView(tester, withFreeText);
        await emit(
          tester,
          withFreeText.copyWith(
            mutation: RecipesMutation.ingredientsImported,
            mutationStatus: RecipesMutationStatus.failure,
          ),
        );

        await tester.tap(find.text('Import 2 ingredients from your recipes'));
        await tester.pumpAndSettle();

        expect(
          find.text('Your ingredients could not be imported.'),
          findsNothing,
        );
      });

      testWidgets('reports nothing when the import succeeds', (tester) async {
        await pumpView(tester, withFreeText);

        await emit(
          tester,
          loaded.copyWith(
            mutation: RecipesMutation.ingredientsImported,
            mutationStatus: RecipesMutationStatus.success,
          ),
        );

        expect(find.byType(FailureBanner), findsNothing);
      });
    });

    group('delete', () {
      testWidgets('is refused for an entry in use, naming the count, '
          'without dispatching', (tester) async {
        await pumpView(tester, loaded);

        await tapDelete(tester, 'Gin');

        expect(
          find.text('Gin is used in 2 recipes, so it cannot be deleted.'),
          findsOneWidget,
        );
        expect(find.byType(FDialog), findsNothing);
        verifyNever(() => recipesBloc.add(any()));
      });

      testWidgets('dispatches after confirming for an unused entry', (
        tester,
      ) async {
        await pumpView(tester, loaded);

        await tapDelete(tester, 'Cinnamon');
        expect(find.text('Delete Cinnamon?'), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        verify(
          () =>
              recipesBloc.add(RecipesIngredientDeleted(cinnamonIngredient.id)),
        ).called(1);
      });

      testWidgets('clears a refusal once a delete is dispatched', (
        tester,
      ) async {
        await pumpView(tester, loaded);

        await tapDelete(tester, 'Gin');
        await tapDelete(tester, 'Cinnamon');
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.byType(FailureBanner), findsNothing);
      });

      testWidgets('does nothing when the confirmation is cancelled', (
        tester,
      ) async {
        await pumpView(tester, loaded);

        await tapDelete(tester, 'Cinnamon');
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

        expect(find.text('Cinnamon'), findsNothing);
        expect(find.byType(FailureBanner), findsNothing);
      });
    });
  });
}
