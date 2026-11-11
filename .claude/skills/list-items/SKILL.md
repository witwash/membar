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
- If the hidden control carries state, expose it on the tile (`FTile(selected: …)` or `Semantics` with `checked`/`toggled`), as `SelectableTile` does.

## Test

Tap the non-text parts of a row (the prefix control, blank space), not only the title. Use `tester.tapAt(tester.getCenter(finder))` for anything under `IgnorePointer`.

Inside a tile or item group, press Tab twice and check that focus moves tile to tile and never lands inside the prefix control (see `test/ui/selectable_tile_test.dart`).
