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

## Deleting a library cannot simply drop it from the ingredients catalog

A `CatalogIngredient` asserts that its `libraryIds` is non-empty, because an
entry visible in no library could never be picked. Library deletion does not
exist yet, but when it is built it cannot remove the library's id from every
entry: an entry scoped only to that library would be left with an empty set.

**Why it was left:** there is no library deletion to design against yet.

**Closing it:** whoever builds library deletion decides between refusing to
delete a library that is an entry's only scope and reassigning those entries to
another library.

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
