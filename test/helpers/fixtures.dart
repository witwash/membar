import 'package:recipes_repository/recipes_repository.dart';

/// The ingredient library [cocktailsLibrary] draws from.
final cocktailsPantry = IngredientLibrary(
  id: 'ingredient-library-cocktails',
  name: 'Cocktails pantry',
);

/// The ingredient library [coffeeLibrary] draws from.
final coffeeShelf = IngredientLibrary(
  id: 'ingredient-library-coffee',
  name: 'Coffee shelf',
);

/// The Select field of [cocktailsLibrary].
final glasswareField = FieldDefinition(
  id: 'field-glassware',
  label: 'Glassware',
  type: FieldType.select,
  options: const ['Coupe', 'Rocks'],
);

/// The Text field of [cocktailsLibrary].
final garnishField = FieldDefinition(
  id: 'field-garnish',
  label: 'Garnish',
  type: FieldType.text,
);

/// A library shaped like the seeded Cocktails template.
final cocktailsLibrary = Library(
  id: 'library-cocktails',
  name: 'Cocktails',
  ingredientLibraryId: cocktailsPantry.id,
  fields: [glasswareField, garnishField],
  template: LibraryTemplate.cocktails,
);

/// The Number field of [coffeeLibrary], carrying a unit.
final doseField = FieldDefinition(
  id: 'field-dose',
  label: 'Dose',
  type: FieldType.number,
  unit: 'g',
);

/// The LongText field of [coffeeLibrary].
final tastingNotesField = FieldDefinition(
  id: 'field-tasting-notes',
  label: 'Tasting notes',
  type: FieldType.longText,
);

/// A library shaped like the seeded Coffee template — a different schema, so
/// screens can be tested against two genuinely different ones.
final coffeeLibrary = Library(
  id: 'library-coffee',
  name: 'Coffee',
  ingredientLibraryId: coffeeShelf.id,
  fields: [doseField, tastingNotesField],
  template: LibraryTemplate.coffee,
);

/// An entry in [cocktailsPantry], with a standard unit.
final ginIngredient = CatalogIngredient(
  id: 'ingredient-gin',
  name: 'Gin',
  defaultUnit: const KnownUnit(StandardUnit.ml),
  ingredientLibraryId: cocktailsPantry.id,
);

/// An entry in [cocktailsPantry] whose name [coffeeSugarIngredient] shares.
final sugarIngredient = CatalogIngredient(
  id: 'ingredient-sugar',
  name: 'sugar',
  defaultUnit: const KnownUnit(StandardUnit.gram),
  ingredientLibraryId: cocktailsPantry.id,
);

/// An entry in [coffeeShelf] named like [sugarIngredient] but unrelated to
/// it, because it lives in another ingredient library.
final coffeeSugarIngredient = CatalogIngredient(
  id: 'ingredient-coffee-sugar',
  name: 'sugar',
  defaultUnit: const KnownUnit(StandardUnit.gram),
  ingredientLibraryId: coffeeShelf.id,
);

/// An entry in [coffeeShelf], with a custom unit.
final cinnamonIngredient = CatalogIngredient(
  id: 'ingredient-cinnamon',
  name: 'Cinnamon',
  defaultUnit: CustomUnit('pinch'),
  ingredientLibraryId: coffeeShelf.id,
);
