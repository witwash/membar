import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';

part 'ingredient.g.dart';

/// {@template ingredient}
/// One line of a recipe's ingredient list.
///
/// The row names no ingredient of its own: it renders the current name of the
/// [CatalogIngredient] carrying [catalogId], so a rename reaches every row.
/// [quantity] and [unit] are free text, because "1 dash" and "to taste" are
/// as valid as "2 oz".
/// {@endtemplate}
@JsonSerializable()
class Ingredient extends Equatable {
  /// {@macro ingredient}
  Ingredient({
    required this.catalogId,
    String quantity = '',
    String unit = '',
  }) : assert(
         catalogId.trim().isNotEmpty,
         'An ingredient row must reference a catalog entry.',
       ),
       quantity = quantity.trim(),
       unit = unit.trim();

  /// Converts a JSON [Map] into an [Ingredient].
  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);

  /// The id of the [CatalogIngredient] this row refers to.
  final String catalogId;

  /// How much of it the recipe calls for, such as `2` or `1 dash`. May be
  /// empty.
  final String quantity;

  /// The unit [quantity] is expressed in, such as `oz` or `ml`. May be empty.
  final String unit;

  /// Converts this [Ingredient] into a JSON [Map].
  Map<String, dynamic> toJson() => _$IngredientToJson(this);

  @override
  List<Object?> get props => [catalogId, quantity, unit];
}
