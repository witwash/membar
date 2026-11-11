# starter_recipes_repository

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

The app's only route to the bundled starter recipes in `starter_recipes`.

`StarterRecipesRepository.load` reads the set offered to a library created
from a `LibraryTemplate`. `buildImport` turns the picked recipes into the
`CatalogIngredient` and `Recipe` values that `RecipesRepository.importRecipes`
writes:

- A bundled ingredient whose name matches an entry of the library's ingredient
  library, ignoring case, is linked to it. Otherwise one entry is created per
  bundled ingredient and shared by every recipe that uses it. An entry created
  in an imperial import gets `oz` where the bundle says `ml`.
- A field value lands on the library field whose label matches it, ignoring
  case, when the field's type accepts it. Anything else is dropped.

Only the app's flavor entrypoints construct `StarterRecipesLoader`. Nothing
else in the app depends on `starter_recipes` directly.

## Development

Run the tests with coverage:

```sh
very_good test --coverage --min-coverage 100
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
