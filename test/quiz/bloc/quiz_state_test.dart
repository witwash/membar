import 'package:flutter_test/flutter_test.dart';
import 'package:membar/quiz/quiz.dart';
import 'package:recipes_repository/recipes_repository.dart';

void main() {
  group('QuizState', () {
    final negroni = Recipe(id: 'negroni', libraryId: 'l', name: 'Negroni');
    final daiquiri = Recipe(id: 'daiquiri', libraryId: 'l', name: 'Daiquiri');
    final martini = Recipe(id: 'martini', libraryId: 'l', name: 'Martini');
    final answeredAt = DateTime(2026, 11, 11, 9);

    CardOutcome outcome(Recipe recipe, {required bool remembered}) =>
        CardOutcome(
          recipeId: recipe.id,
          remembered: remembered,
          answeredAt: answeredAt,
        );

    test('shows the card at index until the pass is finished', () {
      final running = QuizState(deck: [negroni, daiquiri], index: 1);
      final finished = QuizState(deck: [negroni, daiquiri], index: 2);

      expect(running.isFinished, isFalse);
      expect(running.currentRecipe, daiquiri);
      expect(finished.isFinished, isTrue);
      expect(finished.currentRecipe, isNull);
    });

    test('counts and lists only the running pass, in answer order', () {
      final state = QuizState(
        deck: [martini, negroni, daiquiri],
        index: 3,
        outcomes: [
          outcome(negroni, remembered: false),
          outcome(martini, remembered: true),
          outcome(martini, remembered: false),
          outcome(negroni, remembered: true),
          outcome(daiquiri, remembered: false),
        ],
        passStart: 2,
      );

      expect(state.rememberedCount, 1);
      expect(state.missedRecipes, [martini, daiquiri]);
    });

    test('knows whether the running pass has a grade', () {
      final firstPass = QuizState(deck: [negroni, daiquiri]);
      final graded = QuizState(
        deck: [negroni, daiquiri],
        index: 1,
        outcomes: [outcome(negroni, remembered: false)],
      );
      final retryStart = QuizState(
        deck: [negroni],
        outcomes: [
          outcome(negroni, remembered: false),
          outcome(daiquiri, remembered: true),
        ],
        passStart: 2,
      );

      expect(firstPass.hasGradedInPass, isFalse);
      expect(graded.hasGradedInPass, isTrue);
      expect(retryStart.hasGradedInPass, isFalse);
    });

    test('copyWith keeps every field it is not given', () {
      final state = QuizState(
        deck: [negroni, daiquiri],
        index: 1,
        flipped: true,
        outcomes: [outcome(negroni, remembered: true)],
        passStart: 1,
      );

      expect(state.copyWith(), equals(state));
      expect(state.copyWith(flipped: false), isNot(equals(state)));
    });
  });
}
