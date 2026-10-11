---
title: Reorder fields and close three UI known issues
type: feat
date: 2026-10-11
---

## Reorder fields and close three UI known issues - Standard

> Closes four entries of `docs/known-issues.md`: *The last-library refusal reads as a stray
> status line*, *Usage counts span every library*, *Required fields are not marked until a save
> fails* and *Fields cannot be reordered*. Each entry's "Closing it" note is the requirement;
> this plan records the decisions those notes leave open. The other five entries stay open.

## Overview

Four changes, all in the presentation layer and the bloc. No stored shape changes and no
package under `packages/` changes outside its tests.

1. **Refusals become toasts.** Deleting the only library, and deleting an ingredient recipes
   still use, are answered by a toast instead of a red line that sits above the list.
2. **The ingredient refusal names the libraries** whose recipes use the entry.
3. **Required fields are marked** in the recipe editor before a save is attempted.
4. **Fields can be reordered** from the fields screen, without touching any recipe value.

## Problem Statement / Motivation

- A refusal rendered through `FailureBanner` looks like a status of the screen and stays until
  the next action. `FailureBanner` is in-place on purpose, so a failed save leaves its form in
  view; a refusal has no form to protect.
- "Gin is used in 4 recipes" counts recipes in every library, so the recipes behind a refused
  delete may not be visible from the library being browsed, and nothing says where to look.
- A required field looks like an optional one until a save is refused. The field editor now
  lets users add their own required fields, which is when the gap shows.
- Field order is the order the recipe editor and details screen render. Moving a field today
  means deleting and re-adding it, which clears every value recipes held for it.

## Proposed Solution

### Decisions (locked with the user)

| Decision | Choice |
|---|---|
| Issues in scope | The four above. Restore, merge, name normalization, unit labels and the spacing sweep stay open. |
| Reorder control | A header action toggles a reorder mode; each tile swaps its delete button for move-up and move-down buttons. No drag and drop. |
| Ingredient refusal | A toast, like the library refusal. Save, delete and import *failures* stay banners. |

### Decisions made in this plan

| Decision | Choice | Why |
|---|---|---|
| Toast content | A short title plus a description, not one long sentence | The current sentence is too long for a toast title. |
| Toast position | `FToastAlignment.bottomCenter` | The touch theme's default is top centre, which covers the header's add action that the library refusal tells the user to press. |
| Toast lifetime | The screen that raised it dismisses it before raising another and before opening a sheet, dialog or route. Otherwise it expires on its own. | The `FToaster` sits above the `Navigator`, so a bottom toast would cover the buttons of the sheet the user opens next, and repeated taps would stack copies. A toast outliving a popped screen for a few seconds is harmless, so nothing dismisses on dispose. |
| Shared helper | `showRefusalToast` in `lib/ui/`, for two call sites | The position is a non-obvious choice that needs its reason written down once, and the two refusals must not drift apart. |
| Refusal with no resolvable library | A count-only description | Usage counts recipes whose library is gone, and the app already leaves unresolvable library ids out elsewhere (`ingredients_view.dart:108-116`) rather than render them broken. |
| Move event payload | `libraryId`, `fieldId`, `delta` (an offset; the view sends −1 or +1), resolved against bloc state | Mirrors `RecipesFieldDeleted`. Two quick taps both apply; a field list built in the view would drop one. |
| Move announcement | Sent when the move succeeds, not when it is dispatched | At dispatch the view would claim an outcome it does not know, and a stale tap would announce a move that never happens. |
| Move buttons at the ends | Both buttons always render; the inapplicable one is disabled | Buttons keep their position, so a second tap cannot land on the opposite action. |
| Recipe name | Marked as required too | It is the one required field in the editor built outside `SchemaFieldControl`; leaving it bare would make the marks inconsistent. |
| Requirement for assistive tech | `Text.semanticsLabel` reading "{label}, required" | Works on every platform and all three forui controls. `Semantics(isRequired: true)` was considered and rejected: its platform support on iOS and Android is uneven, and using both would announce the requirement twice. |

### 1. Refusal toasts

**New `lib/ui/refusal_toast.dart`**, exported from `lib/ui/ui.dart`:

