// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'catalog_ingredient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CatalogIngredient _$CatalogIngredientFromJson(Map<String, dynamic> json) =>
    CatalogIngredient(
      name: json['name'] as String,
      ingredientLibraryId: json['ingredientLibraryId'] as String,
      id: json['id'] as String?,
      defaultUnit: _unitFromJson(json['defaultUnit'] as Map<String, dynamic>?),
    );

Map<String, dynamic> _$CatalogIngredientToJson(CatalogIngredient instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'defaultUnit': _unitToJson(instance.defaultUnit),
      'ingredientLibraryId': instance.ingredientLibraryId,
    };
