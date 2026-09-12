# Simplicity/YAGNI review — `feat/ingredients` branch diff

Scope: `git diff 4c6c2795a6c0fcb6f47394093b914ddd8f747507..HEAD` (57 files, ~6500
insertions), read against
`docs/plan/2026-09-12-feat-add-ingredients-catalog-plan.md`. The plan's named, deliberate
complexity bets (sealed `Unit`, mutation serialization, per-emission mutation kinds, the
rejected alternatives) are treated as settled and are not relitigated below. Implementation
was checked against the plan's own sketches and none exceeds what the plan describes.

## Core Purpose

Give recipes a persisted, renameable ingredient catalog with a default unit, offered as an
autocomplete in the recipe editor (Phase 2) and curated on a management screen (Phase 3),
without recipes retyping the ingredient's identity on every use.

## Layering check (item 2) — clean

```
grep -rn "package:membar/recipes/widgets\|package:membar/recipes/view\|package:membar/recipes/bloc" lib/ingredients/
```
returns nothing. `lib/ingredients/` imports only `package:membar/recipes/recipes.dart` (the
bloc barrel) plus `package:membar/ui/ui.dart`, exactly as the plan requires. The two
feature-agnostic widgets (`confirm_dialog.dart`, `failure_banner.dart`) were moved to
`lib/ui/` as the plan specifies, and `lib/recipes/widgets/` no longer contains them. No
violation found.

## Duplication (item 1) — the one substantial finding

`lib/recipes/widgets/ingredient_create_sheet.dart` (Phase 2, create-only) and
`lib/ingredients/widgets/ingredient_editor_sheet.dart` (Phase 3, edit) are near-identical in
structure, and the duplication goes well beyond what the plan's two-line note ("The create
sheet (Phase 2) and the edit sheet (Phase 3) share `RecipesMutation.ingredientSaved`... they
are never open at once") anticipates. Specifically, both files duplicate:

- The exact `showFSheet<...>` route-opening boilerplate (bloc re-provide via
  `BlocProvider.value`, `side: FLayout.btt`, `mainAxisMaxRatio: null`).
- The `_chosenUnit` getter — byte-identical in both files (lines
  `ingredient_create_sheet.dart:144-153` and `ingredient_editor_sheet.dart:224-233`).
- The standard/custom unit toggle: an `FSelect<StandardUnit>` built from
  `StandardUnit.values` mapped through `KnownUnit(unit).label`, an `FButton.ghost` that flips
  a `_custom` bool, and a keyed `FTextFormField` for the custom label — present in both
  widgets with only cosmetic differences (the create sheet additionally locks the control
  when reusing an existing entry, which is Phase 2-specific behavior, but the base
  standard/custom switching logic is identical).
- The sheet scaffold: `RecipesMutationListener` on `RecipesMutation.ingredientSaved` →
  `DecoratedBox` with the same border/background decoration → `SingleChildScrollView` padded
  with `AppInsets.sheetContent` → `Form` → a `Column` with `AppSpacing.spacing200` gaps → a
  save `FButton` disabled while `saving` → a cancel/outline `FButton` that pops.
- The `saving` selector (`context.select<RecipesBloc, bool>` reading
  `mutation == ingredientSaved && mutationStatus == loading`) is copy-pasted verbatim in both
  files.
- Disposal of `_nameController`/`_customUnitController` — identical `dispose()` bodies.

None of this is inherent to "create" vs. "edit" being different operations; it is the same
form scaffolding, the same unit-selector widget, and the same mutation-watching boilerplate,
copy-pasted rather than factored into one shared internal widget (e.g. a
`_UnitSelector`/`_IngredientSheetScaffold` used by both, parameterized by title/labels and a
callback for save). The plan does not mention this sharing opportunity, and Phase 3 was
written after Phase 2 already existed, so the second sheet had a working template to extract
from rather than duplicate.

Estimated reduction: the unit-selector block and sheet scaffold together are roughly
80-100 lines duplicated across the two files; extracting a shared widget could plausibly
remove 60-90 LOC net (accounting for the extraction's own parameterization) and would remove
a maintenance hazard — the two `_chosenUnit` getters and two unit-toggle blocks will drift
silently if one is changed without the other (e.g. a future unit picker enhancement).

This is a real simplification opportunity, not a blocker: both sheets work correctly and are
independently well-tested. Flagged as medium-priority cleanup rather than a defect.

## Picker vs. management-screen duplication (item 1, second half) — not found

`lib/recipes/widgets/ingredient_picker.dart` and `lib/ingredients/view/ingredients_view.dart`
do **not** duplicate library-name sorting, usage-count lookup, or unit-label rendering:

- Library-name sorting: the picker doesn't sort by library name at all (it partitions
  in-scope/out-of-scope via bloc getters `libraryIngredients`/`otherLibraryIngredients`,
  which already sort). The management screen's `_describe` sorts library names for display
  using the shared top-level `compareCaseInsensitive` (from `recipes_api`/`tags.dart`) —
  the same function the bloc's own sorting uses, not a re-implementation.
