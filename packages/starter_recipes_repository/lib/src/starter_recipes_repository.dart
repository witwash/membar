import 'package:recipes_api/recipes_api.dart';
import 'package:starter_recipes/starter_recipes.dart';

/// {@template starter_recipes_repository}
/// Reads the bundled starter recipes and turns picked ones into the catalog
/// entries and recipes an import writes.
/// {@endtemplate}
class StarterRecipesRepository {
  /// {@macro starter_recipes_repository}
  const StarterRecipesRepository({required this._loader});

  final StarterRecipesLoader _loader;

  /// The bundled set for [template].
  Future<StarterSet> load(LibraryTemplate template) => _loader.load(template);

  /// The catalog entries to create (only new ones) and the recipes an import
  /// of [set] into [library] writes.
  ///
  /// [names] maps each picked recipe's key to the name it is imported under;
  /// a recipe missing from it is not imported. [entries] is the library's
  /// ingredient library. The output follows the order of [set].
  ///
  /// A bundled ingredient is linked to the entry in [entries] carrying its
  /// name without regard to case or surrounding whitespace. Otherwise one new
  /// entry is created for it and shared by every recipe that uses it. Rows are
  /// written in [system], and so is the default unit of a created entry whose
  /// bundled default is `ml`.
  ///
  /// A field value is stored against the field of [library] whose label
  /// matches it without regard to case, when the field's type accepts it: an
  /// option of a select field (in the option's own spelling), a `num` for a
  /// number field, or a `String` for a text field. Any other value is
  /// dropped.
  ({List<CatalogIngredient> ingredients, List<Recipe> recipes}) buildImport({
    required StarterSet set,
    required Map<String, String> names,
    required Library library,
    required List<CatalogIngredient> entries,
    required MeasureSystem system,
  }) {
    final starters = {
      for (final starter in set.ingredients) starter.key: starter,
    };
    final stored = {for (final entry in entries) _fold(entry.name): entry.id};
    final fields = {
      for (final field in library.fields) _fold(field.label): field,
    };
    final created = <CatalogIngredient>[];
    final catalogIds = <String, String>{};

    String catalogIdOf(String key) => catalogIds.putIfAbsent(key, () {
      final starter = starters[key]!;
      if (stored[_fold(starter.name)] case final id?) return id;
      final entry = CatalogIngredient(
        name: starter.name,
        ingredientLibraryId: library.ingredientLibraryId,
        defaultUnit: KnownUnit(_defaultUnit(starter.defaultUnit, system)),
      );
      created.add(entry);
      return entry.id;
    });

    final recipes = [
      for (final starter in set.recipes)
        if (names[starter.key] case final name?)
          Recipe(
            libraryId: library.id,
            name: name,
            tags: starter.tags,
            steps: starter.steps,
            notes: starter.notes,
            fieldValues: {
              for (final MapEntry(:key, :value) in starter.fields.entries)
                if (fields[_fold(key)] case final field?)
                  field.id: ?_accepted(field, value),
            },
            ingredients: [
              for (final row in starter.rows)
                // Always matches: the `case` only destructures the record, so
                // no row is dropped here.
                if (row.measured(system) case (final quantity, final unit))
                  Ingredient(
                    catalogId: catalogIdOf(row.ingredient),
                    quantity: quantity,
                    unit: unit.name,
                  ),
            ],
          ),
    ];

    return (ingredients: created, recipes: recipes);
  }

  static String _fold(String value) => value.trim().toLowerCase();

  static StandardUnit _defaultUnit(StandardUnit unit, MeasureSystem system) =>
      unit == StandardUnit.ml && system == MeasureSystem.imperial
      ? StandardUnit.oz
      : unit;

  static Object? _accepted(FieldDefinition field, Object value) =>
      switch ((field.type, value)) {
        (FieldType.select, final String option) =>
          field.optionsOrEmpty
              .where((candidate) => _fold(candidate) == _fold(option))
              .firstOrNull,
        (FieldType.number, final num number) => number,
        (FieldType.text || FieldType.longText, final String text) => text,
        _ => null,
      };
}
