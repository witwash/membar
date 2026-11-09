// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'starter_recipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarterRecipe _$StarterRecipeFromJson(Map<String, dynamic> json) =>
    StarterRecipe(
      key: json['key'] as String,
      name: json['name'] as String,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      steps:
          (json['steps'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      notes: json['notes'] as String? ?? '',
      fields:
          (json['fields'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as Object),
          ) ??
          const {},
      rows:
          (json['rows'] as List<dynamic>?)
              ?.map((e) => StarterRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
