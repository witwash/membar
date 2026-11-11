# starter_recipes

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The bundled starter recipes: 42 cocktails and 12 coffees, each set with its own
canonical ingredient list, and `StarterRecipesLoader`, which reads a set from
the package's assets.

Each set is two JSON files under `assets/<template>/`, named after its
`LibraryTemplate`:

- `ingredients.json` lists every ingredient once, with a stable `key`, a
  `name` and a `defaultUnit`.
- `recipes.json` holds the recipes. Field values are keyed by field label, and
  each row references an ingredient by key. A cocktail volume row carries both
  `ml` and `oz` (30 ml to 1 oz). A counted row, and every coffee row, carries
  one `quantity` and `unit`.

`test/src/bundle_test.dart` checks both sets against `LibraryTemplates`. Run it
after every content edit.

## Development

Run the tests with coverage:

```sh
very_good test --coverage --min-coverage 100
```

[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
