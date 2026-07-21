# Voting-Data Methodology — the gate any future metric must pass

Written in V3 Phase 20 (see `docs/v3/20-vote-browsing.md`). This document
is the standing contract: **no vote-derived metric of any kind ships in
this app until every line of the gate below passes**, and the standing
rules below bind any metric that ever does ship. Phase 20 itself ships
*browsing only* — events, tallies, filters — deliberately no metric.

## The gate

A proposed metric (e.g. within-group voting alignment) may only be
computed over a sample that satisfies **all six** lines. Status is
measured against the current shipping `votes.json` as of Phase 20
(12 events, 4,788 positions, imported 2026-07-18):

| # | Requirement | Current sample | Status |
|---|---|---|---|
| 1 | ≥ 30 events | 12 events | ✗ |
| 2 | ≥ 3 distinct sittings (sedute) | 1 sitting (n. 690) | ✗ |
| 3 | ≥ 6 months of date span | 1 day (all events 2026-07-15) | ✗ |
| 4 | ≥ 2 distinct atti among atto-bearing events | 0 atto-bearing events (all 12 titles are bare procedural odg votes) | ✗ |
| 5 | `astenuto` its own category, never folded into favorevole/contrario/assente | Holds structurally: `VoteChoice.astenuto` is a distinct case end-to-end (source `"Astensione"` → `.astenuto`, own badge, own filter chip, own tally) | ✓ |
| 6 | Group-membership-at-vote-date available | **Not available** — `representatives.json` carries only the *current* parliamentary group; the pipeline imports no historical membership intervals. This structurally blocks every group-relative metric regardless of sample size | ✗ |

**Conclusion: 1 of 6 lines passes. Any alignment/cohesion/discipline
metric is deferred to V4 at the earliest**, and only after a Phase 21-style
scope expansion fixes lines 1–4 *and* a dedicated, source-verified
group-membership-history import fixes line 6.

Rationale for the failing lines: a metric computed over 12 same-day,
same-sitting votes on amendments/ordini del giorno to (at most) a couple
of measures would present a single afternoon's party discipline as a
representative behavioral statistic — that is exactly the kind of
real-looking-but-misleading number this project's constraints forbid.

## Standing rules (bind any future metric, independent of sample size)

- **Absences are excluded from every denominator.** The source's
  `"Non ha votato"` genuinely conflates "absent" with "present but not
  voting" (see `docs/v2/04-votes-import.md`); treating it as a behavioral
  signal in either direction would be fabrication.
- **No participation/attendance metric, ever**, for the same
  `"Non ha votato"` ambiguity — the source does not distinguish the
  reasons, so neither can we. (`attendanceRate` stays null everywhere.)
- **Secret ballots stay excluded at fetch scope.** Their per-deputy
  records carry only a generic voted flag by law; including them would
  misrepresent legal unattributability as data.
- **Astenuto is always its own category** (gate line 5, restated as a
  permanent rule).
- **The only permitted metric label is the pinned Italian string**
  `"Allineamento nel campione di votazioni importate"` — the label itself
  must state the sample-bound scope. It appears in this documentation
  only; grep-verified absent from all app code as of Phase 20.
- Any metric ships with its exact denominator definition and the gate
  table above, re-measured, in the same commit.

## Re-evaluation protocol

Whenever the votes sample changes (Phase 21 or later), this file's gate
table must be re-measured from the new `votes.json` in the same commit —
the numbers above are point-in-time, and a stale "✗" is as misleading as
an unearned "✓".
