---
date: 2026-10-17
topic: ingredient-libraries
---

# Ingredient Libraries

## What We're Building

Replace the single global ingredient catalog with named **ingredient libraries**. Each
recipe library (cocktail library) points at exactly one ingredient library, chosen when
the recipe library is created. You can either pick an existing ingredient library or
create a new one. One ingredient library can serve several recipe libraries. Ingredients
in different ingredient libraries are unrelated even when they share a name: `Lime juice`
in *Bar pantry* and `Lime juice` in *Coffee shelf* are two separate entities.

Ingredients can be **copied** or **moved** between ingredient libraries, and are managed
on the Ingredients screen through a switcher between ingredient libraries. Some edits
affect recipes beyond the one being worked on:

- renaming or changing the unit of an ingredient that another recipe library uses;
- moving or deleting an ingredient that any recipe uses.

When an edit has that kind of impact, a dialog lists the affected recipes and recipe
libraries before anything changes. The user can choose *Continue anyway* or cancel.
Edits with no impact go through silently.

This feature is a prerequisite for the starter recipes import
(`2026-10-17-starter-recipes-import-brainstorm-doc.md`). That import resolves ingredients
into the target recipe library's ingredient library.

## Why This Approach

Two data shapes were considered:

- **Separate entity with a foreign key (chosen).** A new `IngredientLibrary(id, name)` is
  stored under its own prefs key. `CatalogIngredient` replaces `libraryIds: Set<String>`
  with a single `ingredientLibraryId`. `Library` gains an `ingredientLibraryId` that is
  fixed after creation. This is the smallest step from today's flat collection per key,
  and keeps the deliberate one-bloc, one-snapshot design from the ingredients-catalog
  brainstorm. Uniqueness becomes a per-library rule.
- **Ingredients nested inside their library's blob (rejected).** Ownership would be
  structural, but every ingredient edit would rewrite the whole library. A move would touch
  two library blobs plus recipes. It also breaks the flat-collection pattern the storage
  layer uses everywhere else.

The impact check is a **pure function over the snapshot** in `RecipesState`, built from the
existing `ingredientUsage` / `libraryIdsUsingIngredient` getters. The UI asks "what would
this affect?" before it dispatches the event. The repository mutation then applies the
cascade (ingredient change plus recipe-row removal) atomically, following the existing
`deleteLibrary` / `importIngredients` write ordering: children first, then a single emission.

## Key Decisions

- **Ingredient libraries are named, user-managed entities.** They can be renamed. The
  Ingredients screen gets a switcher between them, mirroring the recipe library switcher.
  Copy and move need a named destination anyway.
- **One recipe library has one ingredient library, fixed at creation.** Switching later
  is out of scope. To reorganise, copy or move ingredients. Re-pointing would be a
  mass-relink that could strip every recipe in one click.
- **Creating a recipe library offers a choice of ingredient library.** The options are
  *Create new*, defaulting to the recipe library's name, or *Use existing*, picked from a
  list. The editor sheet gains this control next to the existing starting-point picker.
- **Names are unique per ingredient library, case-insensitive.** The global uniqueness in
  `_merged` becomes scoped. Every name lookup moves to the recipe library's ingredient
  library: `_linked`, `ingredientNamed`, `ingredient_row_field.dart`, and the picker.
- **The scope-widening flow goes away.** `RecipesIngredientScopeWidened`, the library
  checkboxes in the ingredient editor sheet, and the *other libraries* section of the
  picker are removed. The picker shows only the linked ingredient library.
- **Free-text recipe rows are no longer allowed.** This reverses the catalog brainstorm's
  decision that "free-text rows stay first-class". Every row references an ingredient in
  the recipe library's ingredient library. Typing an unknown name creates the ingredient
  there, through the existing inline create sheet. This keeps the "row removed when the
  ingredient is gone" rule consistent.
- **Copy** creates a new ingredient (new id, same name and default unit) in the target
  library. It never touches recipes.
- **Move** re-homes the ingredient and **removes the rows that reference it from every
  recipe** whose recipe library uses the source ingredient library. This covers the current
  recipe library as well as the others. The ingredient no longer exists where those
  recipes look for it.
- **Delete follows the same rule as move.** An in-use ingredient can be deleted: the user
  is warned, and its rows are removed from recipes if they continue. This replaces today's
  `IngredientInUseException` refusal.
- **Name clashes on copy or move are refused per ingredient.** If the target already has
  that name, that ingredient is skipped with `IngredientNameTakenException` and the
  existing refusal toast. In a multi-select operation, the others still go through, and
  the toast lists the ones skipped.
- **When the warning fires:**
  - Rename or default-unit change: warn only when recipes in **another** recipe library
    sharing the ingredient library use the ingredient.
  - Move or delete: warn when **any** recipe uses the ingredient, because rows will be
    removed.
  - Adding an ingredient, or editing one that nobody uses: never warn. This resolves the
    open question in the starter-recipes brainstorm: there is no warning on additions.
- **The warning is a dialog shown before the action, and only when there is impact.** It
  is a non-destructive variant of `showConfirmDialog` that lists the affected recipe
  libraries and recipes, with *Continue anyway* and *Cancel* buttons. Row removal can't be
  undone and there is no undo, so the notice must come first. A post-action toast was
  rejected for that reason. An inline banner was rejected because list-level actions have
  no sheet to host it.
- **Ingredient libraries outlive their recipe libraries.** Deleting the last recipe
  library that uses an ingredient library leaves the ingredient library in place, available
  to pick or copy from. It can be deleted manually from the Ingredients screen, and that
  delete is refused while any recipe library uses it. The recipe-library delete sheet's
  successor handover for ingredients (`ingredientCountOnlyIn`, `_withoutLibrary`) goes away.
- **No migration: reseed.** Following the WIP rule, `kSchemaVersion` is bumped and the
  store reseeds. A fresh install gets *Cocktails* and *Coffee*, each with its own ingredient
  library. The one-time `importIngredients` path and the `ingredients_import_version` flag
  are dropped.

## Open Questions

- **Ingredient library names:** should they be unique globally, like recipe library names
  are today? The proposed answer is yes, so the *Use existing* picker and the copy/move
  target list are unambiguous.
- **Copy/move entry point and multi-select:** should the Ingredients screen gain a
  selection mode, so several ingredients can be copied or moved at once, or is a
  per-ingredient action in the editor sheet or a long-press menu enough for v1?
- **Recipe with no ingredients left:** a move or delete can strip a recipe's last row.
  Should the impact dialog call that out, or is an empty ingredient list acceptable?
- **Templates:** should creating a recipe library from the Cocktails or Coffee starting
  point with *Create new* seed any ingredients, or start empty? The starter-recipes import
  may make this moot.
- **Delete-library sheet:** with the ingredient handover gone, does it still need a
  successor picker? It currently uses one for the active-library fallback as well.
- **Documentation:** `docs/known-issues.md` currently says catalog entries are never
  deleted when a library goes away, and describes name folding. Both statements need
  revising.
