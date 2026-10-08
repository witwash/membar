---
date: 2026-09-12
topic: ingredients-catalog
---

# Ingredients Catalog

## What We're Building

A managed catalog of ingredients that recipes reference by id, so the same ingredient
is entered once and reused. Each catalog entry has a name, a default measurement unit,
and a set of libraries it is visible in. In the recipe editor, an ingredient row's name
field becomes a picker over the catalog; picking an entry prefills the row's unit from
the entry's default. A `+ New ingredient` action in the picker opens a bottom sheet
(name + default unit), and the new entry is automatically scoped to the library the
recipe is being written in.

Scope is not a per-entry chore: it is assigned from context on creation, and widens
through use — the picker lists out-of-scope ingredients in a separate section, and
picking one adds the current library to that entry. A management screen handles the
curation that the recipe editor cannot: rename, change the default unit, edit the
library set, and delete (refused while recipes still use the entry).

## Why This Approach

The alternative considered first was to skip persistence entirely and derive ingredient
options from saved recipes, exactly as `_tagOptions` already does in
`recipe_editor_page.dart` via `libraryTags`. That is far cheaper — no new entity, no
storage key, no migration — but it offers no control: you cannot rename an ingredient,
retire an unused one, or give it a default unit that was never typed. The default unit
is the point of the feature, so a real persisted entity won.

A middle option — a persisted catalog that only assists input, copying the name into the
row with no foreign key — was also rejected. It avoids the Recipe model change and every
orphan question, but renaming `Gin` to `London Dry Gin` would then leave saved recipes
behind. Referencing by id was preferred so a rename propagates.

For placement, the decisive constraint is that the delete guard needs recipes and the
catalog **together** to count usage, and `RecipesSnapshot` is a single `BehaviorSubject`
over one set of `shared_preferences` keys. A separate `IngredientsBloc` would mean two
blocs subscribed to one stream with a guard spanning both; a separate package vertical
would be a nominal boundary (`recipes_api` must depend on it anyway, since
`Ingredient.catalogId` references it) with non-atomic writes across two subjects and
triple the scaffolding against a 100% coverage bar. Extending the existing stack keeps
the usage count as a plain derived getter on one state object, alongside `libraryTags`.

## Key Decisions

- **Managed persisted catalog, not derived options**: a default unit cannot be derived
  from what a user happened to type. Costs a new entity, a fifth prefs key, and a
  `kSchemaVersion` bump from 1 to 2.

- **Recipes reference the catalog by id**: `Ingredient` gains a nullable `catalogId`.
  Nullable because free-text rows stay first-class and because existing recipes must
  decode unchanged. `name` is retained on the row as a fallback.

- **Default unit is `enum + custom escape`**: a sealed `Unit` type with known cases
  (ml, cl, oz, dash, piece, gram, ...) plus `Unit.custom(String)`. A closed enum would
  contradict the documented invariant in `ingredient.dart` that `"1 dash"` and
  `"to taste"` are as valid as `"2 oz"`; a bare string would let `ml` and `mL` diverge.
  Costs hand-written JSON and sealed-class switches at every render site.

- **The row's unit is prefilled but stays editable**: `Ingredient.unit` remains a
  `String`. Picking a catalog entry copies its default unit in as text, which the row can
  override — 30 ml of gin in one recipe, 1 dash in another, without two catalog entries.
  Consequence: the sealed `Unit` type lives only on `CatalogIngredient.defaultUnit` and
  renders to a string when prefilling, so row rendering is unchanged.

- **Delete is blocked while in use**: deleting shows `"Gin is used in 4 recipes"` rather
  than degrading those rows. No orphaned `catalogId` can ever exist, so there is no
  stale-reference resolution path to write or test. Cost: retiring an ingredient means
  editing the recipes that use it first.

- **Library scope is assigned from context, then widens through use**:
  `CatalogIngredient.libraryIds` is set to the active library when created from the
  recipe editor, so creation never asks. The picker shows in-scope entries first and
  out-of-scope entries under a `From other libraries` section; picking from that section
  silently adds the current library to that entry. Scope becomes a record of actual use
  rather than an up-front decision. Cost: a mis-tap widens scope, undoable on the
  management screen.