- Usage-count lookup: the management screen reads `state.ingredientUsage` once per build and
  hoists it into a local (`usage`), exactly as the plan specifies; the picker has no usage
  concept at all.
- Unit-label rendering: both read `entry.defaultUnit?.label` directly — a one-line field
  access, not logic worth extracting.

No finding here.

## Unnecessary state (item 3) — none found

- `IngredientPicker`'s `_prefilledUnit` field is exactly what the plan calls for ("Remembering
  the previous default needs one `String? _prefilledUnit` field... plain state, not a
  controller").
- `IngredientCreateSheet`'s `_pending`, `_saveFailed`, `_custom`, `_standardUnit` and
  `IngredientEditorSheet`'s `_libraryIds`, `_submitted`, `_saveFailed`, `_custom`,
  `_standardUnit` are all driven by user interaction or a pending async result and cannot be
  derived from the bloc's state — they are legitimately local UI state (which unit-mode toggle
  is active, whether validation should show a failure banner). No redundant duplication of
  bloc state was found; both sheets read `RecipesBloc` state directly via `context.select`/
  `context.read` for anything the bloc owns (the catalog, the saving flag).
- `IngredientsView` is a `StatefulWidget` only to hold the transient `_failure` banner message
  set by two `RecipesMutationListener`s — this mirrors the existing pattern already used
  elsewhere in `lib/recipes/` (e.g. the recipe editor's own failure banner state) and is not
  new complexity introduced by this branch beyond that convention.

No finding here.

## Dead code (item 4) — none found

- Barrels (`lib/ingredients/ingredients.dart`, `lib/recipes/recipes.dart`, `lib/ui/ui.dart`)
  export only symbols that are used by at least one other file or test; `ImportableIngredient`,
  `catalogEntryNamed`, `IngredientOption`/`CatalogOption`/`CreateOption` are all referenced
  from tests or sibling widgets.
- No `TODO`/`FIXME` markers were introduced by the diff.
- No unused imports were spotted in the changed files reviewed in depth
  (`ingredient_create_sheet.dart`, `ingredient_editor_sheet.dart`, `ingredient_picker.dart`,
  `ingredients_view.dart`, `recipes_bloc.dart`, `recipes_state.dart`, `recipes_event.dart`,
  `ingredient_row_field.dart`).
- `showRecipeConfirmDialog` (the pre-rename name) does not appear anywhere in `lib` or `test`,
  confirming the rename to `showConfirmDialog` was completed cleanly with no leftover
  references.

No finding here.

## General YAGNI (item 5) — none beyond plan-justified complexity

- `RecipesState.ingredientUsage`, `libraryIngredients`, `otherLibraryIngredients`,
  `ingredientById`, `importableIngredients` are all named and justified in the plan's "Bloc
  surface" section, and the implementation matches the plan's sketch member-for-member — no
  extra methods or fields were added beyond it.
- `RecipesMutation.ingredientSaved/ingredientDeleted/ingredientsImported` and
  `RecipesIngredientScopeWidened` (reporting nothing) match the plan's explicit design
  ("Scope widening reports nothing... a mutation kind that exists only so other listeners can
  ignore it is machinery serving no reader" — and indeed no such kind was added).
- `Unit`/`KnownUnit`/`CustomUnit` implementation matches the plan's sketch exactly: `label`
  is the only accessor, both override `props`, `CustomUnit` trims and asserts non-blank. No
  extra methods.
- `_serialized` mutation queue in `local_storage_recipes_api.dart` matches the plan's sketch
  verbatim (same doc comment, same shape).

No finding here.

## Final Assessment

The branch is unusually disciplined for its size — the plan pre-justifies nearly every piece
of complexity that would normally draw a YAGNI flag, and the implementation does not exceed
those sketches anywhere checked. The single real simplification opportunity is the
create-sheet/edit-sheet duplication (unit selector, sheet scaffold, `_chosenUnit`, the saving
selector) — worth a small follow-up extraction, not a blocker for this PR.

Total potential LOC reduction: roughly 2-3% of the branch's insertions (60-90 LOC out of
~6500), concentrated in one pair of files.
Complexity score: Low (the flagged item is duplication, not over-engineering).
Recommended action: Minor tweaks only — extract a shared unit-selector/sheet-scaffold widget
used by both `IngredientCreateSheet` and `IngredientEditorSheet` in a follow-up, if/when a
third such sheet or a unit-selector change makes the duplication costlier to maintain.
