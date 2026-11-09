// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'starter_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarterRow _$StarterRowFromJson(Map<String, dynamic> json) => StarterRow(
  ingredient: json['ingredient'] as String,
  ml: json['ml'] as String?,
  oz: json['oz'] as String?,
  quantity: json['quantity'] as String?,
  unit: $enumDecodeNullable(_$StandardUnitEnumMap, json['unit']),
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
