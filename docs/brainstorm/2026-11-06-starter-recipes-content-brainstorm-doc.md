---
date: 2026-11-06
topic: starter-recipes-content
---

# Starter Recipes Content

## What We're Building

The bundled content behind the starter-recipes import
(`2026-10-17-starter-recipes-import-brainstorm-doc.md`): **42 cocktails** and **12
coffees**, each set with its own **canonical ingredient list**. The import flow stays as
that brainstorm designed it: the user browses a catalog from inside a Cocktails or Coffee
library and picks recipes to import, and the libraries ship empty. This document settles
which recipes the sets contain, how their ingredients are named, and how the bundle is
shaped. It supersedes the Oct 17 counts (about 20 coffees and 50 cocktails) and its
per-row ingredient shape.

The canonical ingredient lists are content only. Nothing imports them on their own and
the model gains no fields. As Oct 17 specified, an ingredient reaches the user's
ingredient library only when a recipe that uses it is imported. It is then linked by
case-insensitive name or created with its bundled default unit.

### Cocktails (42)

| Group | Recipes |
|---|---|
| Stirred | Old Fashioned, Manhattan, Dry Martini, Negroni, Boulevardier, Sazerac, Vieux Carré, Martinez, Americano |
| Sours | Daiquiri, Margarita, Tommy's Margarita, Whiskey Sour, Pisco Sour, Sidecar, Gimlet, Cosmopolitan, Last Word, Aviation, Clover Club, Corpse Reviver #2, Paper Plane, Penicillin, Bee's Knees, Southside |
| Long | Mojito, Caipirinha, Moscow Mule, Tom Collins, Paloma, Cuba Libre, Gin and Tonic, Bloody Mary |
| Sparkling | Aperol Spritz, French 75 |
| Tiki | Mai Tai, Piña Colada, Jungle Bird |
| Other | Mint Julep, Espresso Martini, Black Russian, White Russian |

Considered and left out: Irish Coffee, Mimosa, Bellini, Kir Royale, Long Island Iced Tea,
Hemingway Daiquiri, Bramble, Gold Rush, Naked and Famous, Zombie. Trademarked drink names
such as Dark 'n' Stormy and Painkiller are excluded on purpose.

### Coffee (12)

Espresso, Americano, Cappuccino, Latte, Flat white, Cortado, Mocha, Pour over (V60),
French press, Aeropress, Moka pot, Cold brew.

Every drink maps onto an existing `Brew method` option. Milk drinks use `Espresso`.
Macchiato and Iced latte were dropped to keep the set at 12.

## Why This Approach

**Canonical list as a separate, keyed file (chosen).** Each set has two files: an
ingredients file (stable key, name, default unit) and a recipes file. Each recipe row
references an ingredient by key and carries its quantities, for example
`{ "ingredient": "lime_juice", "ml": 22.5, "oz": 0.75 }`. The list is a deliverable in its
own right, so it gets one authoritative home. A rename or a unit fix is one edit, and the
schema test can check that every key resolves and every ingredient is used.

**Inline ingredients per row (rejected).** This was the Oct 17 shape. Each of the 42
recipes would repeat names and default units, and a typo would produce a near-duplicate
ingredient that is easy to miss, because names fold only on case and whitespace
(`docs/known-issues.md`).

**Content decisions.** The cocktails are mostly IBA classics plus a handful of well-known
modern classics. That set gives broad coverage with modest ingredient overlap. Coffee
covers the six template brew methods and the common espresso-and-milk drinks.

## Key Decisions

- **Lists are fixed as above.** Small swaps are allowed during authoring if a recipe turns
  out to add an ingredient nothing else uses.
- **Naming policy: generic, with a brand only when unavoidable.**
  - Spirits split by the style that changes the drink: London dry gin, Vodka, White rum,
    Aged rum, Dark rum, Bourbon, Rye whiskey, Blended Scotch, Islay Scotch, Tequila
    blanco, Cognac, Pisco, Cachaça, Absinthe.
  - Use generic names over brands, for example Triple sec rather than Cointreau and
    Coffee liqueur rather than Kahlúa. Maraschino liqueur and Crème de violette are
    already generic.
  - Keep the brand where the product has no generic equivalent: Campari, Aperol, Green
    Chartreuse, Bénédictine, Amaro Nonino, Lillet Blanc, Angostura bitters, Peychaud's
    bitters.
  - Citrus appears as juice (Lime juice, Lemon juice). The exception is a whole `Lime`
    counted in pieces where it is muddled (Caipirinha).
  - Prosecco and Champagne collapse into one `Sparkling wine`.
  - Names stay short and canonical, so they match what users have typed.
