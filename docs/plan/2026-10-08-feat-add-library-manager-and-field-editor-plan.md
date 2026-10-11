---
title: Add library manager and field editor
type: feat
date: 2026-10-08
---

## Add library manager and field editor - Standard

> This is the deferred **PR2** of
> `docs/plan/2026-08-14-feat-add-schema-driven-recipe-libraries-plan.md`. That plan and
> `docs/brainstorm/2026-08-11-recipe-libraries-brainstorm-doc.md` record why libraries carry
> schemas; this plan records how the user edits them. Where the two disagree, this plan wins: it
> was written against the code as it stands on 2026-10-08, after the ingredients catalog landed.

## Overview

Libraries are seeded from two templates on first run and are read-only afterwards: nothing can
create, rename or delete one, and nothing can change the fields a library declares. This plan
adds both halves of schema authoring:

- a **library manager** — a Libraries screen reached from the header switcher, where the user
  creates a library (blank or from a template), renames one and deletes one;
- a **field editor** — a Fields screen per library, where the user adds a field, edits its
  label, unit, options and required flag, and deletes it.

No stored shape changes. `Library`, `FieldDefinition`, `Recipe` and `RecipesSnapshot` keep their
JSON, so there is no schema-version bump and no migration. The work is two new mutations on the
existing data stack plus three screens' worth of forms.

## Problem Statement / Motivation

The app's premise is that a library is user data, not an app-defined type. Today that is true of
the model and false of the product: a user who wants a Tea library, a `Strength` field on Coffee,
or `Tiki mug` in the Glassware list has no way to get one. Three things already shipped lean on
this work arriving:

- The Coffee template's second multiline field is "exactly the kind of thing PR2 lets the user
  resolve for themselves".
- `docs/known-issues.md` carries an open entry on what library deletion must do to the
  ingredients catalog.
- The details screen and recipe editor both have a "stale Select value" path that nothing in the
  UI can reach yet.

## Proposed Solution

### Decisions (locked)

Decided with the user on 2026-10-08 unless marked *default*; a *default* is this plan's choice
where the earlier documents were silent.

| Question | Decision |
|----------|----------|
| Scope | Library manager and field editor in one plan, three phases. |
| Deleting a library's recipes | **Cascade.** The delete sheet states the count; confirming deletes the library and its recipes together. No undo. |
| Catalog ingredients on library delete | **Never deleted.** An entry that also belongs to another library just loses this one. An entry that belongs *only* to this library is **moved to a library the user picks**. The motivation is the user's: entering ingredients is tedious, and an unused entry is still worth keeping. |
| The last library | **Cannot be deleted.** Moving ingredients needs somewhere to move them, so the app always has at least one library and the zero-library state the earlier plan anticipated is never built. |
| Removing a Select option recipes use | **Warn, then clear.** Saving the field states how many recipes use the removed options and clears those values on confirm — the same rule as deleting a field. |
| Field reordering | **Deferred.** A new field is appended; schema list position stays the order. |
| Field type | Immutable after creation (carried over). The type control is locked when editing. |
| Deleting a field | Warn with the number of recipes carrying a value, then purge those values (carried over). |
| Renaming a Select option | Rename-and-migrate: recipes holding the old text are rewritten to the new text (carried over). |
| Library names | *Default.* Unique without regard to case, the rule ingredient names already follow. The switcher and the ingredient sheet show names only, so two `Coffee` libraries would be indistinguishable. |
| Field labels | *Default.* Unique within a library without regard to case, checked by the form only. |
| Turning `required` on | *Default.* Allowed with no migration. A recipe lacking the value is untouched until it is next edited, when the recipe editor demands it. |
| A newly created library | *Default.* Appended to the list. The active library does not change. |

### Invariants

1. **There is always at least one library.** `deleteLibrary` takes a required successor that must
   be another existing library, so deleting the last one cannot even be expressed.
   `RecipesSnapshot.activeLibraryId` stays non-null and never blank; the list screen gains no
   empty branch.
2. **A schema edit purges exactly what it removed, and nothing else.** Saving a library drops a
   recipe value only when its field, or its Select option, was present in the stored library and
   is absent from the new one. A key that matched no field *before* the save still survives it —
   the "unknown keys survive" rule of the earlier plan, now with a deliberate exception rather
   than an incidental one.
3. **Every schema edit is one `saveLibrary` call.** Adding, editing and deleting a field and
   renaming a library all save the whole `Library`; the storage layer works out the consequences
   by diffing it against the stored one. There are no field-level api calls — deleting a field
   has its own bloc event, but that event's handler saves the library without it.
4. **A catalog entry never ends up in no library.** `CatalogIngredient` asserts a non-empty
   `libraryIds`; the successor is what keeps that true across a delete.
5. **Schema editing happens with no recipe screen open.** The manager is pushed from the list
   screen, as details and the recipe editor are, so none of them can sit under it. The recipe
   editor's "bind to the library passed at push time" rule therefore still holds untouched. The
   manager's own screens are the opposite case: they read the library **live** from the bloc,
   because they are what changes it.

### Data layer

Two methods join `RecipesApi`, with two exceptions beside them:

