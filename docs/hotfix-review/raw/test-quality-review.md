# Test Quality Review

Scope: uncommitted changes on `hotfix/confirm-dialog-padding` —
`lib/recipes/widgets/confirm_dialog.dart` (modified), `lib/ui/app_spacing.dart` and
`lib/ui/ui.dart` (new), `test/recipes/widgets/confirm_dialog_test.dart` (new),
`docs/known-issues.md` (new, documentation only — not reviewed for test quality).

## Coverage Summary

- Test run: **Pass** — `very_good test --coverage` (via MCP), 164/164 tests green.
- `dart analyze` on the changed files: no errors, no lints.
- Coverage: `lib/recipes/widgets/confirm_dialog.dart` is 18/18 lines hit (100% line
  coverage). `lib/ui/app_spacing.dart` and `lib/ui/ui.dart` emit no `SF:` record in
  `coverage/lcov.info` at all — both files are pure `const` declarations with no
  executable statements, so there is nothing for a line-coverage tool to measure. That
  is expected and not a gap; see the tokens discussion below.
- Files with tests: 1/1 changed testable unit (`confirm_dialog.dart`) has a test file.
  `app_spacing.dart`/`ui.dart` are data-only and do not need one — see Recommendations.
- Missing test files: none.

100% line coverage is misleading here: it does not mean every *branch* is exercised.
See the barrier-dismissal gap below — the line is always hit, but only one operand of
`confirmed ?? false` is ever exercised by the current suite.

## Convention Compliance

`test/recipes/widgets/confirm_dialog_test.dart` follows this repo's established
pattern closely:

- Uses `tester.pumpApp(...)` from `test/helpers/pump_app.dart`, matching every other
  widget test in the repo — no bare `pumpWidget`.
- Top-level `group('showRecipeConfirmDialog', ...)` named after the unit under test,
  matching the `group('RecipeTile', ...)`, `group('LibrarySwitcher', ...)`,
  `group('FailureBanner', ...)` convention in sibling files.
- Local `Future<void> open(WidgetTester tester)` helper mirrors the `pumpTile` /
  `pumpSwitcher` / `pumpDetails` helper-closure pattern used throughout — no
  duplicated pump/tap boilerplate per test.
- No bloc involved (this widget takes no bloc), so the absence of `MockBloc` /
  `whenListen` / `bloc_test` machinery is correct, not a gap — it matches
  `failure_banner_test.dart`, the repo's other bloc-free widget test.
- Every interaction (`tester.tap`) is followed by `await tester.pumpAndSettle()`. No
  missing awaits, no unsettled pumps.
- Assertions are behavioral (`content.padding`, `isTrue`/`isFalse`) — no tautologies,
  no implementation mirroring, no mock over-verification (there are no mocks to
  over-verify here).

No convention deviations found.

## Padding Assertion: Robustness

The regression test walks up from the title `Text` to the nearest `Padding` ancestor
and asserts it equals `AppInsets.dialogContent`:

```dart
final content = tester.widget<Padding>(
  find.ancestor(of: find.text('Delete Negroni?'), matching: find.byType(Padding)).first,
);
expect(content.padding, AppInsets.dialogContent);
```

Strengths:
- `find.ancestor(...)` orders matches nearest-first, and the in-code comment states
  the rationale precisely: without the fix, the nearest `Padding` ancestor is the
  dialog route's own inset padding, not the content padding this test cares about.
  This is exactly what the task's empirical revert-and-rerun check showed
  (`EdgeInsets(40.0, 24.0, 40.0, 24.0)` vs the expected `EdgeInsets.all(24.0)`), so the
  test is provably tied to the real bug, not coincidentally passing.
- It asserts structure (which `Padding` sits immediately around the content) rather
  than a raw pixel literal, so it will not spuriously break if a completely unrelated
  ancestor `Padding` is introduced somewhere further up the tree.

Weakness (see Anti-Pattern/Finding below): the expected value is
`AppInsets.dialogContent`, the same named constant the production code applies. That
protects the *wiring* (padding is applied, and applied as the nearest ancestor) but
not the *value* — if someone edits `AppInsets.dialogContent` in `app_spacing.dart` to
`EdgeInsets.zero`, both the assertion and the production code change together and the
test stays green while the visual bug reappears. Asserting a literal
(`EdgeInsets.all(24)`) or a dedicated token test would close this.

## Coverage Gap: Barrier Dismissal

The doc comment on `showRecipeConfirmDialog` claims:

