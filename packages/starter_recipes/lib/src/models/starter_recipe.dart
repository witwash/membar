import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:starter_recipes/starter_recipes.dart';

part 'starter_recipe.g.dart';

/// {@template starter_recipe}
/// A bundled recipe a user can import.
///
/// [fields] is keyed by field label, because field ids differ per install.
/// A select or text value is a `String`, and a number value is a `num`.
/// {@endtemplate}
@JsonSerializable(createToJson: false)
class StarterRecipe extends Equatable {
  /// {@macro starter_recipe}
  const StarterRecipe({
    required this.key,
    required this.name,
    this.tags = const [],
    this.steps = const [],
    this.notes = '',
    this.fields = const {},
    this.rows = const [],
  });

  /// Converts a JSON [Map] into a [StarterRecipe].
  factory StarterRecipe.fromJson(Map<String, dynamic> json) =>
      _$StarterRecipeFromJson(json);

  /// The id of this recipe within its set, stable across releases.
  final String key;

  /// What the recipe is called, such as `Negroni`.
  final String name;

  /// Lowercase tags, such as `stirred` and `gin`.
  final List<String> tags;

  /// The method, one step per entry.
  final List<String> steps;

  /// Free-form notes. May be empty.
  final String notes;

  /// Field values keyed by field label.
  final Map<String, Object> fields;

  /// The ingredient list.
  final List<StarterRow> rows;

  @override
  List<Object?> get props => [key, name, tags, steps, notes, fields, rows];
}
