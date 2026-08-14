# recipes_api

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

The interface and models for a recipes API.

This package defines *what* a recipes data source must do, not *how*. It holds
the models (`Recipe`, `Ingredient`, `Library`, `FieldDefinition`,
`RecipesSnapshot`), the built-in `LibraryTemplates` a fresh install is seeded
with, and the abstract `RecipesApi` a data source implements. It depends on no
storage mechanism, so a local-storage source and a remote one are peers.

## Development

The models use `json_serializable`, so regenerate the `*.g.dart` part files
after changing one:

```sh
dart run build_runner build --delete-conflicting-outputs
```

The generated files are committed: the app's `flutter analyze` walks into
`packages/`, so a fresh checkout without them fails on missing parts.

Run the tests with coverage:

```sh
very_good test --coverage --min-coverage 100
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
