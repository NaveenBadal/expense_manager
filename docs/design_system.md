# Fund Flow — Quiet Current

Status: canonical product and interface direction
Version: 6.0
Date: 2026-07-18

## Product promise

Fund Flow quietly turns transaction messages into an understandable money
record. The user can ask a question in ordinary language, receive a concise
answer, inspect the records behind it, and approve any change before it occurs.

The interface must feel calm before it feels intelligent. AI is demonstrated
through relevance, clear reasoning, provenance, and reversibility—not through
futuristic decoration or technical vocabulary.

## Experience principles

1. **One clear thought per viewport.** A screen has one dominant purpose and
   one visually dominant action.
2. **Summary before machinery.** Show the useful answer first. Scope,
   confidence, source, and controls remain one step away unless attention is
   required.
3. **Natural language first.** Use `Ask`, `Activity`, `Needs review`, and
   `Messages checked`; never use coordinates, command codes, proof jargon, or
   OS metaphors in normal UI.
4. **Attention is earned.** Color and surfaces appear only for actions,
   selection, money direction, or a state requiring a decision.
5. **Calm density.** Prefer spacing, alignment, and typography over nested
   cards, dividers, labels, icons, or badges.
6. **Trust without anxiety.** State what was checked and what will change in
   short human language. Reveal raw evidence and technical detail on demand.
7. **AI proposes; the user remains in control.** Read-only questions can run
   directly. Mutations name their exact consequence and require approval.

## Information architecture

- **Ask** is home. It contains a small financial brief, relevant question
  suggestions, the conversation, and the composer.
- **Activity** is the chronological money record. Search and review are
  available without turning the first viewport into a filter console.
- **You** contains sources, intelligence connection, privacy, appearance, and
  advanced diagnostics in that order.

The labels have equal visual weight. AI is primary because Ask opens first and
because useful intelligence is integrated into Activity—not because its
navigation item is louder.

## Signature: Quiet Current

The app-specific motif is a pair of fine lines: one continuous and one short.
It represents a financial event and the understanding attached to it. It may
appear beside an answer, a reviewed transaction, or the active destination.
It is never animated continuously and never used as a decorative grid.

The identity is also expressed through editorial composition:

- a small sentence-case context line followed by a confident title;
- financial values aligned on stable tabular baselines;
- open sections separated by breathing room rather than boxes;
- softly inset ledger planes used only for content that belongs together;
- one quiet accent per region.

## Color

### Light

- Canvas `#F6F5F0` — warm mineral paper
- Surface `#FCFBF8` — reading plane
- Soft plane `#ECEBE5` — grouped controls
- Ink `#202522` — softened charcoal
- Secondary ink `#68706B`
- Rule `#DCDDD7`

### Dark

- Canvas `#121614` — deep green-charcoal
- Surface `#191E1B`
- Soft plane `#222824`
- Ink `#EEF1EC`
- Secondary ink `#A8B0AA`
- Rule `#343B36`

### Semantic accents

- Current blue `#476F86` / light-on-dark `#81A9BC` — intelligence and active
  navigation
- Moss `#4F765F` / `#82AC90` — income and confirmed state
- Clay `#A4604D` / `#D39480` — spending and destructive consequence
- Ochre `#A47C3B` / `#D2AA68` — uncertainty and review

No gradients, neon colors, glass blur, glowing edges, or large saturated
fields. Color is never the only carrier of meaning.

## Type and shape

- Inter is the reading and control voice.
- Space Grotesk is reserved for financial values and major conclusions.
- Sentence case is standard. Uppercase is reserved for short financial
  abbreviations such as currency codes.
- Body copy: 15–17sp with generous line height. Supporting text: at least 12sp.
- 4dp spacing base; primary rhythm 8, 12, 16, 24, 32, 48.
- Content width: 680dp for reading, 820dp for activity.
- Surfaces use 14–20dp radii with a subtle 2dp lower-right tightening. This
  small asymmetry is proprietary but quiet; it must never resemble a game HUD.
- Controls have a 48dp minimum target. Familiar symbols may be icon-only only
  when platform convention makes the consequence unmistakable.

## Core compositions

### Ask

The empty/returning state opens with a greeting-sized title and one short
monthly observation. A single grouped list contains two or three relevant
questions. The composer is always easy to find and states its scope only in a
quiet supporting line. Conversation answers use: conclusion, explanation,
`Based on …`, optional records, then relevant follow-ups.

### Activity

The top region contains the title, privacy control, and one month summary.
Search is a normal-width field. Transactions form clean day groups; the amount
and merchant dominate while category/source are secondary. Items needing
review receive an ochre line and an explicit `Review` label. No timeline,
nodes, evidence codes, or staggered entrances.

### You

Use five readable sections: Money sources, Intelligence, Privacy,
Personalization, Advanced. Each row states its current state or consequence.
Technical configuration is collapsed by default.

### Onboarding

Use four short steps: Welcome, Connect intelligence, Allow messages, Ready.
Each step explains one decision, why it is needed, and what leaves the device.
Progress is a small `2 of 4` label and a quiet line. Skipping is always clear.

## Motion and accessibility

- Only event-driven transitions of 140–220ms; no ambient motion, stagger,
  shimmer, particles, pulsing, or decorative timers.
- Honor reduced motion, high contrast, RTL, 200% text, and 320dp width.
- Offstage destinations disable tickers, input, focus, and semantics.
- Every target is at least 48dp and has a useful semantic label.
- Money direction is conveyed by sign/word as well as color.

## Content vetoes

Reject UI containing command/field/axis/coordinate/system-OS language, neon
accents, clipped HUD corners, tiny tracked labels, unequal navigation zones,
decorative intelligence marks, nested cards, dashboard grids, chip clouds,
generic AI sparkles, persistent status telemetry, or more than one competing
primary action.
