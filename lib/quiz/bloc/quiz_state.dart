part of 'quiz_bloc.dart';

final class QuizState extends Equatable {
  const QuizState({
    required this.deck,
    this.index = 0,
    this.flipped = false,
    this.outcomes = const [],
    this.passStart = 0,
  });

  /// The recipes of the running pass, in the order they are shown.
  final List<Recipe> deck;

  /// The position in [deck] of the card on screen. Equal to the deck's length
  /// once the pass is finished.
  final int index;

  /// Whether the card on screen shows its back.
  final bool flipped;

  /// Every grade of the session, across all passes, in answer order.
  final List<CardOutcome> outcomes;

  /// Where the running pass begins in [outcomes].
  final int passStart;

  /// Whether every card of the pass has been graded.
  bool get isFinished => index >= deck.length;

  /// The recipe on screen, or null once the pass is finished.
  Recipe? get currentRecipe => isFinished ? null : deck[index];

  /// How many cards of the running pass were remembered.
  int get rememberedCount =>
      _passOutcomes.where((outcome) => outcome.remembered).length;

  /// The recipes the running pass missed, in answer order.
  List<Recipe> get missedRecipes {
    // The pass grades its deck front to back, so its nth outcome is deck[n].
    final passOutcomes = _passOutcomes;
    return [
      for (var i = 0; i < passOutcomes.length; i++)
        if (!passOutcomes[i].remembered) deck[i],
    ];
  }

  /// Whether a card of the running pass has been graded.
  bool get hasGradedInPass => outcomes.length > passStart;

  List<CardOutcome> get _passOutcomes => outcomes.sublist(passStart);

  QuizState copyWith({
    int? index,
    bool? flipped,
    List<CardOutcome>? outcomes,
  }) {
    return QuizState(
      deck: deck,
      index: index ?? this.index,
      flipped: flipped ?? this.flipped,
      outcomes: outcomes ?? this.outcomes,
      passStart: passStart,
    );
  }

  @override
  List<Object?> get props => [deck, index, flipped, outcomes, passStart];
}
