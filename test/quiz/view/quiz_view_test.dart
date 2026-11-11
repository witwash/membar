import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/quiz/quiz.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockRecipesBloc extends MockBloc<RecipesEvent, RecipesState>
    implements RecipesBloc {}

class _MockQuizBloc extends MockBloc<QuizEvent, QuizState>
    implements QuizBloc {}

void main() {
  group('QuizView', () {
    late RecipesBloc recipesBloc;
    late QuizBloc quizBloc;

    final negroni = Recipe(
      id: 'recipe-negroni',
      libraryId: cocktailsLibrary.id,
      name: 'Negroni',
    );
    final daiquiri = Recipe(
      id: 'recipe-daiquiri',
      libraryId: cocktailsLibrary.id,
      name: 'Daiquiri',
    );
    final martini = Recipe(
      id: 'recipe-martini',
      libraryId: cocktailsLibrary.id,
      name: 'Martini',
    );
    final deck = [negroni, daiquiri, martini];
    final answeredAt = DateTime(2026, 11, 11, 9);

    CardOutcome outcome(Recipe recipe, {bool remembered = true}) => CardOutcome(
      recipeId: recipe.id,
      remembered: remembered,
      answeredAt: answeredAt,
    );

    final fresh = QuizState(deck: deck);
    final flipped = QuizState(deck: deck, flipped: true);
    final graded = QuizState(
      deck: deck,
      index: 1,
      outcomes: [outcome(negroni)],
    );
    final finished = QuizState(
      deck: deck,
      index: 3,
      outcomes: [
        outcome(negroni),
        outcome(daiquiri, remembered: false),
        outcome(martini),
      ],
    );
    final retryPass = QuizState(
      deck: [daiquiri],
      outcomes: finished.outcomes,
      passStart: 3,
    );

    setUpAll(() => registerFallbackValue(const QuizCardFlipped()));

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      quizBloc = _MockQuizBloc();
      when(() => recipesBloc.state).thenReturn(const RecipesState());
    });

    void mockState(QuizState state) => whenListen(
      quizBloc,
      const Stream<QuizState>.empty(),
      initialState: state,
    );

    Future<void> pumpView(WidgetTester tester, QuizState state) async {
      mockState(state);
      await tester.pumpApp(
        BlocProvider.value(value: quizBloc, child: const QuizView()),
        recipesBloc: recipesBloc,
      );
      await tester.pumpAndSettle();
    }

    Future<void> openView(WidgetTester tester, QuizState state) async {
      mockState(state);
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: quizBloc,
                  child: const QuizView(),
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
    }

    Future<void> pressBack(WidgetTester tester) async {
      await tester.tap(find.byType(FHeaderAction).first);
      await tester.pumpAndSettle();
    }

    FButton buttonLabelled(WidgetTester tester, String label) =>
        tester.widget<FButton>(
          find.ancestor(of: find.text(label), matching: find.byType(FButton)),
        );

    testWidgets('shows the title and the card on top of the deck', (
      tester,
    ) async {
      await pumpView(tester, fresh);

      expect(find.text('Quiz'), findsOneWidget);
      expect(find.byType(QuizCard), findsOneWidget);
      expect(find.text('Negroni'), findsOneWidget);
      expect(find.byType(QuizSummary), findsNothing);
    });

    testWidgets('announces the progress as a live region', (tester) async {
      await pumpView(tester, graded);

      expect(
        tester.getSemantics(find.text('Card 2 of 3')),
        isSemantics(label: 'Card 2 of 3', isLiveRegion: true),
      );
    });

    group('grade buttons', () {
      testWidgets('are disabled before the flip', (tester) async {
        await pumpView(tester, fresh);

        expect(buttonLabelled(tester, "Didn't remember").onPress, isNull);
        expect(buttonLabelled(tester, 'Remembered').onPress, isNull);
      });

      testWidgets('grade the flipped card as not remembered', (tester) async {
        await pumpView(tester, flipped);

        await tester.tap(find.text("Didn't remember"));
        await tester.pumpAndSettle();

        verify(
          () => quizBloc.add(const QuizCardGraded(remembered: false)),
        ).called(1);
      });

      testWidgets('grade the flipped card as remembered', (tester) async {
        await pumpView(tester, flipped);

        await tester.tap(find.text('Remembered'));
        await tester.pumpAndSettle();

        verify(
          () => quizBloc.add(const QuizCardGraded(remembered: true)),
        ).called(1);
      });
    });

    testWidgets('focuses the front of the next card after a grade', (
      tester,
    ) async {
      final bloc = QuizBloc(recipes: deck, random: Random(1));
      addTearDown(bloc.close);
      await tester.pumpApp(
        BlocProvider.value(value: bloc, child: const QuizView()),
        recipesBloc: recipesBloc,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(bloc.state.currentRecipe!.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remembered'));
      await tester.pumpAndSettle();

      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.ancestor(
          of: find.byWidget(focused.widget),
          matching: find.byType(QuizCard),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byWidget(focused.widget),
          matching: find.text(bloc.state.currentRecipe!.name),
        ),
        findsOneWidget,
      );
    });

    testWidgets('focuses the front of the next card after a keyboard grade', (
      tester,
    ) async {
      final bloc = QuizBloc(recipes: deck, random: Random(1));
      addTearDown(bloc.close);
      await tester.pumpApp(
        BlocProvider.value(value: bloc, child: const QuizView()),
        recipesBloc: recipesBloc,
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.text('Remembered'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(bloc.state.index, 1);
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.descendant(
          of: find.byWidget(focused.widget),
          matching: find.text(bloc.state.currentRecipe!.name),
        ),
        findsOneWidget,
      );
    });

    testWidgets('runs a pass to the summary and retries only the missed', (
      tester,
    ) async {
      final bloc = QuizBloc(recipes: deck, random: Random(1));
      addTearDown(bloc.close);
      await tester.pumpApp(
        BlocProvider.value(value: bloc, child: const QuizView()),
        recipesBloc: recipesBloc,
      );
      await tester.pumpAndSettle();
      final order = bloc.state.deck;

      for (final (i, recipe) in order.indexed) {
        expect(find.text('Card ${i + 1} of 3'), findsOneWidget);
        await tester.tap(find.text(recipe.name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(i == 0 ? 'Remembered' : "Didn't remember"));
        await tester.pumpAndSettle();
      }

      expect(find.text('1 of 3 remembered'), findsOneWidget);
      expect(find.text(order[0].name), findsNothing);
      expect(find.text(order[1].name), findsOneWidget);
      expect(find.text(order[2].name), findsOneWidget);

      await tester.tap(find.text('Retry missed'));
      await tester.pumpAndSettle();

      expect(find.text('Card 1 of 2'), findsOneWidget);
      expect(bloc.state.deck, unorderedEquals([order[1], order[2]]));
    });

    testWidgets('shows the summary in place of the card when finished', (
      tester,
    ) async {
      await pumpView(tester, finished);

      expect(find.byType(QuizSummary), findsOneWidget);
      expect(find.byType(QuizCard), findsNothing);
      expect(find.text('Remembered'), findsNothing);
    });

    group('back', () {
      testWidgets('pops without asking before any grade', (tester) async {
        await openView(tester, fresh);

        await pressBack(tester);

        expect(find.text('Leave the quiz?'), findsNothing);
        expect(find.byType(QuizView), findsNothing);
      });

      testWidgets('asks after a grade, and Keep going stays', (tester) async {
        await openView(tester, graded);

        await pressBack(tester);
        expect(find.text('Leave the quiz?'), findsOneWidget);
        expect(
          find.text('Your progress in this pass will be lost.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Keep going'));
        await tester.pumpAndSettle();

        expect(find.text('Leave the quiz?'), findsNothing);
        expect(find.byType(QuizView), findsOneWidget);
      });

      testWidgets('asks after a grade, and Leave pops', (tester) async {
        await openView(tester, graded);

        await pressBack(tester);
        await tester.tap(find.text('Leave'));
        await tester.pumpAndSettle();

        expect(find.byType(QuizView), findsNothing);
        expect(find.text('Open'), findsOneWidget);
      });

      testWidgets('pops without asking on the summary', (tester) async {
        await openView(tester, finished);

        await pressBack(tester);

        expect(find.text('Leave the quiz?'), findsNothing);
        expect(find.byType(QuizView), findsNothing);
      });

      testWidgets('pops without asking in a retry pass with nothing graded', (
        tester,
      ) async {
        await openView(tester, retryPass);

        await pressBack(tester);

        expect(find.text('Leave the quiz?'), findsNothing);
        expect(find.byType(QuizView), findsNothing);
      });
    });
  });
}