```dart
/// Answers a tap the app will not act on. A refusal is a toast because it has
/// no form to keep in view; a failed save or delete is a [FailureBanner].
///
/// Shown at the bottom: the touch theme's default is top centre, over the
/// header actions a refusal may be telling the user to press.
FToasterEntry showRefusalToast(
  BuildContext context, {
  required String title,
  required String description,
}) => showFToast(
  context: context,
  alignment: .bottomCenter,
  title: Text(title),
  description: Text(description),
);
```

forui's toast is already a live region (`animated_toast.dart:380`), so the announcement the
banner gave is kept.

**`lib/libraries/view/libraries_view.dart`**

- Replace `String? _refusal` with `FToasterEntry? _refusalToast` and remove the
  `FailureBanner` line.
- `_delete` with one library: dismiss any earlier toast, then
  `_refusalToast = showRefusalToast(...)`.
- `_openFields`, `_edit` and the non-refused branch of `_delete` call
  `_refusalToast?.dismiss()` where they clear `_refusal` today.

**`lib/recipes/bloc/recipes_state.dart`** — one derived member, next to `ingredientUsage`:

```dart
/// The ids of the libraries holding a recipe that references the entry
/// carrying [ingredientId] — where a refused delete sends the user to look.
Set<String> libraryIdsUsingIngredient(String ingredientId) => {
  for (final recipe in recipes)
    if (recipe.ingredients.any((row) => row.catalogId == ingredientId))
      recipe.libraryId,
};
```

It reads recipes, not `CatalogIngredient.libraryIds`: an entry's scope can lag behind its use,
because scope widening fails silently (`recipes_bloc.dart:455-481`).

**`lib/ingredients/view/ingredients_view.dart`**

- `_delete` with `recipeCount > 0`: resolve `libraryIdsUsingIngredient(entry.id)` to names,
  drop ids that resolve to nothing, sort with `compareCaseInsensitive`, join with `', '` (the
  rule `_describe` already uses), and raise the toast. With no resolvable name, use the
  count-only description.
- `_failure` stays for import and delete failures. A refusal no longer sets it.
- Dismiss the toast before raising another, before the confirm dialog and before opening
  `IngredientEditorSheet`.
- Fix the doc comment on `_delete`, which describes the banner.

**`lib/l10n/arb/app_en.arb`** — remove `librariesLastLibraryRefusal` and
`ingredientsDeleteRefusal` together with their `@` entries; add:

| Key | Text |
|---|---|
| `librariesLastLibraryRefusalTitle` | `{library} cannot be deleted` |
| `librariesLastLibraryRefusalDescription` | `It is your only library. Create another library first.` |
| `ingredientsDeleteRefusalTitle` | `{ingredient} cannot be deleted` |
| `ingredientsDeleteRefusalDescription` | `Used in {count, plural, =1{1 recipe} other{{count} recipes}}. Libraries: {libraries}.` |
| `ingredientsDeleteRefusalDescriptionNoLibraries` | `Used in {count, plural, =1{1 recipe} other{{count} recipes}}.` |

Every key this plan adds carries an `@key` entry like the existing ones: a description, and
each placeholder typed with an example.

### 2. Required marks

**New `lib/recipes/widgets/required_field_label.dart`**

```dart
/// The label of a field a recipe has to fill in: the text with a mark after
/// it, read out as "…, required" rather than as a bare glyph.
class RequiredFieldLabel extends StatelessWidget {
  const RequiredFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Text(
      l10n.recipeEditorRequiredFieldMark(label),
      semanticsLabel: l10n.recipeEditorRequiredFieldSemanticLabel(label),
    );
  }
}
```

- `lib/recipes/widgets/schema_field_control.dart`: all three branches build their label
  through one private helper that returns `RequiredFieldLabel(text)` when `field.required`
  and `Text(text)` otherwise. For a number, `text` already includes the unit, so the mark
  follows it: `ABV (%) *`.
- `lib/recipes/view/recipe_editor_page.dart:210`: the name field's label becomes
  `RequiredFieldLabel(l10n.recipeEditorNameLabel)`.
- ARB: `recipeEditorRequiredFieldMark` = `{label} *`,
  `recipeEditorRequiredFieldSemanticLabel` = `{label}, required`.

