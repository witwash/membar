# Code Review — feat/ingredients

17 findings · 🔴 0 critical · 🟡 3 important · 🔵 14 suggestions
Across 87 files. Agents: vgv-review-agent, architecture-review-agent, test-quality-review-agent, code-simplicity-review-agent, pr-readiness-review-agent.

## Findings Index

| ID | Severity | Rule | Location | Finding |
|----|----------|------|----------|---------|
| FINDING-01 | 🟡 Important | `simplicity/duplicate-sheet-scaffold` | `lib/ingredients/widgets/ingredient_editor_sheet.dart` | Share the default-unit selector and sheet frame between the two ingredient sheets |
| FINDING-02 | 🟡 Important | `architecture/circular-feature-dependency` | `lib/recipes/view/recipes_view.dart:4` | Break the recipes <-> ingredients feature import cycle |
| FINDING-03 | 🟡 Important | `vgv/business-logic-in-presentation` | `lib/recipes/widgets/ingredient_picker.dart:18` | Move the name-to-entry rule onto RecipesState |
| FINDING-04 | 🔵 Suggestion | `vgv/long-build-method` | `lib/ingredients/view/ingredients_view.dart:26` | Extract the ingredient tile and move catalog ordering to state |
| FINDING-05 | 🔵 Suggestion | `vgv/stale-ui-state` | `lib/ingredients/view/ingredients_view.dart:137` | Clear the delete refusal banner when its cause changes |
| FINDING-06 | 🔵 Suggestion | `vgv/repeated-failure-emits` | `lib/recipes/bloc/recipes_bloc.dart:195` | Collapse identical failure emits behind one helper |
| FINDING-07 | 🔵 Suggestion | `vgv/avoidable-recomputation` | `lib/recipes/bloc/recipes_state.dart:191` | Remove the nested lookup in importableIngredients |
| FINDING-08 | 🔵 Suggestion | `vgv/unit-inference-intent` | `lib/recipes/bloc/recipes_state.dart:198` | Count inferred default units by resolved Unit, not spelling |
| FINDING-09 | 🔵 Suggestion | `vgv/immutable-state` | `lib/recipes/bloc/recipes_state.dart:207` | Make ImportableIngredient.libraryIds unmodifiable |
| FINDING-10 | 🔵 Suggestion | `vgv/duplicated-lookup` | `lib/recipes/view/recipe_details_page.dart:177` | Use ingredientById in the details ingredient line |
| FINDING-11 | 🔵 Suggestion | `architecture/business-logic-in-presentation` | `lib/recipes/widgets/ingredient_create_sheet.dart:155` | Shrink the create sheet's reuse-or-create branch to a state lookup |
| FINDING-12 | 🔵 Suggestion | `vgv/avoid-casts` | `lib/recipes/widgets/ingredient_create_sheet.dart:259` | Replace the KnownUnit cast with a pattern |
| FINDING-13 | 🔵 Suggestion | `vgv/single-source-of-truth` | `lib/recipes/widgets/ingredient_picker.dart:173` | Scope picks and creates to the recipe's library, not the active one |
| FINDING-14 | 🔵 Suggestion | `vgv/spacing-token-usage` | `lib/ui/failure_banner.dart:20` | Use AppSpacing.spacing150 in the moved FailureBanner |
| FINDING-15 | 🔵 Suggestion | `vgv/lossy-decode-scope` | `packages/recipes_api/lib/src/models/unit.dart:60` | Decode an unknown unit kind as null instead of throwing |
| FINDING-16 | 🔵 Suggestion | `tests/bloc-test-lifecycle-consistency` | `test/recipes/bloc/recipes_bloc_test.dart:47` | Close the bloc built outside blocTest |
| FINDING-17 | 🔵 Suggestion | `vgv/redundant-test` | `test/recipes/bloc/recipes_bloc_test.dart:71` | Remove the duplicate snapshot-catalog blocTest |

## Important

