import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:starter_recipes/starter_recipes.dart';

/// {@template starter_recipes_loader}
/// Reads a [StarterSet] from the JSON files this package bundles.
/// {@endtemplate}
class StarterRecipesLoader {
  /// {@macro starter_recipes_loader}
  const StarterRecipesLoader(this._bundle);

  final AssetBundle _bundle;

  /// Loads the ingredients and recipes of [collection].
  Future<StarterSet> load(StarterCollection collection) async {
    final ingredients = await _list(collection, 'ingredients');
    final recipes = await _list(collection, 'recipes');
    return StarterSet(
      ingredients: ingredients.map(StarterIngredient.fromJson).toList(),
      recipes: recipes.map(StarterRecipe.fromJson).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _list(
    StarterCollection collection,
    String file,
  ) async {
    final json = await _bundle.loadString(
      'packages/starter_recipes/assets/${collection.name}/$file.json',
    );
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }
}
