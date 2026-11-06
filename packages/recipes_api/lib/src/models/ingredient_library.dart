import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:uuid/uuid.dart';

part 'ingredient_library.g.dart';

/// {@template ingredient_library}
/// A named set of [CatalogIngredient]s that one or more [Library]s draw their
/// recipe rows from.
///
/// Ingredients in different ingredient libraries are unrelated even when they
/// share a name.
/// {@endtemplate}
@JsonSerializable()
class IngredientLibrary extends Equatable {
  /// {@macro ingredient_library}
  ///
  /// [id] is generated when omitted.
  IngredientLibrary({required String name, String? id})
    : assert(
        name.trim().isNotEmpty,
        'An ingredient library name must not be blank.',
      ),
      id = id ?? const Uuid().v4(),
      name = name.trim();

  /// Converts a JSON [Map] into an [IngredientLibrary].
  factory IngredientLibrary.fromJson(Map<String, dynamic> json) =>
      _$IngredientLibraryFromJson(json);

  /// The unique identifier of this ingredient library. Libraries and catalog
  /// entries reference it by this id.
  final String id;

  /// What the ingredient library is called, such as `Cocktails`. Unique across
  /// ingredient libraries without regard to case.
  final String name;

  /// Converts this [IngredientLibrary] into a JSON [Map].
  Map<String, dynamic> toJson() => _$IngredientLibraryToJson(this);

  @override
  List<Object?> get props => [id, name];
}