> resolving to true when they confirm and false when they cancel **or dismiss the
> dialog**.

`showFDialog` (forui 0.24.1, `lib/src/widgets/dialog.dart:71`) defaults
`barrierDismissible: true`, and `FDialogRoute` passes that straight to
`RawDialogRoute`, whose barrier tap pops the route with a `null` result. That flows
into `confirmed ?? false` (`confirm_dialog.dart:62`), so dismiss-via-barrier should
resolve `false` — but no test exercises this path. The two behaviors this class
promises to callers (cancel-button → false, barrier-tap → false) are asserted only
for the first. Given the doc comment explicitly calls out barrier dismissal as a
resolved case, this is a real, named contract with no test.

A test could tap outside the dialog surface (e.g.
`tester.tapAt(Offset.zero)` or on the `ModalBarrier`) and assert
`await result == isFalse`, mirroring the existing cancel test.

## Redundancy vs. `recipe_details_page_test.dart`

Not redundant — the two suites test different layers, and the overlap is intentional
and appropriate:

- `confirm_dialog_test.dart` unit-tests `showRecipeConfirmDialog`'s own contract in
  isolation: given a confirm/cancel tap, what does the returned `Future<bool>`
  resolve to, and is the content padded. It has no bloc, no navigation stack beyond
  a bare route.
- `recipe_details_page_test.dart`'s `group('delete', ...)` integration-tests that
  `RecipeDetailsPage` wires the dialog correctly: confirming dispatches
  `RecipesRecipeDeleted`, cancelling does not, and the page reacts to the bloc's
  mutation status afterward. `recipe_editor_page_test.dart` does the equivalent for
  the "discard changes" call site.

`showRecipeConfirmDialog` is shared by two call sites specifically so both present
the same dialog; giving the shared widget its own direct test suite — rather than
relying solely on each call site's integration test — is the correct pattern here,
consistent with how `LibrarySwitcher` and `RecipeTile` each get their own test file
independent of the pages that embed them. If anything, this is what should happen
when new shared widgets are extracted, not a gap to close.

## Design Tokens (`AppSpacing` / `AppInsets`)

No dedicated test file, and none is needed: both classes are `abstract final class`
containers of `static const` values with no logic, computation, or branching. A test
asserting `expect(AppSpacing.sm, 8.0)` would be tautological — it restates the
literal already visible in the source next to its doc comment, and coverage tooling
correctly emits no `SF:` record for either file since there is nothing executable to
hit. This matches the project's existing practice of not writing tests for pure data
declarations elsewhere in the repo.

The one place a token's value should be pinned by a test is where it is consumed to
fix a visible bug — see the padding-assertion weakness above. Closing that (assert a
literal, or add one focused test locking `AppInsets.dialogContent` to
`EdgeInsets.all(24)`) gives the token file exactly the coverage it needs without
adding a hollow test file.

## Anti-Pattern Scan

None found in the new test file. Specifically checked and clear:

- Tautological assertions (`expect(true, isTrue)`-style): none.
- Mocking the class under test: not applicable, no mocks used.
- Implementation mirroring: the padding assertion checks structural placement and a
  named constant, not a re-derivation of the widget's build logic.
- Missing assertions: every `testWidgets` block ends in a meaningful `expect`.
- Missing awaits / unsettled pumps: every `tap` is paired with
  `await tester.pumpAndSettle()`.
- Hardcoded magic values: `AppInsets.dialogContent` is used instead of a bare
  `EdgeInsets.all(24.0)` literal — this cuts the other way (see weakness above) but
  is not a magic-value problem.
- Over-verification: no `verify()` calls at all in this file (none needed, no mocks).

## Recommendations

1. **Important** — Add a test for barrier-tap dismissal resolving to `false`. This is
   the one behavior the function's own doc comment promises that has zero coverage.
2. **Important** — Stop asserting the padding test's expectation against the same
   `AppInsets.dialogContent` constant the production code reads. Assert the literal
   `EdgeInsets.all(24)` (or add one `AppInsets.dialogContent` value-pinning test) so a
   change to the token itself cannot silently reopen the bug this test exists to
   catch.
3. **Suggestion** — Assert that `description` renders (`find.text('This cannot be
   undone.')`), matching the existing assertion on `title`, so a regression that
   drops the description silently would fail a test.

## Verdict

Fix 2 issues before merging (barrier-dismissal coverage gap, self-referential padding
assertion). Everything else — convention compliance, the core regression test's
grounding in the actual bug, redundancy analysis, and the decision not to test the
token file — passes the bar.