```dart
// packages/recipes_api/lib/src/recipes_api.dart

/// Stores [library], replacing any library that already carries its id.
///
/// Replacing a library rewrites its recipes to match: a value whose field
/// [library] no longer declares is dropped, a Select value equal to a key of
/// `optionRenames[fieldId]` becomes that key's value, and a Select value
/// naming an option the field no longer offers is dropped.
///
/// Throws a [LibraryNameTakenException] when a different library already
/// carries the same name without regard to case, and a
/// [RecipesPersistenceException] when a write fails.
Future<void> saveLibrary(
  Library library, {
  Map<String, Map<String, String>> optionRenames = const {},
});

/// Removes the library carrying [id] along with every recipe in it.
///
/// [successorId] names the library that inherits what cannot go with it:
/// catalog entries visible only in [id] move there, and it becomes the
/// active library when [id] was.
///
/// Throws a [LibraryNotFoundException] when [id] matches no library or
/// [successorId] matches no *other* library, and a
/// [RecipesPersistenceException] when a write fails.
Future<void> deleteLibrary(String id, {required String successorId});
```

`optionRenames` is keyed by field id, then by the option's stored text. It has to be passed
explicitly: a Select value is the raw option string, so a before/after diff cannot tell a rename
from a removal plus an addition.

Which options a save removes is decided in **one** place, a method on the model, so the count the
field sheet shows and the values the storage layer clears cannot drift apart:

```dart
// packages/recipes_api/lib/src/models/field_definition.dart

/// The options this field offers that [replacement] no longer does, leaving
/// out the keys of [renames] — those were retyped, not removed.
Set<String> optionsRemovedBy(
  FieldDefinition replacement, {
  Map<String, String> renames = const {},
}) => {...optionsOrEmpty}
  ..removeAll(replacement.optionsOrEmpty)
  ..removeAll(renames.keys);
```

It adds no stored property, so `field_definition.g.dart` does not change.

**`saveLibrary` in `LocalStorageRecipesApi`**, inside `_serialized`:

1. Refuse a name another library carries (`compareCaseInsensitive`), as `_merged` does for
   ingredients.
2. Unknown id → append. Known id → replace **in place**, so the switcher order does not move.
3. For a known id, rewrite each recipe of that library. Per field value:
   - field id in the stored library, not in the new one → drop the key;
   - field is a Select in both: look the value up in `optionRenames[fieldId]` — found → the new
     text; otherwise, value is in `stored.optionsRemovedBy(replacement, renames:)` → drop the
     key;
   - anything else → unchanged.

   Renames are a **single lookup per value**, never applied in sequence, which is what makes
   swapping two options (`A → B`, `B → A`) work. A value already outside the stored options is
   left alone (invariant 2).
4. Write the recipes key **only if a recipe changed**, then the libraries key; emit once.

**`deleteLibrary`**, inside `_serialized`:

1. Resolve `id`, and resolve `successorId` among the libraries that remain. Either miss throws
   `LibraryNotFoundException`. Passing the same id for both, or deleting the only library, fails
   the second lookup — no separate "last library" exception exists.
2. Catalog: every entry listing `id` loses it; an entry left with an empty set gets
   `{successorId}`.
3. Recipes: every recipe with `libraryId == id` is removed.
4. Active library: `successorId` when `id` was active.
5. Write ingredients, then the active id, then recipes, then libraries — each only if it
   changed, except libraries. Emit once.

**Write order is children before parents in both methods.** Every prefix of either sequence is a
state the app already renders correctly: an emptied library that still exists, a field whose
values are gone, a Select value shown as-is. The reverse order would leave recipes pointing at a
library that is gone (hidden, reported as dangling) or values keyed to a field nothing declares
(invisible). As with `importIngredients`, a failure part-way leaves the in-memory snapshot
unchanged, so retrying the same action completes it.

`_emit` gains a `libraries` parameter, and each method emits **exactly once**, after its last
write. A delete that emitted piecemeal would pass through a snapshot whose active id matches no
library, which the list screen renders as a spinner with no switcher. `_restore` is unchanged
apart from its comment, which still says nothing can create a library.

`successorId` deliberately does two jobs. Splitting it into "where the ingredients go" and "what
becomes active" would add a parameter to say something the user reads as one thing: the library
that takes the deleted one's place.

`LibraryTemplates`' doc comment calls them "the libraries a fresh install is seeded with"; it
gains a clause for their second use when Phase 2 adds it.

`RecipesRepository` gains the two pass-throughs. Its barrel adds `LibraryNameTakenException`,
`LibraryNotFoundException` and `LibraryTemplates` to the `show` list — the create sheet needs the
templates, and they are data builders, not a route to the data layer. The barrel's comment
says "the models travel with the repository"; extend it to cover the builders.

### Bloc surface

One `RecipesBloc` still backs every screen. The argument made for the ingredients screen applies
again: the delete sheet needs the libraries, the recipes and the catalog together.

```dart
// lib/recipes/bloc/recipes_event.dart
final class RecipesLibrarySaved extends RecipesEvent {
  const RecipesLibrarySaved(this.library, {this.optionRenames = const {}});
}
final class RecipesLibraryDeleted extends RecipesEvent {
  const RecipesLibraryDeleted(this.id, {required this.successorId});
}
final class RecipesFieldDeleted extends RecipesEvent {
  const RecipesFieldDeleted({required this.libraryId, required this.fieldId});
}
```

