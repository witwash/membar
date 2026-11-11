import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes/starter_recipes.dart';

/// {@template starter_recipes_loader}
/// Reads a [StarterSet] from the JSON files this package bundles.
/// {@endtemplate}
class StarterRecipesLoader {
  /// {@macro starter_recipes_loader}
  const StarterRecipesLoader(this._bundle);

  final AssetBundle _bundle;

  /// Loads the ingredients and recipes bundled for [template].
  Future<StarterSet> load(LibraryTemplate template) async {
    final ingredients = await _list(template, 'ingredients');
    final recipes = await _list(template, 'recipes');
    return StarterSet(
      ingredients: ingredients.map(StarterIngredient.fromJson).toList(),
      recipes: recipes.map(StarterRecipe.fromJson).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _list(
    LibraryTemplate template,
    String file,
  ) async {
    final json = await _bundle.loadString(
      'packages/starter_recipes/assets/${template.name}/$file.json',
    );
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }
}
