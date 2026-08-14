import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:uuid/uuid.dart';

part 'recipe.g.dart';

/// {@template recipe}
/// A single recipe, belonging to exactly one [Library].
///
/// Every recipe carries the same core fields — [name], [ingredients], [steps],
/// [tags] and [notes] — plus [fieldValues], which holds one entry per field
/// declared by its library's schema.
/// {@endtemplate}
@JsonSerializable()
class Recipe extends Equatable {
  /// {@macro recipe}
  ///
  /// [id] is generated when omitted. [fieldValues] entries whose value is null,
  /// or an empty or whitespace-only [String], are dropped, so that "absent" has
  /// a single representation everywhere the map is read.
  Recipe({
    required this.libraryId,
    required String name,
    String? id,
    List<Ingredient> ingredients = const [],
    List<String> steps = const [],
    List<String> tags = const [],
    this.notes = '',
    Map<String, Object?> fieldValues = const {},
  }) : assert(name.trim().isNotEmpty, 'A recipe name must not be blank.'),
       id = id ?? const Uuid().v4(),
       name = name.trim(),
       ingredients = List.unmodifiable(ingredients),
       steps = List.unmodifiable(steps),
       tags = List.unmodifiable(foldCaseInsensitive(tags)),
       fieldValues = Map.unmodifiable(_normalizeFieldValues(fieldValues));

  /// Converts a JSON [Map] into a [Recipe].
  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);

  /// The unique identifier of this recipe.
  final String id;

  /// The id of the [Library] this recipe belongs to.
  final String libraryId;

  /// What the recipe is called.
  final String name;

  /// What the recipe is made of, in the order it is listed.
  final List<Ingredient> ingredients;

  /// How the recipe is made, in the order the steps are performed.
  final List<String> steps;

  /// Free-form labels the recipe can be filtered by. Trimmed, and deduplicated
  /// without regard to case.
  final List<String> tags;

  /// Anything else worth recording. May be empty.
  final String notes;

  /// The recipe's values for its library's schema fields, keyed by
  /// [FieldDefinition.id].
  ///
  /// A [FieldType.number] field stores a [num]; every other type stores a
  /// [String]. Read through [textValue] and [numberValue] rather than
  /// subscripting this map directly.
  final Map<String, Object?> fieldValues;

  /// The [String] value stored for [fieldId], or null when the field has no
  /// value or holds something other than a non-blank [String].
  String? textValue(String fieldId) {
    final value = fieldValues[fieldId];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The [num] value stored for [fieldId], or null when the field has no value
  /// or holds something that is not a number.
  ///
  /// A [String] value — which only a hand-edited storage blob can produce — is
  /// parsed rather than rejected.
  num? numberValue(String fieldId) {
    final value = fieldValues[fieldId];
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }

  /// Converts this [Recipe] into a JSON [Map].
  Map<String, dynamic> toJson() => _$RecipeToJson(this);

  @override
  List<Object?> get props => [
    id,
    libraryId,
    name,
    ingredients,
    steps,
    tags,
    notes,
    fieldValues,
  ];

  static Map<String, Object?> _normalizeFieldValues(
    Map<String, Object?> fieldValues,
  ) {
    final normalized = <String, Object?>{};
    for (final entry in fieldValues.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      normalized[entry.key] = value;
    }
    return normalized;
  }
}
