// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'ingredient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ingredient _$IngredientFromJson(Map<String, dynamic> json) => Ingredient(
  name: json['name'] as String,
  quantity: json['quantity'] as String? ?? '',
  unit: json['unit'] as String? ?? '',
  catalogId: json['catalogId'] as String?,
);

Map<String, dynamic> _$IngredientToJson(Ingredient instance) =>
    <String, dynamic>{
      'name': instance.name,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'catalogId': ?instance.catalogId,
    };
