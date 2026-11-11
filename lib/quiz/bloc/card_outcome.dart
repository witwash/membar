import 'package:equatable/equatable.dart';

/// {@template card_outcome}
/// How the user graded themselves on one flash card.
///
/// Nothing stores it yet. It is the record a later tracking feature persists,
/// which is why it carries [answeredAt].
/// {@endtemplate}
final class CardOutcome extends Equatable {
  /// {@macro card_outcome}
  const CardOutcome({
    required this.recipeId,
    required this.remembered,
    required this.answeredAt,
  });

  /// The id of the recipe the card showed.
  final String recipeId;

  /// Whether the user said they remembered the recipe.
  final bool remembered;

  /// When the user graded the card.
  final DateTime answeredAt;

  @override
  List<Object?> get props => [recipeId, remembered, answeredAt];
}
