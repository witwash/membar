## VGV Code Review

Scope: `git diff 4c6c279..HEAD` on `feat/ingredients` (57 files, +6584/-82), reviewed against
`docs/plan/2026-09-12-feat-add-ingredients-catalog-plan.md`. Plan decisions (one `RecipesBloc`,
numeric `AppSpacing` names, `lib/ingredients` importing the recipes barrel, catch-per-exception
handlers, whole-blob recovery mirroring `_readRecipes`) are treated as settled.

### Summary

Ready to merge after one small consolidation. The branch follows the plan closely: all three
phases land, the migration ordering rules are implemented and tested, mutation serialization is
in the api layer where the plan put it, every handler names its own mutation kind, and the widget
tests drive a `MockBloc` with leak tracking on both sheets. I found no correctness bug that a user
can reach today.

Mechanical gates, all observed green:
- `flutter analyze` at the root and in all three packages: no issues.
- `dart format --set-exit-if-changed`: 0 files changed.
- `flutter pub run bloc_tools:bloc lint .`: 0 issues.
- very_good_cli MCP `test` with `min_coverage: 100`: root (300 tests), `recipes_api` (120),
  `local_storage_recipes_api` (47), and `recipes_repository` (12). All passed.
- Plan grep criteria: no data-package imports in presentation; `lib/ingredients` uses no deep
  recipes imports; `showRecipeConfirmDialog` is gone; `withTrackedAll` is present in both test
  trees.

The one Important finding: the rule "a name resolves to the catalog entry it folds onto" is a
domain rule. It lives as a top-level function in a widget file, and the edit sheet implements it
a second time. Everything else is a suggestion.

### Critical: Must Fix Before Merge

None.

### Important: Should Fix

- **lib/recipes/widgets/ingredient_picker.dart:18** and **lib/ingredients/widgets/ingredient_editor_sheet.dart:208**: the name-to-entry folding rule lives in presentation and exists in two forms.
  - Why: invariant 1 (a row links to the entry whose name folds equal) and the uniqueness check
    behind invariant 2 are business rules. `catalogEntryNamed` is a public top-level function in a
    widget file. It is re-exported through the recipes barrel and consumed by
    `IngredientRowControllers.ingredientIn`, the create sheet's reuse path, and its unit section.
    The edit sheet's `_validateName` implements the same rule inline with `compareCaseInsensitive`;
    `catalogEntryNamed` uses `trim().toLowerCase()`, and `importableIngredients`
    (`recipes_state.dart:180`) uses a third spelling. The three agree today by coincidence, since
    `compareCaseInsensitive` also lowercases. The plan names `compareCaseInsensitive` and
    `foldCaseInsensitive` as the one folding rule, and the acceptance criterion reads "a rename
    that folds onto another entry is refused by the same rule as creation". It is the same rule
    only while the three copies agree. On the state, a `blocTest` can reach the rule, which is the
    reasoning the plan used for `libraryTags` and `importableIngredients`.
  - Fix: add `CatalogIngredient? ingredientNamed(String name)` to `RecipesState`, beside
    `ingredientById`, implemented once with `compareCaseInsensitive` on the trimmed name. Call it
    from `ingredientIn`, the create sheet, and the edit sheet validator
    (`final other = state.ingredientNamed(name); other != null && other.id != widget.entry.id`).
    Have `importableIngredients` build `claimed` the same way. Move the `catalogEntryNamed` tests
    into `recipes_state_test.dart`.

### Suggestions: Nice to Have

- **packages/recipes_api/lib/src/models/unit.dart:60**: an unknown `kind` throws and costs the whole catalog.
  - Suggestion: the plan accepts a lossy `CustomUnit` decode for an unknown standard unit because
    it is "the right trade against a decode that loses the whole catalog". An unknown `kind` (a
    future third subclass read by a rolled-back build) still throws. `_readIngredients` then
    recovers as `[]`, and the next catalog write overwrites the stored blob for good.
    `defaultUnit` is nullable, so `_unitFromJson` in `catalog_ingredient.dart` can map a
    `FormatException` to `null`, which loses one unit instead of every entry. At minimum, narrow
    the doc comment so it does not overstate the guarantee.

- **lib/recipes/widgets/ingredient_picker.dart:173**, **lib/recipes/widgets/ingredient_create_sheet.dart:159**: scope comes from `activeLibraryId`, not from the recipe's library.
  - Suggestion: the editor saves the recipe under `widget.library.id`
    (`recipe_editor_page.dart`), but the picker's in-scope split, the widen, and the create
    sheet's scope all read `bloc.state.activeLibraryId`. The two agree today because nothing can
    switch libraries under an open editor. Still, "the library the recipe is being written in" is
    the plan's wording. Passing the library id down (`IngredientPicker(libraryId:)`,
    `IngredientCreateSheet.show(libraryId:)`) makes the two sources impossible to split.

- **lib/recipes/view/recipe_details_page.dart:177**: this is a second lookup-by-id beside `RecipesState.ingredientById`.
  - Suggestion: `catalog.where((e) => e.id == ingredient.catalogId).firstOrNull` duplicates
    `ingredientById`. Invariant 3 is "one rule, used by the details screen and the management
    screen alike", so select the state and call
    `switch (ingredient.catalogId) { final id? => state.ingredientById(id)?.name, null => null } ?? ingredient.name`.

