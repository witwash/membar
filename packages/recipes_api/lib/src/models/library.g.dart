// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file

part of 'library.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Library _$LibraryFromJson(Map<String, dynamic> json) => Library(
  name: json['name'] as String,
  id: json['id'] as String?,
  fields:
      (json['fields'] as List<dynamic>?)
          ?.map((e) => FieldDefinition.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$LibraryToJson(Library instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'fields': instance.fields.map((e) => e.toJson()).toList(),
};
