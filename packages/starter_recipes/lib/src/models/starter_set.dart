import 'package:equatable/equatable.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes/starter_recipes.dart';

/// {@template starter_set}
/// The recipes bundled for one [LibraryTemplate] and the ingredient list
/// their rows reference.
/// {@endtemplate}
class StarterSet extends Equatable {
  /// {@macro starter_set}
  const StarterSet({required this.ingredients, required this.recipes});

  /// The canonical ingredient list. Every entry is used by some recipe.
  final List<StarterIngredient> ingredients;

  /// The recipes, in catalog order.
  final List<StarterRecipe> recipes;

  @override
  List<Object?> get props => [ingredients, recipes];
}
