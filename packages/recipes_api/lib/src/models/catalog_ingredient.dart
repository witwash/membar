import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:uuid/uuid.dart';

part 'catalog_ingredient.g.dart';

/// {@template catalog_ingredient}
/// An ingredient the user has entered once and can reuse across recipes.
///
/// It belongs to exactly one [IngredientLibrary]. Recipe rows reference it
/// through [Ingredient.catalogId], so renaming an entry renames it everywhere
/// it is used.
/// {@endtemplate}
@JsonSerializable()
class CatalogIngredient extends Equatable {
  /// {@macro catalog_ingredient}
  ///
  /// [id] is generated when omitted.
  CatalogIngredient({
    required String name,
    required this.ingredientLibraryId,
    String? id,
    this.defaultUnit,
  }) : assert(name.trim().isNotEmpty, 'An ingredient name must not be blank.'),
       assert(
         ingredientLibraryId.trim().isNotEmpty,
         'An ingredient must belong to an ingredient library.',
       ),
       id = id ?? const Uuid().v4(),
       name = name.trim();

  /// Converts a JSON [Map] into a [CatalogIngredient].
  factory CatalogIngredient.fromJson(Map<String, dynamic> json) =>
      _$CatalogIngredientFromJson(json);

  /// The unique identifier of this entry. Recipe rows reference it by this id.
  final String id;

  /// What the ingredient is called, such as `Gin`. Unique within its
  /// ingredient library without regard to case.
  final String name;

  /// The unit a recipe row is prefilled with when this entry is picked, or
  /// null for an ingredient measured in no unit, such as ice.
  @JsonKey(fromJson: _unitFromJson, toJson: _unitToJson)
  final Unit? defaultUnit;

  /// The id of the [IngredientLibrary] this entry belongs to.
  final String ingredientLibraryId;

  /// Converts this [CatalogIngredient] into a JSON [Map].
  Map<String, dynamic> toJson() => _$CatalogIngredientToJson(this);

  @override
  List<Object?> get props => [id, name, defaultUnit, ingredientLibraryId];
}

// A converter is not invoked for a null value, so the nullable field bridges
// to Unit's hand-written JSON through functions that handle null themselves.
Unit? _unitFromJson(Map<String, dynamic>? json) =>
    json == null ? null : Unit.fromJson(json);

Map<String, dynamic>? _unitToJson(Unit? unit) => unit?.toJson();
