import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';

part 'ingredient.g.dart';

/// {@template ingredient}
/// One line of a recipe's ingredient list.
///
/// Only [name] is required: [quantity] and [unit] are free text, because
/// "1 dash" and "to taste" are as valid as "2 oz".
/// {@endtemplate}
@JsonSerializable()
class Ingredient extends Equatable {
  /// {@macro ingredient}
  ///
  /// A blank [catalogId] is stored as null, so an empty id can never pass for
  /// a link.
  Ingredient({
    required String name,
    String quantity = '',
    String unit = '',
    String? catalogId,
  }) : assert(name.trim().isNotEmpty, 'An ingredient name must not be blank.'),
       name = name.trim(),
       quantity = quantity.trim(),
       unit = unit.trim(),
       catalogId = catalogId == null || catalogId.trim().isEmpty
           ? null
           : catalogId;

  /// Converts a JSON [Map] into an [Ingredient].
  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);

  /// What the ingredient is, such as `Gin`.
  final String name;

  /// How much of it the recipe calls for, such as `2` or `1 dash`. May be
  /// empty.
  final String quantity;

  /// The unit [quantity] is expressed in, such as `oz` or `ml`. May be empty.
  final String unit;

  /// The id of the [CatalogIngredient] this row refers to, or null for a row
  /// typed as free text.
  ///
  /// Omitted from JSON when null, so an unlinked row is stored exactly as it
  /// was before the catalog existed.
  @JsonKey(includeIfNull: false)
  final String? catalogId;

  /// Converts this [Ingredient] into a JSON [Map].
  Map<String, dynamic> toJson() => _$IngredientToJson(this);

  @override
  List<Object?> get props => [name, quantity, unit, catalogId];
}
