import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes_repository/starter_recipes_repository.dart';

class _MockStarterRecipesLoader extends Mock implements StarterRecipesLoader {}

const _lime = StarterIngredient(
  key: 'lime-juice',
  name: 'Lime juice',
  defaultUnit: StandardUnit.ml,
);
const _rum = StarterIngredient(
  key: 'white-rum',
  name: 'White rum',
  defaultUnit: StandardUnit.ml,
);
const _bitters = StarterIngredient(
  key: 'angostura',
  name: 'Angostura bitters',
  defaultUnit: StandardUnit.dash,
);
const _beans = StarterIngredient(
  key: 'coffee-beans',
  name: 'Coffee beans',
  defaultUnit: StandardUnit.gram,
);

const _daiquiri = StarterRecipe(
  key: 'daiquiri',
  name: 'Daiquiri',
  tags: ['sour', 'rum'],
  steps: ['Shake.', 'Strain.'],
  notes: 'A classic.',
  rows: [
    StarterRow(ingredient: 'white-rum', ml: '60', oz: '2'),
    StarterRow(ingredient: 'lime-juice', ml: '22.5', oz: '0.75'),
  ],
);
const _gimlet = StarterRecipe(
  key: 'gimlet',
  name: 'Gimlet',
  rows: [StarterRow(ingredient: 'lime-juice', ml: '30', oz: '1')],
);
const _pinkGin = StarterRecipe(
  key: 'pink-gin',
  name: 'Pink gin',
  rows: [
    StarterRow(ingredient: 'angostura', quantity: '3', unit: StandardUnit.dash),
  ],
);

const _set = StarterSet(
  ingredients: [_lime, _rum, _bitters, _beans],
  recipes: [_daiquiri, _gimlet, _pinkGin],
);