- **Garnishes go in the `Garnish` field, not in ingredient rows.** The exception is mint
  that is muddled or shaken into the drink (Mojito, Mint Julep, Southside), which is the
  row `Mint leaves`.
- **Draft cocktail ingredient list (about 58 ingredients):**
  - **Spirits:** the 14 above.
  - **Liqueurs and aperitifs:** Triple sec, Coffee liqueur, Maraschino liqueur, Crème de
    violette, Green Chartreuse, Bénédictine, Campari, Aperol, Amaro Nonino, Lillet Blanc.
  - **Wine:** Sweet vermouth, Dry vermouth, Sparkling wine.
  - **Bitters:** Angostura bitters, Peychaud's bitters, Orange bitters.
  - **Juice:** Lime juice, Lemon juice, Cranberry juice, Pineapple juice, Tomato juice.
  - **Sweeteners:** Simple syrup, Honey syrup, Agave syrup, Ginger-honey syrup, Raspberry
    syrup, Orgeat, Sugar.
  - **Mixers:** Soda water, Tonic water, Ginger beer, Cola, Grapefruit soda.
  - **Other:** Egg white, Cream, Coconut cream, Espresso, Mint leaves, Lime,
    Worcestershire sauce, Hot sauce, Salt, Black pepper.
  - The final list is whatever the authored recipes reference. The test enforces that
    every ingredient is used.
- **Coffee ingredient list:** Coffee beans (g), Water (ml), Milk (ml), Chocolate sauce.
  - Every coffee recipe has a `Coffee beans` row even though `Dose` repeats the weight,
    so the recipe reads as complete and beans appear on the Ingredients screen.
  - `Tasting notes` stays empty, since it describes the user's beans rather than the
    recipe.
- **Coffee is metric only.** Its rows are in g and ml, and the import shows no ml/oz
  toggle for coffee. This resolves an Oct 17 open question.
- **Cocktail quantities carry both systems, using bartender-standard conversion:** 30 ml
  = 1 oz, 22.5 ml = ¾ oz, 15 ml = ½ oz, 7.5 ml = ¼ oz, rather than the exact 29.57.
  Counted units (dash, piece, barspoon, teaspoon) are the same in both systems.
- **The Cocktails template gains glassware options `Wine`, `Julep cup` and `Tiki`,** so
  Aperol Spritz, Mint Julep and the tiki drinks get their proper glass. This is a
  `LibraryTemplates` change with a `kSchemaVersion` bump and a reseed. Per the WIP rule,
  there is no migration.
- **Authoring.** IBA specs are the reference for the classics, and established published
  specs cover the rest. Steps are written in our own words, never copied. Each recipe gets
  a stable key, a name, tags, steps, field values keyed by label, and rows keyed by
  ingredient.
- **The schema test grows beyond the Oct 17 checks** (field labels exist, select values
  are among the options, units are valid, recipe names are unique per set). It also
  checks:
  - every row's ingredient key resolves;
  - every listed ingredient is used at least once;
  - ingredient keys and names are unique per set, with names compared case-insensitively;
  - every cocktail row has both `ml` and `oz`, and every coffee row has only metric.

## Open Questions

- **Default unit when importing in oz.** A newly created ingredient gets its bundled
  default unit (ml). Should it get `oz` when the user imports in oz, so the
  Ingredients screen matches their rows?
- **Units outside `StandardUnit`.** `Salt` and `Black pepper` want `pinch`, and
  `Chocolate sauce` may want `ml` or `tablespoon`. Use `CustomUnit` in the bundle, or pick
  the nearest standard unit?
- **Quantity format.** Rows store quantity as a string. Should the bundle write `0.75` or
  `¾`? Decimals keep parsing and future scaling simple. Fractions read better.
- **Tag vocabulary.** Decide on a small fixed set per collection, for example
  `stirred`, `sour`, `highball`, `tiki`, `sparkling` for cocktails and `espresso`,
  `milk`, `filter`, `cold` for coffee, and its casing.
- **Glass for each tiki drink.** Mai Tai and Jungle Bird are often served on the rocks.
  Decide each drink's glass during authoring rather than putting every tiki drink in
  `Tiki`.
- **Oct 17 doc upkeep.** Update the starter-recipes import brainstorm's counts and JSON
  shape to point here, or leave it as history?
