# V3 Phase 21 — Votes Scope Probe: Measured Early Exit (No Data Change)

**Outcome: early exit, data untouched.** The probe ran, the four-scope
table was measured, and the decision the table supports is *not to
expand* — the plan's own clause applies verbatim: "Source may not offer
multi-sitting diversity at reasonable size — that finding is a valid
exit," and "a documented early exit beats a forced import."

## Approval (quoted verbatim)

Phase 21 is the plan's optional, USER-GATED network phase ("the probe
itself fetches; do not begin without explicit approval"). The Phase 20
handoff message named it exactly that way — "**Phase 21 (optional,
user-gated network probe)** to expand the curated votes sample … Your
call." — and the user replied:

> **"Proceed with Phase 21."**

That instruction, given in direct response to the network-probe framing,
is the explicit approval this phase acted on.

## Refetch-protocol checklist

1. **Legislature XIX re-verified at probe time** (2026-07-21, before any
   other network act): `probe_senato_legislature_currency.rq` via
   `run_probe.py` — 21 distinct values, max integer legislature **19**.
2. **Probe fetches quarantined**: all raw responses under
   `tools/probes/output/` (gitignored), never an import source. No
   `fetch_*.py` script ran; `tools/raw/camera_votazioni_sparql.json` is
   byte-untouched; `git status` shows zero changes under `Politici/Data/`
   or `tools/raw/`.
3. Manifest / `docs/DATA_SOURCES.md` re-sync: **not applicable** — no
   fetch script ran, no `retrievedAt` moved, no data changed.
4. Constants: none changed (`votes_scope.json`, `MAX_OUTPUT_BYTES`,
   `MAX_VOTES_FILE_BYTES` all untouched; the 2 MiB policy was **not**
   revised — see the decision below for why revising it would have bought
   nothing).

## The probe

`tools/probes/probe_votes_scope.py` (committed; network-touching by
design, run once under the approval above) plus
`probe_camera_votes_secret_window.rq`. To mirror production instead of
approximating it, the probe **imports the real pipeline's own functions**
— `import_votes.py::group_by_votazione`/`votazione_sort_key` and
`fetch_camera_votes.py::fetch_detail`/`is_safe_uri` — and serializes
dry-runs with the exact Phase 20 normalized schema and serializer
settings.

**Camera endpoint behavior, observed and documented** (previously
uncharacterized): plain `SELECT`s and a `VALUES`-clause detail query with
10 URIs per request all succeed (no 403-on-aggregate encountered because
no aggregate was needed); detail was fetched in 5 chunks of 10 votazioni
returning a uniform 3,990 rows each (399 positions × 10 — no round-number
truncation anywhere, every response complete). Chunking was chosen
because the prior single-shot 25-event fetch returned 9,975 rows,
uncomfortably close to the ~10,000-row cap the *Senato* endpoint showed
in 15b; whether the Camera endpoint has such a cap remains unobserved —
chunking simply never approaches one.

## The four-scope table (measured 2026-07-21)

Candidate window: the 50 most recent public non-secret Assemblea
votazioni — **all 50 dated 2026-07-15, all from sitting 690**, with **29
secret votes excluded inside the same window**. Bundle context at run
time: `Data/` minus votes.json = 2,490,511 B; current votes.json =
711,439 B; per-file votes gate = 2,097,152 B; soft bundle ceiling =
10,485,760 B.

| Scope | Events | Positions | Dropped | Sittings | Atti (atto-bearing ev.) | Date span | Dry-run bytes | % of gate | Projected bundle |
|---|---|---|---|---|---|---|---|---|---|
| 20 | 20 | 7,980 | 0 | **1** | 0 (0) | 1 day | 1,185,823 | 56.5% | 3,676,334 |
| 30 | 30 | 11,970 | 0 | **1** | 0 (0) | 1 day | 1,779,098 | 84.8% | 4,269,609 |
| 40 | 40 | 15,960 | 0 | **1** | 0 (0) | 1 day | **2,372,937** | **113.2%** ✗ | 4,863,448 |
| 50 | 50 | 19,950 | 0 | **1** | 0 (0) | 1 day | **2,966,635** | **141.5%** ✗ | 5,457,146 |

