// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'starter_ingredient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarterIngredient _$StarterIngredientFromJson(Map<String, dynamic> json) =>
    StarterIngredient(
      key: json['key'] as String,
      name: json['name'] as String,
      defaultUnit: $enumDecode(_$StandardUnitEnumMap, json['defaultUnit']),
    );

const _$StandardUnitEnumMap = {
  StandardUnit.ml: 'ml',
  StandardUnit.cl: 'cl',
  StandardUnit.oz: 'oz',
  StandardUnit.dash: 'dash',
  StandardUnit.drop: 'drop',
  StandardUnit.barspoon: 'barspoon',
  StandardUnit.teaspoon: 'teaspoon',
  StandardUnit.tablespoon: 'tablespoon',
  StandardUnit.gram: 'gram',
  StandardUnit.piece: 'piece',
  StandardUnit.pinch: 'pinch',
};
