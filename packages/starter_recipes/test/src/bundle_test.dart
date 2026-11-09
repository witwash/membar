import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes/starter_recipes.dart';

/// Serves the package's asset keys from the files on disk, so the real loader
/// reads the real bundle.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final path = key.replaceFirst('packages/starter_recipes/', '');
    return ByteData.sublistView(await File(path).readAsBytes());
  }
}

const Map<StarterCollection, Set<String>> _tags = {
  StarterCollection.cocktails: {
    'stirred',
    'sour',
    'long',
    'sparkling',
    'tiki',
    'gin',
    'vodka',
    'rum',
    'whiskey',
    'tequila',
    'brandy',
    'cachaça',
  },
  StarterCollection.coffee: {
    'espresso',
    'milk',
    'filter',
    'immersion',
    'stovetop',
    'cold',
  },
};

const Map<StarterCollection, int> _counts = {
  StarterCollection.cocktails: 42,
  StarterCollection.coffee: 12,
};

/// Units a counted cocktail row may not use, because they are volumes or
/// weights that belong in the ml/oz form.
const Set<StandardUnit> _measuredUnits = {
  StandardUnit.ml,
  StandardUnit.cl,
  StandardUnit.oz,
  StandardUnit.gram,
};

Library _template(StarterCollection collection) {
  const templates = LibraryTemplates();
  return switch (collection) {
    StarterCollection.cocktails => templates.cocktails(
      ingredientLibraryId: 'x',
    ),
    StarterCollection.coffee => templates.coffee(ingredientLibraryId: 'x'),
  };
}

/// Every value that appears more than once, ignoring case.
List<String> _duplicates(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final value in values)
      if (!seen.add(value.toLowerCase())) value,
  ];
}