- **lib/ingredients/view/ingredients_view.dart:26**: the build method runs about 85 lines and orders the catalog in the widget.
  - Suggestion: extract the tile into an `_IngredientTile` (entry, recipeCount, libraryNames).
    Move the `[...state.ingredients]..sort(...)` ordering onto the state (for example
    `sortedIngredients`), next to `libraryIngredients`, which already sorts there.

- **lib/ingredients/view/ingredients_view.dart:29-30**: every emission recomputes both derived getters.
  - Suggestion: `context.watch` rebuilds on every state change, including mutation
    `loading`/`success` pairs. Each rebuild recomputes `importableIngredients`, which calls
    `ingredientById` (a linear scan) for every linked row, making it O(rows × entries). At
    personal scale this is harmless. Building an id set once at the top of
    `importableIngredients` removes the nested scan cheaply.

- **lib/ingredients/view/ingredients_view.dart:137**: the delete refusal banner outlives its cause.
  - Suggestion: `_failure` clears only when a later delete or import is dispatched. After
    "Gin is used in 4 recipes", the banner stays while the user renames Gin or deletes other
    entries, and can end up naming an entry that no longer exists. Clear it on the next
    `ingredientSaved` success, or when the named entry's usage changes.

- **lib/recipes/widgets/ingredient_create_sheet.dart:144**, **lib/ingredients/widgets/ingredient_editor_sheet.dart:224**: the two sheets duplicate the unit selector.
  - Suggestion: `_chosenUnit` is byte-identical in both. The `FSelect<StandardUnit>` and
    custom-field swap, including its keys and comment, is duplicated too, and so are three pairs
    of ARB strings (`ingredientCreateUnitLabel`/`ingredientEditUnitLabel`, and so on). Keeping the
    sheets separate is defensible, but a `DefaultUnitField` in `lib/ui/` (it is feature-agnostic)
    would remove about 60 lines and keep the two sheets from drifting. It can wait until a third
    caller appears.

- **lib/recipes/widgets/ingredient_create_sheet.dart:259**: `(existingUnit as KnownUnit?)?.unit` is a cast.
  - Suggestion: the `CustomUnit` branch above makes the cast safe, but a pattern states it
    without one: `switch (existingUnit) { KnownUnit(:final unit) => unit, _ => null }`, which
    matches how the edit sheet initialises `_standardUnit`.

- **lib/recipes/bloc/recipes_state.dart:46** / **:207**: `ImportableIngredient.libraryIds` is a mutable set.
  - Suggestion: the getter hands out the `scopes[key]` set directly, so a caller can mutate a
    value that `Equatable` compares. `CatalogIngredient` wraps its set in `Set.unmodifiable`; do
    the same here.

- **lib/recipes/bloc/recipes_state.dart:198**: unit inference counts spellings, not units.
  - Suggestion: rows `ml`, `mL`, `oz`, `oz` count as `ml:1, mL:1, oz:2`, so `oz` wins even
    though `ml` appears equally often and is seen first. The plan literally says "most frequent
    spelling", so this follows it. Still, the feature exists to stop `ml`/`mL` divergence, and
    counting by the resolved `Unit` matches that intent better.

- **lib/recipes/bloc/recipes_bloc.dart:195-252**: identical failure emits repeat.
  - Suggestion: keep the named catches the plan requires, but have each body call one helper,
    `void _fail(Emitter<RecipesState> emit, RecipesMutation kind)`. That removes about 50 lines
    of identical `copyWith` blocks across the six handlers.

- **test/recipes/bloc/recipes_bloc_test.dart:71**: one `blocTest` is redundant.
  - Suggestion: "carries the snapshot's catalog into the state" asserts what the preceding test
    already asserts, since its expected state includes `ingredients: snapshot.ingredients` and the
    snapshot contains `gin`. Delete it, or make the fixture's first test omit ingredients so each
    test proves a distinct thing.

- **lib/ui/failure_banner.dart:20**: an off-token literal sits inside the design-system folder.
  - Suggestion: `EdgeInsets.only(bottom: 12)` now lives in `lib/ui/`, and the new ingredient
    screens render it. `AppSpacing.spacing150` is exactly 12. The sweep of the recipe screens
    stays out of scope, but this one-token change is in a file the branch moved.

### Simplicity Assessment

- Lines that could be removed: about 130 (duplicate failure emits ~50, the shared unit selector
  ~60, the redundant blocTest ~10, and the details-page lookup).
- Unnecessary abstractions: none. The sealed `Unit` is the plan's named bet and is used.
  `IngredientOption` has exactly the two kinds the picker needs.
- YAGNI violations: none found. `saveIngredients` landed with its only caller, as planned.
- Complexity verdict: minor tweaks needed.

### Testing Assessment

- New code with tests: yes. Every new model, api method, repository pass-through, bloc handler,
  state getter, widget and page has a test file, and coverage is 100% in all four units.
- Test quality: meaningful. Failure paths are parametrised per exception. The interleaving
  `blocTest` proves mutation kinds under overlap. The migration tests assert write order and
  byte-identical recipes. The serialization tests cover overlap, a stalled queue, and the initial
  write. Controller disposal is proven with `withTrackedAll`.
- State management test coverage: complete (see the redundant test above).
- UI component test coverage: complete. The picker covers sections, contains-matching, the
  create item on an empty catalog, prefill rules, and the widen. Both sheets cover
  success/failure/foreign-success/dispose/re-provide. The editor covers every linking path from
  the plan, including rename priming and the not-dirty check.
