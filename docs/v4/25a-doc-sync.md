# 25A — Post-Phase-25 doc-sync (side-task record)

**Not a numbered phase.** A scoped cleanup closing out documentation and
generated-note drift left open by Phase 25 and by a spawned doc-fix
session. This is the first record written under the side-task convention
added in `docs/plan/00-baseline-and-rules.md` rule 8 (added in this task's
Commit C). Run on 2026-07-22, on branch `v4`, on top of Phase 25's
`15f3f95`. No push, no tag.

Scope was deliberately narrow: no changes under `Politici/` app source,
`PoliticiTests/`, or `PoliticiUITests/`; no changes to `districts*.geojson`,
`representatives.json`, or `votes.json`; the only generated data file
touched is `Politici/Data/sources.json`, and only its `notes` strings
(`generatedAt` did not even move — see below).

## 1. Step-1 diagnosis (the hard gate)

Everything below was read from the repository before any edit.

- **Worktrees.** `git worktree list` showed two: the primary
  `/Users/giuliocarpilapi/GitHub/Politici` at `15f3f95 [v4]`, and a spawned
  worktree `.claude/worktrees/elated-taussig-0c601b` on branch
  `claude/elated-taussig-0c601b` at **`3dc224e`** — the last v3 commit,
  which **predates all of v4** (phases 23/24/25).
