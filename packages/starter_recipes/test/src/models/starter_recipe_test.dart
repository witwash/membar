import 'package:flutter_test/flutter_test.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes/starter_recipes.dart';

void main() {
  group(StarterRecipe, () {
    test('parses every property', () {
      expect(
        StarterRecipe.fromJson(const {
          'key': 'daiquiri',
          'name': 'Daiquiri',
          'tags': ['sour', 'rum'],
          'steps': ['Shake with ice.', 'Strain into a chilled coupe.'],
          'notes': 'Classic.',
          'fields': {'Glassware': 'Coupe', 'Dose': 18},
          'rows': [
            {'ingredient': 'white_rum', 'ml': '60', 'oz': '2'},
          ],
        }),
        equals(
          const StarterRecipe(
            key: 'daiquiri',
            name: 'Daiquiri',
            tags: ['sour', 'rum'],
            steps: ['Shake with ice.', 'Strain into a chilled coupe.'],
            notes: 'Classic.',
            fields: {'Glassware': 'Coupe', 'Dose': 18},
            rows: [StarterRow(ingredient: 'white_rum', ml: '60', oz: '2')],
          ),
        ),
      );
    });

    test('defaults every optional property to empty', () {
      expect(
        StarterRecipe.fromJson(const {'key': 'k', 'name': 'N'}),
        equals(const StarterRecipe(key: 'k', name: 'N')),
      );
    });
  });

  group(StarterIngredient, () {
    test('parses its default unit by name', () {
      expect(
        StarterIngredient.fromJson(const {
          'key': 'salt',
          'name': 'Salt',
          'defaultUnit': 'pinch',
        }),
        equals(
          const StarterIngredient(
            key: 'salt',
            name: 'Salt',
            defaultUnit: StandardUnit.pinch,
          ),
        ),
      );
    });
  });
}