### FINDING-01 · `simplicity/duplicate-sheet-scaffold` · `lib/ingredients/widgets/ingredient_editor_sheet.dart`
Share the default-unit selector and sheet frame between the two ingredient sheets.
- **Why**: `_chosenUnit`, the standard/custom unit selector with its toggle, the sheet chrome and three pairs of ARB strings are copied between the create and edit sheets (~60–90 LOC), so a fix to one can miss the other.
- **Fix**: Extract a feature-agnostic default-unit field (and optionally the sheet frame) into `lib/ui/` and use it from both sheets.
- **Reported by**: code-simplicity-review-agent, architecture-review-agent, vgv-review-agent · [details](raw/code-simplicity-review.md)

### FINDING-02 · `architecture/circular-feature-dependency` · `lib/recipes/view/recipes_view.dart:4`
Break the recipes <-> ingredients feature import cycle.
- **Why**: recipes_view imports the ingredients barrel and every lib/ingredients file imports the recipes barrel, so the two features now depend on each other.
- **Fix**: Give RecipesView an injected onOpenIngredients callback (or route builder) supplied from lib/app, so lib/recipes never names IngredientsPage.
- **Reported by**: architecture-review-agent · [details](raw/architecture-review.md)

### FINDING-03 · `vgv/business-logic-in-presentation` · `lib/recipes/widgets/ingredient_picker.dart:18`
Move the name-to-entry rule onto RecipesState.
- **Why**: The rule behind invariant 1 lives in a widget file, and the edit sheet validator and `importableIngredients` each reimplement it, so creation and rename share a rule only while the copies agree — and no blocTest can reach it.
- **Fix**: Add `RecipesState.ingredientNamed(name)` built on `compareCaseInsensitive`, use it from `ingredientIn`, both sheets and `importableIngredients`, and delete `catalogEntryNamed`.
- **Reported by**: vgv-review-agent, architecture-review-agent · [details](raw/vgv-review.md)

## Suggestions

### FINDING-04 · `vgv/long-build-method` · `lib/ingredients/view/ingredients_view.dart:26`
Extract the ingredient tile and move catalog ordering to state.
- **Why**: The build method runs ~85 lines and sorts the catalog in the widget, duplicating the ordering `_sortedIngredients` applies.
- **Fix**: Extract `_IngredientTile` and add a sorted-catalog getter on `RecipesState`.
- **Reported by**: vgv-review-agent, architecture-review-agent · [details](raw/vgv-review.md)