- **This (primary) worktree.** `HEAD = 15f3f95…` (Phase 25), and
  `git status --porcelain` was **empty** — clean. So the Step-1 STOP
  conditions ("HEAD is not 15f3f95 / base predates it / uncommitted
  changes based on a pre-25 tree") did **not** apply to the worktree the
  work was done in. Good to proceed.
- **Is Phase 25's `votazioni_scope_note` fix already in `15f3f95`? Yes.**
  `git show 15f3f95 -- tools/make_manifest.py` contains the exact fix:

  ```diff
  -    vote_count = len({v["sourceUrl"] for v in votes if v.get("sourceUrl")})
  +    events = votes["events"] if isinstance(votes, dict) else votes
  +    vote_count = len({e["sourceUrl"] for e in events if e.get("sourceUrl")})
  ```

  with an in-code comment: *"first re-run since Phase 20 was Phase 25; see
  docs/v4/25-plurinominale-geography.md."* Phase 25 also regenerated
  `sources.json` (its stat touched `sources.json`, `DATA_SOURCES.md`, and
  `make_manifest.py`), so the committed manifest already had 8 sources and
  `generatedAt: 2026-07-22`.

- **The spawned worktree's uncommitted diff.** `git diff` in
  `elated-taussig-0c601b` showed three modified files
  (`Politici/Data/sources.json`, `docs/DATA_SOURCES.md`,
  `tools/make_manifest.py`). Its `make_manifest.py` hunk was **two things**:
  (i) a *duplicate* `votazioni_scope_note` fix
  (`events = votes.get("events", []) if isinstance(votes, dict) else votes`),
  and (ii) the Senato uninominale note edit.

### Resolution of the duplicate-fix contradiction

Phase 25's report (§4.5) and the spawned session both claimed to have
fixed the same `votazioni_scope_note` crash. The repository resolves it
unambiguously: **Phase 25's fix is committed in `15f3f95`; the spawned
session's identical fix was made on a worktree based on `3dc224e`, which
predates Phase 25 and therefore still had the stale flat-list code.** The
spawned diff was never committed to `v4`. Both narratives are true in
isolation (each session did fix the crash on the tree it saw), but only
one fix reached the branch. Per the task, the spawned diff was **not**
committed; instead its *note* edits were re-applied by hand on top of
`15f3f95`, discarding the duplicate scope-note hunk (Phase 25's version is
kept verbatim).

## 2. `.fetch_metadata.json` — present, not reconstructed

`tools/raw/.fetch_metadata.json` **exists** in this worktree (it lives
under the gitignored `tools/raw/` cache) and holds the real committed
fetch dates: `camera` / `camera_votazioni` / `istat` = `2026-07-18`,
`senato` = `2026-07-21` — matching every `retrievedAt` in the committed
`sources.json`. It did **not** have to be reconstructed.

Pre-flight reproducibility check, run on the clean tree before any edit:
`make manifest` reproduced `sources.json` **byte-identical** (`git diff
--quiet` → no diff). Because today (`2026-07-22`) equals the committed
`generatedAt`, and the cache supplies real `retrievedAt` dates, every
subsequent scoped diff below is attributable solely to the one note edited.

## 3. Commit A — `7af1dce`

`fix(tools): correct stale Senato uninominale linkage note in generated sources`

- `tools/make_manifest.py`: the `istat-collegi-elettorali-senato-uninominali`
  note's closing sentence "Nessun senatore è ancora collegato…" replaced
  with the 73/74 linkage wording citing `docs/v3/17-senato-mandates.md`.
- `docs/DATA_SOURCES.md`: the ISTAT (Senato, uninominali) "Transformation
  summary" mirror corrected the same way; a dated cross-check entry added.
- `make manifest` re-run; scoped `sources.json` diff (only that note):

  ```diff
  -      "notes": "…scaricato nello stesso momento. Nessun senatore è ancora collegato al proprio collegio in questo prototipo (vedi docs/v3/15-senato-exploration.md).",
  +      "notes": "…scaricato nello stesso momento. 73 dei 74 collegi sono collegati al rispettivo senatore eletto in via uninominale (districtId associato tramite osr:collegioElezione; vedi docs/v3/17-senato-mandates.md).",
  ```

  `generatedAt` stayed `2026-07-22`; all eight `retrievedAt` byte-identical.
- `make validate` green (confirms "73/74 collegi uninominali Senato con un
  senatore corrente").

## 4. Commit B — `a7d4c71`

`fix(tools): correct stale Senato Open Data collegio-linkage note`

- `tools/make_manifest.py`: the `senato-della-repubblica-xix-legislatura`
  note's stale "Il collegio elettorale non è ancora associato … (districtId
  è null)" rewritten to mirror the Camera Open Data note — senators elected
  in an uninominale collegio carry a `districtId`, the rest stay `null`
  (`docs/v3/17-senato-mandates.md`). This was a second stale note the
  spawned session did **not** touch; fixing it prevents `sources.json`
  shipping two contradictory statements about the same fact after Commit A.
- `docs/DATA_SOURCES.md`: the Senato Open Data "Transformation summary"
  prose was **already** Phase-17-correct (verified, not assumed — it already
  reads "the 73 senators whose `osr:tipoElezione` starts with `"Eletto
  uninominale"` carry the `districtId`… docs/v3/17-senato-mandates.md"), so
  only a dated cross-check entry was added.
- `make manifest` re-run; scoped `sources.json` diff (only that note):

  ```diff
  -      "notes": "…all'endpoint ufficiale dati.senato.it. Il collegio elettorale non è ancora associato ai collegi campione di questo prototipo (districtId è null).",
  +      "notes": "…all'endpoint ufficiale dati.senato.it. I senatori eletti in un collegio uninominale sono associati al relativo collegio ISTAT (districtId); gli altri non hanno un collegio associato (districtId è null). Vedi docs/v3/17-senato-mandates.md.",
  ```

  `generatedAt` stayed `2026-07-22`; all eight `retrievedAt` byte-identical.
- `make validate` green.

`tools/SOURCES.md` was checked for both notes and makes **no**
senator-to-collegio linkage claim at all (its ISTAT entry describes
boundaries only), so it needed no change — matching the cross-check
entries' assertion.

## 5. Commit C — plan & rules sync

`docs(v4): sync plan baseline (389), a11y deferral handoff, manifest + side-task rules`

Documentation only (this record is committed here):

- **(a) 397 → 389.** `grep -rn "397" docs/plan/ CLAUDE.md` found two hits:
  `docs/plan/phase-25.md` (a completed phase — left untouched, its report
  already documents the correction) and `docs/plan/00-baseline-and-rules.md`
  (the "Deputy coverage codes" baseline row). The baseline row was
  corrected to **389/400** with the 8 estero + 3 bare breakdown and a
  pointer to `docs/v4/25-plurinominale-geography.md` §2. Verified against
  the shipped data: exactly 389 deputies carry `collegioPlurinominale`,
  73 senators carry a `districtId`. No **pending** phase file said 397.
- **(b) Phase 24 → 32A a11y handoff.** `docs/plan/phase-32a.md` deliverable
  #2 previously said only "reconciled against Phase 24's automated audits";
  it now explicitly names the **62** `performAccessibilityAudit` findings
  Phase 24 recorded rather than fixed (all `.contrast` / `.dynamicType` /
  `.textClipped`, inventoried in `docs/v4/24-ui-tests.md` §5), each to be
  triaged in 32A. A matching row was added to the deferred list in
  `00-baseline-and-rules.md` (framed as a within-V4 deferral, not a drop).
- **(c) `make manifest` reproducibility hazard** recorded in `CLAUDE.md`
  next to the log-truncation caveat, scoped so it leads with the safe case
  (in a normal working checkout `make manifest` is reproducible — the
  cache is present): the hazard is specifically that `.fetch_metadata.json`
  is gitignored, so from a **fresh checkout or new worktree** it is absent
  and `make manifest` silently rewrites every `retrievedAt` to today; the
  precaution (confirm / reconstruct the cache first) is scoped to that
  case, not to every run. The **hardening candidate — not implemented
  here** (`make_manifest.py` should fail loudly on an absent cache instead
  of silently advancing dates) is tracked as a backlog row in the deferred
  list in `00-baseline-and-rules.md`, keeping the auto-loaded `CLAUDE.md`
  to what every session must know rather than a to-do; `CLAUDE.md` carries
  only a one-line pointer to it.
- **(d) Side-task rule** added as rule 8 in `00-baseline-and-rules.md`.
  *Output side:* out-of-phase work ends committed with a clean tree, never
  pushes or tags, and — where it touches `tools/` or `Politici/Data/` — is
  recorded under `docs/v4/` and referenced from the next phase's report.
  *Input side:* a spawned/background session's base commit must be verified
  against `v4`'s tip before its output is trusted — the generalizable
  lesson from this incident, which was fundamentally an **input** failure
  (a session forked from the pre-v4 `3dc224e`, under a v3-era `CLAUDE.md`
  that had never seen the plan files), not an output one.
- **(e) This record.** Linked from the plan index prose in
  `docs/plan/README.md` (not the status table — no phase changed status).

## 6. Verification

- **Full suite: 158/158, 0 failures.** Read from the `.xcresult`
  (`xcresulttool … test-results summary`): `totalTestCount: 158`,
  `passedTests: 158`, `failedTests: 0`, `result: Passed` — the authoritative
  bundle count, not a log grep. Unchanged from Phase 25's 158/158 (this
  task touches no compiled source or test; `SchemaV2Tests` only asserts the
  manifest's `schemaVersion == 2` and non-empty `sources`, neither affected
  by the note text).
- **`make validate` green** at every step.
- Post-commit: clean working tree; three new commits on top of `15f3f95`
  (`7af1dce`, `a7d4c71`, and this Commit C).

### Note on the spawned worktree

`.claude/worktrees/elated-taussig-0c601b` (branch
`claude/elated-taussig-0c601b` @ `3dc224e`) still holds its now-superseded
uncommitted diff. It was correctly **not** committed to `v4`, and was left
untouched here (separate branch/worktree, outside this task's scope).
Removing that worktree or discarding its diff is a user/spawned-session
concern, not part of this cleanup.
