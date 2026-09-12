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

    test('is unlinked by default', () {
      expect(Ingredient(name: 'Gin').catalogId, isNull);
    });

    test('normalizes a blank catalog id to null', () {
      expect(Ingredient(name: 'Gin', catalogId: '').catalogId, isNull);
      expect(Ingredient(name: 'Gin', catalogId: '  ').catalogId, isNull);
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

    test('tells a linked row from an unlinked one', () {
      expect(
        Ingredient(name: 'Gin', catalogId: 'i1'),
        isNot(equals(Ingredient(name: 'Gin'))),
      );
    });

    group('json', () {
      test('round-trips', () {
        final ingredient = Ingredient(name: 'Gin', quantity: '2', unit: 'oz');

        expect(Ingredient.fromJson(ingredient.toJson()), equals(ingredient));
      });

      test('round-trips a catalog link', () {
        final ingredient = Ingredient(name: 'Gin', catalogId: 'i1');

        expect(Ingredient.fromJson(ingredient.toJson()), equals(ingredient));
      });

      test('serializes the catalog link when there is one', () {
        expect(
          Ingredient(name: 'Gin', catalogId: 'i1').toJson(),
          equals({
            'name': 'Gin',
            'quantity': '',
            'unit': '',
            'catalogId': 'i1',
          }),
        );
      });

      test('decodes a row written before the catalog as unlinked', () {
        final ingredient = Ingredient.fromJson(const {
          'name': 'Gin',
          'quantity': '2',
          'unit': 'oz',
        });

        expect(ingredient.catalogId, isNull);
      });

      test('serializes an unlinked row without a catalog link', () {
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