### FINDING-05 · `vgv/stale-ui-state` · `lib/ingredients/view/ingredients_view.dart:137`
Clear the delete refusal banner when its cause changes.
- **Why**: "X is used in N recipes" stays up through renames and other deletes and can name an entry that no longer exists.
- **Fix**: Reset `_failure` on the next successful ingredient mutation, or when the named entry's usage changes.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-06 · `vgv/repeated-failure-emits` · `lib/recipes/bloc/recipes_bloc.dart:195`
Collapse identical failure emits behind one helper.
- **Why**: ~50 lines of identical `copyWith(mutation, failure)` blocks repeat across handlers.
- **Fix**: Keep the named catches the plan requires, but have each call `_fail(emit, kind)`.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-07 · `vgv/avoidable-recomputation` · `lib/recipes/bloc/recipes_state.dart:191`
Remove the nested lookup in importableIngredients.
- **Why**: Every emission rebuilds the view and rescans entries per linked row — O(rows × entries).
- **Fix**: Build a set of catalog ids once at the top of the getter and test membership against it.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-08 · `vgv/unit-inference-intent` · `lib/recipes/bloc/recipes_state.dart:198`
Count inferred default units by resolved Unit, not spelling.
- **Why**: Rows `ml`, `mL`, `oz`, `oz` infer `oz` although `ml` is as frequent and seen first — the ml/mL split the feature exists to stop.
- **Fix**: Resolve each spelling to a `Unit` before counting (refines the plan's "most frequent spelling" wording).
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-09 · `vgv/immutable-state` · `lib/recipes/bloc/recipes_state.dart:207`
Make ImportableIngredient.libraryIds unmodifiable.
- **Why**: The getter hands out its internal mutable set inside an Equatable value.
- **Fix**: Wrap it with `Set.unmodifiable`, as `CatalogIngredient` does.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-10 · `vgv/duplicated-lookup` · `lib/recipes/view/recipe_details_page.dart:177`
Use ingredientById in the details ingredient line.
- **Why**: A second inline lookup-by-id breaks invariant 3's "one rule" for rendering a referenced row.
- **Fix**: Resolve the name through `ingredientById(id)?.name ?? ingredient.name`.
- **Reported by**: vgv-review-agent, architecture-review-agent · [details](raw/vgv-review.md)

### FINDING-11 · `architecture/business-logic-in-presentation` · `lib/recipes/widgets/ingredient_create_sheet.dart:155`
Shrink the create sheet's reuse-or-create branch to a state lookup.
- **Why**: The sheet decides reuse/widen/create itself, so only widget tests reach that decision.
- **Fix**: Once `ingredientNamed` exists, branch only on `state.ingredientNamed(...)`.
- **Reported by**: architecture-review-agent · [details](raw/architecture-review.md)

### FINDING-12 · `vgv/avoid-casts` · `lib/recipes/widgets/ingredient_create_sheet.dart:259`
Replace the KnownUnit cast with a pattern.
- **Why**: `(existingUnit as KnownUnit?)` is only safe because of the branch above it.
- **Fix**: Use `switch (existingUnit) { KnownUnit(:final unit) => unit, _ => null }`.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-13 · `vgv/single-source-of-truth` · `lib/recipes/widgets/ingredient_picker.dart:173`
Scope picks and creates to the recipe's library, not the active one.
- **Why**: Picker, widen and create sheet read `activeLibraryId` while the editor saves under `widget.library.id`; they agree only because nothing switches libraries while the editor is open.
- **Fix**: Pass the library id down through `IngredientPicker` and `IngredientCreateSheet.show`.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-14 · `vgv/spacing-token-usage` · `lib/ui/failure_banner.dart:20`
Use AppSpacing.spacing150 in the moved FailureBanner.
- **Why**: A literal `12` now sits inside `lib/ui/` though an exact token exists.
- **Fix**: Replace it with `EdgeInsets.only(bottom: AppSpacing.spacing150)`.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-15 · `vgv/lossy-decode-scope` · `packages/recipes_api/lib/src/models/unit.dart:60`
Decode an unknown unit kind as null instead of throwing.
- **Why**: An unknown `kind` makes the whole catalog recover as empty, and the next catalog write erases it.
- **Fix**: In `_unitFromJson`, map a `FormatException` to a null `defaultUnit`, or narrow the doc comment's guarantee.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-16 · `tests/bloc-test-lifecycle-consistency` · `test/recipes/bloc/recipes_bloc_test.dart:47`
Close the bloc built outside blocTest.
- **Why**: The initial-state test builds a bloc that is never closed, unlike every other instance in the file.
- **Fix**: Add `addTearDown(bloc.close)`.
- **Reported by**: test-quality-review-agent · [details](raw/test-quality-review.md)

### FINDING-17 · `vgv/redundant-test` · `test/recipes/bloc/recipes_bloc_test.dart:71`
Remove the duplicate snapshot-catalog blocTest.
- **Why**: The preceding test already expects `ingredients: snapshot.ingredients`.
- **Fix**: Delete it, or change fixtures so each test asserts something different.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

## Why this matters

Nothing blocks merge: the build is green at 100% coverage and every layering gate holds. The biggest lever is FINDING-03 — one state-level name lookup would retire four copies of the rule invariant 1 rests on, and makes FINDING-11 and part of FINDING-01 fall out almost for free.