Iterable<String> _quantities(StarterRow row) =>
    [row.ml, row.oz, row.quantity].nonNulls;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pubspec', () {
    for (final collection in StarterCollection.values) {
      for (final file in ['ingredients', 'recipes']) {
        test('declares assets/${collection.name}/$file.json', () async {
          await expectLater(
            rootBundle.loadString('assets/${collection.name}/$file.json'),
            completes,
          );
        });
      }
    }
  });

  for (final collection in StarterCollection.values) {
    group('${collection.name} bundle', () {
      late StarterSet set;
      late Map<String, FieldDefinition> fields;

      setUpAll(() async {
        set = await StarterRecipesLoader(_DiskBundle()).load(collection);
        fields = {
          for (final field in _template(collection).fields) field.label: field,
        };
      });

      Iterable<(StarterRecipe, StarterRow)> rows() => [
        for (final recipe in set.recipes)
          for (final row in recipe.rows) (recipe, row),
      ];

      test('has ${_counts[collection]} recipes', () {
        expect(set.recipes, hasLength(_counts[collection]));
      });

      test('has unique recipe keys and names', () {
        expect(_duplicates(set.recipes.map((r) => r.key)), isEmpty);
        expect(_duplicates(set.recipes.map((r) => r.name)), isEmpty);
      });

      test('has unique ingredient keys and names', () {
        expect(_duplicates(set.ingredients.map((i) => i.key)), isEmpty);
        expect(_duplicates(set.ingredients.map((i) => i.name)), isEmpty);
      });

      test('has no blank or untrimmed names', () {
        final names = [
          ...set.recipes.map((r) => r.name),
          ...set.ingredients.map((i) => i.name),
        ];
        expect(
          names.where((name) => name.isEmpty || name != name.trim()),
          isEmpty,
        );
      });

      test('resolves every row to a listed ingredient', () {
        final keys = set.ingredients.map((i) => i.key).toSet();
        expect(
          [
            for (final (recipe, row) in rows())
              if (!keys.contains(row.ingredient))
                '${recipe.key}: ${row.ingredient}',
          ],
          isEmpty,
        );
      });

      test('uses every listed ingredient', () {
        final used = rows().map((entry) => entry.$2.ingredient).toSet();
        expect(
          set.ingredients.map((i) => i.key).where((k) => !used.contains(k)),
          isEmpty,
        );
      });

      test('uses each ingredient at most once per recipe', () {
        expect(
          [
            for (final recipe in set.recipes)
              for (final key in _duplicates(
                recipe.rows.map((row) => row.ingredient),
              ))
                '${recipe.key}: $key',
          ],
          isEmpty,
        );
      });

      test('writes every quantity as a positive decimal', () {
        expect(
          [
            for (final (recipe, row) in rows())
              for (final quantity in _quantities(row))
                if (!((num.tryParse(quantity) ?? 0) > 0))
                  '${recipe.key}: ${row.ingredient} $quantity',
          ],
          isEmpty,
        );
      });

      test('names only fields the template declares', () {
        expect(
          [
            for (final recipe in set.recipes)
              for (final label in recipe.fields.keys)
                if (!fields.containsKey(label)) '${recipe.key}: $label',
          ],
          isEmpty,
        );
      });

      test('gives every field a value its type accepts', () {
        bool accepts(FieldDefinition field, Object value) =>
            switch (field.type) {
              FieldType.number => value is num,
              FieldType.select =>
                value is String && field.options!.contains(value),
              FieldType.text ||
              FieldType.longText => value is String && value.trim().isNotEmpty,
            };

        expect(
          [
            for (final recipe in set.recipes)
              for (final MapEntry(:key, :value) in recipe.fields.entries)
                if (fields[key] case final field? when !accepts(field, value))
                  '${recipe.key}: $key = $value',
          ],
          isEmpty,
        );
      });

      test('tags every recipe from the fixed vocabulary', () {
        expect(
          [
            for (final recipe in set.recipes)
              for (final tag in recipe.tags)
                if (!_tags[collection]!.contains(tag)) '${recipe.key}: $tag',
          ],
          isEmpty,
        );
        expect(
          set.recipes.where((r) => r.tags.isEmpty).map((r) => r.key),
          isEmpty,
        );
      });

      test('gives every recipe at least one non-blank step', () {
        expect(
          set.recipes
              .where(
                (r) =>
                    r.steps.isEmpty ||
                    r.steps.any((step) => step.trim().isEmpty),
              )
              .map((r) => r.key),
          isEmpty,
        );
      });

      test('gives every recipe at least one row', () {
        expect(
          set.recipes.where((r) => r.rows.isEmpty).map((r) => r.key),
          isEmpty,
        );
      });

      switch (collection) {
        case StarterCollection.cocktails:
          test('writes every volume as ml = oz × 30', () {
            expect(
              [
                for (final (recipe, row) in rows())
                  if (row.ml != null &&
                      (num.parse(row.ml!) - num.parse(row.oz!) * 30).abs() >
                          0.01)
                    '${recipe.key}: ${row.ingredient}',
              ],
              isEmpty,
            );
          });

          test('counts no row in a volume or weight unit', () {
            expect(
              [
                for (final (recipe, row) in rows())
                  if (_measuredUnits.contains(row.unit))
                    '${recipe.key}: ${row.ingredient}',
              ],
              isEmpty,
            );
          });

          test('sets Glassware on every recipe', () {
            expect(
              set.recipes
                  .where((r) => !r.fields.containsKey('Glassware'))
                  .map((r) => r.key),
              isEmpty,
            );
          });

        case StarterCollection.coffee:
          test('writes every row metric, in gram or ml', () {
            expect(
              [
                for (final (recipe, row) in rows())
                  if (row.ml != null ||
                      !{StandardUnit.gram, StandardUnit.ml}.contains(row.unit))
                    '${recipe.key}: ${row.ingredient}',
              ],
              isEmpty,
            );
          });

          test('sets Brew method and a Coffee beans row on every recipe', () {
            expect(
              set.recipes
                  .where(
                    (r) =>
                        !r.fields.containsKey('Brew method') ||
                        !r.rows.any((row) => row.ingredient == 'coffee_beans'),
                  )
                  .map((r) => r.key),
              isEmpty,
            );
          });

          test('leaves Tasting notes empty', () {
            expect(
              set.recipes
                  .where((r) => r.fields.containsKey('Tasting notes'))
                  .map((r) => r.key),
              isEmpty,
            );
          });
      }
    });
  }
}
