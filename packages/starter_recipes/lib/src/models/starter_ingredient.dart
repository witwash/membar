import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';

part 'starter_ingredient.g.dart';

/// {@template starter_ingredient}
/// One entry of a starter set's canonical ingredient list.
///
/// Rows reference it by [key]. Nothing imports it on its own: it reaches an
/// ingredient library only through a recipe that uses it.
/// {@endtemplate}
@JsonSerializable(createToJson: false)
class StarterIngredient extends Equatable {
  /// {@macro starter_ingredient}
  const StarterIngredient({
    required this.key,
    required this.name,
    required this.defaultUnit,
  });

  /// Converts a JSON [Map] into a [StarterIngredient].
  factory StarterIngredient.fromJson(Map<String, dynamic> json) =>
      _$StarterIngredientFromJson(json);

  /// The id rows use to reference this ingredient, stable across releases.
  final String key;

  /// The canonical name, such as `Lime juice`.
  final String name;

  /// The unit a newly created ingredient gets.
  final StandardUnit defaultUnit;

  @override
  List<Object?> get props => [key, name, defaultUnit];
}
