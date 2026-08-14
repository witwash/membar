import 'package:json_annotation/json_annotation.dart';

/// {@template field_type}
/// The kind of control a schema field renders, and the kind of value it holds.
///
/// A field's type is fixed once the field exists: changing it would strip the
/// meaning from every value already stored against the field.
/// {@endtemplate}
@JsonEnum()
enum FieldType {
  /// A single line of free text. Stored as a [String].
  text,

  /// One choice out of a fixed option list. Stored as the raw option [String].
  select,

  /// A numeric value, optionally carrying a unit. Stored as a [num].
  number,

  /// Multiple lines of free text. Stored as a [String].
  longText,
}
