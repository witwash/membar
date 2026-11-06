// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'ingredient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ingredient _$IngredientFromJson(Map<String, dynamic> json) => Ingredient(
  catalogId: json['catalogId'] as String,
  quantity: json['quantity'] as String? ?? '',
  unit: json['unit'] as String? ?? '',
);

Map<String, dynamic> _$IngredientToJson(Ingredient instance) =>
    <String, dynamic>{
      'catalogId': instance.catalogId,
      'quantity': instance.quantity,
      'unit': instance.unit,
    };
