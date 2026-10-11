# Known issues

Deliberate limitations carried by shipped code. Each entry says what is wrong,
why it was left, and what closing it involves.

## Spacing literals have not been moved onto the design system

`lib/ui/app_spacing.dart` names the app's spacing scale, but only the shared
dialog, the ingredient sheets and the ingredients screen read from it. The
recipe screens still write their gaps as literals —
`spacing: 8`, `SizedBox(height: 12)`, `EdgeInsets.only(top: 24)` — across
`lib/recipes/view/` and `lib/recipes/widgets/`. Nothing stops a new screen from
inventing a step that is not on the scale.

**Why it was left:** the tokens arrived with a hotfix for the dialog's missing
padding, and a sweep of every recipe screen is a wider blast radius than a
hotfix should carry.

**Closing it:** replace the literals in `lib/recipes/` with `AppSpacing` steps,
adding a named step for any value that has no equivalent rather than widening
the scale by reflex. Widget tests assert behaviour rather than pixel gaps, so
the sweep should be verifiable by the existing suite. Consider promoting
`lib/ui/` to a `packages/app_ui` package at the same time if a second app or
package needs the tokens.

## A deleted library cannot be restored

Deleting a library removes it and every recipe in it at once, and nothing
keeps a copy. The delete sheet states the recipe count first, but confirming
is final. Catalog ingredients are the exception: they are never deleted, and
the ones that belonged only to that library move to one the user picks.

**Why it was left:** a "recently deleted" area was asked for and is the next
slice. It was kept out of the one that introduced deletion so the cascade and
the ingredient handover could be reviewed on their own.

**Closing it:** keep a deleted library and its recipes in a separate store
until the user restores or purges them, and decide what a restore does to the
ingredients that moved away in the meantime.

## Two libraries cannot be merged

A recipe belongs to the library it was created in and cannot move to another,
so folding one library into another means re-entering its recipes.

**Why it was left:** two libraries rarely declare the same fields, so a move
has to decide what happens to the values the destination has no field for.

**Closing it:** add a move that maps each source field onto a destination
field or drops it, stating the count of values dropped before it runs — the
rule schema edits already follow.

## Fields cannot be reordered

A new field is appended to its library's schema, and the schema's list order
is the order the recipe editor and the details screen render. Moving a field
means deleting it and adding it again, which clears every value recipes held
for it.

**Why it was left:** reordering was deferred from the slice that introduced
the field editor, to keep the sheet and its option rows in a review of their
own.

**Closing it:** add a reorder control to the fields screen that saves the
library with its fields in the new order. A field's id does not change when it
moves, so no recipe value is touched.

## Unit labels are not localized

`Unit.label` is the canonical spelling (`ml`, `barspoon`) and is rendered as-is
by the unit selectors and the ingredients screen.

**Why it was left:** the app ships `en` only, so nothing renders
inconsistently today, and the label doubles as the text copied into a recipe
row's free-text unit.

**Closing it:** add ARB keys per `StandardUnit` for display, keeping `label`
as the stored and copied spelling.

## Ingredient names fold on case and surrounding whitespace only

`St. Germain` and `St Germain` are two catalog entries. Folding matches the
rule tags already use, so the app has one notion of "the same name".

**Why it was left:** a stricter rule for one entity would leave the app with
two, and merging near-duplicates is a rename on the ingredients screen.

**Closing it:** introduce a shared normalization for tags and ingredients
together, and migrate existing duplicates deliberately.


## Usage counts span every library

"Used in 4 recipes" on the ingredients screen counts recipes in all libraries,
because deleting an entry is global. The recipes behind a refused delete may
not all be visible from the library being browsed.

**Why it was left:** a per-library count would let a delete look safe while
another library still depends on the entry.

**Closing it:** name the libraries alongside the count in the refusal.

## The last-library refusal reads as a stray status line

Trying to delete the only library prints "… is your only library, so it cannot
be deleted" as left-aligned red text above the list on the Libraries screen,
where it stays until the next rename, create or delete. It looks like a status
of the screen rather than an answer to the tap that caused it.

**Why it was left:** it was noticed in the manual walkthrough after the slice
was built. `LibrariesView` reuses `FailureBanner`, which is rendered in place
on purpose so a failed save leaves its form in view; a refusal has no form to
protect, so that reasoning does not carry over.

**Closing it:** show the refusal as a toast through the `FToaster` already
mounted in `lib/app/view/app.dart` and drop the `_refusal` state from
`LibrariesView`. Keep it announced to screen readers, which the banner's live
region does today.

## Required fields are not marked until a save fails

The recipe editor renders a required field's label exactly like an optional
one. The only sign is "This field is required." under the control after a save
is refused. The fields screen does say `Required` beside each field, but that
is not where a recipe is filled in.

**Why it was left:** it was noticed in the manual walkthrough after the slice
was built. Required fields existed in the templates before, but the field
editor is what lets a user add their own, which is when the gap shows.

**Closing it:** mark the label of a required field in
`lib/recipes/widgets/schema_field_control.dart`, for every field type, with an
asterisk or an equivalent, and expose the requirement to assistive technology
rather than as a bare glyph.
