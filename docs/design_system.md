# Fund Flow — Flow Loom Design System

Status: **LOCKED CANONICAL SYSTEM**
Version: 5.0
Locked: 2026-07-18

This document and `blank_slate_redesign_plan.md` are the only visual/product
sources of truth. All earlier Quiet Intelligence, Flow Field, Material
Expressive, glass, capsule, card, dashboard, and equal-tab directions are
superseded. Existing code is never a design reference unless it implements the
rules below.

## Product definition

Fund Flow is an evidence-bound financial agent that turns transaction messages
into private local proof, answers questions against that proof, and performs
only explicitly approved mutations.

The dominant loop is:

`signal → understand → attach proof → ask → compute locally → explain → inspect
evidence → approve → learn from correction`

Ask is the product. Proof and System support it. Manual entry, categories,
logs, and diagnostics are secondary correction or recovery tools.

## Product architecture

- **Ask / Flow** is the default and visually dominant workspace.
- **Proof** exposes chronology, source, confidence, exclusions, and correction.
- **System** exposes intelligence connection, evidence channels, privacy, and
  personalization as a control map.
- The Command Rail gives Ask 52% visual weight, Proof 30%, System 18%.
- Navigation selection is a proof thread and stronger typography, never a
  filled pill or stock navigation indicator.

## Signature language

### Loom Mark

The single intelligence mark: square nodes arranged on three implied threads.
It is static at rest. State changes through density, progress, and semantic
color. Never substitute a circle, sparkle, robot, gradient orb, or animation.

### Proof Thread

A 2–4dp cyan or semantic line connects intent, result, provenance,
confidence, and consequence. It communicates relationship rather than acting
as decoration.

### Ledger Cut

Interactive and evidence surfaces use clipped opposing corners and aligned
edges. Four generic rounded corners, stadium shapes, and automatic capsules are
not Flow Loom.

### Coordinates

Uppercase 9–11sp labels identify scope and state: `FIELD / 00`, `SOURCE / SMS`,
`CHECKED LOCALLY`, `AGENT / USER AUTHORITY`. Every coordinate must communicate
real structure or provenance.

### Open canvas

Space, rules, and alignment establish hierarchy. Add a surface only for
interaction, contrast, proof grouping, or consequence. Never build boxes
inside boxes for decoration.

## Color constitution

| Role | Value | Meaning |
| --- | --- | --- |
| Ink | `#090A0F` | OLED dark canvas |
| Paper | `#F7F7F2` | warm light canvas |
| Loom Violet | `#5B4BFF` | intelligence and command |
| Proof Cyan | `#22D3EE` | provenance and verified computation |
| Mint | `#2ED3A7` | money in and successful verification |
| Coral | `#FF5F7A` | money out or destructive consequence |
| Amber | `#F6B94A` | uncertainty and review |

Neutral planes are explicit ink/paper mixtures. Device wallpaper and Material
seed generation may not redefine identity or trust states. Color is a signal,
not a large generic container fill.

## Type and geometry

- Space Grotesk: conclusions, mastheads, major financial results.
- Inter: reading, evidence, controls, metadata.
- Money uses tabular figures and strong baseline alignment.
- 4dp base grid; 8/12/16/24/32/48 cadence.
- Minimum touch target: 48dp.
- Reading measure: 620dp. Evidence measure: 760dp.
- No unfamiliar icon-only action; label the consequence.

## Interaction grammar

- Composer: cut Command Surface with visible evidence scope, multiline growth,
  and explicit Send/Stop controls.
- Answer: intent coordinate → conclusion → local result → explanation → records
  checked and freshness → evidence → next commands → approval if required.
- Transaction: Evidence Strip on a continuous thread, never avatar/list-tile.
- Filter: dedicated Query Scope editor, never a chip row.
- Toggle: explicit On/Off Binary Rail.
- Theme: visual swatches, never a segmented control.
- Confirmation: Approval Report naming mutation, affected objects,
  reversibility, and transfer boundary.
- Empty/error/loading: State Narrative with a static Loom state and one next
  action; never spinner, shimmer, skeleton, or delayed reveal.

## AI trust contract

- `Verified` requires successful local tool output.
- `Understood` means a signal became an event; uncertain fields show confidence.
- Forecasts are labeled `Estimated`.
- Raw SMS is concealed by default and never copied or transmitted accidentally.
- Read-only computation may run directly. Mutation requires explicit approval.
- Approval names the verb and object, not generic `Apply`.
- Corrections explain whether they affect future understanding.

## Energy contract

- Zero continuous animation, repeating controller, periodic decorative timer,
  shimmer, ambient particle, live blur, or ticker.
- Static custom painters are isolated in `RepaintBoundary`.
- Navigation and state transitions last 160–260ms and respect reduced motion.
- Lists paint immediately with no entry opacity or stagger.
- Progress is determinate or a static named stage.
- Offscreen root destinations use `Offstage`, `TickerMode(false)`,
  `IgnorePointer`, and excluded semantics.
- Dark mode keeps luminous area restrained for OLED efficiency.

## Accessibility contract

- 200% text must remain usable at 320dp width.
- RTL preserves logical reading and does not reverse financial meaning.
- Every interactive target has semantics and a minimum 48dp hit region.
- Color never carries direction, confidence, or selection alone.
- High contrast strengthens rules and content contrast without changing roles.
- Reduced motion disables nonessential movement.
- Keyboard focus and input remain visible above system insets.

## Implementation authority

Proprietary primitives live under `lib/flow_os/`:

- `foundation/flow_color.dart` — fixed palette roles;
- `primitives/loom_mark.dart` — sole intelligence mark;
- `primitives/cut_surface.dart` — Ledger Cut plane;
- `primitives/proof_thread.dart` — evidence relationship;
- `primitives/coordinate_label.dart` — scope and provenance;
- `shell/command_rail.dart` and `command_column.dart` — root navigation;
- `ask/` — masthead and query command surface;
- `proof/` — evidence masthead and chronology;
- `system/` — control nodes and explicit rails;
- `agent/decision_sheet.dart` — approval reports;
- `ingestion/evidence_consent_sheet.dart` — consent boundary.

`lib/theme/app_theme.dart` is only a platform-control fallback. It must never
become the product design system. `lib/theme/app_tokens.dart` contains only
layout, short event-driven motion, and financial semantics.

## Veto checklist

Reject a change if it:

- promotes manual CRUD above AI ingestion or Ask;
- adds a card, tile, pill, chip, generic app bar, or stock navigation anatomy;
- introduces another intelligence icon;
- hides provenance, confidence, scope, or consequence;
- uses color as decoration without a defined signal role;
- adds continuous or scroll-entry animation;
- delays painting existing content;
- creates one-off geometry outside Flow Loom primitives;
- fails narrow, large-text, RTL, high-contrast, or reduced-motion behavior.

## Completion evidence

The redesign is not complete because a screen “looks consistent.” Completion
requires all user-facing states in `blank_slate_redesign_plan.md` to be
implemented, static analysis and tests to pass, forbidden primitives to be
absent from live UI, no idle scheduled frames, and primary/secondary surfaces
to pass rendered phone and tablet audits.
