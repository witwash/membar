import 'dart:convert';

import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('CatalogIngredient', () {
    test('generates an id when none is given', () {
      final first = CatalogIngredient(name: 'Gin', libraryIds: const {'l1'});
      final second = CatalogIngredient(name: 'Gin', libraryIds: const {'l1'});

      expect(first.id, isNotEmpty);
      expect(first.id, isNot(equals(second.id)));
    });

    test('keeps the id it is given', () {
      expect(
        CatalogIngredient(id: 'i1', name: 'Gin', libraryIds: const {'l1'}).id,
        equals('i1'),
      );
    });

    test('trims the name', () {
      expect(
        CatalogIngredient(name: '  Gin ', libraryIds: const {'l1'}).name,
        equals('Gin'),
      );
    });

    test('asserts on a blank name', () {
      expect(
        () => CatalogIngredient(name: '  ', libraryIds: const {'l1'}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on an empty library set', () {
      expect(
        () => CatalogIngredient(name: 'Gin', libraryIds: const {}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('defaults to no unit', () {
      expect(
        CatalogIngredient(name: 'Ice', libraryIds: const {'l1'}).defaultUnit,
        isNull,
      );
    });

    test('exposes its library set as unmodifiable', () {
      final libraryIds = {'l1'};
      final ingredient = CatalogIngredient(name: 'Gin', libraryIds: libraryIds);
      libraryIds.add('l2');

      expect(ingredient.libraryIds, equals({'l1'}));
      expect(() => ingredient.libraryIds.add('l2'), throwsUnsupportedError);
    });

    test('supports value equality', () {
      CatalogIngredient build({Unit? defaultUnit}) => CatalogIngredient(
        id: 'i1',
        name: 'Gin',
        libraryIds: const {'l1'},
        defaultUnit: defaultUnit,
      );

      expect(build(), equals(build()));
      expect(
        build(defaultUnit: const KnownUnit(StandardUnit.ml)),
        isNot(equals(build(defaultUnit: CustomUnit('ml')))),
      );
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
          libraryIds: const {'l1'},
        );

        expect(roundTrip(ingredient), equals(ingredient));
      });

      test('round-trips with a known default unit', () {
        final ingredient = CatalogIngredient(
          id: 'i1',
          name: 'Gin',
          libraryIds: const {'l1'},
          defaultUnit: const KnownUnit(StandardUnit.ml),
        );

        expect(roundTrip(ingredient), equals(ingredient));
      });

      test('round-trips with a custom default unit', () {
        final ingredient = CatalogIngredient(
          id: 'i1',
          name: 'Mint',
          libraryIds: const {'l1'},
          defaultUnit: CustomUnit('sprig'),
        );

        expect(roundTrip(ingredient), equals(ingredient));
      });

      test('round-trips a multi-library scope', () {
        final ingredient = CatalogIngredient(
          id: 'i1',
          name: 'Sugar',
          libraryIds: const {'l1', 'l2'},
        );

        expect(roundTrip(ingredient).libraryIds, equals({'l1', 'l2'}));
      });

      test('serializes every field', () {
        expect(
          CatalogIngredient(
            id: 'i1',
            name: 'Gin',
            libraryIds: const {'l1'},
            defaultUnit: const KnownUnit(StandardUnit.ml),
          ).toJson(),
          equals({
            'id': 'i1',
            'name': 'Gin',
            'defaultUnit': {'kind': 'standard', 'unit': 'ml'},
            'libraryIds': ['l1'],
          }),
        );
      });
    });
  });
}
