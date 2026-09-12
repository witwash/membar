import 'package:equatable/equatable.dart';
import 'package:recipes_api/recipes_api.dart';

/// {@template recipes_snapshot}
/// Everything the app needs to render, as one mutually consistent value.
///
/// The collections travel together because a recipe list is meaningless
/// without the library that describes it: emitting them separately would let a
/// listener observe recipes against a schema that no longer matches.
///
/// This value is never persisted — each field is stored under its own key — so
/// it carries no JSON serialization.
/// {@endtemplate}
class RecipesSnapshot extends Equatable {
  /// {@macro recipes_snapshot}
  const RecipesSnapshot({
    required this.libraries,
    required this.recipes,
    required this.ingredients,
    required this.activeLibraryId,
    required this.ingredientsImported,
  });

  /// Every library that exists, in creation order.
  final List<Library> libraries;

  /// Every recipe that exists, across all libraries.
  final List<Recipe> recipes;

  /// Every catalog entry that exists, across all libraries.
  final List<CatalogIngredient> ingredients;

  /// The id of the library currently being browsed.
  ///
  /// Never blank: there is always at least one library, so there is always an
  /// active one.
  final String activeLibraryId;

  /// Whether the one-time import of ingredient names from saved recipes has
  /// run.
  final bool ingredientsImported;

  @override
  List<Object?> get props => [
    libraries,
    recipes,
    ingredients,
    activeLibraryId,
    ingredientsImported,
  ];
}
