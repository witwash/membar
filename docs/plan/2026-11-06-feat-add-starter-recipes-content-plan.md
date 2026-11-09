---
title: "feat: add starter recipes content"
type: feat
date: 2026-11-06
---

## feat: add starter recipes content

> Source: `docs/brainstorm/2026-11-06-starter-recipes-content-brainstorm-doc.md`. Its key
> decisions are the requirement. This plan records how its open questions were settled. The
> import flow (`2026-10-17-starter-recipes-import-brainstorm-doc.md`: template marker,
> `RecipeNameTakenException`, catalog screen, atomic import) is **out of scope** and gets its
> own plan. That plan consumes this bundle.

## Context

The starter-recipes import needs content: 42 cocktails and 12 coffees, each set with a
canonical, keyed ingredient list. This plan ships the content as JSON in a new
`starter_recipes` Flutter package. The package also holds the DTOs and an asset loader, and a
schema test that validates the bundle against `LibraryTemplates`. It also makes the two model
changes the content needs: a `pinch` unit, and three new Cocktails glassware options.

Nothing in the app reads the bundle yet. The import plan adds the app dependency and the UI.

First build step: save this plan as
`docs/plan/2026-11-06-feat-add-starter-recipes-content-plan.md`.

## Decisions

### Open questions from the brainstorm, settled here

| Question | Answer |
|---|---|
| Units outside `StandardUnit` | **Add `StandardUnit.pinch`.** Salt and Black pepper default to it. Chocolate sauce uses `ml`. Every unit in the bundle is a `StandardUnit`. |
| Quantity format | **Decimal strings**, for example `"0.75"` and `"22.5"`. No fractions. The test requires every quantity to parse as a positive `num`. |
| Tag vocabulary | **Lowercase. A style tag plus the base spirit(s).** Cocktail style: `stirred`, `sour`, `long`, `sparkling`, `tiki` (the *Other* group gets no style tag). Spirit: `gin`, `vodka`, `rum`, `whiskey`, `tequila`, `brandy`, `cachaça` (Pisco counts as `brandy`, Vieux Carré gets both `whiskey` and `brandy`, and Americano and Aperol Spritz get none). Coffee: `espresso`, `milk`, `filter`, `immersion`, `stovetop`, `cold`. The test enforces the list. |
| Glass for each tiki drink | Mai Tai: `Rocks`. Jungle Bird: `Rocks`. Piña Colada: `Tiki`. Also: Aperol Spritz `Wine`, Mint Julep `Julep cup`, Moscow Mule `Mug`, French 75 `Flute`. |
| Default unit when importing in oz | **Deferred to the import plan.** The bundle records the metric default (`ml`). |
| Oct 17 doc upkeep | Add a short note under its title: counts and bundle shape are superseded by the Nov 6 doc and this plan. The body is left as history. |
| Asset location (Oct 17 question) | **New `packages/starter_recipes` Flutter package** that owns the JSON, the DTOs and the loader. |

### Decisions made in this plan

- **Row shape.** A row takes one of two forms. The test enforces this.
  - Volume (cocktails only): `{"ingredient": "lime_juice", "ml": "22.5", "oz": "0.75"}`.
  - Counted, or any coffee row: `{"ingredient": "angostura_bitters", "quantity": "2", "unit": "dash"}`.
    Coffee rows use only `gram` or `ml`. A counted cocktail row never uses `ml`, `cl`, `oz` or
    `gram`.
- **`ml == oz × 30`** on every volume row, within 0.01. This is the bartender-standard rule from
  the brainstorm, and the test checks it so that a typo in one column is caught.
- **Field values are a `fields` map keyed by label.** Select and text values are JSON strings,
  and number fields are JSON numbers (`"Dose": 18`). `Garnish` is a field value, not a row.
  Coffee recipes never set `Tasting notes`.
- **Units decode as `StandardUnit` by enum name** (`"ml"`, `"gram"`, `"pinch"`), so an unknown
  unit fails at parse time.
- **The DTOs are fromJson only** (`@JsonSerializable(createToJson: false)`), with Equatable
  like the `recipes_api` models.
