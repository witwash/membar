import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:membar/quiz/bloc/card_outcome.dart';
import 'package:recipes_repository/recipes_repository.dart';

export 'card_outcome.dart';

part 'quiz_event.dart';
part 'quiz_state.dart';

/// {@template quiz_bloc}
/// Runs a flash-card pass over a snapshot of recipes, shuffled, and logs a
/// [CardOutcome] for every grade.
///
/// It reads no repository and persists nothing: the deck is what it was given
/// and the outcomes live only as long as the bloc.
/// {@endtemplate}
class QuizBloc extends Bloc<QuizEvent, QuizState> {
  /// {@macro quiz_bloc}
  ///
  /// [random] shuffles the first pass and every retry; [now] stamps each
  /// outcome. Both are injectable so tests are deterministic.
  QuizBloc({
    required List<Recipe> recipes,
    Random? random,
    DateTime Function() now = DateTime.now,
  }) : this._(recipes, random ?? Random(), now);

  QuizBloc._(List<Recipe> recipes, this._random, this._now)
    : assert(recipes.isNotEmpty, 'A quiz needs at least one recipe.'),
      super(QuizState(deck: [...recipes]..shuffle(_random))) {
    on<QuizCardFlipped>(_onCardFlipped);
    on<QuizCardGraded>(_onCardGraded);
    on<QuizMissedRetried>(_onMissedRetried);
  }

  final Random _random;

  final DateTime Function() _now;

  void _onCardFlipped(QuizCardFlipped event, Emitter<QuizState> emit) {
    if (state.flipped || state.isFinished) return;
    emit(state.copyWith(flipped: true));
  }

  void _onCardGraded(QuizCardGraded event, Emitter<QuizState> emit) {
    final recipe = state.currentRecipe;
    if (recipe == null || !state.flipped) return;
    emit(
      state.copyWith(
        outcomes: [
          ...state.outcomes,
          CardOutcome(
            recipeId: recipe.id,
            remembered: event.remembered,
            answeredAt: _now(),
          ),
        ],
        index: state.index + 1,
        flipped: false,
      ),
    );
  }

  void _onMissedRetried(QuizMissedRetried event, Emitter<QuizState> emit) {
    final missed = state.missedRecipes;
    if (!state.isFinished || missed.isEmpty) return;
    emit(
      QuizState(
        deck: missed..shuffle(_random),
        outcomes: state.outcomes,
        passStart: state.outcomes.length,
      ),
    );
  }
}
