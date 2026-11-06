import 'dart:convert';

import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('CatalogIngredient', () {
    test('generates an id when none is given', () {
      final first = CatalogIngredient(name: 'Gin', ingredientLibraryId: 'il1');
      final second = CatalogIngredient(name: 'Gin', ingredientLibraryId: 'il1');

      expect(first.id, isNotEmpty);
      expect(first.id, isNot(equals(second.id)));
    });

    test('keeps the id it is given', () {
      expect(
        CatalogIngredient(id: 'i1', name: 'Gin', ingredientLibraryId: 'il1').id,
        equals('i1'),
      );
    });

    test('trims the name', () {
      expect(
        CatalogIngredient(name: '  Gin ', ingredientLibraryId: 'il1').name,
        equals('Gin'),
      );
    });

    test('asserts on a blank name', () {
      expect(
        () => CatalogIngredient(name: '  ', ingredientLibraryId: 'il1'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on a blank ingredient library id', () {
      expect(
        () => CatalogIngredient(name: 'Gin', ingredientLibraryId: ' '),
        throwsA(isA<AssertionError>()),
      );
    });

    test('defaults to no unit', () {
      expect(
        CatalogIngredient(name: 'Ice', ingredientLibraryId: 'il1').defaultUnit,
        isNull,
      );
    });

    test('supports value equality', () {
      CatalogIngredient build({
        Unit? defaultUnit,
        String ingredientLibraryId = 'il1',
      }) => CatalogIngredient(
        id: 'i1',
        name: 'Gin',
        ingredientLibraryId: ingredientLibraryId,
        defaultUnit: defaultUnit,
      );

      expect(build(), equals(build()));
      expect(
        build(defaultUnit: const KnownUnit(StandardUnit.ml)),
        isNot(equals(build(defaultUnit: CustomUnit('ml')))),
      );
      expect(build(), isNot(equals(build(ingredientLibraryId: 'il2'))));
    });

    group('json', () {
      CatalogIngredient roundTrip(CatalogIngredient ingredient) =>
          CatalogIngredient.fromJson(
            json.decode(json.encode(ingredient.toJson()))
                as Map<String, dynamic>,
          );

      test('round-trips with no default unit', () {
        final ingredient = CatalogIngredient(
          id: 'i1',
          name: 'Ice',
          ingredientLibraryId: 'il1',
        );

        expect(roundTrip(ingredient), equals(ingredient));
      });

      test('round-trips with a known default unit', () {
        final ingredient = CatalogIngredient(
          id: 'i1',
          name: 'Gin',
          ingredientLibraryId: 'il1',
          defaultUnit: const KnownUnit(StandardUnit.ml),
        );

        expect(roundTrip(ingredient), equals(ingredient));
      });

      test('round-trips with a custom default unit', () {
        final ingredient = CatalogIngredient(
          id: 'i1',
          name: 'Mint',
          ingredientLibraryId: 'il1',
          defaultUnit: CustomUnit('sprig'),
        );

        expect(roundTrip(ingredient), equals(ingredient));
      });

      test('serializes every field', () {
        expect(
          CatalogIngredient(
            id: 'i1',
            name: 'Gin',
            ingredientLibraryId: 'il1',
            defaultUnit: const KnownUnit(StandardUnit.ml),
          ).toJson(),
          equals({
            'id': 'i1',
            'name': 'Gin',
            'defaultUnit': {'kind': 'standard', 'unit': 'ml'},
            'ingredientLibraryId': 'il1',
          }),
        );
      });
    });
  });
}
