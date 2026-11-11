import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
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

class _MockQuizBloc extends MockBloc<QuizEvent, QuizState>
    implements QuizBloc {}

void main() {
  group('QuizCard', () {
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

    setUpAll(() => registerFallbackValue(const QuizCardFlipped()));

    setUp(() {
      recipesBloc = _MockRecipesBloc();
      quizBloc = _MockQuizBloc();
      when(() => recipesBloc.state).thenReturn(const RecipesState());
      when(() => quizBloc.state).thenReturn(QuizState(deck: [negroni]));
    });

    Future<void> pumpCard(
      WidgetTester tester, {
      bool flipped = false,
      bool disableAnimations = false,
    }) async {
      await tester.pumpApp(
        BlocProvider.value(
          value: quizBloc,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: QuizCard(recipe: negroni, flipped: flipped),
            ),
          ),
        ),
        recipesBloc: recipesBloc,
      );
      await tester.pump();
    }

    final card = find.byType(FCard);

    double cardWidth(WidgetTester tester) =>
        tester.getSize(find.byType(QuizCard)).width;

    Future<void> slowDrag(WidgetTester tester, double dx) => tester.timedDrag(
      find.byType(QuizCard),
      Offset(dx, 0),
      const Duration(seconds: 1),
    );

    group('front', () {
      testWidgets('shows the name and the reveal hint', (tester) async {
        await pumpCard(tester);

        expect(find.text('Negroni'), findsOneWidget);
        expect(find.text('Tap to reveal'), findsOneWidget);
        expect(find.byType(QuizCardBack), findsNothing);
      });

      testWidgets('reads as a button labelled with the name', (tester) async {
        await pumpCard(tester);

        expect(
          tester.getSemantics(find.bySemanticsLabel('Negroni')),
          isSemantics(
            label: 'Negroni',
            isButton: true,
            hasTapAction: true,
            onTapHint: 'reveal the recipe',
          ),
        );
      });

      testWidgets('flips on tap', (tester) async {
        await pumpCard(tester);

        await tester.tap(find.text('Negroni'));
        await tester.pumpAndSettle();

        verify(() => quizBloc.add(const QuizCardFlipped())).called(1);
      });

      testWidgets('flips on Enter while focused', (tester) async {
        await pumpCard(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);

        verify(() => quizBloc.add(const QuizCardFlipped())).called(1);
      });

      testWidgets('ignores a drag', (tester) async {
        await pumpCard(tester);
        final start = tester.getTopLeft(card);

        await slowDrag(tester, cardWidth(tester));
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(card), start);
        verifyNever(() => quizBloc.add(any()));
      });
    });

    group('back', () {
      testWidgets('shows once flipped', (tester) async {
        await pumpCard(tester, flipped: true);
        await tester.pumpAndSettle();

        expect(find.byType(QuizCardBack), findsOneWidget);
        expect(find.text('Tap to reveal'), findsNothing);
      });

      testWidgets('grades a drag right past the threshold as remembered', (
        tester,
      ) async {
        await pumpCard(tester, flipped: true);

        await slowDrag(tester, cardWidth(tester) * swipeDistanceFraction + 20);
        await tester.pumpAndSettle();

        verify(
          () => quizBloc.add(const QuizCardGraded(remembered: true)),
        ).called(1);
      });

      testWidgets('grades a drag left past the threshold as not remembered', (
        tester,
      ) async {
        await pumpCard(tester, flipped: true);

        await slowDrag(
          tester,
          -(cardWidth(tester) * swipeDistanceFraction + 20),
        );
        await tester.pumpAndSettle();

        verify(
          () => quizBloc.add(const QuizCardGraded(remembered: false)),
        ).called(1);
      });

      testWidgets('grades a short fling', (tester) async {
        await pumpCard(tester, flipped: true);

        await tester.fling(
          find.byType(QuizCard),
          const Offset(-60, 0),
          swipeVelocity * 2,
        );
        await tester.pumpAndSettle();

        verify(
          () => quizBloc.add(const QuizCardGraded(remembered: false)),
        ).called(1);
      });

      testWidgets('springs back from a short drag without grading', (
        tester,
      ) async {
        await pumpCard(tester, flipped: true);
        await tester.pumpAndSettle();
        final start = tester.getTopLeft(card);

        await slowDrag(tester, 60);
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(card), start);
        verifyNever(() => quizBloc.add(any()));
      });

      testWidgets('springs back from a cancelled drag without grading', (
        tester,
      ) async {
        await pumpCard(tester, flipped: true);
        await tester.pumpAndSettle();
        final start = tester.getTopLeft(card);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(QuizCard)),
        );
        await gesture.moveBy(const Offset(40, 0));
        await gesture.moveBy(const Offset(200, 0));
        await tester.pump();
        expect(tester.getTopLeft(card), isNot(start));

        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(card), start);
        verifyNever(() => quizBloc.add(any()));
      });

      testWidgets('ignores further drags while flying off', (tester) async {
        await pumpCard(tester, flipped: true);

        final threshold = cardWidth(tester) * swipeDistanceFraction;
        await slowDrag(tester, threshold + 20);
        // Started before the next frame, so it lands on the card mid-flight.
        await slowDrag(tester, -(threshold + 20));
        await tester.pumpAndSettle();

        verify(
          () => quizBloc.add(const QuizCardGraded(remembered: true)),
        ).called(1);
        verifyNever(
          () => quizBloc.add(const QuizCardGraded(remembered: false)),
        );
      });

      testWidgets('grades a swipe at once when animations are disabled', (
        tester,
      ) async {
        await pumpCard(tester, flipped: true, disableAnimations: true);

        await slowDrag(tester, cardWidth(tester));

        verify(
          () => quizBloc.add(const QuizCardGraded(remembered: true)),
        ).called(1);
        expect(tester.hasRunningAnimations, isFalse);
      });
    });

    testWidgets('records one outcome when a button grades during a fly-off', (
      tester,
    ) async {
      final bloc = QuizBloc(recipes: [negroni, daiquiri]);
      addTearDown(bloc.close);
      await tester.pumpApp(
        BlocProvider.value(value: bloc, child: const QuizView()),
        recipesBloc: recipesBloc,
      );

      await tester.tap(find.text(bloc.state.currentRecipe!.name));
      await tester.pumpAndSettle();
      await tester.timedDrag(
        find.byType(QuizCard),
        Offset(-cardWidth(tester), 0),
        const Duration(seconds: 1),
      );
      await tester.pump(flyOffDuration ~/ 4);
      await tester.tap(find.text('Remembered'));
      await tester.pumpAndSettle();

      expect(bloc.state.outcomes, hasLength(1));
      expect(bloc.state.outcomes.single.remembered, isTrue);
      expect(bloc.state.index, 1);
    });
  });
}
