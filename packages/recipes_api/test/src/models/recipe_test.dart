import 'dart:convert';

import 'package:recipes_api/recipes_api.dart';
import 'package:test/test.dart';

void main() {
  group('Recipe', () {
    test('generates an id when none is given', () {
      final first = Recipe(libraryId: 'l1', name: 'Negroni');
      final second = Recipe(libraryId: 'l1', name: 'Negroni');

      expect(first.id, isNotEmpty);
      expect(first.id, isNot(equals(second.id)));
    });

    test('keeps the id it is given', () {
      expect(
        Recipe(id: 'r1', libraryId: 'l1', name: 'Negroni').id,
        equals('r1'),
      );
    });

    test('trims the name', () {
      expect(
        Recipe(libraryId: 'l1', name: '  Negroni  ').name,
        equals('Negroni'),
      );
    });

    test('asserts on a blank name', () {
      expect(
        () => Recipe(libraryId: 'l1', name: '   '),
        throwsA(isA<AssertionError>()),
      );
    });

    test('defaults every collection to empty', () {
      final recipe = Recipe(libraryId: 'l1', name: 'Negroni');

      expect(recipe.ingredients, isEmpty);
      expect(recipe.steps, isEmpty);
      expect(recipe.tags, isEmpty);
      expect(recipe.notes, isEmpty);
      expect(recipe.fieldValues, isEmpty);
    });

    test('exposes its collections as unmodifiable', () {
      final recipe = Recipe(libraryId: 'l1', name: 'Negroni');

      expect(() => recipe.steps.add('Stir'), throwsUnsupportedError);
      expect(() => recipe.tags.add('bitter'), throwsUnsupportedError);
      expect(() => recipe.fieldValues['f1'] = 'x', throwsUnsupportedError);
      expect(
        () => recipe.ingredients.add(Ingredient(name: 'Gin')),
        throwsUnsupportedError,
      );
    });

    group('tags', () {
      test('are trimmed', () {
        expect(
          Recipe(
            libraryId: 'l1',
            name: 'Negroni',
            tags: const [' bitter '],
          ).tags,
          equals(['bitter']),
        );
      });

      test('drop blank entries', () {
        expect(
          Recipe(
            libraryId: 'l1',
            name: 'Negroni',
            tags: const ['bitter', '  ', ''],
          ).tags,
          equals(['bitter']),
        );
      });

      test('are deduplicated without regard to case, keeping the first', () {
        expect(
          Recipe(
            libraryId: 'l1',
            name: 'Negroni',
            tags: const ['Bitter', 'bitter', 'BITTER', 'stirred'],
          ).tags,
          equals(['Bitter', 'stirred']),
        );
      });
    });

    group('fieldValues', () {
      test('drops null, empty and whitespace-only entries', () {
        final recipe = Recipe(
          libraryId: 'l1',
          name: 'Negroni',
          fieldValues: const {
            'f1': 'Coupe',
            'f2': null,
            'f3': '',
            'f4': '   ',
            'f5': 0,
          },
        );

        expect(recipe.fieldValues, equals({'f1': 'Coupe', 'f5': 0}));
      });

      test('treats absent, null and blank as the same recipe', () {
        Recipe build(Map<String, Object?> fieldValues) => Recipe(
          id: 'r1',
          libraryId: 'l1',
          name: 'Negroni',
          fieldValues: fieldValues,
        );

        expect(build(const {}), equals(build(const {'f1': null})));
        expect(build(const {}), equals(build(const {'f1': ''})));
      });
    });

    group('textValue', () {
      test('returns the trimmed stored string', () {
        final recipe = Recipe(
          libraryId: 'l1',
          name: 'Negroni',
          fieldValues: const {'f1': ' Coupe '},
        );

        expect(recipe.textValue('f1'), equals('Coupe'));
      });

      test('returns null for an absent field', () {
        expect(
          Recipe(libraryId: 'l1', name: 'Negroni').textValue('f1'),
          isNull,
        );
      });

      test('returns null for a non-string value', () {
        final recipe = Recipe(
          libraryId: 'l1',
          name: 'Negroni',
          fieldValues: const {'f1': 18},
        );

        expect(recipe.textValue('f1'), isNull);
      });
    });

    group('numberValue', () {
      test('returns a stored num', () {
        final recipe = Recipe(
          libraryId: 'l1',
          name: 'Negroni',
          fieldValues: const {'f1': 92.5},
        );

        expect(recipe.numberValue('f1'), equals(92.5));
      });

      test('parses a stored numeric string', () {
        final recipe = Recipe(
          libraryId: 'l1',
          name: 'Negroni',
          fieldValues: const {'f1': ' 18 '},
        );

        expect(recipe.numberValue('f1'), equals(18));
      });

      test('returns null for an unparseable string', () {
        final recipe = Recipe(
          libraryId: 'l1',
          name: 'Negroni',
          fieldValues: const {'f1': 'hot'},
        );

        expect(recipe.numberValue('f1'), isNull);
      });

      test('returns null for an absent field', () {
        expect(
          Recipe(libraryId: 'l1', name: 'Negroni').numberValue('f1'),
          isNull,
        );
      });

      test('returns null for a value that is neither num nor String', () {
        final recipe = Recipe(
          libraryId: 'l1',
          name: 'Negroni',
          fieldValues: const {'f1': true},
        );

        expect(recipe.numberValue('f1'), isNull);
      });
    });

    test('supports value equality', () {
      Recipe build() => Recipe(
        id: 'r1',
        libraryId: 'l1',
        name: 'Negroni',
        ingredients: [Ingredient(name: 'Gin')],
        steps: const ['Stir'],
        tags: const ['bitter'],
        notes: 'Classic',
        fieldValues: const {'f1': 'Coupe'},
      );

      expect(build(), equals(build()));
      expect(
        build(),
        isNot(equals(Recipe(id: 'r2', libraryId: 'l1', name: 'Negroni'))),
      );
    });

    group('json', () {
      Recipe buildRecipe() => Recipe(
        id: 'r1',
        libraryId: 'l1',
        name: 'Negroni',
        ingredients: [
          Ingredient(name: 'Gin', quantity: '1', unit: 'oz'),
          Ingredient(name: 'Campari'),
        ],
        steps: const ['Stir with ice', 'Strain'],
        tags: const ['bitter', 'stirred'],
        notes: 'Equal parts.',
        fieldValues: const {'f1': 'Coupe', 'f2': 18.5},
      );

      test('round-trips through a JSON string', () {
        final recipe = buildRecipe();

        final decoded = Recipe.fromJson(
          json.decode(json.encode(recipe.toJson())) as Map<String, dynamic>,
        );

        expect(decoded, equals(recipe));
      });

      test('serializes nested ingredients as plain maps', () {
        expect(
          buildRecipe().toJson()['ingredients'],
          equals([
            {'name': 'Gin', 'quantity': '1', 'unit': 'oz'},
            {'name': 'Campari', 'quantity': '', 'unit': ''},
          ]),
        );
      });

      test('keeps both String and num field values', () {
        final decoded = Recipe.fromJson(
          json.decode(json.encode(buildRecipe().toJson()))
              as Map<String, dynamic>,
        );

        expect(decoded.textValue('f1'), equals('Coupe'));
        expect(decoded.numberValue('f2'), equals(18.5));
      });

      test('round-trips a whole number written as a double', () {
        final recipe = Recipe(
          id: 'r1',
          libraryId: 'l1',
          name: 'Pour over',
          fieldValues: const {'f1': 92.0},
        );

        final decoded = Recipe.fromJson(
          json.decode(json.encode(recipe.toJson())) as Map<String, dynamic>,
        );

        expect(decoded, equals(recipe));
        expect(decoded.numberValue('f1'), equals(92));
      });

      test('reads a whole number stored without a decimal point', () {
        // A blob written by anything other than dart:convert — a hand edit, or
        // another platform — drops the `.0`, so the value decodes as an int.
        // Reading it as a `double` would throw; `numberValue` returns `num`.
        final decoded = Recipe.fromJson(const {
          'id': 'r1',
          'libraryId': 'l1',
          'name': 'Pour over',
          'fieldValues': {'f1': 92},
        });

        expect(decoded.fieldValues['f1'], isA<int>());
        expect(decoded.numberValue('f1'), equals(92));
        expect(decoded.numberValue('f1')!.toDouble(), equals(92.0));
      });

      test('survives a field value whose field no longer exists', () {
        final decoded = Recipe.fromJson(const {
          'id': 'r1',
          'libraryId': 'l1',
          'name': 'Negroni',
          'fieldValues': {'gone': 'Coupe'},
        });

        expect(decoded.textValue('gone'), equals('Coupe'));
      });

      test('decodes a minimal payload', () {
        final decoded = Recipe.fromJson(const {
          'id': 'r1',
          'libraryId': 'l1',
          'name': 'Negroni',
        });

        expect(decoded.ingredients, isEmpty);
        expect(decoded.steps, isEmpty);
        expect(decoded.tags, isEmpty);
        expect(decoded.notes, isEmpty);
        expect(decoded.fieldValues, isEmpty);
      });
    });
  });
}
