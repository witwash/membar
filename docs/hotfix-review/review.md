# Code Review — hotfix/confirm-dialog-padding (working tree)

7 findings · 🔴 0 critical · 🟡 3 important · 🔵 4 suggestions
Across 3 files. Agents: vgv-review-agent, test-quality-review-agent.

## Findings Index

| ID | Severity | Rule | Location | Finding |
|----|----------|------|----------|---------|
| FINDING-01 | 🟡 Important | `vgv/spacing-scale-deviates-from-vgv-names` | `lib/ui/app_spacing.dart:9-27` | Spacing step names collide with VGV's canonical AppSpacing |
| FINDING-02 | 🟡 Important | `tests/missing-documented-behavior-coverage` | `test/recipes/widgets/confirm_dialog_test.dart` | Barrier-tap dismissal (documented to resolve false) is untested |
| FINDING-03 | 🟡 Important | `vgv/test-asserts-widget-tree-not-rendered-output` | `test/recipes/widgets/confirm_dialog_test.dart:37-46` | Padding assertion is structural and self-referential |
| FINDING-04 | 🔵 Suggestion | `vgv/missing-dialog-semantics-label` | `lib/recipes/widgets/confirm_dialog.dart:20` | Dialog has no semantics label |
| FINDING-05 | 🔵 Suggestion | `vgv/deep-widget-tree-in-function` | `lib/recipes/widgets/confirm_dialog.dart:24-53` | Extract the dialog content into a private widget |
| FINDING-06 | 🔵 Suggestion | `vgv/single-use-abstraction` | `lib/ui/app_spacing.dart:33-40` | AppInsets holds one constant and repeats the call-site rationale |
| FINDING-07 | 🔵 Suggestion | `tests/incomplete-happy-path-assertions` | `test/recipes/widgets/confirm_dialog_test.dart:31` | Description text is never asserted to render |

## Important

### FINDING-01 · `vgv/spacing-scale-deviates-from-vgv-names` · `lib/ui/app_spacing.dart:9-27`
Spacing step names collide with VGV's canonical AppSpacing.
- **Why**: VGV's scale (verified in the material-theming skill reference) is `spaceUnit` 16 with xxs 4, xs 6, sm 8, md 12, lg 16, xlg 24, xxlg 32 — here `xxs` is 2, `xs` is 4, and 24 is `xl`, so three names mean something other than what a VGV developer reads them as.
- **Fix**: Adopt the canonical scale verbatim, derived from `spaceUnit = 16`, while only three call sites exist.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)
- **Resolution**: not adopted. The scale is now numeric against a base of 8 (`spacing100` = 8), a deliberate deviation scoped to spacing and sizing tokens. Do not re-apply the t-shirt names.

### FINDING-02 · `tests/missing-documented-behavior-coverage` · `test/recipes/widgets/confirm_dialog_test.dart`
Barrier-tap dismissal (documented to resolve false) is untested.
- **Why**: `showFDialog` defaults to `barrierDismissible: true` and the function's doc comment promises dismissal resolves false, but nothing exercises the `confirmed ?? false` branch.
- **Fix**: Add a case that taps outside the dialog and asserts the future resolves false.
- **Reported by**: test-quality-review-agent, vgv-review-agent · [details](raw/test-quality-review.md), [details](raw/vgv-review.md)

### FINDING-03 · `vgv/test-asserts-widget-tree-not-rendered-output` · `test/recipes/widgets/confirm_dialog_test.dart:37-46`
Padding assertion is structural and self-referential.
- **Why**: It compares a found `Padding` widget against `AppInsets.dialogContent` — the same constant production applies — so setting that token to zero keeps the test green while restoring the bug.
- **Fix**: Assert rendered geometry: measure the title's rect against the dialog frame's rect and pin the gap to the literal 24.
- **Reported by**: vgv-review-agent, test-quality-review-agent · [details](raw/vgv-review.md), [details](raw/test-quality-review.md)

## Suggestions

### FINDING-04 · `vgv/missing-dialog-semantics-label` · `lib/recipes/widgets/confirm_dialog.dart:20`
Dialog has no semantics label.
- **Why**: `FDialog.semanticsLabel` is null, so screen readers announce nothing when a destructive confirmation opens.
- **Fix**: Pass `semanticsLabel: title` on the `FDialog`.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-05 · `vgv/deep-widget-tree-in-function` · `lib/recipes/widgets/confirm_dialog.dart:24-53`
Extract the dialog content into a private widget.
- **Why**: The builder closure is a five-level tree inside a top-level function, and tests have no type to target.
- **Fix**: Extract `_ConfirmDialogContent` taking the four strings and two callbacks.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-06 · `vgv/single-use-abstraction` · `lib/ui/app_spacing.dart:33-40`
AppInsets holds one constant and repeats the call-site rationale.
- **Why**: The forui explanation is written twice — once on the token, once at the call site.
- **Fix**: Keep the named inset (it is the reusable surface the user asked for) but delete the duplicated rationale from one of the two places.
- **Reported by**: vgv-review-agent · [details](raw/vgv-review.md)

### FINDING-07 · `tests/incomplete-happy-path-assertions` · `test/recipes/widgets/confirm_dialog_test.dart:31`
Description text is never asserted to render.
- **Why**: A regression that drops the description would pass every current test.
- **Fix**: Assert the description alongside the title.
- **Reported by**: test-quality-review-agent · [details](raw/test-quality-review.md)

## Why this matters

Nothing here threatens the fix itself — both agents confirmed the diagnosis against forui
0.24.1's source, and the suite is green. The lever is FINDING-01 and FINDING-03 together: a
tokens module is only worth having if its names mean what the team expects and if something
fails when a token drifts, and both are far cheaper to settle now, at three call sites, than
after the migration recorded in `docs/known-issues.md`.
