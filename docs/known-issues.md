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

## Empty inline callbacks stand in for "do nothing"

Where an API requires a callback and the caller has nothing to do, the code
writes an empty closure on the spot:

- `onSuccess: (_) {}` on three `RecipesMutationListener`s — both in
  `lib/ingredients/view/ingredients_view.dart` and the `fieldDeleted` one in
  `lib/libraries/view/library_fields_view.dart`.
- `result.then((_) {}, …)` in `_serialized` in
  `packages/local_storage_recipes_api/lib/src/local_storage_recipes_api.dart`.

Each reads as a body someone forgot to fill in rather than a decision to
discard the value.

**Why it was left:** every one is correct as written, so this is a readability
cleanup with no behaviour attached, deferred until the helper below exists.

**Closing it:** add a helper named `ignore` that takes one nullable dynamic
argument and does nothing — `void ignore(dynamic _) {}` — and pass it as a
tear-off (`onSuccess: ignore`) in place of every empty single-argument
closure. The app and `local_storage_recipes_api` cannot share an app-level
file, so the helper needs a home both can import, or one copy per package.
Closures of a different shape are out of its reach and stay as they are: the
two-argument `onError: (_, _) {}` beside the `then` above, zero-argument ones
such as `setState(() {})`, and `parse: (_) => null` in
`lib/recipes/widgets/ingredient_picker.dart`, which must return a value.

## Mutable state is declared with `var`, and no linter says otherwise

Seventeen mutable fields across eight files in `lib/` are declared as
`var _submitted = false;` rather than `bool _submitted = false;`, and three
locals in `lib/recipes/bloc/recipes_state.dart` and
`packages/local_storage_recipes_api/lib/src/local_storage_recipes_api.dart`
do the same. The type is inferred correctly everywhere, but a reader has to
work it out from the initializer, and the house preference is to see it
written.

The gap behind it is wider than `var`: the only static analysis is
`very_good_analysis` plus `bloc_lint`, which cover style and Bloc usage but
not metrics, unused code or the stricter rules a dedicated linter adds.

**Why it was left:** the code follows the lint set as configured.
`very_good_analysis` 10.3.0 asks for a type only when there is no initializer
or the type is not obvious, and its `omit_local_variable_types` rejects a
type on a local outright. Retyping by hand with no rule behind it would drift
back.

**Closing it:** two steps, the second of which keeps the first from undoing
itself.

1. Give the seventeen fields and three locals explicit types. The locals need
   `omit_local_variable_types` switched off in every `analysis_options.yaml`
   first — the root and the three under `packages/` — or the fix trades one
   warning for another.
2. Add DCM (dcm.dev) on its Free plan and enable a chosen set of its rules
   under `dcm: rules:` in `analysis_options.yaml`. As of October 2026 that plan
   offers 100 lint rules and 22 metrics for one seat and up to 50k analyzed
   lines, activated per device with a licence key; the repo holds about 23k
   lines of Dart including tests.

Two things to settle before step 2:

- DCM's rule for this, `prefer-type-over-var`, is badged "pro+" in its docs,
  so the Free plan will not enforce step 1. Either accept the Pro plan for
  that rule, enable Dart's own `always_specify_types` (which also demands
  types on closure parameters and generic literals), or leave step 1 as a
  convention.
- The pricing page lists the CI/CD key under the Teams plan. Confirm whether
  a Free licence can run in `.github/workflows/main.yaml`; if not, DCM is a
  local and IDE check only.
