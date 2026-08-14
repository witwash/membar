import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/recipes/recipes.dart';
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

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      whenListen(
        recipesBloc,
        const Stream<RecipesState>.empty(),
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
      expect(find.byType(RecipeDetailsPage), findsOneWidget);

      await tester.tap(find.byType(FHeaderAction));
      await tester.pumpAndSettle();

      expect(find.byType(RecipeDetailsPage), findsNothing);
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
