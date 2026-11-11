---
title: "fix: whole list item tap target"
type: fix
date: 2026-11-11
---

## fix: whole list item tap target - Minimal

On the starter catalog, tapping a recipe row's checkbox does nothing. Only the rest of the row toggles it.

The rule this fix sets for the whole app: **tapping anywhere on a list item triggers its main action, and the item is one keyboard stop.** The only exceptions are explicit action buttons on the item, such as rename, delete or move, which keep their own targets. A grid scan of every list in the app found the catalog checkbox to be the only place that breaks the rule.

The fix:

- moves the catalog's private `_SelectableTile` into `lib/ui` as a public `SelectableTile`,
- isolates its display-only checkbox from forui's tile-group gesture handling and from keyboard focus,
- adds a `list-items` project skill so future lists follow the rule. The skill loads only when list work comes up, not in every session.

## Success Criteria

```success-criteria
GOAL: Every list item triggers its main action when tapped anywhere outside its explicit action buttons, and is a single keyboard stop; the starter catalog uses a shared SelectableTile that guarantees this, and a list-items project skill records the rule.

SUCCESS CRITERIA:
- SelectableTile lives in lib/ui and is exported from the ui barrel | verify: test -f lib/ui/selectable_tile.dart && grep -q "export 'selectable_tile.dart';" lib/ui/ui.dart
- The starter catalog no longer carries its own private tile | verify: ! grep -q "_SelectableTile" lib/starter_catalog/view/starter_catalog_page.dart && grep -q "SelectableTile(" lib/starter_catalog/view/starter_catalog_page.dart
- The checkbox is isolated from the tile group and from focus | verify: grep -q "FTappableGroup.isolate" lib/ui/selectable_tile.dart && grep -q "ExcludeFocus" lib/ui/selectable_tile.dart
- Widget tests cover checkbox taps inside and outside a tile group, keyboard order, and the merged semantics label | verify: grep -q "FTileGroup" test/ui/selectable_tile_test.dart && grep -q "LogicalKeyboardKey.tab" test/ui/selectable_tile_test.dart && grep -q "getSemantics" test/ui/selectable_tile_test.dart
- The catalog page test toggles a recipe on and off from its checkbox | verify: grep -q "from its checkbox" test/starter_catalog/view/starter_catalog_page_test.dart
- A list-items project skill states the rule, the pitfall and the fix | verify: f=.claude/skills/list-items/SKILL.md && test -f $f && grep -q "^name: list-items" $f && grep -q "^description: " $f && grep -q "SelectableTile" $f && grep -q "FTappableGroup.isolate" $f
- The app analyzes cleanly | verify: flutter analyze
- Code is formatted | verify: dart format --output=none --set-exit-if-changed .
- All app tests pass at 100% coverage | verify: very_good test --coverage --min-coverage 100
- Tapping anywhere on a catalog row toggles it on a device | verify: manual 1) run `flutter run --flavor development --target lib/main_development.dart` 2) open the Cocktails library and choose Browse starter recipes 3) tap Negroni's checkbox and confirm it ticks and the button reads Import 1 4) tap the same checkbox again and confirm it unticks and the button reads Import 5) tap the row's blank right-hand side and its subtitle and confirm each toggles it 6) tap the Select all checkbox and confirm every row ticks, then tap it again to clear 7) on a desktop or with a hardware keyboard, press Tab through the list and confirm focus moves row to row without stopping on any checkbox, and Space toggles the focused row
- The skill loads for list work | verify: manual 1) in a new Claude Code session in this repo, ask "add a list of tags to the settings screen" 2) confirm the list-items skill is invoked or offered before code is written

NON-GOALS:
- Changing any other list (audited below: Libraries, Library fields, Ingredients, Recipes, library switcher, tags multi-select and the field editor's Required checkbox already react across the whole item).
- The 1 px border line around an `FTileGroup`/`FItemGroup`, which belongs to the list's frame, not the item.
- Library fields' reorder mode, where the item body has no action and only the move buttons work. There is nothing to open mid-reorder.
- Locking catalog rows while an import is running (behaviour unchanged).
- A whole-item tap test for every list view, or a root `CLAUDE.md` entry (the skill carries the rule instead).
- Reworking FCheckbox or upstreaming a forui change.

VERIFICATION COMMAND: test -f lib/ui/selectable_tile.dart && grep -q "export 'selectable_tile.dart';" lib/ui/ui.dart && ! grep -q "_SelectableTile" lib/starter_catalog/view/starter_catalog_page.dart && grep -q "SelectableTile(" lib/starter_catalog/view/starter_catalog_page.dart && grep -q "FTappableGroup.isolate" lib/ui/selectable_tile.dart && grep -q "ExcludeFocus" lib/ui/selectable_tile.dart && grep -q "FTileGroup" test/ui/selectable_tile_test.dart && grep -q "LogicalKeyboardKey.tab" test/ui/selectable_tile_test.dart && grep -q "getSemantics" test/ui/selectable_tile_test.dart && grep -q "from its checkbox" test/starter_catalog/view/starter_catalog_page_test.dart && f=.claude/skills/list-items/SKILL.md && test -f $f && grep -q "^name: list-items" $f && grep -q "^description: " $f && grep -q "SelectableTile" $f && grep -q "FTappableGroup.isolate" $f && flutter analyze && dart format --output=none --set-exit-if-changed . && very_good test --coverage --min-coverage 100
```