### 3. Field reorder

**Bloc** (`lib/recipes/bloc/`)

- `RecipesMutation.fieldMoved`, so a failed move is not raised on the field sheet and a failed
  sheet save is not raised as a move.
- `RecipesFieldMoved({required libraryId, required fieldId, required int delta})`, with all
  three in `props`. `delta` is documented as an offset in list positions.
- `_onFieldMoved`, registered `sequential()`:
  1. Look up the library and the field's index in `state`; `target = index + delta`.
  2. Field found but `target` out of range or equal to `index`: return without emitting. This
     is a stale second tap, not a failure. `_onLibrarySelected` and `_onIngredientsImported`
     return early the same way.
  3. Emit `fieldMoved` / `loading`.
  4. Library or field missing: emit `failure` and return, as `_onFieldDeleted` does.
  5. `saveLibrary` with the field removed and re-inserted at `target`; emit `success`, or
     `failure` on `LibraryNameTakenException` and `RecipesPersistenceException`.
- Update the comment at `recipes_bloc.dart:24-27`. It says library edits never overlap because
  the sheets are modal; a move is not modal, so say what holds instead: moves queue behind one
  another, and reorder mode offers neither delete nor the field sheet.
- A queued second move sees the first one's order because `saveLibrary` emits its snapshot
  before its future completes (`local_storage_recipes_api.dart:216`), so the snapshot reaches
  the bloc before the next handler starts. Two tests pin this, one on each side of the
  boundary (see "Tests").

**Storage** — no code change. `saveLibrary` passes recipes through `_conformed`, which only
alters a value whose field or option is gone or renamed, so a reorder writes the libraries key
alone. Add tests that pin this and the snapshot ordering above.

**`lib/libraries/view/library_fields_view.dart`**

- `bool _reordering`, and `_deleteFailed` becomes `String? _failure` fed by two nested
  `RecipesMutationListener`s (`fieldDeleted`, `fieldMoved`), the shape
  `ingredients_view.dart:40-48` already has. Dispatching a move or a delete clears it.
- Header suffixes:

  | State | Suffixes |
  |---|---|
  | Library gone | none (unchanged) |
  | Normal, fewer than 2 fields | add |
  | Normal, 2 or more fields | reorder toggle, add |
  | Reorder mode | done toggle only |

- Tiles in reorder mode: `onPress` is null (no sheet), and the suffix is a move-up and a
  move-down `FButton.icon`; up is disabled on the first tile and down on the last.
- A move dispatches `RecipesFieldMoved` and remembers the field's id. The `fieldMoved`
  listener's `onSuccess` reads that field's position from bloc state and announces it with
  `SemanticsService.sendAnnouncement`. Tiles are not keyed, so screen-reader focus stays on
  the slot rather than following the field; the announcement is what says where it went. A
  failed move is reported by the banner, which is a live region, and a stale tap that the
  handler ignores announces nothing.
- System back and the header's back action pop the screen in either mode. Moves are saved as
  they are made, so there is nothing to discard.

ARB:

| Key | Text |
|---|---|
| `libraryFieldsReorderLabel` | `Reorder fields` |
| `libraryFieldsReorderDoneLabel` | `Done reordering` |
| `libraryFieldsMoveUpLabel` | `Move {field} up` |
| `libraryFieldsMoveDownLabel` | `Move {field} down` |
| `libraryFieldsMovedAnnouncement` | `{field} moved to position {position} of {count}` |
| `libraryFieldsMoveFailure` | `Your field could not be moved.` |

### Tests

Every new branch is covered; the app and packages hold 100% coverage in CI.

**Existing tests that encode the old behaviour**