- **`StarterRow.measured(MeasureSystem)`** returns `(String quantity, StandardUnit unit)`. A
  volume row gives `ml` or `oz`, and a counted row gives the same value in both systems. This
  pins down what the bundle means, and the import plan reuses it.
- **The Cocktails glassware order** is `Coupe, Rocks, Highball, Collins, Martini,
  Nick and Nora, Flute, Wine, Julep cup, Tiki, Mug`.
- **The ingredient lists are exactly what the recipes reference.** The test fails on an unused
  ingredient, as the brainstorm requires.

### Bundle layout

```
packages/starter_recipes/assets/
  cocktails/ingredients.json   [{ "key", "name", "defaultUnit" }]
  cocktails/recipes.json       [{ "key", "name", "tags", "steps", "notes", "fields", "rows" }]
  coffee/ingredients.json
  coffee/recipes.json
```

## Phase 1 — Model and template changes

`packages/recipes_api`
- [ ] `lib/src/models/unit.dart`: add `pinch` to `StandardUnit`, after `piece`, with a doc
  comment ("A pinch, as of salt."). The `FSelect` in `lib/ui/default_unit_field.dart:133`
  iterates `StandardUnit.values`, so it picks the new value up with no other change.
- [ ] `lib/src/templates/library_templates.dart`: Glassware options in the order above.
- [ ] `test/src/templates/library_templates_test.dart`: assert the exact Glassware option list.
- [ ] Unit tests: a `pinch` round-trip through `Unit.fromJson` and `toJson`.

`packages/local_storage_recipes_api`
- [ ] `local_storage_recipes_api.dart:75`: `kSchemaVersion` goes to `4`. The doc comment
  already explains the reseed, so only the number changes. No migration (WIP rule).
- [ ] Test: update the "version 2 install is discarded and reseeded" case (~:255) so it also
  covers a version 3 install, which must now be reseeded.

## Phase 2 — `starter_recipes` package

- [ ] Scaffold `packages/starter_recipes` as a Flutter package (`very_good create
  flutter_package`, or by hand to match `local_storage_recipes_api`). It gets `publish_to: none`
  and the same SDK and Flutter constraints. It depends on `flutter`, `recipes_api` (path),
  `equatable` and `json_annotation`. Dev dependencies are `build_runner`, `json_serializable`,
  `flutter_test` and `very_good_analysis`. Copy `build.yaml` from `recipes_api` for the
  coverage-ignore header. Declare `assets/cocktails/` and `assets/coffee/` under `flutter:`.
- [ ] `lib/src/models/`: `StarterIngredient {key, name, defaultUnit: StandardUnit}`,
  `StarterRow {ingredient, ml?, oz?, quantity?, unit?}` (assert exactly one complete form, plus
  `measured`), `StarterRecipe {key, name, tags, steps, notes = '', fields: Map<String, Object>,
  rows}` and `StarterSet {ingredients, recipes}`. Also `enum MeasureSystem {metric, imperial}`
  and `enum StarterCollection {cocktails, coffee}`.
- [ ] `lib/src/starter_recipes_loader.dart`: `StarterRecipesLoader(AssetBundle bundle)` with
  `Future<StarterSet> load(StarterCollection)`. It reads
  `packages/starter_recipes/assets/<collection.name>/{ingredients,recipes}.json`.
- [ ] Barrel file `lib/starter_recipes.dart`. Run `dart run build_runner build
  --delete-conflicting-outputs`.
- [ ] Seed `assets/*/*.json` with `[]` so the loader and the schema test run before content
  lands.
- [ ] `.github/workflows/main.yaml`: add a `build-starter-recipes` job modelled on
  `build-local-storage-recipes-api` (`flutter_package.yml`, `working_directory:
  packages/starter_recipes`).

Tests (`packages/starter_recipes/test/`):
- [ ] DTO tests: both row forms parse; a row with neither form, or with both, is rejected;
  `measured` covers both systems for volume and counted rows; an unknown unit throws.
- [ ] Loader test: a fake `AssetBundle` keyed by the expected asset paths returns the parsed
  set.
