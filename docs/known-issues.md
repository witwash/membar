# Known issues

Deliberate limitations carried by shipped code. Each entry says what is wrong,
why it was left, and what closing it involves.

## Spacing literals have not been moved onto the design system

`lib/ui/app_spacing.dart` names the app's spacing scale, but only the confirm
dialog reads from it. Every other screen still writes its gaps as literals —
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
