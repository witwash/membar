import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:uuid/uuid.dart';

part 'library.g.dart';

/// {@template library}
/// A named collection of recipes that declares its own field schema.
///
/// The schema is [fields], and its list order is the order the fields are
/// rendered in — there is no separate ordering index.
/// {@endtemplate}
@JsonSerializable()
class Library extends Equatable {
  /// {@macro library}
  ///
  /// [id] is generated when omitted.
  Library({
    required String name,
    String? id,
    List<FieldDefinition> fields = const [],
  }) : assert(name.trim().isNotEmpty, 'A library name must not be blank.'),
       // Two fields sharing an id would share a value, a controller and a
       // form key, which collapses them into one broken control.
       assert(
         fields.map((field) => field.id).toSet().length == fields.length,
         'A library must not declare the same field twice.',
       ),
       id = id ?? const Uuid().v4(),
       name = name.trim(),
       fields = List.unmodifiable(fields);

  /// Converts a JSON [Map] into a [Library].
  factory Library.fromJson(Map<String, dynamic> json) =>
      _$LibraryFromJson(json);

  /// The unique identifier of this library. Recipes reference it by this id.
  final String id;

  /// What the library is called, as shown in the library switcher.
  final String name;

  /// The schema every recipe in this library carries values for, in render
  /// order.
  final List<FieldDefinition> fields;

  /// Converts this [Library] into a JSON [Map].
  Map<String, dynamic> toJson() => _$LibraryToJson(this);

  @override
  List<Object?> get props => [id, name, fields];
}
