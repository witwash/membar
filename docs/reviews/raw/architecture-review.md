# Architecture Review: `feat/ingredients`

Scope: `git diff 4c6c2795a6c0fcb6f47394093b914ddd8f747507..HEAD` (57 files).
Reference: `docs/plan/2026-09-12-feat-add-ingredients-catalog-plan.md`, the `layered-architecture` and `bloc` skills.

These plan decisions were treated as settled and not flagged: one `RecipesBloc` for recipes and the catalog; no `ingredients_api` package; `lib/ingredients` importing `package:membar/recipes/recipes.dart` for the bloc, its state and `RecipesMutationListener`; confirm dialog and failure banner moved to `lib/ui`; name uniqueness enforced in the data layer; the delete guard checking `ingredientUsage` before dispatch; the silent scope widen; `ImportableIngredient` as an id-free getter type; unlocalized `Unit.label`.

## Layer Separation

- Violations found: 0
- Presentation never imports a data package. `grep "package:local_storage_recipes_api\|package:recipes_api"` over `lib/recipes`, `lib/ingredients`, `lib/app`, `lib/ui` and their tests returns nothing. Every domain type arrives through `package:recipes_repository/recipes_repository.dart`, whose `show` list gained `CatalogIngredient`, `Unit`, `KnownUnit`, `CustomUnit`, `StandardUnit` and the three new exceptions.
- `lib/ingredients` reaches recipes only through the barrel. No deep `recipes/{bloc,view,widgets}/` import exists.
- `lib/ui` imports only Flutter and forui (`confirm_dialog.dart` imports `app_spacing.dart`). It holds no domain or feature import, so it stays portable.
- `packages/recipes_api` stays pure Dart (equatable, json_annotation, uuid). `packages/recipes_repository` depends only on `recipes_api`. `packages/local_storage_recipes_api` depends only on `recipes_api` plus its storage plugins.
- The bloc imports only `bloc`, `bloc_concurrency`, `equatable` and `recipes_repository`.

Clean files: every changed file under `packages/`, `lib/recipes/bloc/`, `lib/ui/`, `lib/ingredients/view/ingredients_page.dart`.

## State Management Assessment

### RecipesBloc: correct, with one misplaced rule nearby

- Event names follow `Subject + Noun + VerbPast`: `RecipesIngredientSaved`, `RecipesIngredientDeleted`, `RecipesIngredientsImported`, `RecipesIngredientScopeWidened`.
- State is immutable. `copyWith`, `props` and `onData` all thread `ingredients` (`recipes_bloc.dart:60`, `recipes_state.dart:249,260,274`).
- Every mutation handler is `sequential()` and names its own `RecipesMutation` on each emission, as the plan requires.
- Each handler catches every exception its repository call declares: saved catches NameTaken and Persistence; deleted catches NotFound, InUse and Persistence; imported catches NameTaken and Persistence.
- Derived rules sit on the state where `blocTest` can reach them: `libraryIngredients`, `otherLibraryIngredients`, `ingredientUsage`, `importableIngredients`, `ingredientById`. The import mints ids inside the handler (`recipes_bloc.dart:270-277`), so two reads of the getter compare equal.

### Business rules living in presentation

1. **The name-link rule lives in a widget file** (Important).
   `catalogEntryNamed` at `lib/recipes/widgets/ingredient_picker.dart:18` decides which catalog entry a saved row links to (invariant 1). It is consumed by:
   - `lib/recipes/widgets/ingredient_row_field.dart:54` (`IngredientRowControllers.ingredientIn`, the save-time link),
   - `lib/recipes/widgets/ingredient_create_sheet.dart:113,160` (reuse on a folded name).

   The same rule is re-implemented three more times:
   - `lib/ingredients/widgets/ingredient_editor_sheet.dart:208-222` (`_validateName`, via `compareCaseInsensitive(...) == 0`),
   - `lib/recipes/bloc/recipes_state.dart:179-190` (`importableIngredients`, via `toLowerCase()`),
   - `packages/local_storage_recipes_api/.../local_storage_recipes_api.dart` `saveIngredients` (the data-layer guard, which the plan settles).

   All four agree today, because `CatalogIngredient` and `Ingredient` both trim in their constructors. Still, the presentation copies are exactly what the plan's own `libraryTags` reasoning warns against: "a `blocTest` can reach it, which neither widget's own copy of the rule could". The editor sheet in `lib/ingredients` cannot reuse `catalogEntryNamed` without leaning on a `lib/recipes/widgets/` symbol, the very coupling the plan meant to prevent, so it grew its own copy.

   Fix: add `CatalogIngredient? ingredientNamed(String name)` to `RecipesState` beside `ingredientById`. Call it from the picker, the create sheet, `IngredientRowControllers.ingredientIn` (pass the state or the lookup), `IngredientEditorSheet._validateName` (with an id exclusion) and `importableIngredients`. Then delete the top-level function and move its test into `recipes_state_test.dart`.

2. **The reuse-or-create decision sits in the create sheet** (Suggestion).
   `lib/recipes/widgets/ingredient_create_sheet.dart:155-185` decides between reusing an existing entry, widening its scope, and creating a new one, then dispatches. The plan assigns this behavior to the sheet but says nothing about where the decision lives. Only widget tests can reach it. That is acceptable given the plan, but if finding 1 lands, the branch shrinks to `state.ingredientNamed(...)` and needs nothing more.