- Each event carries its payload as fields and lists every one in `props`. `RecipesEvent.props`
  defaults to `[]`, so an event that forgets them equals every other instance of its type and
  every `verify(() => bloc.add(...))` in the widget tests passes for any payload.
- `RecipesMutation` gains `librarySaved`, `libraryDeleted` and `fieldDeleted`. All three handlers
  are `sequential()`, name their own mutation on every emission, and emit `failure` for each
  exception their repository call declares.
- **`fieldDeleted` is its own kind because of who is listening.** The Fields screen deletes a
  field while the field sheet above it saves one; if both were `librarySaved`, a failed sheet
  save would also raise a banner on the screen beneath it. The mutation enum exists so that no
  widget has to keep a "was that mine?" flag. `_onFieldDeleted` reads the library from the
  state, emits `failure` when the library or the field is not there, and otherwise calls
  `saveLibrary` with the field left out.
- `_onLibraryDeleted` records whether the deleted library was the active one **before** awaiting,
  and clears `searchTerm` and `activeTags` on success when it was — the same reset a manual
  switch performs, for the same reason. The list subtree is already keyed on the library id, so
  its search control and scroll position reset by themselves.
- `RecipesState` gains the derived members the confirmations read, each a plain function of the
  state so a state test can reach it:

  | Member | Used by |
  |--------|---------|
  | `Library? libraryById(String id)` | the Fields screen and `_onFieldDeleted` |
  | `Library? libraryNamed(String name)` — trims and folds case, like `ingredientNamed` | the name validator |
  | `int recipeCountIn(String libraryId)` | the Libraries tile and the delete sheet |
  | `int ingredientCountOnlyIn(String libraryId)` — entries whose `libraryIds` is exactly `{libraryId}` | the delete sheet |
  | `int fieldValueCount(String libraryId, String fieldId)` — recipes carrying a value for the field | the delete-field confirmation |
  | `int recipeCountUsingOptions(String libraryId, String fieldId, Set<String> options)` — recipes whose value is one of them | the removed-options confirmation |

  Three of these count what the storage layer then removes, and the two sides share no code —
  the storage package cannot depend on the bloc, and its tests cannot import the app's fixtures.
  So the predicate is fixed here, for both to implement and both test suites to mirror:

  | Count | Predicate |
  |-------|-----------|
  | `ingredientCountOnlyIn(id)` | `entry.libraryIds` has exactly one element and it is `id` |
  | `fieldValueCount(libraryId, fieldId)` | recipe is in the library and `fieldValues` contains the key `fieldId` |
  | `recipeCountUsingOptions(libraryId, fieldId, options)` | recipe is in the library and `fieldValues[fieldId]` is a `String` equal to one of `options` — raw equality, not `textValue`, which trims |

### Screens

A new feature directory, `lib/libraries/`, laid out like `lib/ingredients/` and reaching the bloc
through the `recipes` barrel only. New widgets take every gap from `AppSpacing` / `AppInsets`.

**Who reports a failure.** Each widget listens for the mutation kind it dispatches and no other.
The sheets follow `IngredientEditorSheet` unchanged: a `_submitted` flag so only their own save
closes them, their own failure banner, and an action disabled while the bloc reports that
mutation loading. The Fields screen listens for `fieldDeleted` and raises its banner on failure.
The Libraries screen dispatches nothing and listens to nothing.

`FailureBanner` gains `Semantics(liveRegion: true)`, so a refusal or a failed save is announced
rather than only painted. It is a shared widget; the change reaches the ingredients screens too.

**Entry point.** `LibrarySwitcher` gains a second `FItemGroup` holding one `FItem`, "Manage
libraries…", which hides the popover and pushes `LibrariesPage.route(bloc:)`.

**Libraries screen** (`LibrariesPage` / `LibrariesView`) — `FHeader.nested` with a back action
and a `+` action; a `FailureBanner` slot; one `FTile` per library in stored order:

- title: the name; subtitle: `2 fields · 24 recipes`;
- suffix: a rename icon button and a delete icon button, each with a semantics label naming the
  library;
- `onPress`: opens that library's Fields screen (wired in Phase 3).

Tapping delete on the only library does not open the sheet. It sets the banner to a refusal that
says why and what to do — the pattern the ingredients screen uses for an entry in use.

**Library sheet** (`LibraryEditorSheet`, create and rename) — modelled on
`IngredientEditorSheet`: `showFSheet`, bloc re-provided, a failure banner that keeps the typed
values.

- Name: required; refused when `libraryNamed` finds a *different* library. It starts empty in
  create mode whatever template is chosen — `Cocktails` would collide on a default install.
- Create mode only: a "Start from" `FSelect` offering Blank, Cocktails and Coffee. The three
  labels come from the ARB, each paired with nothing, `templates.cocktails` or
  `templates.coffee`: the sheet throws the template's own name away, so here the names are
  chrome, not user data. Creating dispatches
  `RecipesLibrarySaved(Library(name: typed, fields: template().fields))` — the template supplies
  fields with fresh ids, never its name.
- Rename mode dispatches the same event with the library's id and fields unchanged.

