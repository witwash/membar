import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('Ingredient', () {
    test('trims quantity and unit', () {
      final ingredient = Ingredient(
        catalogId: 'i1',
        quantity: ' 2 ',
        unit: ' oz ',
      );

      expect(ingredient.quantity, equals('2'));
      expect(ingredient.unit, equals('oz'));
    });

    test('defaults quantity and unit to empty', () {
      final ingredient = Ingredient(catalogId: 'i1');

      expect(ingredient.quantity, isEmpty);
      expect(ingredient.unit, isEmpty);
    });

    test('asserts on a blank catalog id', () {
      expect(() => Ingredient(catalogId: '  '), throwsA(isA<AssertionError>()));
    });

    test('supports value equality', () {
      expect(
        Ingredient(catalogId: 'i1', quantity: '2', unit: 'oz'),
        equals(Ingredient(catalogId: 'i1', quantity: '2', unit: 'oz')),
      );
      expect(
        Ingredient(catalogId: 'i1'),
        isNot(equals(Ingredient(catalogId: 'i2'))),
      );
    });

    group('json', () {
      test('round-trips', () {
        final ingredient = Ingredient(
          catalogId: 'i1',
          quantity: '2',
          unit: 'oz',
        );

        expect(Ingredient.fromJson(ingredient.toJson()), equals(ingredient));
      });

      test('serializes every field', () {
        expect(
          Ingredient(catalogId: 'i1', quantity: '2', unit: 'oz').toJson(),
          equals({'catalogId': 'i1', 'quantity': '2', 'unit': 'oz'}),
        );
      });

      test('decodes missing quantity and unit as empty', () {
        final ingredient = Ingredient.fromJson(const {'catalogId': 'i1'});

        expect(ingredient.quantity, isEmpty);
        expect(ingredient.unit, isEmpty);
      });
    });
  });
}
