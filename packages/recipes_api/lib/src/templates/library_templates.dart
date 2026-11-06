import 'package:recipes_api/recipes_api.dart';
import 'package:uuid/uuid.dart';

String _uuidV4() => const Uuid().v4();

/// {@template library_templates}
/// The libraries a fresh install is seeded with, and the schemas a new
/// library can start from — creating one takes a template's fields and
/// leaves its name behind.
///
/// Each call builds a [Library] with freshly generated ids, so a seeded
/// library is indistinguishable from a hand-built one once it exists. A
/// template names no ingredients: the [IngredientLibrary] it points at is
/// supplied by the caller and starts empty.
///
/// Template names and field labels are deliberately not localized: they become
/// the user's own data the moment they are seeded, so resolving them per locale
/// would rename a library when the device language changes.
/// {@endtemplate}
class LibraryTemplates {
  /// {@macro library_templates}
  ///
  /// [idBuilder] generates every id a template needs. Inject a deterministic
  /// one in tests; production uses uuid v4.
  const LibraryTemplates({this.idBuilder = _uuidV4});

  /// Generates every id a template needs.
  final String Function() idBuilder;

  /// A library for cocktail recipes, with `Glassware` and `Garnish` fields,
  /// whose rows draw from [ingredientLibraryId].
  Library cocktails({required String ingredientLibraryId}) => Library(
    id: idBuilder(),
    name: 'Cocktails',
    ingredientLibraryId: ingredientLibraryId,
    fields: [
      FieldDefinition(
        id: idBuilder(),
        label: 'Glassware',
        type: FieldType.select,
        options: const [
          'Coupe',
          'Rocks',
          'Highball',
          'Collins',
          'Martini',
          'Nick and Nora',
          'Flute',
          'Mug',
        ],
      ),
      FieldDefinition(
        id: idBuilder(),
        label: 'Garnish',
        type: FieldType.text,
      ),
    ],
  );

  /// A library for coffee recipes, with brew method, dose, water temperature,
  /// grind and tasting-note fields, whose rows draw from
  /// [ingredientLibraryId].
  Library coffee({required String ingredientLibraryId}) => Library(
    id: idBuilder(),
    name: 'Coffee',
    ingredientLibraryId: ingredientLibraryId,
    fields: [
      FieldDefinition(
        id: idBuilder(),
        label: 'Brew method',
        type: FieldType.select,
        options: const [
          'Pour over',
          'Espresso',
          'French press',
          'Aeropress',
          'Moka pot',
          'Cold brew',
        ],
      ),
      FieldDefinition(
        id: idBuilder(),
        label: 'Dose',
        type: FieldType.number,
        unit: 'g',
      ),
      FieldDefinition(
        id: idBuilder(),
        label: 'Water temp',
        type: FieldType.number,
        unit: '°C',
      ),
      FieldDefinition(
        id: idBuilder(),
        label: 'Grind',
        type: FieldType.text,
      ),
      FieldDefinition(
        id: idBuilder(),
        label: 'Tasting notes',
        type: FieldType.longText,
      ),
    ],
  );

  /// Every template, in the order a fresh install seeds them, each paired with
  /// a same-named [IngredientLibrary] it points at. The first one is the
  /// library the app opens on.
  List<(Library, IngredientLibrary)> all() => [
    _paired('Cocktails', cocktails),
    _paired('Coffee', coffee),
  ];

  (Library, IngredientLibrary) _paired(
    String name,
    Library Function({required String ingredientLibraryId}) template,
  ) {
    final ingredientLibrary = IngredientLibrary(id: idBuilder(), name: name);
    return (
      template(ingredientLibraryId: ingredientLibrary.id),
      ingredientLibrary,
    );
  }
}
