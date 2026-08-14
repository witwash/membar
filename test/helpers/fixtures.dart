import 'package:recipes_repository/recipes_repository.dart';

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
  fields: [glasswareField, garnishField],
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
  fields: [doseField, tastingNotesField],
);
