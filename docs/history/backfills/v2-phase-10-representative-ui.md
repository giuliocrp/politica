Written retrospectively during V3. Not an original v2 artifact.

# v2 Phase 10 — Full Representative UI and Explainer (retrospective)

`8a1aa90`, 2026-07-18 — commit message: "feat(v2): UI completion for real
data — search, party filters, initials avatars, and explainer copy"

Every other v2 phase from 5 onward has a `docs/v2/*.md` design note
written at the time. Phase 10 does not — a verified absence (confirmed by
`docs/history/POLITICA_HISTORY_GAPS_AND_CONFLICTS.md`, finding **G3**, and
by `docs/history/ROUND_2_AUDIT.md`'s directed sweep). This document
backfills that missing note. It is reconstructed from the commit itself
and from the historical-archive narrative already assembled in
`docs/history/POLITICA_IMPLEMENTATION_HISTORY_V1_V2.md` §7.10 and
`docs/history/implementation-evidence-v1-v2.md` — those documents grade
this narrative **[E3]** (session narrative without a contemporaneous
design-note or independent artifact beyond the commit diff itself), and
that grading is preserved here rather than silently upgraded. Nothing
below is new research; this is a formatting pass that gives Phase 10 the
same report shape as its siblings, not a re-investigation.

## Starting state / problem

601 real representatives were already in the bundle (since Phase 5), but
the only place to see any of them was Home's 4-item featured preview —
there was no route to browse or search the full set.

## Original plan

The v2 master plan's Phase 8 slot was reused as addendum Phase 10, with a
prepended audit instruction: *"AUDIT FIRST: a 601-representative display
already exists somewhere on Home — inspect it before creating
RepresentativesListView; extend rather than duplicate."* The addendum also
asserted that sigla mapping and empty states were already done (Phase 6),
and scoped this phase to: polish colors/shortNames, add search + party
filter chips, add initials avatars, and add the explainer.

## What the audit found

The audit-first instruction caught a wrong premise in its own brief:
party styling was **already complete** — `Data/parties.json` and
`PartyStyleService` had shipped in Phase 6 with full 19-value coverage and
verified WCAG contrast. There was nothing to build there. The actual gap
was the one the brief treated as settled: no UI route existed to browse
past Home's 4-item preview.

## Actual implementation

- `RepresentativeListView` — `.searchable` name filtering with the
  project's standard diacritic/case-insensitive Italian-locale folding; a
  horizontal row of party filter chips built from *distinct `shortName`s*
  rather than raw `party` values, collapsing the 19 `parties.json` entries
  to 12 chips (a Camera-sigla/Senato-full-name pair like `"FDI"` /
  `"Fratelli d'Italia"` both map to `"FdI"` and filter as one chip).
- `InitialsAvatar` — a party-colored circle with two-letter initials
  (first + last name token), replacing generic SF Symbol placeholders;
  used at two sizes (list rows, profile header); no image asset, no
  network fetch.
- Home's "Come funziona l'elezione" `DisclosureGroup`, stating in-app what
  is and isn't mapped: the 147 Camera uninominale deputies are linked to a
  real collegio; other Camera deputies (plurinominale/estero) are listed
  but unmapped; senators are listed but Senato collegio boundaries aren't
  part of this dataset.
- New `.representativeList` route; Home's "Vedi tutti" link and the
  "Rappresentanti" stat card both route to it.

## Files touched (per the commit)

`Views/RepresentativeListView.swift`, `Utilities/Initials.swift`,
`Utilities/ColorHex.swift`, `HomeView.swift`, `AppRoute`.

## Data/schema impact

None — UI built over data that already existed.

## Testing

`InitialsTests.swift` (8 methods) added; existing suites remained green.

## Deviations from plan

The brief's own premise (styling needing work) was wrong, and the
audit-first instruction is what caught it — treated as the process
working as intended, not a deviation to flag. Separately: the explainer
landed on Home, while the original (pre-addendum) master-plan prompt had
proposed placing it on `DistrictDetailView`; the addendum's delta restated
the content requirement without re-pinning the location. This placement
choice is defensible but was never recorded as a deliberate decision at
the time (tracked as **C9** in
`docs/history/POLITICA_HISTORY_GAPS_AND_CONFLICTS.md`).

## Remaining limitation

This backfill cannot upgrade its own evidence tier — it is still a
post-hoc reconstruction, not a contemporaneous phase report written
against the live diff. Where the historical archive marks a specific
claim `[E3]`, that grading is inherited here, not resolved.

## Lesson

"Audit before implementing" caught a stale premise even though the same
process wrote the premise a few phases earlier — a dataset being imported
does not mean it is browsable, and the UI layer needs its own gap
analysis separate from the data layer. (Restated in `CLAUDE.md`'s working
methodology as of the v2 tag.)
