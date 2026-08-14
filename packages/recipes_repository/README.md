# recipes_repository

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A repository that exposes recipes, libraries, and the active library to the app.

It wraps a constructor-injected `RecipesApi` and re-exports the models, so the
business logic layer depends on this package alone and never on a storage
implementation.

## Development

Run the tests with coverage:

```sh
very_good test --coverage --min-coverage 100
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
