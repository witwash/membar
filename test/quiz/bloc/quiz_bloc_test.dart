import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:membar/quiz/quiz.dart';
import 'package:recipes_repository/recipes_repository.dart';

void main() {
  group('QuizBloc', () {
    final negroni = Recipe(id: 'negroni', libraryId: 'l', name: 'Negroni');
    final daiquiri = Recipe(id: 'daiquiri', libraryId: 'l', name: 'Daiquiri');
    final martini = Recipe(id: 'martini', libraryId: 'l', name: 'Martini');
    final gimlet = Recipe(id: 'gimlet', libraryId: 'l', name: 'Gimlet');
    final recipes = [negroni, daiquiri, martini, gimlet];
    final answeredAt = DateTime(2026, 11, 11, 9);

    CardOutcome outcome(Recipe recipe, {required bool remembered}) =>
        CardOutcome(
          recipeId: recipe.id,
          remembered: remembered,
          answeredAt: answeredAt,
        );

    QuizBloc buildBloc({List<Recipe>? deck}) => QuizBloc(
      recipes: deck ?? recipes,
      random: Random(7),
      now: () => answeredAt,
    );

    group('initial deck', () {
      test('is a permutation of the recipes it is given', () {
        final state = buildBloc().state;

        expect(state.deck, unorderedEquals(recipes));
        expect(state.index, 0);
        expect(state.flipped, isFalse);
        expect(state.outcomes, isEmpty);
        expect(state.passStart, 0);
      });

      test('has a stable order for a seeded Random', () {
        expect(buildBloc().state.deck, buildBloc().state.deck);
        expect(buildBloc().state.deck, [...recipes]..shuffle(Random(7)));
      });

      test('is shuffled without an injected Random', () {
        expect(QuizBloc(recipes: recipes).state.deck, unorderedEquals(recipes));
      });

      test('asserts a non-empty list of recipes', () {
        expect(() => QuizBloc(recipes: const []), throwsAssertionError);
      });

      test('leaves the given list untouched', () {
        final given = [...recipes];
        buildBloc(deck: given);

        expect(given, recipes);
      });
    });

    group('QuizCardFlipped', () {
      blocTest<QuizBloc, QuizState>(
        'flips the current card',
        build: buildBloc,
        seed: () => QuizState(deck: recipes),
        act: (bloc) => bloc.add(const QuizCardFlipped()),
        expect: () => [QuizState(deck: recipes, flipped: true)],
      );

      blocTest<QuizBloc, QuizState>(
        'emits nothing when the card is already flipped',
        build: buildBloc,
        seed: () => QuizState(deck: recipes, flipped: true),
        act: (bloc) => bloc.add(const QuizCardFlipped()),
        expect: () => const <QuizState>[],
      );

      blocTest<QuizBloc, QuizState>(
        'emits nothing when the pass is finished',
        build: buildBloc,
        seed: () => QuizState(deck: recipes, index: 4),
        act: (bloc) => bloc.add(const QuizCardFlipped()),
        expect: () => const <QuizState>[],
      );
    });

    group('QuizCardGraded', () {
      blocTest<QuizBloc, QuizState>(
        'emits nothing when the card is not flipped',
        build: buildBloc,
        seed: () => QuizState(deck: recipes),
        act: (bloc) => bloc.add(const QuizCardGraded(remembered: true)),
        expect: () => const <QuizState>[],
      );

      blocTest<QuizBloc, QuizState>(
        'logs the outcome stamped with now, advances and unflips',
        build: buildBloc,
        seed: () => QuizState(deck: recipes, flipped: true),
        act: (bloc) => bloc.add(const QuizCardGraded(remembered: false)),
        expect: () => [
          QuizState(
            deck: recipes,
            index: 1,
            outcomes: [outcome(negroni, remembered: false)],
          ),
        ],
      );

      blocTest<QuizBloc, QuizState>(
        'a second grade before the next flip is ignored',
        build: buildBloc,
        seed: () => QuizState(deck: recipes, flipped: true),
        act: (bloc) => bloc
          ..add(const QuizCardGraded(remembered: true))
          ..add(const QuizCardGraded(remembered: true)),
        expect: () => [
          QuizState(
            deck: recipes,
            index: 1,
            outcomes: [outcome(negroni, remembered: true)],
          ),
        ],
      );

      blocTest<QuizBloc, QuizState>(
        'grading the last card finishes the pass',
        build: buildBloc,
        seed: () => QuizState(deck: recipes, index: 3, flipped: true),
        act: (bloc) => bloc.add(const QuizCardGraded(remembered: true)),
        verify: (bloc) {
          expect(bloc.state.isFinished, isTrue);
          expect(bloc.state.flipped, isFalse);
          expect(bloc.state.outcomes, [outcome(gimlet, remembered: true)]);
        },
      );

      blocTest<QuizBloc, QuizState>(
        'emits nothing when the pass is finished',
        build: buildBloc,
        seed: () => QuizState(deck: recipes, index: 4, flipped: true),
        act: (bloc) => bloc.add(const QuizCardGraded(remembered: true)),
        expect: () => const <QuizState>[],
      );
    });

    group('QuizMissedRetried', () {
      final finished = QuizState(
        deck: recipes,
        index: 4,
        outcomes: [
          outcome(negroni, remembered: false),
          outcome(daiquiri, remembered: true),
          outcome(martini, remembered: false),
          outcome(gimlet, remembered: true),
        ],
      );

      blocTest<QuizBloc, QuizState>(
        'emits nothing before the pass is finished',
        build: buildBloc,
        seed: () => finished.copyWith(index: 3),
        act: (bloc) => bloc.add(const QuizMissedRetried()),
        expect: () => const <QuizState>[],
      );

      blocTest<QuizBloc, QuizState>(
        'emits nothing when nothing was missed',
        build: buildBloc,
        seed: () => QuizState(
          deck: [negroni],
          index: 1,
          outcomes: [outcome(negroni, remembered: true)],
        ),
        act: (bloc) => bloc.add(const QuizMissedRetried()),
        expect: () => const <QuizState>[],
      );

      blocTest<QuizBloc, QuizState>(
        'reshuffles the missed recipes with the injected Random',
        build: buildBloc,
        seed: () => QuizState(
          deck: recipes,
          index: 4,
          outcomes: [
            for (final recipe in recipes) outcome(recipe, remembered: false),
          ],
        ),
        act: (bloc) => bloc.add(const QuizMissedRetried()),
        verify: (bloc) {
          // Replays the bloc's Random: one shuffle for the first pass, then
          // the retry's.
          final random = Random(7);
          [...recipes].shuffle(random);
          final expected = [...recipes]..shuffle(random);

          expect(expected, isNot(recipes));
          expect(bloc.state.deck, expected);
        },
      );

      blocTest<QuizBloc, QuizState>(
        'starts a pass over exactly the missed recipes, keeping every outcome',
        build: buildBloc,
        seed: () => finished,
        act: (bloc) => bloc.add(const QuizMissedRetried()),
        verify: (bloc) {
          final state = bloc.state;
          expect(state.deck, unorderedEquals([negroni, martini]));
          expect(state.index, 0);
          expect(state.flipped, isFalse);
          expect(state.outcomes, finished.outcomes);
          expect(state.passStart, 4);
          expect(state.hasGradedInPass, isFalse);
        },
      );
    });

    blocTest<QuizBloc, QuizState>(
      'runs a single-card deck through a miss and a retry',
      build: () => buildBloc(deck: [negroni]),
      act: (bloc) => bloc
        ..add(const QuizCardFlipped())
        ..add(const QuizCardGraded(remembered: false))
        ..add(const QuizMissedRetried())
        ..add(const QuizCardFlipped())
        ..add(const QuizCardGraded(remembered: true)),
      expect: () => [
        QuizState(deck: [negroni], flipped: true),
        QuizState(
          deck: [negroni],
          index: 1,
          outcomes: [outcome(negroni, remembered: false)],
        ),
        QuizState(
          deck: [negroni],
          outcomes: [outcome(negroni, remembered: false)],
          passStart: 1,
        ),
        QuizState(
          deck: [negroni],
          flipped: true,
          outcomes: [outcome(negroni, remembered: false)],
          passStart: 1,
        ),
        QuizState(
          deck: [negroni],
          index: 1,
          outcomes: [
            outcome(negroni, remembered: false),
            outcome(negroni, remembered: true),
          ],
          passStart: 1,
        ),
      ],
      verify: (bloc) {
        expect(bloc.state.isFinished, isTrue);
        expect(bloc.state.rememberedCount, 1);
        expect(bloc.state.missedRecipes, isEmpty);
      },
    );
  });
}
