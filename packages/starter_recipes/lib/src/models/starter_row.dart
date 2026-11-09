import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes/starter_recipes.dart';

part 'starter_row.g.dart';

/// {@template starter_row}
/// One line of a starter recipe's ingredient list.
///
/// A row takes exactly one of two forms: a volume carrying both [ml] and
/// [oz], or a [quantity] in a [unit] that reads the same in every
/// [MeasureSystem], such as `2 dash`.
/// {@endtemplate}
@JsonSerializable(createToJson: false)
class StarterRow extends Equatable {
  /// {@macro starter_row}
  const StarterRow({
    required this.ingredient,
    this.ml,
    this.oz,
    this.quantity,
    this.unit,
  }) : assert(
         (ml != null && oz != null && quantity == null && unit == null) ||
             (ml == null && oz == null && quantity != null && unit != null),
         'A row is either a volume in ml and oz, or a quantity and unit.',
       );

  /// Converts a JSON [Map] into a [StarterRow].
  factory StarterRow.fromJson(Map<String, dynamic> json) =>
      _$StarterRowFromJson(json);

  /// The [StarterIngredient.key] of the ingredient this row uses.
  final String ingredient;

  /// The volume in millilitres, such as `22.5`.
  final String? ml;

  /// The same volume in bartender-standard ounces (30 ml to 1 oz), such as
  /// `0.75`.
  final String? oz;

  /// How much of [unit] the recipe calls for, when the row is not a volume.
  final String? quantity;

  /// The unit [quantity] is counted in.
  final StandardUnit? unit;

  /// The quantity and unit this row is written with in [system].
  (String, StandardUnit) measured(MeasureSystem system) => switch (system) {
    _ when quantity != null => (quantity!, unit!),
    MeasureSystem.metric => (ml!, StandardUnit.ml),
    MeasureSystem.imperial => (oz!, StandardUnit.oz),
  };

  @override
  List<Object?> get props => [ingredient, ml, oz, quantity, unit];
}