## Context

### Root cause (reproduced with widget tests on forui 0.27.4)

- `FTileGroup` wraps its rows in an `FTappableGroup` when it is unbounded and slideable (`forui-0.27.4/lib/src/widgets/tile/tile_group.dart:329`).
- The group's `TappableGroupGestureRecognizer` doesn't use the render hit-test. It picks the **deepest registered `FTappable` that has a primary callback, by geometry** (`GroupEntry.hitTest`, `foundation/tappable/tappable_group.dart`; selection at `tappable_group_recognizer.dart:252-272`).
- `FCheckbox` is itself an `FTappable`. Its `onPress` is `enabled ? () => onChange?.call(!value) : null` (`widgets/checkbox.dart:118`), so with `onChange: null` it still counts as having a callback. Inside its 20×20 box it wins over the tile and does nothing.
- The existing `IgnorePointer` doesn't help because the group never consults the hit-test. `ExcludeSemantics` is unrelated.
- Keyboard: the same live `FTappable` keeps a focus node, so Tab order was `tile > checkbox > tile > checkbox`, and Space on a checkbox does nothing.
- The same trap applies to any enabled forui control (`FCheckbox`, `FSwitch`, `FButton`, …) placed as decoration in a tile's prefix, title, subtitle or details. That is the pitfall the skill names.

### Spiked fixes (in a throwaway test inside an `FTileGroup`)

| Prefix | Checkbox tap | Tab order |
|---|---|---|
| current `IgnorePointer(ExcludeSemantics(FCheckbox))` | no-op | tile > checkbox > … |
| `FTappableGroup.isolate(…)` | toggles | tile > checkbox > … |
| `FTappableGroup.isolate(ExcludeFocus(…))` | toggles | tile > tile > … |
| `FCheckbox(onChange: …)` without IgnorePointer | toggles | (two handlers to keep in sync; rejected) |

`FTappableGroup.isolate` is public forui API: a `TappableGroupScope(entries: null)` that stops the subtree from registering with an ancestor group. `enabled: false` would also drop the checkbox from the group, but it renders the disabled style, so it's rejected.

### Audit of every list item (grid scan, roughly 670 tap points per row)

Each row was tapped on a 6 px grid along five horizontal lines (the edges, near the edges, and the middle). Taps on action buttons were checked to fire the button, not the row.

| List | Source | Dead points, excluding the 1 px group border |
|---|---|---|
| Libraries (rename and delete buttons) | `lib/libraries/view/libraries_view.dart:51` | none; buttons fire their own action |
| Library fields (delete or move buttons) | `lib/libraries/view/library_fields_view.dart:95` | none (same tile shape as Ingredients) |
| Ingredients (details and delete button) | `lib/ingredients/view/ingredients_view.dart:59` | none; button fires its own action |
| Recipes (placeholder image prefix) | `lib/recipes/widgets/recipe_tile.dart:20` | none; the image toggles too |
| Library switcher (check icon suffix) | `lib/recipes/widgets/library_switcher.dart:40` | none |
| Recipe editor tags `FMultiSelect` | `lib/recipes/view/recipe_editor_page.dart:535` | none in text or check slot |
| Field editor **Required** checkbox | `lib/libraries/widgets/field_editor_sheet.dart:180` | none; the label spans the full width |
| **Starter catalog recipe row** | `lib/starter_catalog/view/starter_catalog_page.dart:212-241` | **the checkbox** (fixed by this plan) |
| Starter catalog row with the planned prefix | — | none |

The other row types are form rows, not single-action list items: option rows, recipe-editor ingredient rows and rename-sheet rows are made of text fields plus remove buttons. The recipe details lists are read-only text.

### Conventions to keep

- Shared widgets live in `lib/ui/`, are exported from `lib/ui/ui.dart`, and are tested in `test/ui/<name>_test.dart` with `tester.pumpApp` from `test/helpers/helpers.dart` (see `failure_banner.dart` and its test).
- Comment only the non-obvious. The isolate and `ExcludeFocus` wraps need a comment saying *why*, since nothing in the code makes the group recognizer visible. Replace the current comment at `starter_catalog_page.dart:287`.
- The existing catalog tests only ever tap title text, which is how this slipped through. Tap the checkbox with `tester.tapAt(tester.getCenter(checkboxFinder))`. A plain `tester.tap` on an `IgnorePointer`ed finder logs a "would not hit test" warning.
- The repo has no project skills yet. `.claude/skills/` is not git-ignored, so the skill is committed with the fix.