- [ ] **Schema test** (`test/src/bundle_test.dart`). It loads both collections through the real
  loader, using a `CachingAssetBundle` subclass that reads files from disk by removing the
  `packages/starter_recipes/` prefix. For each set it checks against
  `LibraryTemplates().cocktails(...)` / `.coffee(...)`:
  - recipe keys are unique, and names are unique ignoring case (`compareCaseInsensitive`);
  - ingredient keys are unique, and names are unique ignoring case;
  - every row's ingredient resolves, and every ingredient is used at least once;
  - every `fields` label exists in the template; select values are among the options; number
    fields hold a `num` and other fields a non-blank `String`;
  - row form per set (see *Row shape*), quantities parse as positive decimals, and
    `ml == oz × 30`;
  - tags come from the fixed vocabulary, and every recipe has at least one step;
  - cocktails: every recipe has `Glassware`. Coffee: every recipe has `Brew method` and a
    `coffee_beans` row, and none sets `Tasting notes`;
  - counts of 42 and 12. **Added in phase 3**, because the empty seed fails them.
- [ ] Declaration check: one `flutter_test` case that loads each of the four files through
  `rootBundle` under the root-package key (`assets/cocktails/recipes.json`), proving the
  pubspec declares them. If `flutter test` does not resolve root-package assets this way, drop
  the case and leave the check to the import plan's app-level test.

## Phase 3 — Content

Write the four JSON files. The recipe lists and ingredient naming policy are fixed by the
brainstorm (*Cocktails (42)*, *Coffee (12)*, *Naming policy*, *Draft cocktail ingredient
list*).

- [ ] Cocktails: IBA specs for the classics, and established published specs for the modern
  ones (Paper Plane, Penicillin, Jungle Bird, Tommy's Margarita, and so on). **Steps are written
  in our own words.** Garnish goes in the `Garnish` field. Mint that is muddled or shaken is a
  `mint_leaves` row. Caipirinha uses a whole `lime` row in `piece`. Margarita's salt rim is a
  garnish. Salt and Black pepper (`pinch`) appear only where they go into the drink (Bloody
  Mary).
- [ ] Coffee: the 12 drinks from the brainstorm. Pour over (V60) uses the `Pour over` option,
  and milk drinks use `Espresso`. Typical values, for example espresso 18 g at 93 °C. Rows draw
  only on `coffee_beans` (gram), `water`, `milk` and `chocolate_sauce` (ml).
- [ ] Small swaps are allowed if a recipe would add an ingredient nothing else uses. Record any
  swap in the PR description.
- [ ] Turn on the count assertions in the schema test.

## Phase 4 — Docs

- [ ] Oct 17 brainstorm: add the superseded-in-part note under the title.
- [ ] `docs/known-issues.md`: no change expected. Name-folding near-duplicates are already
  listed, and the canonical names are the mitigation.

## Critical files

- `packages/recipes_api/lib/src/models/unit.dart`
- `packages/recipes_api/lib/src/templates/library_templates.dart`
- `packages/local_storage_recipes_api/lib/src/local_storage_recipes_api.dart` (`kSchemaVersion`)
- `packages/starter_recipes/**` (new)
- `.github/workflows/main.yaml`

Reused: `LibraryTemplates`, `StandardUnit`, `compareCaseInsensitive`
(`packages/recipes_api/lib/src/models/tags.dart:3`), and `recipes_api`'s `build.yaml`.

## Verification

- `dart test` in `packages/recipes_api`, and `flutter test` in
  `packages/local_storage_recipes_api` and `packages/starter_recipes`, all pass, including the
  schema test against the full content.
- `flutter test` at the root still passes: the unit picker now lists `pinch`, and nothing else
  changes.
- `dart analyze` / `flutter analyze` and `dart format --set-exit-if-changed` are clean in
  every touched package.
- Run the app on a simulator: an existing install reseeds (schema 4), a new Cocktails library
  offers the three new glasses, and the default-unit picker shows `pinch`.
- Spot-check five recipes by hand against their IBA specs (Negroni, Daiquiri, Mai Tai, Bloody
  Mary, Mint Julep), and check that no steps text is copied verbatim.
