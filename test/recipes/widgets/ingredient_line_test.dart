import 'package:flutter_test/flutter_test.dart';
import 'package:membar/recipes/recipes.dart';
import 'package:recipes_repository/recipes_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ingredientLine', () {
    final state = RecipesState(ingredients: [ginIngredient]);

    test('reads the quantity, the unit and the entry name', () {
      expect(
        ingredientLine(
          state,
          Ingredient(catalogId: ginIngredient.id, quantity: '30', unit: 'ml'),
        ),
        '30 ml Gin',
      );
    });

    test('reads only the entry name when there is no quantity or unit', () {
      expect(
        ingredientLine(state, Ingredient(catalogId: ginIngredient.id)),
        'Gin',
      );
    });

    test('is null for a row whose catalog entry is gone', () {
      expect(
        ingredientLine(state, Ingredient(catalogId: 'ingredient-deleted')),
        isNull,
      );
    });
  });
}