**Delete sheet** (`LibraryDeleteSheet`) — a sheet rather than `showConfirmDialog` because it can
carry a control:

- the recipe count that goes with the library, with its own wording for zero;
- when `ingredientCountOnlyIn > 0`: that count, and a "Move them to" `FSelect` of the other
  libraries, preselected to the first. It is shown even when there is one other library, so there
  is one code path and the destination is always stated. Library names are unique, so they are
  safe as the select's labels;
- a destructive Delete, disabled while the delete is loading, and Cancel.

It dispatches `RecipesLibraryDeleted(id, successorId:)` — the selection, or the first other
library when no select was shown — pops on success, and on failure stays open behind a banner
with Delete enabled again.

**Fields screen** (`LibraryFieldsPage` / `LibraryFieldsView`) — takes a library **id** and reads
`libraryById` on every build. Header: the library's name, back, and a `+` action. A miss renders
the header with its back action and an empty body; nothing can delete a library while its Fields
screen is open, so this is a null-safety branch, not a flow.

- one `FTile` per field in schema order: the label; a subtitle joining the type name, the unit or
  option count, and `Required` when set; a delete icon button; `onPress` opens the field sheet;
- an empty state — a line of explanation and a primary "Add field" button — for a library with no
  fields, which is what a Blank library starts as and what deleting the last field returns to;
- delete: `showConfirmDialog` stating how many recipes carry a value (with its own wording for
  zero), then `RecipesFieldDeleted`.

**Field sheet** (`FieldEditorSheet`, add and edit):

- Label: required; unique within the library after trimming and without regard to case,
  excluding itself.
- Type: an `FSelect<FieldType>` — Text, Long text, Number, Choice. Free when adding (Text by
  default), disabled when editing, with a line saying a type cannot be changed.
- Unit: shown for Number only; optional; blank saves as null. Changing it relabels the stored
  numbers; nothing is converted.
- Options: shown for Choice only. One `OptionRowField` per option — a text field and a remove
  button, both labelled with the row's position (`Option 3`, `Remove option 3`), built like
  `StepRowField`, whose controllers class also remembers the row's **original** text (null for a
  row added in this session) — plus an "Add option" button. Blank rows are dropped on save. An
  error line under the list, itself a live region, covers "add at least one option" and "two
  options are the same". Duplicates are judged between the rows' **current** texts, ignoring
  case, never against a row's own original — so retyping `dry` as `Dry` is a rename, not a clash
  with itself.
- Required: an `FCheckbox`, the control the ingredient sheet already uses.

On save the sheet hands its rows to a pure function that lives beside the row widget, so the
table below is a unit test rather than something only a widget test can reach:

```dart
// lib/libraries/widgets/option_row_field.dart

/// The option list and the renames a set of edited rows amounts to.
///
/// Each row's text is trimmed and a blank row is dropped *before* anything is
/// derived, so blanking a stored option removes it rather than renaming it to
/// nothing.
({List<String> options, Map<String, String> renames}) optionEdits(
  Iterable<({String? original, String text})> rows,
);
```

`renames` maps a surviving row's original to its text wherever the two differ. The sheet then
asks the model what that removes: `field.optionsRemovedBy(edited, renames: renames)`.

If `recipeCountUsingOptions` finds any recipe on a `removed` option, it asks first, through
`showConfirmDialog`, stating the number of recipes. It then dispatches `RecipesLibrarySaved` with
the field replaced in place (or appended), passing `optionRenames: {field.id: renames}` when
there are any. Keying renames on the **row** rather than on the text is what makes the awkward
edits come out right:

| Edit | renames | removed | Result |
|------|---------|---------|--------|
| `Coupe` → `Coupe glass` | `{Coupe: Coupe glass}` | — | values follow the rename |
| `dry` → `Dry` | `{dry: Dry}` | — | values follow the rename; no duplicate error |
| swap `A` and `B` | `{A: B, B: A}` | — | values swap |
| delete row `B`, retype row `A` as `B` | `{A: B}` | — | a merge: both sets of recipes read `B`, nothing is cleared |
| retype row `A` as `C`, add a new row `A` | `{A: C}` | — | old values become `C`; the new `A` starts unused |
| delete row `Flute`, or blank its text | — | `{Flute}` | confirmation, then those values are cleared |
| add a row and leave it blank | — | — | the row is dropped; nothing else changes |

## Technical Considerations

- **What does not change.** The models and their JSON, `kSchemaVersion`, corrupt-blob recovery,
  the recipe editor, the details screen, `SchemaFieldControl` and the ingredients screens. The
  recipe editor and details already handle a Select value outside the option list; after this
  plan that state arises only from a partial write failure or a hand-edited blob.
- **Layering.** `lib/libraries/` imports `package:membar/recipes/recipes.dart` and
  `package:recipes_repository/recipes_repository.dart`, never a data package and never a path
  under `lib/recipes/`. `lib/recipes/` importing `lib/libraries/` for the route mirrors the
  existing `recipes` ↔ `ingredients` pair.
- **Widget tests drive a `MockBloc`**, not a real `RecipesBloc`, as the ingredients tests do.
  Sheets and option rows own controllers; their disposal is asserted with
  `LeakTesting.settings.withTrackedAll()` rather than read off `dispose()`.