3. **The details page re-implements `ingredientById`** (Suggestion).
   `lib/recipes/view/recipe_details_page.dart:183-186` does `catalog.where((entry) => entry.id == ingredient.catalogId).firstOrNull`. `RecipesState.ingredientById` already exists for this, and the editor page uses it (`recipe_editor_page.dart`, `state.ingredientById(id)`).

4. **The ingredients screen re-implements catalog ordering** (Suggestion).
   `lib/ingredients/view/ingredients_view.dart:34-35` sorts `state.ingredients` with `compareCaseInsensitive`. `RecipesState._sortedIngredients` already encodes that order for the two scoped getters. A public `sortedIngredients` getter (or `_sortedIngredients((_) => true)`) would keep all three lists on one rule.

### Widgets: correct lifecycle

- `IngredientEditorSheet` and `IngredientCreateSheet` dispose both controllers. Each re-provides the bloc with `BlocProvider.value` because the sheet route sits above the provider.
- `IngredientsPage.route` re-provides the bloc, mirroring `RecipeEditorPage.route`.
- `IngredientsView` uses `context.watch` in `build` and `context.read` in callbacks. Each `RecipesMutationListener` is scoped to its own mutation kind.
- The picker reads state at call time in `_filter`, as the plan specifies.

## Dependency Direction

- Direction violations: 0 layer violations. 1 feature-level cycle.
  - `lib/recipes/view/recipes_view.dart:4` imports `package:membar/ingredients/ingredients.dart` to push `IngredientsPage.route`.
  - `lib/ingredients/view/ingredients_view.dart:8`, `ingredients_page.dart:4` and `widgets/ingredient_editor_sheet.dart:5` import `package:membar/recipes/recipes.dart`.
  - Result: `recipes` -> `ingredients` -> `recipes` (circular, at the barrel level).

  The plan settles each edge on its own terms: the ingredients-to-recipes edge for the bloc and listener, and the recipes-to-ingredients edge for the header action. It never addresses the cycle their combination creates. Dart compiles it, but the two feature directories are no longer independently movable. The `recipes` barrel also exports every recipes view and widget, so `lib/ingredients` can see `IngredientPicker`, `IngredientCreateSheet` and `catalogEntryNamed` through the permitted import. The plan's verify grep catches only deep paths, so nothing stops that use.

  Two ways to break the cycle without reopening the one-bloc decision:
  - (a) Inject navigation. `RecipesView` takes a `VoidCallback onOpenIngredients`, or a route builder, supplied from `lib/app`, which already depends on both features.
  - (b) Move the ingredients entry point into `lib/app` routing, so `lib/recipes` never names `IngredientsPage`.

  Either way, `recipes -> ingredients` disappears and the documented `ingredients -> recipes` edge stays one-directional.

- Clean dependencies:
  - `recipes_api` <- `recipes_repository` <- app (bloc, presentation)
  - `recipes_api` <- `local_storage_recipes_api` <- app bootstrap only (pre-existing)
  - `lib/ui` <- `lib/recipes`, `lib/ingredients` (one-way)

## Package Structure

- `packages/recipes_api`: complete. New models `unit.dart` and `catalog_ingredient.dart` are exported through `models.dart`, and the generated `catalog_ingredient.g.dart` is committed. New tests: `unit_test.dart`, `catalog_ingredient_test.dart`, and extended `ingredient_test.dart`, `recipes_snapshot_test.dart`, `recipes_api_test.dart`. No Flutter imports.
- `packages/local_storage_recipes_api`: complete. It adds the fifth key, the v1 to v2 migration, the `_serialized` mutation queue, and per-key recovery for the catalog. Tests are extended.
- `packages/recipes_repository`: complete. It adds three pass-throughs with constructor-injected `RecipesApi`, extends the barrel `show` list, and extends the tests.
- `lib/ingredients`: new feature directory with a barrel (`ingredients.dart`), `view/` (Page/View split), `widgets/`, and matching tests under `test/ingredients/`.
- `lib/ui`: gains `confirm_dialog.dart` and `failure_banner.dart` with their tests moved to `test/ui/`. The barrel is updated.
- No new packages. The pubspecs are unchanged by this branch.

Shared presentation duplicated across features (Suggestion): `IngredientCreateSheet` (`lib/recipes/widgets/ingredient_create_sheet.dart`) and `IngredientEditorSheet` (`lib/ingredients/widgets/ingredient_editor_sheet.dart`) duplicate the sheet chrome (`DecoratedBox` + border + `SingleChildScrollView(padding: AppInsets.sheetContent)`), the standard/custom unit selector with its toggle, and the `_chosenUnit` getter, nearly line for line. The plan's boundary keeps the editor sheet from importing from `lib/recipes/widgets/`. A unit-agnostic sheet frame could live in `lib/ui`. The unit selector names `StandardUnit`, so it needs a shared home: either `lib/ingredients/widgets/` imported by recipes (which deepens the cycle above) or a small shared catalog-widgets directory. Worth resolving together with the cycle.

## Verdict

The layers are clean: no presentation-to-data import, no reverse package dependency, and every plan decision is honored. Two items need attention before merging:

1. Break the `recipes` <-> `ingredients` feature import cycle (Important).
2. Move the case-folded name-matching rule out of `lib/recipes/widgets/ingredient_picker.dart` onto `RecipesState`, so the four copies collapse to one reachable by `blocTest` (Important).

The rest are Suggestions.
