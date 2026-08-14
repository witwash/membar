// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'field_definition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FieldDefinition _$FieldDefinitionFromJson(Map<String, dynamic> json) =>
    FieldDefinition(
      label: json['label'] as String,
      type: $enumDecode(
        _$FieldTypeEnumMap,
        json['type'],
        unknownValue: FieldType.text,
      ),
      id: json['id'] as String?,
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      unit: json['unit'] as String?,
    );

Map<String, dynamic> _$FieldDefinitionToJson(FieldDefinition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'type': _$FieldTypeEnumMap[instance.type]!,
      'required': instance.required,
      'options': instance.options,
      'unit': instance.unit,
    };

const _$FieldTypeEnumMap = {
  FieldType.text: 'text',
  FieldType.select: 'select',
  FieldType.number: 'number',
  FieldType.longText: 'longText',
};
