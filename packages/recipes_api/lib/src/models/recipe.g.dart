// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'recipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Recipe _$RecipeFromJson(Map<String, dynamic> json) => Recipe(
  libraryId: json['libraryId'] as String,
  name: json['name'] as String,
  id: json['id'] as String?,
  ingredients:
      (json['ingredients'] as List<dynamic>?)
          ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  steps:
      (json['steps'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  notes: json['notes'] as String? ?? '',
  fieldValues: json['fieldValues'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$RecipeToJson(Recipe instance) => <String, dynamic>{
  'id': instance.id,
  'libraryId': instance.libraryId,
  'name': instance.name,
  'ingredients': instance.ingredients.map((e) => e.toJson()).toList(),
  'steps': instance.steps,
  'tags': instance.tags,
  'notes': instance.notes,
  'fieldValues': instance.fieldValues,
};