## Tasks

- [x] **Red test first.** Before moving any code, add the catalog checkbox test (last code task) and confirm it fails on the current code, so the bug is proven before the fix. The `SelectableTile` tests follow once the widget exists.
- [x] Create `lib/ui/selectable_tile.dart` with a public `SelectableTile`, moved from `_SelectableTile` with the same API: `title`, `subtitle?`, `badge?`, `selected`, `onPress`. Use the prefix below and keep the dartdoc. The doc comment should state the rule: the whole row is the one tap target and one keyboard stop.
- [x] Export it from `lib/ui/ui.dart`, keeping the list alphabetical.
- [x] In `lib/starter_catalog/view/starter_catalog_page.dart`, delete `_SelectableTile` and use `SelectableTile` for both the Select all row and the recipe rows. `package:membar/ui/ui.dart` is already imported.
- [x] `test/ui/selectable_tile_test.dart`:
  - Inside an `FTileGroup` (two tiles), tapping a tile's checkbox calls only that tile's `onPress`, once. This is the regression guard if a forui upgrade changes how the group routes presses.
  - Outside any group (the Select all case), tapping the checkbox calls `onPress` once.
  - Tapping the title, the subtitle, and the blank area at the row's right edge each call `onPress`.
  - Inside an `FTileGroup`, the first Tab focuses tile A and the second focuses tile B, with focus never inside an `FCheckbox`. Enter on a focused tile calls `onPress` (Enter is `FTappable`'s own shortcut).
  - The row reads as one label (`title, subtitle, badge`) and reports its selected state. The badge and subtitle are omitted when null, and so is an empty subtitle. Today's `[title, ?subtitle, ?badge]` reads an empty subtitle aloud as `"Negroni, "` while hiding it on screen, so the label is built from non-empty parts only.
  - `selected` drives the checkbox's `value`.
- [x] `test/starter_catalog/view/starter_catalog_page_test.dart`: add `'toggles a recipe on and off from its checkbox'`. Tap Negroni's checkbox (found as a descendant of the Negroni `FTile`) and expect `Import 1`, then tap it again and expect `Import`. Keep the existing row-label semantics test.
- [x] Add `.claude/skills/list-items/SKILL.md` from the draft below. Keep it short: the rule, the pitfall, the fix, and how to test.

## MVP

```dart
// lib/ui/selectable_tile.dart (prefix only; the rest moves as is)
prefix: FTappableGroup.isolate(
  // FTileGroup routes a press to the deepest FTappable under it by geometry,
  // not by hit-testing, so IgnorePointer alone would leave this checkbox
  // swallowing taps; isolate keeps it out of the group and ExcludeFocus out
  // of the tab order, leaving the tile as the one target.
  child: ExcludeFocus(
    child: IgnorePointer(
      child: ExcludeSemantics(child: FCheckbox(value: selected)),
    ),
  ),
),
```

<details>
<summary>Draft: <code>.claude/skills/list-items/SKILL.md</code></summary>

```markdown
---
name: list-items
description: Membar's rule for list items — FTile, FItem and rows in FTileGroup or FItemGroup. The whole item is the tap target and one keyboard stop. Use when building, changing, reviewing or testing any list, tile or row under lib/.
---

# List items

## Rule

- Tapping anywhere on a list item (prefix, title, subtitle, details, blank space) triggers its main action.
- Only explicit action buttons on the item (rename, delete, move) are separate targets.
- The item is a single keyboard stop. Tab moves item to item, and Enter or Space triggers it.

## Pitfall

Inside an `FTileGroup` or `FItemGroup`, forui routes a press to the deepest `FTappable` under the finger by geometry, not by hit-testing. Any enabled forui control used as decoration in a tile's prefix, title, subtitle or details (`FCheckbox`, `FSwitch`, `FButton`, …) swallows the press, and `IgnorePointer` does not stop it. It also stays a dead focus stop.

## Do

- For checkbox rows, use `SelectableTile` from `package:membar/ui/ui.dart`.
- For any other display-only control, wrap it as `FTappableGroup.isolate(child: ExcludeFocus(child: IgnorePointer(child: ExcludeSemantics(child: ...))))`.

## Test

Tap the non-text parts of a row (the prefix control, blank space), not only the title. Use `tester.tapAt(tester.getCenter(finder))` for anything under `IgnorePointer`.
```

</details>

## References

- Bug surfaced after #20 (starter recipes import). The catalog was introduced in `57867bf`.
- Starter import plan: `docs/plan/2026-11-10-feat-add-starter-recipes-import-plan.md`
- forui 0.27.4 source: `lib/src/foundation/tappable/tappable_group.dart` (`FTappableGroup.isolate`), `tappable_group_recognizer.dart`, `widgets/checkbox.dart`, `widgets/tile/tile_group.dart`