| Test | What happens to it |
|---|---|
| `libraries_view_test.dart` "is refused for the only library, saying why, without opening the sheet" | Assert the title and description inside an `FToast`, and no `FailureBanner`. |
| `libraries_view_test.dart` "clears the refusal once a library is opened", "…is being added", "…once a second library can take over" | They assert `FailureBanner` is absent, so they would pass while proving nothing. Rewrite each to assert the toast is dismissed. |
| `ingredients_view_test.dart` "is refused for an entry in use, naming the count, without dispatching" | New wording, in a toast. The fixture puts every recipe in Cocktails; add a two-library case and an unresolvable-library case. |
| `ingredients_view_test.dart` "clears a refusal once a delete is dispatched" | Same hollow assertion; rewrite to assert the toast is dismissed once a delete reaches the dialog. |
| `schema_field_control_test.dart` "renders a label without a unit when it has none" | Pumps a required field and finds `Dose`; point it at an optional field or expect the mark. |
| `recipe_editor_page_test.dart` `fieldNamed('Garnish')` on a required field (lines 194-244), and any finder on the `Name` label | Update to the marked label. |
| `library_fields_view_test.dart` "renders only the back action for a library that is gone" | Still expects exactly one `FHeaderAction`; keep it passing. |

**New tests**

- `test/ui/refusal_toast_test.dart`: renders the title and description in an `FToast` in the
  bottom half of the screen.
- `libraries_view_test.dart`: a second refused tap leaves one toast.
- `recipes_state_test.dart`: `libraryIdsUsingIngredient` — no use, one library, two libraries,
  one recipe using the entry on two rows, a recipe whose library is gone.
- `ingredients_view_test.dart`: names sorted and comma-joined; count-only fallback; a refusal
  raises no banner; a second refused tap leaves one toast; the toast is dismissed by opening
  the editor sheet.
- `test/recipes/widgets/required_field_label_test.dart`, plus per-type cases in
  `schema_field_control_test.dart`: text, long text, number with and without a unit, and
  select each show the mark and expose "…, required" when required, and the bare label when
  not. `recipe_editor_page_test.dart`: the name label is marked.
- `recipes_event_test.dart`: `RecipesFieldMoved` equality over all three fields.
- `recipes_bloc_test.dart`, group `RecipesFieldMoved`: up and down each save the expected
  order; an out-of-range move and a zero `delta` emit nothing and save nothing; a missing
  library and a missing field emit failure without calling the repository; each exception
  emits failure; every emission names `fieldMoved`; two queued moves of one field, with a
  mocked `saveLibrary` that pushes the new snapshot before it returns, save two successive
  orders.
- `library_fields_view_test.dart`: the toggle shows only with two or more fields; reorder mode
  swaps delete for the move buttons and hides add; up is disabled first and down last; a move
  dispatches the right event; a successful move announces the field's new position
  (`tester.takeAnnouncements()`) and a failed one announces nothing; a tile tap opens no
  sheet; done returns to normal mode; a failed move raises its banner and the next dispatch
  clears it; a failed delete still raises its own; a library that disappears while in reorder
  mode leaves only the back action.
- `packages/local_storage_recipes_api/test/src/local_storage_recipes_api_test.dart`, group
  `saveLibrary`: saving the same fields in another order stores the new order, writes only the
  libraries key, and leaves every recipe equal; a listener on `watch()` holds the new snapshot
  by the time `await saveLibrary(...)` returns.

### Docs

Remove the four closed entries from `docs/known-issues.md` as each phase lands.

## Technical Considerations

- **Architecture.** No layer boundary moves. The views reach the bloc through the `recipes`
  barrel as they do today; `lib/ui/` gains one function. Nothing under `packages/*/lib`
  changes.
- **Accessibility.** Toasts announce as live regions. Every new button has a semantics label
  naming its field. The required mark has a spoken form; forui merges a field's label into
  the control's semantics node, so it is read with the control. A move is announced, with one
  limit: Flutter documents announcement events as deprecated on Android, so the announcement
  may not be spoken there. One known loss: a banner stayed on screen to be re-read, a toast
  leaves after five seconds.
- **Performance.** `libraryIdsUsingIngredient` scans the recipes once, and only when a delete
  is refused.
- **Security.** None; no new input, storage or network surface.

## Implementation Phases

### Phase 1: Refusal toasts