void main() {
  group(StarterRecipesRepository, () {
    late StarterRecipesLoader loader;
    late StarterRecipesRepository repository;
    late Library library;

    setUp(() {
      loader = _MockStarterRecipesLoader();
      repository = StarterRecipesRepository(loader: loader);
      library = Library(name: 'Bar', ingredientLibraryId: 'shelf');
    });

    ({List<CatalogIngredient> ingredients, List<Recipe> recipes}) build({
      StarterSet set = _set,
      Map<String, String>? names,
      List<CatalogIngredient> entries = const [],
      MeasureSystem system = MeasureSystem.metric,
    }) => repository.buildImport(
      set: set,
      names:
          names ?? {for (final recipe in set.recipes) recipe.key: recipe.name},
      library: library,
      entries: entries,
      system: system,
    );

    test('load delegates to the loader', () async {
      when(() => loader.load(LibraryTemplate.coffee))
          .thenAnswer((_) async => _set);

      expect(await repository.load(LibraryTemplate.coffee), equals(_set));
      verify(() => loader.load(LibraryTemplate.coffee)).called(1);
    });

    group('buildImport', () {
      test('links an ingredient to a stored entry by folded name', () {
        final stored = CatalogIngredient(
          name: 'LIME JUICE',
          ingredientLibraryId: 'shelf',
        );

        final import = build(names: {'gimlet': 'Gimlet'}, entries: [stored]);

        expect(import.ingredients, isEmpty);
        expect(
          import.recipes.single.ingredients.single.catalogId,
          equals(stored.id),
        );
      });

      test('creates one entry per new ingredient, shared by its recipes', () {
        final import = build(
          names: {'daiquiri': 'Daiquiri', 'gimlet': 'Gimlet'},
        );

        expect(
          import.ingredients.map((entry) => entry.name),
          equals(['White rum', 'Lime juice']),
        );
        expect(
          import.ingredients.map((entry) => entry.ingredientLibraryId),
          everyElement('shelf'),
        );
        final limeId = import.ingredients[1].id;
        expect(import.recipes[0].ingredients[1].catalogId, equals(limeId));
        expect(import.recipes[1].ingredients.single.catalogId, equals(limeId));
      });

      test('creates no entry for an ingredient no picked recipe uses', () {
        final import = build(names: {'pink-gin': 'Pink gin'});

        expect(
          import.ingredients.map((entry) => entry.name),
          equals(['Angostura bitters']),
        );
      });

      test('defaults a created ml entry to ml in metric', () {
        final import = build();

        expect(
          import.ingredients.map((entry) => entry.defaultUnit),
          equals([
            const KnownUnit(StandardUnit.ml),
            const KnownUnit(StandardUnit.ml),
            const KnownUnit(StandardUnit.dash),
          ]),
        );
      });

      test('defaults a created ml entry to oz in imperial', () {
        final import = build(system: MeasureSystem.imperial);

        expect(
          import.ingredients.map((entry) => entry.defaultUnit),
          equals([
            const KnownUnit(StandardUnit.oz),
            const KnownUnit(StandardUnit.oz),
            const KnownUnit(StandardUnit.dash),
          ]),
        );
      });

      test('writes volume rows in the chosen system', () {
        final metric = build(names: {'gimlet': 'Gimlet'});
        final imperial = build(
          names: {'gimlet': 'Gimlet'},
          system: MeasureSystem.imperial,
        );

        final metricRow = metric.recipes.single.ingredients.single;
        final imperialRow = imperial.recipes.single.ingredients.single;
        expect((metricRow.quantity, metricRow.unit), equals(('30', 'ml')));
        expect((imperialRow.quantity, imperialRow.unit), equals(('1', 'oz')));
      });

      test('writes a counted row the same in both systems', () {
        final metric = build(names: {'pink-gin': 'Pink gin'});
        final imperial = build(
          names: {'pink-gin': 'Pink gin'},
          system: MeasureSystem.imperial,
        );

        final metricRow = metric.recipes.single.ingredients.single;
        final imperialRow = imperial.recipes.single.ingredients.single;
        expect((metricRow.quantity, metricRow.unit), equals(('3', 'dash')));
        expect((imperialRow.quantity, imperialRow.unit), equals(('3', 'dash')));
      });

      test('copies tags, steps and notes into the library', () {
        final recipe = build(names: {'daiquiri': 'Daiquiri'}).recipes.single;

        expect(recipe.libraryId, equals(library.id));
        expect(recipe.name, equals('Daiquiri'));
        expect(recipe.tags, equals(['sour', 'rum']));
        expect(recipe.steps, equals(['Shake.', 'Strain.']));
        expect(recipe.notes, equals('A classic.'));
      });

      test('imports a recipe under the name it was given', () {
        final recipe = build(
          names: {'daiquiri': 'Daiquiri (mine)'},
        ).recipes.single;

        expect(recipe.name, equals('Daiquiri (mine)'));
      });

      test('follows the order of the set, not of the picks', () {
        final import = build(
          names: {'pink-gin': 'Pink gin', 'daiquiri': 'Daiquiri'},
        );

        expect(
          import.recipes.map((recipe) => recipe.name),
          equals(['Daiquiri', 'Pink gin']),
        );
      });

      group('field values', () {
        late FieldDefinition method;
        late FieldDefinition abv;
        late FieldDefinition glass;
        late FieldDefinition history;

        setUp(() {
          method = FieldDefinition(
            label: 'Method',
            type: FieldType.select,
            options: const ['Shaken', 'Stirred'],
          );
          abv = FieldDefinition(label: 'ABV', type: FieldType.number);
          glass = FieldDefinition(label: 'Glass', type: FieldType.text);
          history = FieldDefinition(label: 'History', type: FieldType.longText);
          library = Library(
            name: 'Bar',
            ingredientLibraryId: 'shelf',
            fields: [method, abv, glass, history],
          );
        });

        Map<String, Object?> valuesOf(Map<String, Object> fields) => build(
          set: StarterSet(
            ingredients: const [],
            recipes: [StarterRecipe(key: 'x', name: 'X', fields: fields)],
          ),
        ).recipes.single.fieldValues;

        test('stores each type against the field with that label', () {
          expect(
            valuesOf({
              'Method': 'Shaken',
              'ABV': 18.5,
              'Glass': 'Coupe',
              'History': 'Old.',
            }),
            equals({
              method.id: 'Shaken',
              abv.id: 18.5,
              glass.id: 'Coupe',
              history.id: 'Old.',
            }),
          );
        });

        test('matches a label ignoring case', () {
          expect(valuesOf({'glass': 'Coupe'}), equals({glass.id: 'Coupe'}));
        });

        test('stores a select value in the option spelling', () {
          expect(
            valuesOf({'Method': 'STIRRED'}),
            equals({method.id: 'Stirred'}),
          );
        });

        test('drops a select value matching no option', () {
          expect(valuesOf({'Method': 'Thrown'}), isEmpty);
        });

        test('drops a value the field type does not accept', () {
          expect(
            valuesOf({'Method': 1, 'ABV': '18', 'Glass': 2, 'History': 3}),
            isEmpty,
          );
        });

        test('drops a value whose label matches no field', () {
          expect(valuesOf({'Garnish': 'Lime wheel'}), isEmpty);
        });
      });
    });
  });
}
