import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/quiz/quiz.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

void main() {
  group('QuizPage', () {
    late RecipesBloc recipesBloc;

    final recipes = [
      Recipe(id: 'recipe-negroni', libraryId: cocktailsLibrary.id, name: 'N'),
      Recipe(id: 'recipe-daiquiri', libraryId: cocktailsLibrary.id, name: 'D'),
    ];

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      when(() => recipesBloc.state).thenReturn(const RecipesState());
    });

    test('route is named quiz', () {
      expect(
        QuizPage.route(bloc: recipesBloc, recipes: recipes).settings.name,
        'quiz',
      );
    });

    testWidgets('renders QuizView over a quiz of the given recipes', (
      tester,
    ) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(
              context,
            ).push(QuizPage.route(bloc: recipesBloc, recipes: recipes)),
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizView), findsOneWidget);
      final context = tester.element(find.byType(QuizView));
      expect(context.read<QuizBloc>().state.deck, unorderedEquals(recipes));
      expect(context.read<RecipesBloc>(), same(recipesBloc));
    });
  });
}