- **Status:** Done
- **Scope:** `showRefusalToast`; the library and ingredient refusals move onto it; the ingredient refusal names its libraries.
- **Files touched:** `lib/ui/refusal_toast.dart`, `lib/ui/ui.dart`, `lib/libraries/view/libraries_view.dart`, `lib/ingredients/view/ingredients_view.dart`, `lib/recipes/bloc/recipes_state.dart`, `lib/l10n/arb/app_en.arb`, `lib/l10n/gen/*`, `test/ui/refusal_toast_test.dart`, `test/libraries/view/libraries_view_test.dart`, `test/ingredients/view/ingredients_view_test.dart`, `test/recipes/bloc/recipes_state_test.dart`, `docs/known-issues.md`
- **Acceptance criteria:** Both refusals render in an `FToast` with a title and description; the ingredient one names the libraries or falls back to the count; neither view renders a refusal through `FailureBanner`; the two known-issues entries are gone.
- **Validation:** `flutter gen-l10n && dart format --output=none --set-exit-if-changed . && flutter analyze && dart run bloc_tools:bloc lint . && flutter test`

### Phase 2: Required marks

- **Status:** Done
- **Scope:** `RequiredFieldLabel`, used by every required schema field and by the recipe name.
- **Files touched:** `lib/recipes/widgets/required_field_label.dart`, `lib/recipes/widgets/schema_field_control.dart`, `lib/recipes/view/recipe_editor_page.dart`, `lib/l10n/arb/app_en.arb`, `lib/l10n/gen/*`, `test/recipes/widgets/required_field_label_test.dart`, `test/recipes/widgets/schema_field_control_test.dart`, `test/recipes/view/recipe_editor_page_test.dart`, `docs/known-issues.md`
- **Acceptance criteria:** A required text, long text, number and select field and the recipe name each show the mark and expose "…, required"; optional fields are unchanged; the known-issues entry is gone.
- **Validation:** `flutter gen-l10n && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`

### Phase 3: Field reorder

- **Status:** Not started
- **Scope:** `RecipesFieldMoved`, its handler and mutation kind; reorder mode on the fields screen; the storage test that pins a reorder to a libraries-only write.
- **Files touched:** `lib/recipes/bloc/recipes_bloc.dart`, `lib/recipes/bloc/recipes_event.dart`, `lib/recipes/bloc/recipes_state.dart`, `lib/libraries/view/library_fields_view.dart`, `lib/l10n/arb/app_en.arb`, `lib/l10n/gen/*`, `test/recipes/bloc/recipes_bloc_test.dart`, `test/recipes/bloc/recipes_event_test.dart`, `test/libraries/view/library_fields_view_test.dart`, `packages/local_storage_recipes_api/test/src/local_storage_recipes_api_test.dart`, `docs/known-issues.md`
- **Acceptance criteria:** A field moves up or down from reorder mode and the new order persists; no recipe value changes; a failed move is reported on the fields screen only; the known-issues entry is gone.
- **Validation:** `flutter gen-l10n && dart format --output=none --set-exit-if-changed . && flutter analyze && dart run bloc_tools:bloc lint . && flutter test && (cd packages/local_storage_recipes_api && flutter analyze && flutter test)`

## Success Criteria