- **l10n.** Every new string goes in `lib/l10n/arb/app_en.arb`, counts as ICU plurals. A seeded
  library's name and field labels stay unlocalized user data; the create sheet's three "Start
  from" labels and the field-type names are chrome. The type names come from one exhaustive
  `switch` on `FieldType`, so a new type is a compile error there.
- **forui 0.27.4 is pinned exactly.** `FSelect`, `FCheckbox`, `FTile`, `FItemGroup`, `showFSheet`
  and `FPopoverMenu` are all in use already. A disabled `FSelect` is the one API this plan has
  not seen used in the repo: read it from the resolved source in the pub cache before relying on
  it, and fall back to rendering the type as plain text in edit mode if it is awkward.

### Known limitations (update `docs/known-issues.md` as each one becomes true)

- Phase 2 — remove the entry "Deleting a library cannot simply drop it from the ingredients
  catalog". Deletion ships in that phase and closes it.
- Phase 2 — add: **a deleted library cannot be restored.** The user asked for a "recently
  deleted" area so a deletion can be reverted; it is the next slice, deliberately left out of
  this one.
- Phase 2 — add: **two libraries cannot be merged**, and a recipe cannot move between libraries.
- Phase 3 — add: **fields cannot be reordered.** Moving a field means deleting and re-adding it,
  which purges its values.

## Implementation Phases

Phase boundaries are PR boundaries. The codebase compiles and its tests pass after each.

**On running the test suite.** A repo hook routes `very_good test` through the very_good_cli MCP
`test` tool rather than the shell. Run the coverage gate through that tool with
`min_coverage: 100`; the validation commands below use the plain test runners so they are
shell-executable.

### Phase 1 (PR1): data layer and bloc

- **Status:** Done
- **Scope:** `saveLibrary` / `deleteLibrary` with their two exceptions, the storage
  implementation with its diff, the repository pass-throughs and barrel exports, and the bloc's
  three events, three mutation kinds and six derived state members. Invisible to the user. Also
  corrects the `_restore` comment that says nothing can create a library, since this phase is
  what makes it false.
- **Files touched:**
  - `packages/recipes_api/lib/src/{recipes_api.dart,models/field_definition.dart}`
  - `packages/local_storage_recipes_api/lib/src/local_storage_recipes_api.dart`
  - `packages/recipes_repository/lib/{recipes_repository.dart,src/recipes_repository.dart}`
  - `lib/recipes/bloc/{recipes_bloc.dart,recipes_event.dart,recipes_state.dart}`
  - tests: `packages/recipes_api/test/src/{recipes_api_test.dart,models/field_definition_test.dart}`,
    `packages/local_storage_recipes_api/test/src/local_storage_recipes_api_test.dart`,
    `packages/recipes_repository/test/src/recipes_repository_test.dart`,
    `test/recipes/bloc/{recipes_bloc_test.dart,recipes_event_test.dart,recipes_state_test.dart}`
- **Acceptance criteria:**
  - `optionsRemovedBy` returns the options the replacement dropped, leaves out renamed ones,
    and is empty for a field that is not a Select.
  - `saveLibrary` appends an unknown id and replaces a known one **at the same index**; throws
    `LibraryNameTakenException` on a folded collision with a different id but not when saving a
    library under its own name; writes only the libraries key when no recipe changed.
  - Replacing a library drops the values of a removed field from that library's recipes only,
    leaves a key that matched no stored field in place, leaves other libraries' recipes
    byte-identical, applies a rename, applies a two-way swap, clears the values of a removed
    option, treats "delete `B`, rename `A` to `B`" as a merge, and leaves a value that was
    already outside the stored options alone.
  - `saveLibrary` writes recipes before libraries; a failed libraries write throws
    `RecipesPersistenceException` and emits nothing.
  - Each method emits one snapshot per call, and every emitted snapshot's active id names a
    library in it.
  - `deleteLibrary` removes the library and its recipes; strips the id from shared entries;
    moves entries scoped only to it to the successor; makes the successor active when the deleted
    library was, and leaves the active id alone otherwise; throws `LibraryNotFoundException` for
    an unknown id, an unknown successor, a successor equal to the id, and the only library;
    writes ingredients, active id, recipes, libraries in that order, skipping the unchanged ones.
  - Both mutations go through the queue: one dispatched alongside a recipe save lands with it.
  - The repository delegates both calls.
  - Each bloc handler emits `loading` then `success`, emits `failure` for every declared
    exception, and names its own mutation on every emission; deleting the active library clears
    the search term and tag filter, and deleting another one does not; `RecipesFieldDeleted`
    saves the library without the field, and emits `failure` without calling the repository for
    an unknown library or field.
  - Two events of one type that differ in any payload field — `library`, `optionRenames`, `id`,
    `successorId`, `libraryId`, `fieldId` — are unequal.
  - The six state members return the documented values, including zero or null for an unknown
    id, and each count follows its predicate in the table — including a value that differs from
    an option only by surrounding whitespace, which is not counted.
  - 100% coverage in all four units.