- **Inline creation is a bottom sheet, not a pushed route**: the picker's
  `+ New ingredient` opens a sheet with name and default unit, returning to the row with
  the entry selected. The editor never unmounts, so its hand-rolled dirty check and
  `TextEditingController`s are untouched, and the default unit is a decision made at
  creation rather than a side effect of the first row typed.

- **Migration starts empty and offers a one-time import**: `kSchemaVersion` 1 -> 2 writes
  `__ingredients_key__ = []` and leaves recipes untouched, so no user recipe data is
  rewritten on upgrade. The catalog's empty state then offers
  `Found N ingredients in your recipes -> [Import them]`, running the same scan on
  demand and visibly.

- **Extend the existing stack**: `CatalogIngredient` and `Unit` into `recipes_api`;
  a fifth key in `LocalStorageRecipesApi`; `ingredients` added to `RecipesSnapshot`;
  pass-throughs on `RecipesRepository`; new events and a derived usage getter on the
  existing `RecipesBloc`, reusing `RecipesMutation` / `RecipesMutationListener`.
  Management UI as a new `lib/ingredients/view/`; picker and sheet as widgets under
  `lib/recipes/widgets/`.

- **Three PRs**: data layer first (no UI), then picker + create sheet, then management.

## Delivery Plan

1. **Data layer only** — `CatalogIngredient`, the sealed `Unit` type and its JSON,
   `Ingredient.catalogId`, `RecipesSnapshot.ingredients`, the `__ingredients_key__` prefs
   key with per-key corruption recovery, the v1 -> v2 migration, `RecipesApi` /
   `RecipesRepository` methods, and `RecipesBloc` events plus the derived usage count.
   Ships nothing user-visible, which is the acknowledged cost of this split.
2. **Picker + create sheet** — the ingredient-row picker with in-scope and
   `From other libraries` sections, widen-on-pick, unit prefill, and the
   `+ New ingredient` bottom sheet. This is the PR that delivers the original complaint.
3. **Management screen** — catalog list and navigation entry, edit name / default unit /
   library set, delete with the usage guard, and the empty-state import action.

## Open Questions

- **Does the picker need search?** `FSelect` / `FMultiSelect` / `FPopoverMenu` are the
  only picker patterns in the app and all are flat lists. Fine at 20 ingredients, noisy
  at 200 — and the two-section scope layout makes a flat list longer, not shorter. Decide
  in PR2 whether a searchable variant is needed, since none exists to copy.

- **What does the import actually write?** The empty-state import can create catalog
  entries only, or also backfill `catalogId` onto matching rows in saved recipes. The
  second is more useful and is a rewrite of user recipe data; the migration decision
  deliberately avoided that on upgrade, so doing it behind an explicit button needs a
  conscious yes.

- **How are names folded?** Tags use `foldCaseInsensitive` / `compareCaseInsensitive` to
  stop a retyped tag sprouting a duplicate. The catalog needs the same protection at
  creation (`Gin` vs `gin`), and the import needs it across recipes. Confirm whether
  folding is case-only or also trims/normalises punctuation.

- **Where does the management screen live in navigation?** There is no nav host beyond
  `LibrarySwitcher` in the recipes page header, and no route table — screens are pushed
  with plain `Navigator`. PR3 needs an entry point decision.

- **What happens to `libraryIds` when a library is deleted?** The library manager is
  unbuilt (deferred as PR2 of the schema-driven libraries plan), so nothing can delete a
  library today. When it can, an ingredient's `libraryIds` could empty out and strand the
  entry. Note it as a constraint for whoever builds library deletion.

- **Creating an ingredient mid-edit persists immediately.** The catalog write is a
  separate mutation from the recipe save, so creating `Bourbon` and then abandoning the
  recipe leaves `Bourbon` in the catalog. Probably correct — but it means PR2 needs a
  second `RecipesMutation` value that the editor listens for without treating it as a
  recipe save.

- **Does the details screen change?** `recipe_details_page.dart` renders ingredient rows
  for reading. Referenced rows could render the catalog's current name (so renames show)
  or the stored row name. Decide in PR2.
