---
date: 2026-10-17
topic: starter-recipes-import
---

# Starter Recipes Import

## What We're Building

A bundled catalog of starter recipes, about 20 coffee and 50 cocktail recipes, that the
user browses from inside a library and imports by picking recipes. A library created from
the Cocktails or Coffee template records that template. That marker is how the library
knows which starter set to offer. A blank or custom library has no marker and offers no
catalog.

The catalog screen is a searchable list. Each row shows the recipe name, a short subtitle
(key ingredients or brew method) and a checkbox. The screen also has `Select all` and an
`Import N` button, and no detail page. The cocktail set has an ml/oz toggle. The bundle
stores both measures, but an imported recipe keeps only the chosen system and edits like
any recipe the user wrote.

Importing a recipe also adds its ingredients:
- A bundled ingredient whose name matches an entry in the library's ingredient library
  (ignoring case) is linked to that entry.
- An ingredient with no match is created there, with its default unit.

This applies to coffee and cocktails alike. Coffee simply has fewer ingredients: beans,
water, milk and syrups.

This feature also makes recipe names unique within a library, ignoring case, in both the
editor and the import. When picked recipes clash with existing names, a rename sheet
lists each clash with an editable name field before anything is written.

**Depends on:** the ingredient-libraries rework, which is a separate brainstorm and must
land first. In that model, ingredients live in ingredient libraries that are separate
from each other. A recipe library either creates its own ingredient library or chooses an
existing one. Several recipe libraries can share one. Editing a shared ingredient shows a
warning that doesn't block the edit. Entries can be copied or moved between ingredient
libraries. An entry in one ingredient library has nothing to do with an entry of the same
name in another. This import targets the ingredient library of the recipe library being
imported into, not today's global catalog with its `libraryIds` scope.

## Why This Approach

**Bundled data format.** The options were:
- Typed Dart data next to `LibraryTemplates`, which was recommended for its compile-time
  safety and sync loading.
- JSON asset files.
- A remote catalog.

JSON assets won. Seventy recipes are content rather than code. JSON keeps them compact and
editable without touching Dart. The cost is accepted: parse errors only surface at
runtime, asset loading has to be wired up, and a schema test is needed. That test must
parse every bundled file and check it against the templates. A remote catalog was ruled
out under YAGNI, since nothing calls for updates between releases.

**Entry point.** The options were:
- One-tap "import all".
- Auto-seeding on fresh install.
- Browse and pick.

Browse and pick won, so the user curates their library instead of deleting 50 recipes
they don't want. The catalog sits inside a library, so the import target is never in
question.

**Which set to show.** The options were:
- Always showing both sets in tabs.
- Inferring the kind from field shape.
- An explicit template marker.

The marker won. It is unambiguous, and the library editor's starting-point picker (blank,
Cocktails or Coffee) already knows the template at creation time.

**Field values.** Values map by field label because field ids are random per install. A
stable per-field template key would survive renames, but it adds schema for a rare case.

**Duplicates.** Recipe names were assumed to be unique. They are not: only library and
ingredient names are enforced today, via `LibraryNameTakenException` and
`IngredientNameTakenException`. Rather than tracking a source id per recipe, the decision
is to make recipe names unique within a library everywhere, matching the other two
entities. A clash at import time then becomes a rename prompt.

## Key Decisions

- **Browse and pick, from inside a library.** The catalog opens from a library that has a
  template marker and imports into that library.
- **Template marker on `Library`.** It is set from the library editor's starting point,
  and blank means no marker. No backfill or migration for existing installs, because the
  app is WIP and a reseed is acceptable.
- **Field values map by label,** ignoring case, onto the target library's fields. A value
  is dropped when the field was renamed or deleted, when a select value is no longer
  among the options, or when a number field gets something that isn't a number.
- **Recipe names are unique per library, ignoring case, everywhere.**
  - A new `RecipeNameTakenException` is enforced on save and on import.
  - The editor shows a refusal toast like the ingredient and library ones.
  - Names fold the same way ingredient names do, on case and surrounding whitespace.
- **A clash means a rename prompt for each recipe.** Before writing, a sheet lists every
  picked recipe whose name is taken, each with an editable name field. A name must be
  free against both the library and the other picks before `Import` is enabled.
- **Ingredients resolve into the recipe library's ingredient library.** A name match
  (ignoring case) is linked and left unchanged. A missing ingredient is created with the
  bundled default unit. Coffee and cocktails follow the same rule on one code path.
- **ml/oz is chosen at import time only.** The bundle carries both measures for cocktails.
  Imported rows store the chosen one, and there is no app-wide unit setting.
- **The import is atomic.** All picked recipes and every new ingredient are written in one
  snapshot, like the `importIngredients` precedent. Any failure writes nothing.
- **JSON asset files.**
  - Each bundled recipe has a stable key, its name, tags, steps and notes.
  - Field values are keyed by label.
  - Each ingredient has a name, a default unit, and a quantity for each measure system.
  - A test parses every file and checks it against the templates: labels exist, select
    values are among the options, units are valid, and names are unique within each set.
- **Catalog UI is a list with multi-select.** It has search, a subtitle on each row,
  checkboxes, `Select all` and `Import N`. It has no preview page and no tag grouping.
- **Recipe names and content are not localized.** They become user data, the same rule
  as for template names and field labels.

## Open Questions

- **Asset location and loading.** The options are app-level `assets/` loaded through
  `rootBundle`, or a Flutter package that owns the files. The DTO and `fromJson` could
  live in the pure-Dart `recipes_api`, with only the loading in the app layer. Decide
  where the boundary goes.
- **Template marker shape.** It could be an enum or a string id, and it could be fixed at
  creation or editable later. Should a heavily edited Cocktails library still offer the
  catalog? Leaning yes, with dropped values accepted.
- **Rows already in the library.** Should the catalog mark rows whose name already exists
  in the library, for example `In library`? That would warn the user before the rename
  sheet appears.
- **Feedback for dropped field values.** Should dropped values be silent, or should the
  import toast summarise them, for example "3 values didn't match this library's fields"?
- **Shared ingredient libraries.** Importing adds new entries that other recipe libraries
  sharing that ingredient library will see. Does the shared-edit warning cover additions,
  or only changes to existing entries? Leaning towards changes only. The import never
  modifies existing entries.
- **Does coffee get the ml/oz toggle?** Coffee fields are fixed in g and °C, but milk and
  syrup rows have volumes. Leaning towards metric only for coffee.
- **Ingredient naming in the bundle.** Names only fold on case and whitespace (see
  `docs/known-issues.md`), so the bundle needs canonical, simple names such as
  `Lime juice` rather than `Fresh lime juice` to avoid near-duplicates of what users
  typed.
- **Content authoring.** Who writes the 70 recipes, and against which reference? IBA
  specs are the obvious choice for the classic cocktails. Steps must be written in our
  own words, not copied verbatim.
- **Entry point placement.** It could be a library screen action, the recipes empty
  state, or both.