- **Validation:** `(cd packages/recipes_api && dart pub get && dart analyze && dart test) && (cd packages/local_storage_recipes_api && flutter pub get && flutter analyze && flutter test) && (cd packages/recipes_repository && dart pub get && dart analyze && dart test) && flutter analyze && dart run bloc_tools:bloc lint . && flutter test`

### Phase 2 (PR2): library manager

- **Status:** Done
- **Scope:** the switcher's "Manage libraries…" item, the Libraries screen, the create/rename
  sheet and the delete sheet. After this phase a user can create a Tea library from a template,
  rename it and delete it; its fields are still whatever the template gave it. A Libraries tile
  has no `onPress` yet — say so in the PR description; Phase 3 wires it.
- **Files touched:**
  - `lib/libraries/{libraries.dart,view/libraries_page.dart,view/libraries_view.dart,widgets/library_editor_sheet.dart,widgets/library_delete_sheet.dart}` (new)
  - `lib/recipes/widgets/library_switcher.dart`, `lib/l10n/arb/app_en.arb`,
    `lib/ui/failure_banner.dart`, `docs/known-issues.md`,
    `packages/recipes_api/lib/src/templates/library_templates.dart` (doc comment only)
  - tests: `test/libraries/view/{libraries_page_test.dart,libraries_view_test.dart}`,
    `test/libraries/widgets/{library_editor_sheet_test.dart,library_delete_sheet_test.dart}` (new),
    `test/recipes/widgets/library_switcher_test.dart`, `test/ui/failure_banner_test.dart`
- **New ARB keys:** the switcher item; the screen's title, add label, tile subtitle (two
  plurals), rename and delete labels, last-library refusal and failure messages; the sheet's two
  titles, name label, required and taken errors, "Start from" label and its three entries,
  save, create and cancel labels and failure message; the delete sheet's title, recipe-count
  line, ingredient line, "Move them to" label, confirm and cancel labels and failure message.
- **Acceptance criteria:**
  - "Manage libraries…" closes the popover and pushes the Libraries screen with the bloc
    re-provided.
  - The screen lists libraries in stored order with their field and recipe counts.
  - Create: a blank name and a name folding onto an existing library are refused in the form;
    Blank creates a library with no fields; a template creates one with that template's field
    labels under the typed name; the sheet closes on its own success only, and keeps the typed
    values behind a banner on failure.
  - Rename: the sheet opens prefilled, accepts the library's own name, and dispatches the same
    id and fields.
  - Delete: the sheet states the recipe count, including zero; shows the ingredient line and the
    select only when an entry is scoped solely to the library; dispatches the selected successor,
    or the first other library when no select was shown; disables Delete while loading; pops on
    success, and on failure stays open behind a banner with Delete enabled.
  - Tapping delete on the only library opens nothing and shows the refusal.
  - `FailureBanner` is a live region.
  - Sheets dispose their controllers, asserted with leak tracking. 100% coverage.
- **Validation:** `flutter pub get && flutter gen-l10n && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`

### Phase 3 (PR3): field editor

- **Status:** Done
- **Scope:** the Fields screen, the field sheet with its option rows, the two confirmations, the
  Libraries tile's `onPress`, and the documentation updates.
- **Files touched:**
  - `lib/libraries/{view/library_fields_page.dart,view/library_fields_view.dart,widgets/field_editor_sheet.dart,widgets/option_row_field.dart}` (new),
    `lib/libraries/{libraries.dart,view/libraries_view.dart}`, `lib/l10n/arb/app_en.arb`
  - `docs/known-issues.md`
  - tests: `test/libraries/view/{library_fields_page_test.dart,library_fields_view_test.dart}`,
    `test/libraries/widgets/{field_editor_sheet_test.dart,option_row_field_test.dart}` (new),
    `test/libraries/view/libraries_view_test.dart`
- **New ARB keys:** the Fields screen's add label, empty-state title and description, tile
  subtitle parts (option count plural, `Required`), delete label, delete confirmation (title,
  plural description, confirm, cancel) and failure message; the four field-type names; the
  sheet's two titles, label / type / unit / options / required labels, type-locked note, the
  option field label and remove label (both positional), the add-option label, the three
  validation errors, the removed-options confirmation (title, plural description, confirm,
  cancel), save and cancel labels and failure message.
- **Acceptance criteria:**
  - Tapping a library opens its Fields screen; the screen follows the bloc, so a field saved
    from the sheet appears without reopening it.
  - A library with no fields shows the empty state, and its button opens the sheet.
  - Add: the type defaults to Text; Unit appears for Number only and Options for Choice only; a
    blank or duplicate label is refused; a Choice with no non-blank option, or with two options
    equal ignoring case, is refused; the new field is appended.
  - Edit: the sheet opens with the field's values, the type cannot be changed, and saving keeps
    the field's id and position.
  - Options: `optionEdits` returns the options and renames of each of the seven rows of the
    table under "Field sheet", unit-tested without a widget; one widget test proves the sheet
    dispatches what it returns; removing an option no recipe uses asks nothing; removing one in use asks with the
    count, and cancelling leaves the sheet open with nothing dispatched.
  - Delete field: the confirmation states the number of recipes carrying a value, including zero,
    and confirming dispatches `RecipesFieldDeleted`.
  - A failed save keeps the sheet open behind a banner with every typed value intact and
    raises **no** banner on the Fields screen beneath it. A failed field delete raises the
    screen's banner.
  - Option rows dispose their controllers when removed and when the sheet closes, asserted with
    leak tracking. 100% coverage.
