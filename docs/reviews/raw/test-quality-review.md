# Test Quality Review

**Branch:** `feat/ingredients` vs merge-base `4c6c2795a6c0fcb6f47394093b914ddd8f747507`
**Scope:** app (`lib/`, `test/`) + `packages/recipes_api`, `packages/local_storage_recipes_api`,
`packages/recipes_repository`
**Plan under test:** `docs/plan/2026-09-12-feat-add-ingredients-catalog-plan.md`

## Coverage Summary

- Test run (via the very_good_cli MCP `test` tool, `min_coverage: 100`, `exclude_coverage: **/*.g.dart`):
  - Root app: **Pass** — 300 tests, "All tests passed!"
  - `packages/recipes_api`: **Pass** — 120 tests
  - `packages/local_storage_recipes_api`: **Pass** — 47 tests
  - `packages/recipes_repository`: **Pass** — 12 tests
  - All four report the `min_coverage: 100` gate satisfied (the tool would have failed the run
    otherwise; none did).
- Static analysis (`flutter analyze` / `dart analyze` for all three packages): **No issues found**
  in all four targets, confirming `public_member_api_docs` is satisfied without needing a
  file-by-file audit.
- Files with tests: every new and changed unit listed in the plan's "Files touched" sections for
  Phases 1–3 has a corresponding test file. No missing test files found.

## Method

Read every new/changed production file paired with its test file for the highest-risk units named
in the plan (the picker, the create sheet, the editor sheet, the bloc/state, the local storage
migration, and the editor/details pages' link-resolution logic), then spot-checked the remaining
smaller diffs (event equality, repository pass-throughs, model round-trips, the five plumbing
sites, the moved `lib/ui/` widgets). Cross-checked the plan's grep-based success-criteria lines
directly against the working tree (schema key/version, moved files, `showRecipeConfirmDialog`
absence, the two layering greps, `withTrackedAll` usage) — all passed as claimed.

## State Management Test Quality

- `test/recipes/bloc/recipes_bloc_test.dart`: **Pass.** Every handler has a happy path and a
  failure path per declared exception. The plan's hardest requirement — "every emission carries
  its own mutation kind, proven by a blocTest interleaving a recipe save and an ingredient save" —
  is met exactly: the `overlapping mutations` group holds a recipe save open on an uncompleted
  `Completer`, fires an ingredient save through to completion, then resolves the recipe save, and
  asserts the full four-state sequence carries the correct `mutation` on every entry. Scope-widen
  is asserted to emit **no** state at all, on both the failure and already-in-scope/unknown-id
  paths, which is the behavior the plan calls out as "safe by construction."
- `test/recipes/bloc/recipes_state_test.dart`: **Pass.** Every derived getter
  (`libraryIngredients`, `otherLibraryIngredients`, `ingredientUsage`, `importableIngredients`,
  `ingredientById`) is tested for its ordering rule, its cross-library counting rule, and its edge
  cases (empty, one entry used twice, a dangling `catalogId`, a recipe in a deleted library). The
  `importableIngredients` "is equal across two reads" test directly proves the plan's
  id-free-value-type design point (a `blocTest` could not otherwise pin down freshly-minted ids).
- `test/recipes/bloc/recipes_event_test.dart`: **Pass.** Every event's equality is tested; the two
  no-payload events are deliberately built non-const with a comment explaining why (avoids
  const-canonicalization masking a broken `props`).
- `packages/local_storage_recipes_api/test/src/local_storage_recipes_api_test.dart`: **Pass**, and
  the most demanding file in the diff. All four rows of the plan's migration table are covered,
  including write-order assertions via a `_RecordingStore`; the "written only when absent" and
  "version written last" invariants are both directly exercised. Serialization is proven with a
  real overlapping-write race (`Future.wait`) and the before-initial-write ordering case the plan
  calls out by name. Every recovery path reports through the injected callback and is asserted on
  its exact message prefix rather than just "something was reported."

## UI Component Test Quality

- `test/recipes/widgets/ingredient_picker_test.dart`, `ingredient_create_sheet_test.dart`,
  `test/ingredients/widgets/ingredient_editor_sheet_test.dart`: **Pass.** All three use
  `MockBloc`/`whenListen`, never a real `RecipesBloc`. Both sheets assert controller disposal with
  `experimentalLeakTesting: LeakTesting.settings.withTrackedAll()` as required. The picker's
  ordering, empty-catalog create action, unit-prefill-only-when-empty-or-previous-default rule, and
  scope-widen dispatch are all exercised with real widget interaction (tap/enterText +
  pumpAndSettle), not just unit-level checks on the pure `catalogEntryNamed`/`_filter` logic. The
  create sheet's reuse-and-widen path and its "switches the unit as the name is typed onto an
  entry" test both match the plan's most subtle acceptance criterion precisely.
- `test/recipes/view/recipe_editor_page_test.dart`: **Pass.** The `catalog links` group is a
  faithful test of all five invariants in the plan: link-by-pick, link-by-exact-type, link-by-
  typeahead-completion, drop-on-hand-edit, same-entry-from-two-rows, save-as-free-text after the
  entry is deleted mid-edit, a renamed entry opening with its new name **and** not opening dirty,
  and a created-but-abandoned entry surviving in the catalog. This is exactly the "five plumbing
  sites" and "five invariants" section of the plan translated into tests.
- `test/recipes/view/recipe_details_page_test.dart`: **Pass.** Confirms a referenced row renders
  the catalog's current name and an unreferenced/dangling one renders the stored name, in the same
  test group, using a recipe crafted to include both cases plus a plain free-text row.
- `test/ingredients/view/ingredients_view_test.dart`: **Pass.** Covers the list, the per-entry
  usage count (including "Not used"), the usage-guarded delete (refused-with-count vs.
  confirm-then-dispatch), and the import's three offer states (nothing to import / offered above a
  list / offered on the empty state) plus its in-flight-disabled and failure-banner behavior.
- `test/ui/confirm_dialog_test.dart`, `test/ui/failure_banner_test.dart`: moved cleanly with the
  rename; the padding-regression test measures rendered geometry against the frame rather than
  asserting on the widget tree, avoiding an implementation-mirroring assertion.

## Anti-Patterns Found

None of the anti-patterns in the checklist (tautological assertions, mocking the SUT,
implementation-mirroring, assertion-free tests, single-state UI coverage, magic numbers without
context, over-verification, missing async waits) were found in the reviewed files. No test body
carries a comment restating its own test name — comments present are all "why" notes (e.g. why a
value is deliberately non-`const`, why a measurement is taken from rendered geometry rather than
the widget tree), consistent with the project's own comment convention.

## Recommendations

1. `test/recipes/bloc/recipes_bloc_test.dart`'s `'initial state has nothing loaded'` test builds a
   bloc directly (`buildBloc().state`) outside `blocTest`, which manages closing the bloc for every
   other test in the file. This one instance is never closed. It causes no observed failure (the
   suite is green under the config's leak tracking), but tearing it down explicitly would make the
   file's bloc-lifecycle handling uniform. Cosmetic only.
2. No other actionable gaps found. The suite is unusually disciplined about matching tests to the
   plan's named acceptance criteria almost line-for-line, particularly around the picker's
   `contentBuilder`-not-`filter` behavior, the storage migration's write-ordering guarantees, and
   the bloc's per-emission mutation-kind invariant — the three areas the plan itself flagged as the
   highest risk.

## Verdict

All tests pass quality bar. Nothing here blocks merge.