Supplementary depth probe (metadata-only, 300-event window, saved to
`output/camera_votes_depth_window.json`): the recent per-sitting-day
distribution is 2026-07-15: **51** non-secret votes, 07-14: 3, 07-08:
**109**, 07-07: 77, 07-01: 43, … — so:

- the minimum "most recent N" reaching even **3 distinct sitting days is
  N = 55**, projecting to **~3,261,000 B ≈ 155% of the gate** (at the
  measured ~148.6 B/position all-in cost);
- the maximum gate-compliant N (whole-event stopping, ~5% headroom) is
  **~33 events — all inside the single 2026-07-15 sitting**;
- a ≥6-month span (methodology line 3) lies hundreds of same-shape votes
  deeper still — unreachable under this selection design at any
  defensible size.

## Decision — from the table alone

**No scope is chosen; the phase exits with data untouched.**

- Scopes 40 and 50 **breach** the unchanged 2 MiB per-file gate outright.
- Scope 30 fits (84.8%) but delivers *zero* diversity: still one sitting,
  one day, zero atto-bearing events. Of the methodology gate's six lines
  it would flip only line 1 (≥30 events) — worthless alone, since a
  metric requires all six — while nearly tripling votes.json (711 KB →
  1.78 MB) to add 18 more same-afternoon amendment/odg votes to a browse
  screen that already shows that afternoon. Cost without value.
- Scope 20 is strictly dominated by 30 on every axis while changing
  nothing.
- **Revising the 2 MiB policy was considered and rejected**: even ~3.3 MB
  (a ~56% policy increase) would buy only a 3-day span; the diversity the
  methodology gate actually needs is structurally unreachable under the
  "N most recent" selection design, at any N a bundled prototype could
  justify. Spending policy budget for no diversity would be a forced
  import wearing a policy revision as a costume.

**The finding, stated plainly**: the Camera Assemblea produces votes in
same-day bursts (51, 109, 77 non-secret votes on single recent sitting
days). "The N most recent" is therefore the wrong *selection design* for
sample diversity — the bottleneck is the design, not the byte budget.

**Constructive path (V4 / roadmap, not smuggled in here)**: a stratified
selection — e.g. the K most recent *sittings* with a per-sitting cap, or
hand-curated atto-bearing final votes via the already-existing
`votes_scope.json` `"explicit"` mode — could hit all four sample-shape
methodology lines within the existing 2 MiB gate (e.g. 30 events spread
over 10 sittings ≈ the measured 30-scope bytes). That is a new
scope-design decision deserving its own probe and plan treatment, not a
quiet reinterpretation of this phase's prescribed candidates.

## What this phase deliberately did NOT do (early-exit scope)

Per the plan, the lazy-`VoteService`/loading-states/decode-timings work
and every `tools/config`/validator/test change were conditioned on a
scope being chosen — none of it was touched. The methodology gate table
in `docs/v3/votes-methodology.md` is **unchanged and still accurate** (its
re-evaluation trigger is a sample change; the sample did not change):
1 of 6 lines passes, metric deferred to V4. No metric ships. The two
12-event test constants, the Votazioni scope line (N=12, data-driven),
and the app remain exactly as Phase 20 left them.

## Acceptance criteria walk

1. ✅ Four-scope probe table with full-bundle arithmetic from run-time
   file sizes (above); no `import_votes.py` limit changed, so none needed
   tracing.
2. ✅ Early exit with the table and decision committed; data untouched
   (`git status`: only probe scripts + this report).
3–4. n/a — no data shipped.
5. ✅ No metric ships; suite untouched and green as of Phase 20's run
   (nothing app-side changed); this report committed in the phase commit.

**Commit-message note**: the plan pinned a `feat(v3)` message written for
the data-shipping outcome; since this phase ships only findings, the
commit uses the `docs(v3)` prefix instead, following the Phase 15
read-only-phase precedent — disclosed here rather than silently applied.

## Notes for 22A

- Roadmap entry: votes expansion **attempted and measurably exited** in
  Phase 21 (this report); the stratified-selection redesign is the
  recorded V4 candidate.
- The lazy-votes work rides with any future expansion (its trigger was
  the file growing; at 711 KB eager decode stands).
- No new a11y surfaces (no UI change).
