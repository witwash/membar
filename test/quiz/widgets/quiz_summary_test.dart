import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:membar/quiz/quiz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

class _MockQuizBloc extends MockBloc<QuizEvent, QuizState>
    implements QuizBloc {}

void main() {
  group('QuizSummary', () {
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
    final answeredAt = DateTime(2026, 11, 11, 9);

    QuizState finished(List<(Recipe, bool)> graded) => QuizState(
      deck: [for (final (recipe, _) in graded) recipe],
      index: graded.length,
      outcomes: [
        for (final (recipe, remembered) in graded)
          CardOutcome(
            recipeId: recipe.id,
            remembered: remembered,
            answeredAt: answeredAt,
          ),
      ],
    );

    final withMisses = finished([
      (martini, false),
      (negroni, true),
      (daiquiri, false),
    ]);

    setUpAll(() => registerFallbackValue(const QuizMissedRetried()));

    setUp(() => quizBloc = _MockQuizBloc());

    Future<void> pumpSummary(WidgetTester tester, QuizState state) async {
      when(() => quizBloc.state).thenReturn(state);
      await tester.pumpApp(
        BlocProvider.value(
          value: quizBloc,
          child: const FScaffold(child: QuizSummary()),
        ),
      );
    }

    FButton buttonLabelled(WidgetTester tester, String label) =>
        tester.widget<FButton>(
          find.ancestor(of: find.text(label), matching: find.byType(FButton)),
        );

    testWidgets('announces the score as a live region', (tester) async {
      await pumpSummary(tester, withMisses);

      expect(
        tester.getSemantics(find.text('1 of 3 remembered')),
        isSemantics(label: '1 of 3 remembered', isLiveRegion: true),
      );
    });

    testWidgets('lists the missed recipes in answer order', (tester) async {
      await pumpSummary(tester, withMisses);

      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Negroni'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Martini')).dy,
        lessThan(tester.getTopLeft(find.text('Daiquiri')).dy),
      );
      expect(find.byKey(ValueKey(martini.id)), findsOneWidget);
      expect(find.byKey(ValueKey(daiquiri.id)), findsOneWidget);
    });

    testWidgets('retries the missed recipes', (tester) async {
      await pumpSummary(tester, withMisses);

      expect(buttonLabelled(tester, 'Done').variant, FButtonVariant.outline);
      await tester.tap(find.text('Retry missed'));
      await tester.pumpAndSettle();

      verify(() => quizBloc.add(const QuizMissedRetried())).called(1);
    });

    testWidgets('pops on Done', (tester) async {
      when(() => quizBloc.state).thenReturn(withMisses);
      await tester.pumpApp(
        Builder(
          builder: (context) => FButton(
            onPress: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: quizBloc,
                  child: const FScaffold(child: QuizSummary()),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizSummary), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    group('when everything was remembered', () {
      testWidgets('congratulates a single card', (tester) async {
        await pumpSummary(tester, finished([(negroni, true)]));

        expect(find.text('1 of 1 remembered'), findsOneWidget);
        expect(find.text('You remembered it!'), findsOneWidget);
      });

      testWidgets('congratulates several cards, with no retry', (
        tester,
      ) async {
        await pumpSummary(
          tester,
          finished([(negroni, true), (daiquiri, true), (martini, true)]),
        );

        expect(find.text('You remembered all 3!'), findsOneWidget);
        expect(find.text('Missed'), findsNothing);
        expect(find.text('Retry missed'), findsNothing);
        expect(buttonLabelled(tester, 'Done').variant, FButtonVariant.primary);
      });
    });
  });
}
