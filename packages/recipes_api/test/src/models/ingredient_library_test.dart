import 'dart:convert';

import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('IngredientLibrary', () {
    test('generates an id when none is given', () {
      final first = IngredientLibrary(name: 'Cocktails');
      final second = IngredientLibrary(name: 'Cocktails');

      expect(first.id, isNotEmpty);
      expect(first.id, isNot(equals(second.id)));
    });

    test('keeps the id it is given', () {
      expect(IngredientLibrary(id: 'il1', name: 'Cocktails').id, equals('il1'));
    });

    test('trims the name', () {
      expect(
        IngredientLibrary(name: '  Cocktails ').name,
        equals('Cocktails'),
      );
    });

    test('asserts on a blank name', () {
      expect(
        () => IngredientLibrary(name: '  '),
        throwsA(isA<AssertionError>()),
      );
    });

    test('supports value equality', () {
      expect(
        IngredientLibrary(id: 'il1', name: 'Cocktails'),
        equals(IngredientLibrary(id: 'il1', name: 'Cocktails')),
      );
      expect(
        IngredientLibrary(id: 'il1', name: 'Cocktails'),
        isNot(equals(IngredientLibrary(id: 'il1', name: 'Coffee'))),
      );
    });

    group('json', () {
      test('round-trips through a JSON string', () {
        final ingredientLibrary = IngredientLibrary(
          id: 'il1',
          name: 'Cocktails',
        );

        final decoded = IngredientLibrary.fromJson(
          json.decode(json.encode(ingredientLibrary.toJson()))
              as Map<String, dynamic>,
        );

        expect(decoded, equals(ingredientLibrary));
      });

      test('serializes every field', () {
        expect(
          IngredientLibrary(id: 'il1', name: 'Cocktails').toJson(),
          equals({'id': 'il1', 'name': 'Cocktails'}),
        );
      });
    });
  });
}