- **Validation:** `flutter pub get && flutter gen-l10n && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`

## Success Criteria

```success-criteria
GOAL: A user can create, rename and delete libraries and add, edit and delete the fields each library declares, with every destructive edit stating what it will remove before it removes it, no catalog ingredient ever deleted by a library deletion, and no change to any stored shape.

SUCCESS CRITERIA:
- Static analysis is clean across the app and all three packages | verify: flutter analyze && (cd packages/recipes_api && dart analyze) && (cd packages/local_storage_recipes_api && flutter analyze) && (cd packages/recipes_repository && dart analyze)
- Code is formatted | verify: dart format --output=none --set-exit-if-changed .
- Bloc lints pass | verify: dart run bloc_tools:bloc lint .
- Localized strings generate cleanly, plurals included | verify: flutter gen-l10n && flutter analyze
- recipes_api declares saveLibrary and deleteLibrary with LibraryNameTakenException and LibraryNotFoundException, and FieldDefinition.optionsRemovedBy leaves renamed options out | verify: cd packages/recipes_api && dart analyze && dart test
- local_storage_recipes_api: saveLibrary appends or replaces in place, refuses a folded name collision with a different id, purges a removed field's values from that library only, applies renames including a swap, clears removed options, leaves unknown keys and other libraries' recipes untouched, and writes recipes before libraries; deleteLibrary cascades to recipes, strips or reassigns catalog entries so none is left in no library, hands the active library to the successor, refuses an unknown id, an unknown successor, a successor equal to the id and the only library, and writes ingredients, active id, recipes, libraries in that order | verify: cd packages/local_storage_recipes_api && flutter test
- recipes_repository delegates saveLibrary and deleteLibrary to the injected RecipesApi | verify: cd packages/recipes_repository && dart test
- App, bloc and widget tests pass, covering: all three handlers emitting loading then success, emitting failure for each declared exception and naming their own mutation; filters clearing only when the active library is deleted; event equality over every payload field; the six derived state members; the switcher item; the Libraries screen's list, counts and last-library refusal; create from Blank and from a template; rename; the delete sheet's counts, conditional successor select and dispatched successor; the Fields screen's list, empty state and delete confirmation; the field sheet's per-type controls, locked type on edit, label and option validation, the seven option edits in the plan's table, a failed sheet save raising no banner beneath it, and the removed-options confirmation | verify: flutter test
- The schema version is unchanged and no generated model code changed | verify: grep -q "kSchemaVersion = 2" packages/local_storage_recipes_api/lib/src/local_storage_recipes_api.dart && git diff --quiet main -- 'packages/recipes_api/lib/src/models/*.g.dart'
- Sheet and option-row controllers are disposed, proven rather than read | verify: grep -rq "withTrackedAll" test/libraries
- The libraries feature reaches the bloc through the recipes barrel and nothing deeper | verify: ! grep -rq "package:membar/recipes/widgets/\|package:membar/recipes/view/\|package:membar/recipes/bloc/" lib/libraries/
- Presentation never imports a data package directly | verify: ! grep -rq "package:local_storage_recipes_api\|package:recipes_api" lib/recipes lib/ingredients lib/libraries lib/app lib/ui
- The closed known issue is gone and the new limitations are recorded | verify: ! grep -q "cannot simply drop it from the ingredients catalog" docs/known-issues.md && grep -qi "cannot be restored" docs/known-issues.md && grep -qi "cannot be reordered" docs/known-issues.md
- Coverage is 100% in the app and all three packages | verify: manual 1) run the very_good_cli MCP `test` tool with min_coverage 100 at the repo root 2) run it again for each of packages/recipes_api, packages/local_storage_recipes_api and packages/recipes_repository 3) confirm all four report 100%
- Schema edits survive a restart and reach the recipe screens | verify: manual 1) run `flutter run --flavor development --target lib/main_development.dart` 2) in Cocktails add a recipe with Glassware `Flute` and a Garnish, and add an ingredient that exists only in Cocktails 3) open the switcher, choose `Manage libraries…`, create `Tea` from the Coffee template, and confirm it lists five fields and no recipes 4) open Cocktails' fields, edit Glassware, retype `Flute` as `Champagne flute` and save; confirm the recipe's details show `Champagne flute` 5) edit Glassware again, remove `Champagne flute`, and confirm the warning names 1 recipe; confirm, and check the recipe now shows no Glassware 6) delete the Garnish field, confirming the warning names 1 recipe, and check the recipe editor no longer shows Garnish 7) add a required Number field `ABV` with unit `%` and confirm the recipe editor refuses to save the recipe without it 8) with Cocktails active, delete Cocktails; confirm the sheet names its recipe count and offers to move its ingredients, choose Tea, and confirm 9) confirm the list screen now shows another library with no filter applied, and the ingredients screen lists the moved ingredient under Tea 10) delete libraries until one is left and confirm the last one is refused with an explanation 11) fully kill and relaunch the app and confirm the libraries, fields and ingredients are as you left them

NON-GOALS:
- Restoring a deleted library, field or option ("recently deleted" / undo) — the next slice
- Reordering fields
- Changing a field's type, or converting stored values between types
- Deleting the last library, and any zero-library state
- Moving a recipe between libraries, merging libraries, duplicating a library
- Saving a user's library as a template, or editing the built-in templates
- Library icons or emoji
- Min/max or other validation rules on a field beyond `required`
- A discard-changes prompt on the sheets (they follow the ingredient sheets: Cancel closes)
- Localizing template names, or reintroducing Spanish
- Sweeping the existing recipe screens onto `AppSpacing` (still a known issue)

VERIFICATION COMMAND: (cd packages/recipes_api && dart pub get && dart analyze && dart test) && (cd packages/local_storage_recipes_api && flutter pub get && flutter analyze && flutter test) && (cd packages/recipes_repository && dart pub get && dart analyze && dart test) && flutter pub get && flutter gen-l10n && dart format --output=none --set-exit-if-changed . && flutter analyze && dart run bloc_tools:bloc lint . && flutter test && grep -q "kSchemaVersion = 2" packages/local_storage_recipes_api/lib/src/local_storage_recipes_api.dart && git diff --quiet main -- 'packages/recipes_api/lib/src/models/*.g.dart' && grep -rq "withTrackedAll" test/libraries && ! grep -rq "package:membar/recipes/widgets/\|package:membar/recipes/view/\|package:membar/recipes/bloc/" lib/libraries/ && ! grep -rq "package:local_storage_recipes_api\|package:recipes_api" lib/recipes lib/ingredients lib/libraries lib/app lib/ui && ! grep -q "cannot simply drop it from the ingredients catalog" docs/known-issues.md && grep -qi "cannot be restored" docs/known-issues.md && grep -qi "cannot be reordered" docs/known-issues.md
```

