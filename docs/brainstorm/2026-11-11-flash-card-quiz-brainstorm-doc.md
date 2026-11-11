---
date: 2026-11-11
topic: flash-card-quiz
---

# Flash-Card Quiz

## What We're Building

The first study mode, and the main point of the app: a flash-card quiz over the active
library. The user starts it from the recipes screen. The deck is every recipe in the active
library, shuffled. Each card shows the recipe **name**. Tapping it flips the card to the
**ingredients with amounts, then the steps**.

Once a card is flipped, the user grades themselves:
- Swipe **right** (or tap ✓) means *remembered*.
- Swipe **left** (or tap ✗) means *didn't remember*.

The deck is one pass. At the end, a summary shows the score and lists the missed recipes. A
**Retry missed** button starts a new pass with only those recipes.

Nothing is persisted yet. Later, a follow-up feature will track success/failure rates per
card and bring back problematic recipes. This feature has to leave room for that without
building it.

## Why This Approach

We considered three approaches:
- **A.** Keep the outcomes in quiz state.
- **B.** Also define a review-log API with a no-op implementation in `packages/` now.
- **C.** Persist outcomes to `shared_preferences` now, with no UI.

We chose **A**. It follows the existing `lib/<feature>/{bloc,view,widgets}` pattern and
doesn't touch any package or the storage schema. It also already produces the record the
tracking feature will need.

B builds an interface for a need we can only guess at. Whether tracking stores an event log
or aggregated counts is easier to decide once tracking is actually being built. C goes
against "no need to implement the tracking right away" and adds a schema bump for data
nobody can see.

The cost of A is small. When tracking arrives, `CardOutcome` moves into a package. The
tracking feature then adds a repository, and the swipe handler makes one more call to it.

## Key Decisions

- **New `lib/quiz/` feature with a `QuizBloc`.** It follows the bloc, imperative
  `Navigator.push` and static `route()` patterns used by `starter_catalog` and `recipes`.
- **Direction: name → recipe only.** This is the core memorization task. Since there is only
  one direction, a card is identified by `recipe.id` alone.
- **Card back: ingredients with amounts, then steps.** Library `fieldValues` (glass, method,
  and so on), tags and notes are left out to keep the card focused.
- **Deck: the whole active library, shuffled.** There is no count picker and no hand-picking.
  Filtering to weak recipes belongs to the tracking feature.
- **The deck is a snapshot taken at start.** Edits, deletes and library switches during a
  session don't change the running deck.
- **The card must be flipped before it can be graded.** This keeps the self-check honest.
  The swipe and the ✗/✓ buttons are only enabled after the flip.
- **✗/✓ buttons do the same as the swipes.** Swiping is never the only way to grade. The
  buttons make grading reachable by keyboard and screen reader, as the accessibility and
  `list-items` conventions require.
- **No undo.** The user didn't ask for one.
- **One pass, then a summary with Retry missed.** The summary reads the outcomes of the pass
  that just finished. Retry missed starts a new pass with only the recipes that pass missed.
- **Each swipe appends a `CardOutcome(recipeId, remembered, answeredAt)` to quiz state.**
  The summary and Retry missed are built from this list. Its shape is the future
  success/failure record, so tracking needs no changes to the quiz flow.
- **Nothing is persisted.** Leaving mid-session discards the session.

## Open Questions

- **Swipe implementation:** a custom gesture (`GestureDetector`/`Draggable` with a
  rotate-and-fly-off animation) or a pub package such as `flutter_card_swiper`. A package
  has to pass the license check.
- **Entry point:** where the Start quiz action sits on `RecipesPage`, for example an app-bar
  action or a button. When the active library has no recipes, the action is hidden or
  disabled. Decide which.
- **Thin recipes:** what the back of a card shows when a recipe has no ingredients or no
  steps. Decide whether such recipes are skipped or shown with an empty-section label.
- **Ingredient display:** check whether the recipes feature already renders
  ingredients with amounts in a reusable widget the card back can use.
- **Leaving mid-session:** decide whether leaving needs a confirm dialog or just pops.
- **For the tracking feature, not this one:** whether outcomes from Retry missed passes count
  toward a recipe's success/failure rate or only first attempts do. The in-state log keeps
  every outcome either way.
