import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:uuid/uuid.dart';

part 'field_definition.g.dart';

/// {@template field_definition}
/// A single field declared by a [Library]'s schema.
///
/// Recipe values are keyed off [id], never off [label], so relabelling a field
/// never orphans the values already stored against it.
/// {@endtemplate}
@JsonSerializable()
class FieldDefinition extends Equatable {
  /// {@macro field_definition}
  ///
  /// [id] is generated when omitted. [options] must be a non-empty,
  /// duplicate-free list for a [FieldType.select] field and null for every
  /// other type; [unit] is only meaningful for [FieldType.number].
  FieldDefinition({
    required String label,
    required this.type,
    String? id,
    this.required = false,
    List<String>? options,
    this.unit,
  }) : assert(label.trim().isNotEmpty, 'A field label must not be blank.'),
       assert(
         type != FieldType.select || (options != null && options.isNotEmpty),
         'A select field must declare at least one option.',
       ),
       assert(
         type != FieldType.select ||
             options == null ||
             options.toSet().length == options.length,
         'A select field must not declare duplicate options.',
       ),
       assert(
         type == FieldType.select || options == null,
         'Only a select field may declare options.',
       ),
       assert(
         type == FieldType.number || unit == null,
         'Only a number field may declare a unit.',
       ),
       id = id ?? const Uuid().v4(),
       label = label.trim(),
       options = options == null ? null : List.unmodifiable(options);

  /// Converts a JSON [Map] into a [FieldDefinition].
  factory FieldDefinition.fromJson(Map<String, dynamic> json) =>
      _$FieldDefinitionFromJson(json);

  /// The unique identifier of this field. Recipe values are keyed off it.
  final String id;

  /// The human-readable name shown above the field's control.
  final String label;

  /// The kind of control this field renders, and the kind of value it holds.
  @JsonKey(unknownEnumValue: FieldType.text)
  final FieldType type;

  /// Whether a recipe must carry a value for this field in order to be saved.
  final bool required;

  /// The choices offered by a [FieldType.select] field; null for every other
  /// type.
  final List<String>? options;

  /// The unit rendered alongside a [FieldType.number] field's value, such as
  /// `g` or `°C`; null for every other type.
  final String? unit;

  /// Converts this [FieldDefinition] into a JSON [Map].
  Map<String, dynamic> toJson() => _$FieldDefinitionToJson(this);

  @override
  List<Object?> get props => [id, label, type, required, options, unit];
}
