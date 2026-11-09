import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes/starter_recipes.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this._files);

  final Map<String, Object> _files;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(utf8.encode(jsonEncode(_files[key])));
  }
}

void main() {
  group(StarterRecipesLoader, () {
    test('reads both files of a collection from the package', () async {
      final loader = StarterRecipesLoader(
        _MapBundle({
          'packages/starter_recipes/assets/coffee/ingredients.json': [
            {
              'key': 'coffee_beans',
              'name': 'Coffee beans',
              'defaultUnit': 'gram',
            },
          ],
          'packages/starter_recipes/assets/coffee/recipes.json': [
            {
              'key': 'espresso',
              'name': 'Espresso',
              'rows': [
                {
                  'ingredient': 'coffee_beans',
                  'quantity': '18',
                  'unit': 'gram',
                },
              ],
            },
          ],
        }),
      );

      expect(
        await loader.load(StarterCollection.coffee),
        equals(
          const StarterSet(
            ingredients: [
              StarterIngredient(
                key: 'coffee_beans',
                name: 'Coffee beans',
                defaultUnit: StandardUnit.gram,
              ),
            ],
            recipes: [
              StarterRecipe(
                key: 'espresso',
                name: 'Espresso',
                rows: [
                  StarterRow(
                    ingredient: 'coffee_beans',
                    quantity: '18',
                    unit: StandardUnit.gram,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  });
}