```success-criteria
GOAL: The app answers a refused delete with a toast that says why and where to look, marks required fields in the recipe editor before a save, and lets a library's fields be reordered without touching any recipe value, with no change to any stored shape.

SUCCESS CRITERIA:
- Static analysis is clean in the app and the one package whose tests change | verify: flutter analyze && (cd packages/local_storage_recipes_api && flutter analyze)
- Code is formatted | verify: dart format --output=none --set-exit-if-changed .
- Bloc lints pass | verify: dart run bloc_tools:bloc lint .
- Localized strings generate cleanly, plurals included | verify: flutter gen-l10n && flutter analyze
- App, bloc and widget tests pass, covering every case listed under "Tests" in this plan | verify: flutter test
- A reorder stores the new field order, writes only the libraries key and leaves every recipe equal, and a snapshot is delivered before saveLibrary returns | verify: cd packages/local_storage_recipes_api && flutter test
- Both refusals go through showRefusalToast, and the Libraries screen no longer renders a banner | verify: grep -q "showRefusalToast" lib/libraries/view/libraries_view.dart && grep -q "showRefusalToast" lib/ingredients/view/ingredients_view.dart && ! grep -q "FailureBanner" lib/libraries/view/libraries_view.dart
- The single-sentence refusal strings and their metadata entries are gone | verify: ! grep -q 'ingredientsDeleteRefusal"\|librariesLastLibraryRefusal"' lib/l10n/arb/app_en.arb
- Every required schema field and the recipe name use RequiredFieldLabel | verify: grep -q "RequiredFieldLabel" lib/recipes/widgets/schema_field_control.dart && grep -q "RequiredFieldLabel" lib/recipes/view/recipe_editor_page.dart
- A move is its own event and mutation kind | verify: grep -q "class RecipesFieldMoved" lib/recipes/bloc/recipes_event.dart && grep -q "fieldMoved" lib/recipes/bloc/recipes_state.dart
- No package source and no stored shape changed | verify: git diff --quiet "$(git merge-base main HEAD)" -- packages/recipes_api/lib packages/local_storage_recipes_api/lib packages/recipes_repository/lib
- Presentation never imports a data package directly | verify: ! grep -rq "package:local_storage_recipes_api\|package:recipes_api" lib/recipes lib/ingredients lib/libraries lib/app lib/ui
- The four closed known issues are gone and the open ones remain | verify: ! grep -q "Fields cannot be reordered\|Usage counts span every library\|reads as a stray status line\|not marked until a save fails" docs/known-issues.md && grep -q "cannot be restored" docs/known-issues.md && grep -q "cannot be merged" docs/known-issues.md && grep -q "Spacing literals" docs/known-issues.md && grep -q "Unit labels are not localized" docs/known-issues.md && grep -q "fold on case" docs/known-issues.md
- Coverage is 100% in the app and in local_storage_recipes_api | verify: manual 1) run the very_good_cli MCP `test` tool with min_coverage 100 at the repo root 2) run it again for packages/local_storage_recipes_api 3) confirm both report 100%
- The four changes work together on a device | verify: manual 1) run `flutter run --flavor development --target lib/main_development.dart` 2) delete libraries until one is left, tap its delete action, and confirm a toast at the bottom says it cannot be deleted and why, with the header's add action still reachable 3) tap delete twice more and confirm one toast shows, then tap add and confirm the toast is gone and does not cover the sheet 4) create a second library, add a recipe in each using the same catalog ingredient, open Ingredients, tap that ingredient's delete action, and confirm the toast names the recipe count and both libraries 5) open a library's fields, add a required Number field with a unit, open the recipe editor, and confirm Name and the new field show `*` while optional fields do not 6) with a screen reader on, confirm the required field's label is read as "…, required" 7) on the fields screen tap the reorder action, confirm delete and add are gone and each row has up and down, with up disabled on the first row and down on the last 8) tap the last field's own up button, then its own up button again in its new row, and confirm it lands two rows higher; with a screen reader on, confirm each move is announced with its new position 9) tap done, open the recipe editor and a recipe's details, and confirm both list the fields in the new order with every value intact 10) kill and relaunch the app and confirm the order held

NON-GOALS:
- Drag-and-drop reordering, and reordering libraries or a Select field's options
- Restoring a deleted library, merging libraries, shared name normalization, unit label localization, and the spacing-literal sweep (all still known issues)
- Turning save, delete or import failures into toasts; they stay banners
- Marking required fields in the library, field and ingredient sheets
- Capping or truncating a long list of library names in the ingredient refusal
- Correcting the usage count for recipes whose library no longer exists
- A per-library breakdown of the usage count, on the tile or in the refusal
- Any change to a stored shape, the schema version, or code under packages/*/lib

VERIFICATION COMMAND: flutter pub get && flutter gen-l10n && dart format --output=none --set-exit-if-changed . && flutter analyze && dart run bloc_tools:bloc lint . && flutter test && (cd packages/local_storage_recipes_api && flutter pub get && flutter analyze && flutter test) && grep -q "showRefusalToast" lib/libraries/view/libraries_view.dart && grep -q "showRefusalToast" lib/ingredients/view/ingredients_view.dart && ! grep -q "FailureBanner" lib/libraries/view/libraries_view.dart && ! grep -q 'ingredientsDeleteRefusal"\|librariesLastLibraryRefusal"' lib/l10n/arb/app_en.arb && grep -q "RequiredFieldLabel" lib/recipes/widgets/schema_field_control.dart && grep -q "RequiredFieldLabel" lib/recipes/view/recipe_editor_page.dart && grep -q "class RecipesFieldMoved" lib/recipes/bloc/recipes_event.dart && grep -q "fieldMoved" lib/recipes/bloc/recipes_state.dart && git diff --quiet "$(git merge-base main HEAD)" -- packages/recipes_api/lib packages/local_storage_recipes_api/lib packages/recipes_repository/lib && ! grep -rq "package:local_storage_recipes_api\|package:recipes_api" lib/recipes lib/ingredients lib/libraries lib/app lib/ui && ! grep -q "Fields cannot be reordered\|Usage counts span every library\|reads as a stray status line\|not marked until a save fails" docs/known-issues.md && grep -q "cannot be restored" docs/known-issues.md && grep -q "cannot be merged" docs/known-issues.md && grep -q "Spacing literals" docs/known-issues.md && grep -q "Unit labels are not localized" docs/known-issues.md && grep -q "fold on case" docs/known-issues.md
```

