import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/quiz/quiz.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('QuizCardBack', () {
    late RecipesBloc recipesBloc;

    final negroni = Recipe(
      id: 'recipe-negroni',
      libraryId: cocktailsLibrary.id,
      name: 'Negroni',
      ingredients: [
        Ingredient(catalogId: ginIngredient.id, quantity: '30', unit: 'ml'),
        Ingredient(catalogId: sugarIngredient.id),
      ],
      steps: const ['Stir with ice', 'Strain'],
      tags: const ['bitter'],
      notes: 'A classic',
      fieldValues: {glasswareField.id: 'Rocks'},
    );
    final empty = Recipe(
      id: 'recipe-empty',
      libraryId: cocktailsLibrary.id,
      name: 'Empty',
    );

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      when(() => recipesBloc.state).thenReturn(
        RecipesState(
          status: RecipesStatus.success,
          libraries: [cocktailsLibrary],
          ingredientLibraries: [cocktailsPantry],
          ingredients: [ginIngredient, sugarIngredient],
          activeLibraryId: cocktailsLibrary.id,
        ),
      );
    });

    Future<void> pumpBack(WidgetTester tester, Recipe recipe) =>
        tester.pumpApp(QuizCardBack(recipe: recipe), recipesBloc: recipesBloc);

    testWidgets('lists ingredient lines with amounts and numbered steps', (
      tester,
    ) async {
      await pumpBack(tester, negroni);

      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('30 ml Gin'), findsOneWidget);
      expect(find.text('sugar'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('1. Stir with ice'), findsOneWidget);
      expect(find.text('2. Strain'), findsOneWidget);
    });

    testWidgets('leaves out fields, tags and notes', (tester) async {
      await pumpBack(tester, negroni);

      expect(find.text('Rocks'), findsNothing);
      expect(find.text('bitter'), findsNothing);
      expect(find.text('A classic'), findsNothing);
    });

    testWidgets('reads No ingredients and No steps for an empty recipe', (
      tester,
    ) async {
      await pumpBack(tester, empty);

      expect(find.text('No ingredients'), findsOneWidget);
      expect(find.text('No steps'), findsOneWidget);
    });

    testWidgets('reads No ingredients when every catalog entry is gone', (
      tester,
    ) async {
      when(() => recipesBloc.state).thenReturn(const RecipesState());

      await pumpBack(tester, negroni);

      expect(find.text('No ingredients'), findsOneWidget);
      expect(find.text('Gin'), findsNothing);
    });

    testWidgets('announces the name as a header in a live region', (
      tester,
    ) async {
      await pumpBack(tester, negroni);

      expect(
        tester.getSemantics(find.text('Negroni')),
        isSemantics(label: 'Negroni', isHeader: true, isLiveRegion: true),
      );
    });

    testWidgets('takes focus when the card is flipped', (tester) async {
      await tester.pumpApp(
        BlocProvider(
          create: (_) => QuizBloc(recipes: [negroni]),
          child: const QuizView(),
        ),
        recipesBloc: recipesBloc,
      );

      await tester.tap(find.text('Negroni'));
      await tester.pumpAndSettle();

      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.ancestor(
          of: find.byWidget(focused.widget),
          matching: find.byType(QuizCardBack),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byWidget(focused.widget),
          matching: find.text('Negroni'),
        ),
        findsOneWidget,
      );
    });
  });
}
