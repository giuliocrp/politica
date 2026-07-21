# V4 Master Plan — Index

One file per phase; shared context in
[`00-baseline-and-rules.md`](00-baseline-and-rules.md) (verified
baseline, open questions Q1–Q7, plan-wide rules, deferred-scope list —
**read it before any phase file**). Phase reports land in `docs/v4/`.
Prepared 2026-07-21 from the shipped v3.0-prototype state.

## Status

The session executing a phase flips its row in the same commit as the
phase's report. Statuses: `pending` / `in progress` / `done` /
`NO-GO` / `NOT RUN` / `exited` (all terminal states link the report).

| Phase | Title | Gate / network | Status |
|---|---|---|---|
| [23](phase-23.md) | Baseline audit & hygiene | — | [done](../v4/23-baseline-audit.md) |
| [24](phase-24.md) | Real UI tests + a11y audits | — | [done](../v4/24-ui-tests.md) |
| [25](phase-25.md) | Plurinominale geography | GO-PLURI | pending |
| [26](phase-26.md) | Senato regione + electionType | GO-REG | pending |
| [27](phase-27.md) | Stratified votes + lazy loading | **USER-GATED network** | pending |
| [28](phase-28.md) | Group-membership history | GO-STORICO, **USER-GATED network** | pending |
| [29](phase-29.md) | Alignment metric | all six methodology lines | pending |
| [30](phase-30.md) | Comuni-centroid geocoding | GO-COMUNI, **USER-GATED acquisition** | pending |
| [31](phase-31.md) | Staleness + live-refresh ADR | — | pending |
| [32A](phase-32a.md) | Docs, a11y, release prep | — | pending |
| [32B](phase-32b.md) | Decisions + tag | explicit tag approval | pending |

**Dependencies:** 23 first; 24–26, 30, 31 independent after it; 27 and
28 are the two network-gated evidence phases; 29 requires 27 **and** 28
(and may legitimately end NOT RUN); 32A after everything executed; 32B
only on explicit approval. Phase 24 deliberately redefines the
test-count baseline — landing it early keeps later arithmetic simple.

## The per-session prompt

Paste this into a fresh session, substituting the phase number:

> Implement Phase **{N}** of the V4 plan.
>
> 1. Read `docs/plan/00-baseline-and-rules.md` and
>    `docs/plan/phase-{N}.md` in full, plus the `docs/v3`/`docs/v4`
>    reports the phase file cites. `CLAUDE.md` governs throughout.
> 2. Verify the phase's preconditions and dependencies against the
>    actual repository state before writing anything. If a gate
>    evaluates NO-GO or a precondition fails, stop and write the report
>    documenting it — that is a valid outcome.
> 3. Execute exactly as specified. Anything network-touching or
>    user-gated: stop and ask me first; quote my approval verbatim in
>    the report.
> 4. Validate against the phase's test specifications one by one.
> 5. Write `docs/v4/{N}-<slug>.md`, flip the status row in
>    `docs/plan/README.md`, and commit with the phase's pinned message.
>    Never push, tag (except 32B), or touch GitHub — print commands
>    instead.
> 6. End by walking the acceptance criteria and reporting any deviation
>    honestly.

Short form (equivalent by convention once this index exists):
`Implement Phase {N} from docs/plan/phase-{N}.md per docs/plan/README.md's workflow; validate against its acceptance criteria.`
