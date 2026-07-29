# Phase 30B — Comuni Resolve via Published Assignment [GO-ASSIGN]

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 30.
> **Network:** none — the assignment fields are already local, inside the
> ISTAT collegi package attributed since v2 (Phase 30's headline finding).
> **Report:** `docs/v4/30b-comuni-assignment.md`.
> **Commit:** `feat(v4): phase 30b — comuni resolve via published collegio assignment (gated)`

## Objectives & deliverables

Phase 30 resolved comune names geometrically (centroid → point-in-polygon)
and used the source's own `CU20_COD`/`SU20_COD` only to *grade* the result.
That was the spec's instruction, but the alternative was never weighed:
for a name lookup the geometric answer is a derived guess where the
publisher's assignment is a sourced fact. This phase inverts that, and in
doing so makes a second, larger problem expressible.

- **Name lookups read the published assignment.** `CU20_COD`/`SU20_COD`
  (with `_DEN`, plurinominale and circoscrizione fields) become the
  resolution path for comune-name queries. Simplification artefacts leave
  that path entirely: the two known mismatches become correct and the
  known gaps gain answers.
- **Geometry is retained for the coordinate/address path only.** The two
  paths now diverge deliberately; both are documented, and the coordinate
  path's behaviour is unchanged.
- **Multi-collegio comuni become representable.** The current schema holds
  one collegio per comune and therefore *cannot* state that Roma spans 7
  Camera collegi — it is structurally forced to present one as the answer.
  The model gains the ability to return a set; those comuni route through
  the homonym chooser Phase 30 already built, or render with an honest
  all-of-these label. **A comune spanning more than one collegio must never
  resolve to a single collegio presented as the answer.**
- **`comuni.json` schemaVersion bump**, with importer, validator, model and
  service updated in lockstep and the app failing loudly on an unexpected
  version rather than degrading silently.
- **Flow 7's test-side bound** (see risks): retire the 300 s ceiling via
  injection, test-only. The production `CLGeocoder` timeout is **out of
  scope** and stays with 32A.

## Technical requirements

- Extend the Phase 30 comuni importer to carry the published assignment
  per chamber; retain centroids (still required by the coordinate path and
  the map). Explicit sort on a composed key before writing — the artifact
  must be byte-identical across runs (Phase 27 precedent).
- Model/service: the name-lookup return type must be able to express *one*,
  *many*, or *none*. None stays `nil` — never a default, never a nearest
  neighbour (the Phase 28 / Phase 29 nil-not-fallback family).
- `validate_data.py`: every distinct published code resolves to a shipped
  district id; expected counts taken from **gate evidence, not from this
  plan**; new per-file byte gate with measured headroom; existing cross-file
  invariants unchanged.
- All other generated artifacts — boundary files, `representatives.json`,
  `votes.json`, `memberships_camera.json` — **byte-identical**.
- Rule 9 applies: the in-app copy changes when a query can return several
  collegi. Sweep the explainer, README and `DATA_SOURCES.md` prose.
- Flow 7: bound the wait through the `AddressResolving` seam Phase 30
  added, in the UI test target only. No production behaviour change.

## Known risks & edge cases — the GO-ASSIGN gate (all conditions required)

(a) **Field coverage re-measured, not inherited** from Phase 30's report:
`CU20_COD`/`SU20_COD` populated across every comune. Any unpopulated row is
**NO-GO** — a partial field cannot replace a total one.

(b) **Referential integrity is exact**: every distinct published code is
already a shipped district id, both chambers. One unresolvable code is
**NO-GO**; do not add aliases to close a gap.

(c) **Multi-collegio set enumerated and named**, with populations and the
**vintage of the population field stated** (`POP_2011` — the same field
Phase 25 used for placeholder detection; it is census-2011, not current).
The probe measured 6 comuni ≈ 6.94 M residents ≈ 11.67%; reconfirm the set
and the arithmetic. If any comune's multiplicity cannot be expressed by the
chooser, **stop and document** rather than picking one.

(d) **Byte maxima measured before committing to ship.** `comuni.json` was
581,849 B against a 768 KiB gate; the new schema is expected to grow it
~35%, requiring a raise to ~1 MiB. Measure first, then state the gate and
its headroom. `Data/` stands at 6,351,326 B (60.6% of the soft ceiling) —
record the post-30B total for 32A/32B. If the measured growth is materially
worse than projected, a leaner schema (codes without redundant `_DEN`
strings) is the documented fallback — not a silent trim.

(e) **The resolution diff is enumerated comune by comune**, before/after,
each named. The probe measured 7 changes on the Camera side and 4 on the
Senato side, including two corrections (`Carbonara di Nola`,
`Torre de' Roveri`) and gaps that gain answers (`Isole Tremiti` and
others). An **unexplained additional change is NO-GO** — it would mean the
two paths disagree somewhere the probe did not predict.

Additional risks:

- **The schema bump crosses four layers.** A version mismatch that degrades
  quietly instead of failing is the failure mode to design against.
- **Phase 30's coverage figures are superseded, not wrong.** Its 99.94% /
  99.97% described the geometric path. Reconcile explicitly in this
  report; do **not** edit Phase 30's report or spec — they are the
  historical record (baseline rule on completed phases).
- **The 14 hardcoded comune→collegio pairs** from Phase 30's integration
  tests must be **re-derived by standalone script before hardcoding**
  (Phase 25 precedent), since split comuni no longer have a single expected
  id.
- Address-level resolution has no offline path and never will under
  local-first. Bilingual (Italian/German) comune names remain deferred —
  no source publishes them in this package.

## Validation strategy

Promote Phase 30's follow-up measurement script to a **committed probe**,
run **before** any importer change: field coverage, referential integrity
both chambers, the multi-collegio set with populations, the full
before/after resolution diff, and byte measurements at the candidate
schema. Generated-data protocol on every artifact, with each changed line
explained. Import run twice and the artifact diffed — byte-identical, not
asserted by inspection. Full suite against the Phase 30 baseline of **204**,
`totalTestCount` read from the `.xcresult` (the log-truncation quirk is
documented in `CLAUDE.md` and has now been sighted four times).

## Test specifications (strict acceptance criteria)

1. Probe output quoted in the report with gate conditions (a)–(e)
   individually evidenced; GO or NO-GO stated (NO-GO path: report + probe
   only, zero other diff).
2. Validator green with expected counts taken from the gate evidence, not
   from this plan; new byte gate stated with measured headroom; all other
   generated files byte-identical.
3. Named resolution regressions: the corrected comuni, every
   previously-unresolved comune that now answers, and a sample of unchanged
   ones — expected ids verified by standalone script before hardcoding.
4. Multi-collegio: a comune spanning several collegi returns all of them
   and is never rendered as a single answer; the chooser path is tested;
   an unknown comune still returns nil, never a fallback.
5. Coordinate/address path behaviour unchanged from Phase 30, with a test
   pinning that the two paths are deliberately distinct.
6. Unexpected `schemaVersion` fails loudly; no silent degradation path.
7. Flow 7's wait is bounded through the test seam; no production timeout
   introduced by this phase.
8. UI strings pinned in the report, all Italian; rule 9 sweep recorded,
   including any deliberate decision **not** to change a surface.
9. Suite green; additions counted against the Phase 30 baseline (204).

**Standing constraints (non-negotiable):**
- Never rename the Xcode project ("Politici"), target, scheme, or bundle identifier.
- All user-facing strings must be in Italian.
- The app runtime is strictly local-first: no network calls from the app.
- Developer tools may query official public endpoints only, and only inside tools/.
- Never fabricate political data, geography, or licensing information.
- If data is missing or ambiguous, stop and document it.

**Verification command trio:**
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | grep iPhone
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'platform=iOS Simulator,name=<SimName>' test
```