## Success Metrics

- `docs/known-issues.md` drops from nine entries to five.
- Reordering a field changes zero recipe values, proven by the storage test rather than by
  reading the code.
- No refusal in the app is rendered through `FailureBanner`.

## Dependencies & Risks

- **forui is pinned at 0.27.4 and the toast API was read from its source, not run.** The
  first toast test confirms what the plan assumes: `FToastAlignment.bottomCenter` places the
  toast at the bottom and `FToasterEntry.dismiss()` removes it.
- **Toast timers in widget tests.** A toast holds a five-second `Timer`, cancelled on dispose.
  A test that ends with a toast showing should pass, but if the pending-timer check fires,
  dismiss the toast or pump past the duration before the test ends.
- **The move handler reads bloc state**, so it depends on the snapshot of one move reaching
  the bloc before the next handler runs. That ordering holds today and is pinned by the two
  tests named above; a storage change that breaks it fails them.
- **A move still being written when the user leaves reorder mode.** The field sheet saves the
  library as it was when the sheet opened (`field_editor_sheet.dart:306-316`), so a sheet
  opened in the milliseconds before a move lands would undo it. Not guarded; if it is ever
  seen, disable the done toggle while a move is loading.
- **Coverage cannot be a shell command here.** A project hook blocks `very_good test` in the
  shell and requires the very_good_cli MCP tool, so the coverage criterion stays manual.
- **Existing tests that keep passing while proving nothing** are the main trap of phase 1.
  The table under "Tests" names them.
- **Long library names.** The toast clips at 250dp high. Uncapped by decision; revisit only if
  it is seen.

## References & Research

- Requirements: `docs/known-issues.md` (the four entries named at the top)
- Banner versus toast reasoning: `lib/ui/failure_banner.dart:5-9`
- Toaster already mounted: `lib/app/view/app.dart:43`, `test/helpers/pump_app.dart:36`
- Refusals today: `lib/libraries/view/libraries_view.dart:108-121`, `lib/ingredients/view/ingredients_view.dart:128-137`
- Usage counting: `lib/recipes/bloc/recipes_state.dart:219-233`
- Field labels: `lib/recipes/widgets/schema_field_control.dart:211-238`, `lib/recipes/view/recipe_editor_page.dart:207-218`
- Handler and mutation-kind pattern to mirror: `lib/recipes/bloc/recipes_bloc.dart:268-328`, `lib/recipes/bloc/recipes_state.dart:12-28`
- Two nested mutation listeners feeding one banner: `lib/ingredients/view/ingredients_view.dart:40-59`
- Why a reorder touches no recipe: `packages/local_storage_recipes_api/lib/src/local_storage_recipes_api.dart:187-217` and `:348-377`
- forui 0.27.4 source: `widgets/toast/toaster.dart:36-84` (`showFToast`), `:417-423` (`FToasterEntry`), `toaster_style.dart:83` (touch alignment), `animated_toast.dart:380` (live region)
- Previous plan, for conventions: `docs/plan/2026-10-08-feat-add-library-manager-and-field-editor-plan.md`
