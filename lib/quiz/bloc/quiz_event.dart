part of 'quiz_bloc.dart';

sealed class QuizEvent extends Equatable {
  const QuizEvent();

  @override
  List<Object?> get props => [];
}

/// Turns the current card over to its ingredients and steps.
final class QuizCardFlipped extends QuizEvent {
  const QuizCardFlipped();
}

/// Grades the flipped card and moves to the next one.
final class QuizCardGraded extends QuizEvent {
  const QuizCardGraded({required this.remembered});

  final bool remembered;

  @override
  List<Object?> get props => [remembered];
}

/// Starts a new pass over the recipes missed in the finished one.
final class QuizMissedRetried extends QuizEvent {
  const QuizMissedRetried();
}
