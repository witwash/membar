# local_storage_recipes_api

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A `shared_preferences` implementation of `RecipesApi`.

Libraries, recipes and the id of the library being browsed are stored under
separate keys, each rewritten in full on every mutation, and every change is
published through a single `BehaviorSubject<RecipesSnapshot>` so the three
collections are never observed out of step.

A fresh install — one with no stored schema version — is seeded from the
built-in `LibraryTemplates`. Storage recovers from a bad blob rather than
throwing: unreadable libraries are re-seeded, unreadable recipes come back as
an empty list, and a stale active library id falls back to the first library.
Every recovery is reported through the injected `onRecoveryError`.

Everything above the data layer depends on `recipes_api`, never on this
package. Only the app's flavor entrypoints construct it.

## Development

Run the tests with coverage:

```sh
very_good test --coverage --min-coverage 100
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
