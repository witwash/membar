import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('RecipeDetailsPage', () {
    late RecipesBloc recipesBloc;

    final negroni = Recipe(
      id: 'recipe-negroni',
      libraryId: cocktailsLibrary.id,
      name: 'Negroni',
      ingredients: [
        Ingredient(name: 'Gin', quantity: '1', unit: 'oz'),
        Ingredient(name: 'Ice'),
      ],
      steps: const ['Stir with ice.', 'Strain over a big cube.'],
      tags: const ['Bitter'],
      notes: 'Equal parts.',
      fieldValues: const {
        'field-glassware': 'Rocks',
        'field-garnish': 'Orange peel',
      },
    );

    late StreamController<RecipesState> states;

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      states = StreamController<RecipesState>.broadcast();
      addTearDown(states.close);
      whenListen(
        recipesBloc,
        states.stream,
        initialState: const RecipesState(),
      );
    });

    Future<void> pumpDetails(
      WidgetTester tester, {
      required Recipe recipe,
      required Library library,
    }) => tester.pumpApp(
      RecipeDetailsPage(recipe: recipe, library: library),
      recipesBloc: recipesBloc,
    );

    /// Pumps details on a pushed route, so popping it can be observed.
    Future<void> pushDetails(WidgetTester tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).push(
              RecipeDetailsPage.route(
                bloc: recipesBloc,
                recipe: negroni,
                library: cocktailsLibrary,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders the recipe name and the placeholder image', (
      tester,
    ) async {
      await pumpDetails(
        tester,
        recipe: negroni,
        library: cocktailsLibrary,
      );

      expect(find.text('Negroni'), findsOneWidget);
      expect(find.byType(RecipePlaceholderImage), findsOneWidget);
    });

    testWidgets('does not render the library switcher', (tester) async {
      await pumpDetails(
        tester,
        recipe: negroni,
        library: cocktailsLibrary,
      );

      expect(find.byType(LibrarySwitcher), findsNothing);
    });

    testWidgets('renders schema fields in schema order', (tester) async {
      await pumpDetails(
        tester,
        recipe: negroni,
        library: cocktailsLibrary,
      );

      expect(find.text('Details'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Glassware')).dy,
        lessThan(tester.getTopLeft(find.text('Garnish')).dy),
      );
      expect(find.text('Orange peel'), findsOneWidget);
    });

    testWidgets('renders a Select value as a badge', (tester) async {
      await pumpDetails(
        tester,
        recipe: negroni,
        library: cocktailsLibrary,
      );

      expect(
        find.descendant(of: find.byType(FBadge), matching: find.text('Rocks')),
        findsOneWidget,
      );
    });

    testWidgets('renders core sections', (tester) async {
      // Every section at once needs more than the default 600px of height.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpDetails(
        tester,
        recipe: negroni,
        library: cocktailsLibrary,
      );

      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('1 oz Gin'), findsOneWidget);
      expect(find.text('Ice'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('1. Stir with ice.'), findsOneWidget);
      expect(find.text('2. Strain over a big cube.'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Equal parts.'), findsOneWidget);
    });

    group('ingredient names', () {
      final sour = Recipe(
        id: 'recipe-sour',
        libraryId: cocktailsLibrary.id,
        name: 'Sour',
        ingredients: [
          Ingredient(
            name: 'Gin',
            quantity: '2',
            unit: 'oz',
            catalogId: ginIngredient.id,
          ),
          Ingredient(name: 'Sugar', catalogId: 'ingredient-deleted'),
          Ingredient(name: 'Lemon'),
        ],
      );

      setUp(() {
        whenListen(
          recipesBloc,
          states.stream,
          initialState: RecipesState(
            ingredients: [
              CatalogIngredient(
                id: ginIngredient.id,
                name: 'London Dry Gin',
                libraryIds: ginIngredient.libraryIds,
              ),
            ],
          ),
        );
      });

      testWidgets("renders a referenced row under its entry's current name", (
        tester,
      ) async {
        await pumpDetails(tester, recipe: sour, library: coffeeLibrary);

        expect(find.text('2 oz London Dry Gin'), findsOneWidget);
      });

      testWidgets('renders the stored name when there is no entry to read', (
        tester,
      ) async {
        await pumpDetails(tester, recipe: sour, library: coffeeLibrary);

        expect(find.text('Sugar'), findsOneWidget);
        expect(find.text('Lemon'), findsOneWidget);
      });
    });

    testWidgets('omits sections the recipe has nothing for', (tester) async {
      await pumpDetails(
        tester,
        recipe: Recipe(libraryId: cocktailsLibrary.id, name: 'Water'),
        library: cocktailsLibrary,
      );

      expect(find.text('Details'), findsNothing);
      expect(find.text('Ingredients'), findsNothing);
      expect(find.text('Steps'), findsNothing);
      expect(find.text('Tags'), findsNothing);
      expect(find.text('Notes'), findsNothing);
    });

    testWidgets('omits a schema field with no value', (tester) async {
      await pumpDetails(
        tester,
        recipe: Recipe(
          libraryId: cocktailsLibrary.id,
          name: 'Negroni',
          fieldValues: const {'field-glassware': 'Rocks'},
        ),
        library: cocktailsLibrary,
      );

      expect(find.text('Glassware'), findsOneWidget);
      expect(find.text('Garnish'), findsNothing);
    });

    testWidgets('renders a whole Number with its unit', (tester) async {
      await pumpDetails(
        tester,
        recipe: Recipe(
          libraryId: coffeeLibrary.id,
          name: 'Morning cup',
          fieldValues: const {'field-dose': 92.0},
        ),
        library: coffeeLibrary,
      );

      expect(find.text('92 g'), findsOneWidget);
    });

    testWidgets('preserves newlines in a LongText value', (tester) async {
      await pumpDetails(
        tester,
        recipe: Recipe(
          libraryId: coffeeLibrary.id,
          name: 'Morning cup',
          fieldValues: const {'field-tasting-notes': 'Stone fruit\nCocoa'},
        ),
        library: coffeeLibrary,
      );

      final text = tester.widget<Text>(find.text('Stone fruit\nCocoa'));
      expect(text.maxLines, isNull);
    });

    testWidgets('pops when the back action is tapped', (tester) async {
      await pushDetails(tester);
      expect(find.byType(RecipeDetailsPage), findsOneWidget);

      // The back action is the header's only prefix; edit and delete follow.
      await tester.tap(find.byType(FHeaderAction).first);
      await tester.pumpAndSettle();

      expect(find.byType(RecipeDetailsPage), findsNothing);
    });

    testWidgets('renders the edited recipe the bloc now holds', (tester) async {
      whenListen(
        recipesBloc,
        states.stream,
        initialState: RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          recipes: [
            Recipe(
              id: negroni.id,
              libraryId: cocktailsLibrary.id,
              name: 'Negroni Sbagliato',
            ),
          ],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );

      await pumpDetails(tester, recipe: negroni, library: cocktailsLibrary);

      expect(find.text('Negroni Sbagliato'), findsOneWidget);
      expect(find.text('Negroni'), findsNothing);
    });

    testWidgets('opens the editor from the edit action', (tester) async {
      await pumpDetails(tester, recipe: negroni, library: cocktailsLibrary);

      await tester.tap(find.bySemanticsLabel('Edit recipe'));
      await tester.pumpAndSettle();

      expect(find.byType(RecipeEditorPage), findsOneWidget);
    });

    group('delete', () {
      Future<void> tapDelete(WidgetTester tester) async {
        await tester.tap(find.bySemanticsLabel('Delete recipe'));
        await tester.pumpAndSettle();
      }

      testWidgets('asks for confirmation first', (tester) async {
        await pumpDetails(tester, recipe: negroni, library: cocktailsLibrary);

        await tapDelete(tester);

        expect(find.text('Delete Negroni?'), findsOneWidget);
        verifyNever(() => recipesBloc.add(RecipesRecipeDeleted(negroni.id)));
      });

      testWidgets('keeps the recipe when the dialog is cancelled', (
        tester,
      ) async {
        await pumpDetails(tester, recipe: negroni, library: cocktailsLibrary);

        await tapDelete(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Negroni?'), findsNothing);
        verifyNever(() => recipesBloc.add(RecipesRecipeDeleted(negroni.id)));
      });

      testWidgets('dispatches the deletion once confirmed', (tester) async {
        await pumpDetails(tester, recipe: negroni, library: cocktailsLibrary);

        await tapDelete(tester);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        verify(
          () => recipesBloc.add(RecipesRecipeDeleted(negroni.id)),
        ).called(1);
      });

      testWidgets('pops once the deletion succeeds', (tester) async {
        await pushDetails(tester);

        await tapDelete(tester);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        // The bloc reports the delete in flight before it reports the outcome.
        states.add(
          const RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.loading,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RecipeDetailsPage), findsOneWidget);

        states.add(
          const RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.success,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecipeDetailsPage), findsNothing);
      });

      testWidgets('reports a failed deletion and stays put', (tester) async {
        await pushDetails(tester);

        await tapDelete(tester);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        states.add(
          const RecipesState(
            mutation: RecipesMutation.recipeDeleted,
            mutationStatus: RecipesMutationStatus.failure,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecipeDetailsPage), findsOneWidget);
        expect(find.text('Your recipe could not be deleted.'), findsOneWidget);
      });

      testWidgets('ignores the outcome of another kind of mutation', (
        tester,
      ) async {
        await pushDetails(tester);

        // One bloc backs all three screens, so a save reaching details must
        // not pop it.
        states.add(
          const RecipesState(
            mutation: RecipesMutation.recipeSaved,
            mutationStatus: RecipesMutationStatus.success,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecipeDetailsPage), findsOneWidget);
      });
    });

    testWidgets('route re-provides the bloc to the pushed page', (
      tester,
    ) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).push(
              RecipeDetailsPage.route(
                bloc: recipesBloc,
                recipe: negroni,
                library: cocktailsLibrary,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(RecipeDetailsPage));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
