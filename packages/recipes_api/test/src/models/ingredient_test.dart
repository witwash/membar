import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('Ingredient', () {
    test('trims name, quantity and unit', () {
      final ingredient = Ingredient(
        name: '  Gin  ',
        quantity: ' 2 ',
        unit: ' oz ',
      );

      expect(ingredient.name, equals('Gin'));
      expect(ingredient.quantity, equals('2'));
      expect(ingredient.unit, equals('oz'));
    });

    test('defaults quantity and unit to empty', () {
      final ingredient = Ingredient(name: 'Ice');

      expect(ingredient.quantity, isEmpty);
      expect(ingredient.unit, isEmpty);
    });

    test('asserts on a blank name', () {
      expect(() => Ingredient(name: '   '), throwsA(isA<AssertionError>()));
    });

    test('supports value equality', () {
      expect(
        Ingredient(name: 'Gin', quantity: '2', unit: 'oz'),
        equals(Ingredient(name: 'Gin', quantity: '2', unit: 'oz')),
      );
      expect(
        Ingredient(name: 'Gin'),
        isNot(equals(Ingredient(name: 'Vodka'))),
      );
    });

    group('json', () {
      test('round-trips', () {
        final ingredient = Ingredient(name: 'Gin', quantity: '2', unit: 'oz');

        expect(Ingredient.fromJson(ingredient.toJson()), equals(ingredient));
      });

      test('serializes every field', () {
        expect(
          Ingredient(name: 'Gin', quantity: '2', unit: 'oz').toJson(),
          equals({'name': 'Gin', 'quantity': '2', 'unit': 'oz'}),
        );
      });

      test('decodes missing quantity and unit as empty', () {
        final ingredient = Ingredient.fromJson(const {'name': 'Ice'});

        expect(ingredient.quantity, isEmpty);
        expect(ingredient.unit, isEmpty);
      });
    });
  });
}
