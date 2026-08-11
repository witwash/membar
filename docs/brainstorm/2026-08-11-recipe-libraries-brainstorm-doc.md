---
date: 2026-08-11
topic: recipe-libraries
---

# Recipe Libraries (generalizing Membar beyond cocktails)

## What We're Building

Membar becomes a **multi-library recipe app** rather than a cocktail app. A user can keep
any number of named libraries — Cocktails, Coffee, Tea, whatever — each of which defines its
own set of extra fields. Every recipe shares a common core (name, ingredients, steps, tags,
image, notes) and additionally carries values for the fields its library declares. So a
cocktail has *Glassware* and *Garnish*; a pour-over has *Brew method*, *Dose*, *Water temp*,
*Grind*, and *Tasting notes* — from the same model and the same screens.

The recipe editor is therefore **generated from data**: it renders the built-in core fields,
then one control per field in the active library's schema. The app ships with built-in
**templates** (Cocktails, Coffee) so a fresh install is usable immediately without designing
a schema by hand. CRUD, search, tag filtering, local-first persistence, and (later) the quiz
all operate identically across every library.

## Why This Approach

The existing plan (`docs/plan/2026-07-21-feat-cocktail-library-plan.md`) is cocktail-only:
a `Cocktail` model with hard-coded `glassware`/`garnish`, packages named `cocktails_*`, and a
`CocktailsBloc`. Its **architecture** — abstract data API → local-storage implementation →
repository → bloc → forui screens — survives this change untouched. Only its *model* and
naming do not.

Three approaches were considered:

- **Staged generalization (chosen).** Build the generic model now, split delivery in two.
  PR1 ships the data stack, header library switcher, and full recipe CRUD with the editor
  rendered dynamically from a schema — libraries seeded from built-in templates and not yet
  editable. PR2 adds the library manager and schema editor. PR1 stays roughly the size of the
  current plan and therefore reviewable; the dynamic form renderer gets built and tested
  against real template data before any schema-editing UI sits on top of it; PR2 is purely
  additive.
- **Big-bang generic.** Everything in one slice. Feature-complete at first merge, but roughly
  double the current plan's scope (schema editor, Select option-list management, destructive
  change confirmation, all at 100% coverage) and hard to review as a single PR.
- **Cocktails first, generalize later.** Rejected. Nothing is implemented yet — `lib/` is
  still the VGV counter scaffold and all five plan phases are "Not started" — so building the
  cocktail-specific model would guarantee rewriting three packages, the bloc, and three
  screens, *plus* writing a migration for cocktails saved in the meantime. The only argument
  for it is sunk cost in a document whose architecture we are keeping anyway.

## Key Decisions

- **Libraries are user-created, not app-defined types.** The app has no special knowledge of
  "cocktail" or "coffee" as concepts; both are just libraries the user happens to have. Keeps
  one code path for every domain and lets the app grow to tea, wine notes, or baking without
  a code change.

- **Each library declares a field schema; recipes carry values against it.** Chosen over
  free-form per-recipe label/value pairs because consistent field definitions are what make
  reliable filtering and auto-generated quiz questions possible. Free-form labels drift
  ("Glass" vs "Glassware") and nothing downstream can depend on them.

- **Four field types: Text, Select, Number+unit, Long text.** Select constrains values to a
  schema-defined option list, which is what enables both dependable filtering and
  multiple-choice quiz questions with plausible distractors drawn from the unused options.
  Number stores a real number with the unit fixed by the field, leaving room for sorting and
  range filters later.

- **Core fields stay built-in on every recipe:** name, ingredients (name/quantity/unit),
  steps, tags, image, notes. Schema fields cover only the domain-specific extras. Avoids
  making the universal parts of a recipe configurable for no benefit.

- **Recipe values are keyed by field `id` (uuid), not by label.** Renaming a field must not
  orphan the values already stored against it. Cheap now, painful to retrofit.

- **`Glassware` stops being a Dart enum.** It becomes the option list of a Select field in the
  Cocktails template — otherwise the app still hard-codes cocktail domain knowledge.

- **Built-in templates seed new libraries.** "New library → from Cocktails template" copies a
  ready-made schema the user can then edit. Templates are seed data, not privileged types, so
  a template-created library is indistinguishable from a hand-built one afterwards.

- **Navigation: library switcher in the header.** Home opens the active library's recipe list;
  a header dropdown swaps libraries and holds "Manage libraries…". Fewest taps to the content
  the user actually wants. Requires persisting a "last active library" preference.

- **Schema edits: warn, then drop.** Deleting a field shows how many recipes carry a value and
  permanently removes them on confirm. Field **type is immutable after creation** — to change
  a type, delete the field and add a new one. Rejected orphaning values (invisible data,
  values mysteriously reappearing) and add-only schemas (a mistyped field is permanent
  clutter). Best-effort type conversion was rejected as speculative for a personal app.

- **Persistence stays `shared_preferences` + JSON.** A relational store (drift/isar) is a poor
  fit for user-defined fields — it degrades into a hand-rolled entity-attribute-value table —
  whereas a `Map<fieldId, value>` serializes to JSON naturally. The existing plan's
  whole-blob-rewrite scaling ceiling still applies and still doesn't matter at personal scale.

- **Package renaming follows the model:** `cocktails_api` → `recipes_api`,
  `cocktails_repository` → `recipes_repository`, `local_storage_cocktails_api` →
  `local_storage_recipes_api`. The layering and dependency direction are unchanged.

## Open Questions

- **Search and filter scope.** Does search cover only the active library, or all libraries at
  once? The header switcher implies per-library; global search may still be wanted later.
- **Deleting a library.** Presumably a confirmation that cascades to its recipes — needs the
  same "this will delete 24 recipes" treatment as field removal. Not yet decided.
- **Required vs optional schema fields.** Can a field be marked required, and does that block
  saving a recipe? Currently assumed all-optional.
- **Field ordering.** Can the user reorder fields in the schema editor, or is it
  creation-order only?
- **Library identity in the switcher.** Icon or emoji per library, or name only?
- **Template versioning.** If a future app version ships an improved Cocktails template, do
  existing libraries created from it change? Assumed no — templates are a one-time copy.
- **Empty-library / no-library states.** What the recipe list shows before any recipe exists,
  and whether the user can delete their last remaining library.
- **Quiz implications (later slice).** Schema fields are the richest quiz source — Select
  fields especially. Worth confirming the model exposes what the quiz will need before the
  quiz slice starts.
- **Fate of the existing plan document.** `docs/plan/2026-07-21-feat-cocktail-library-plan.md`
  is superseded by this direction and should be rewritten or replaced during planning, not
  edited piecemeal. `docs/plan.md` (the whole-app spec) also still describes a cocktail-only
  Library.
- **Branch name.** `feat/cocktail-library` no longer describes the work.