## Success Metrics

- A third domain — tea, wine notes, baking — is added entirely in the UI, with **zero** Dart
  changes.
- No library deletion ever reduces the size of the ingredients catalog.
- Every destructive schema edit shows a count before it runs, and the count matches what is
  removed.
- Zero bytes of stored data are rewritten by upgrading to this version.
- 100% line coverage across the app and all three packages, unchanged from today.

## Dependencies & Risks

- **The field sheet is the risk.** It is the first form in the repo whose controls depend on
  another control's value, it owns a dynamic row list, and its save derives two sets and may
  raise a confirmation — against a 100% coverage bar. Phase 3 exists to hold it in its own
  review, and the table of option edits is its test list.
- **Multi-key writes are not atomic.** `shared_preferences` has no transaction. The write order
  makes every partial state renderable and a retry complete it, but a failure followed by an
  app restart can leave an emptied library or a cleared value behind without the schema change
  that justified it. Accepted at personal scale, as it already is for `importIngredients`.
- **A count shown must match what is removed.** Which options a save removes is shared code
  (`optionsRemovedBy`). The recipe and ingredient counts are not; the predicate table under "Bloc
  surface" is what the bloc's state tests and the storage tests are both written from.
- **Corrupt-libraries recovery now costs more.** An unreadable libraries blob still re-seeds the
  two templates with fresh ids, which hides every recipe (kept, reported as dangling). Until now
  that lost nothing a reinstall would not rebuild; from here it also loses libraries and fields
  the user authored. Accepted for this slice and unchanged by it; a recovery that preserves
  schemas belongs with the "recently deleted" work.
- **`lib/recipes/bloc/` keeps growing.** A sixth and seventh mutation land in one bloc. Splitting
  it is not justified by this plan — every new confirmation reads across libraries, recipes and
  the catalog — but it is the next thing to revisit if a further feature adds more.
- **Depends on nothing unmerged.** The branch starts from `main` at `e9d9340`.

## References & Research

- Parent plan and its PR2 notes: `docs/plan/2026-08-14-feat-add-schema-driven-recipe-libraries-plan.md`
- Decision record: `docs/brainstorm/2026-08-11-recipe-libraries-brainstorm-doc.md` ("Schema
  edits: warn, then drop")
- The catalog constraint this plan closes: `docs/known-issues.md`, and
  `docs/plan/2026-09-12-feat-add-ingredients-catalog-plan.md`
- Patterns to mirror:
  - multi-key serialized mutation: `importIngredients` and `_merged` in
    `packages/local_storage_recipes_api/lib/src/local_storage_recipes_api.dart`
  - mutation handler shape: `_onIngredientSaved` in `lib/recipes/bloc/recipes_bloc.dart`
  - derived state members: `ingredientNamed`, `ingredientUsage` in
    `lib/recipes/bloc/recipes_state.dart`
  - pushed page re-providing the bloc: `lib/ingredients/view/ingredients_page.dart`
  - list screen with refusal banner and delete: `lib/ingredients/view/ingredients_view.dart`
  - form sheet: `lib/ingredients/widgets/ingredient_editor_sheet.dart`
  - dynamic rows with owned controllers: `lib/recipes/widgets/step_row_field.dart`
  - confirmation: `lib/ui/confirm_dialog.dart`
  - fixtures and harness: `test/helpers/fixtures.dart`, `test/helpers/pump_app.dart`
- External research: none. Every widget and pattern this plan uses is already in the repo.
