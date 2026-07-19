# POLITICA — History Gaps and Conflicts
### Every contradiction, missing artifact, and confidence concern found while compiling the v1→v2 implementation history, plus the questions that would resolve them.

Compiled 2026-07-18. Source hierarchy applied throughout (highest first): the evidence audit `implementation-evidence-v1-v2.md` → code/data at the tags → git history → committed docs → session summaries → prompts/plans → the commissioning brief. Where sources disagree, the higher source's finding stands in Documents A/B and the disagreement is recorded here — never silently resolved. Labels as in Documents A/B: [E1]–[E6], [U] = commissioning-brief-only.

---

## 1. Conflicts and discrepancies

**C1 — No `v1.0.0` tag exists, yet "v1.0.0" is a canonical release name.** Git contains exactly one tag (`v2.0-prototype`). The v1 boundary is commit `6d3b866`, identified via its message and the reflog (the v2 branch was created from it). All documentation — CHANGELOG, README, the commissioning brief, Documents A/B — treats "v1.0.0" as a release, but nothing in git marks it. Consequence: anyone reconstructing history from tags alone will find one release, not two. Resolution options: retro-tag `6d3b866` as `v1.0.0` (annotated, with a message noting it is retrospective), or explicitly document the label-only status wherever the version scheme is described. [E1 for the absence]

**C2 — CLGeocoder deprecation warnings: brief vs. audit. Audit wins.** The commissioning brief (item 4) states v1-era builds produced CLGeocoder deprecation warnings under "iOS 26", motivating the geocoding seam. The evidence audit examined the targeted SDK and found **CLGeocoder is not deprecated there**, and no build log preserving such a warning exists. Per the hierarchy, Documents A/B carry the audit's finding and downgrade the warning claim to unverified. The *architecture* is unaffected either way — `GeocodingProviding` exists and is the migration seam regardless of motive. Possible reconciliations: a different SDK at v1 build time; a misread of a different warning; or a real warning in a toolchain no longer inspectable. [E1/E6 vs. U]

**C3 — "requests" vs. Python-urllib; unverified 403 and HTTP→HTTPS redirect.** The brief (item 6) describes the Senato fetch failing under the `requests` library's default UA with a 403 after an HTTP→HTTPS redirect. The repository contradicts the library detail twice over: the plan constraint mandates stdlib-only, and `sparql_client.py`'s own comment names the rejected UA as **`Python-urllib`** — the stdlib default. Documents A/B state the stdlib version. The redirect and the literal "403" status code appear nowhere in committed material and remain [U]. The substantive fact — the endpoint rejects anonymous/default UAs and the client now sends a descriptive one — is [E1/E2] and uncontested.

**C4 — Test count: 92 static vs. 96–97 observed vs. the brief's "96".** Static grep at the tag: 92 methods in `PoliticiTests` (95 including the UITests templates). The audit session's own `xcodebuild test` runs: 96–97 passed, 0 failed. The brief: "96 passing tests, subject to verification." The evidence report deliberately left this open, hypothesizing (without asserting) that XCTest reports more "Test Case" lines than there are declared methods — e.g., via a `measure`-based test. No source is plainly wrong; they are counting under different definitions. Documents A/B state both numbers and the non-reconciliation. Resolution: one instrumented run, reading the result log line by line. [E1 vs. E4]

**C5 — ISTAT retrieval date: 2025-07-18 vs. 2026-07-18.** `docs/v2/03-boundaries-audit.md` quotes `tools/raw/SOURCES.txt` recording the ISTAT download as `RetrievedAt: 2025-07-18`; the shipped manifest and `docs/DATA_SOURCES.md` say `2026-07-18`. `SOURCES.txt` is human-maintained and gitignored (only its quoted content survives), so this is a committed-doc vs. shipped-data year discrepancy — almost certainly a typo on one side, but which side is not determinable from available material. The manifest's date comes from the human-entered ISTAT metadata path, not `.fetch_metadata.json` stamping, so neither value is machine-attested. Low stakes; worth one edit to fix. [E2 vs. E1, mutually inconsistent]

**C6 — Simplification toolchain: mapshaper/Visvalingam planned, ogr2ogr/Douglas-Peucker shipped.** The addendum's Phase 7 prompt specifies mapshaper with Visvalingam keep-shapes weighting; `build_boundaries.sh` ships GDAL `ogr2ogr -simplify` (Douglas-Peucker) at a 1000 m tolerance, with a comment recording the tolerance calibration. No committed note explains the substitution (plausibly toolchain availability — GDAL was verified present; mapshaper never mentioned again). The output met every stated acceptance criterion except the vertex gate (C7). Recorded as a plan-vs-implementation deviation in Documents A §7.7/§19. [E1 vs. plan]

**C7 — Per-feature vertex budget planned, not evidenced.** The plan set two budgets: ≤~3 MB file size *and* ≤~1500 vertices per feature, both to be printed. Only the byte gate exists in the shipped scripts and outputs; no vertex counting or gate is evidenced anywhere. The shipped geometry may well satisfy the vertex budget — it was simply never measured. Flagged as debt in Document A §22.2. [E1 for the absence]

**C8 — User-Agent evolution: browser-like first, descriptive later.** Session-era narrative describes an initial fix using a browser-like UA when the Senato endpoint first rejected the default; the shipped `sparql_client.py` (Phase 6) uses the honest descriptive `PoliticaApp-DataPipeline/1.0 …` string. Both facts can be true in sequence — the pre-Phase-6 scripts are superseded and the interim state left no committed trace. Documents A/B present the shipped UA as the standing fact and the browser-like interim as [E3] narrative. No action needed; recorded so the sequence isn't misread as a contradiction.

**C9 — Election explainer location: Home vs. the plan's DistrictDetailView.** The master-plan Phase 8 prompt proposed the "Come funziona l'elezione" explainer on `DistrictDetailView`; the addendum's Phase 10 delta restated the content requirement without re-pinning the location; the shipped explainer is a `DisclosureGroup` on **Home**. A defensible product placement, but formally a plan deviation with no recorded rationale. [E1 for placement; plan for the proposal]

**C10 — When did party shortNames converge? RESOLVED — present in full at Phase 6.** Phase 6's report describes creating `parties.json` as 19 *independent* entries with the explicit decision not to merge cross-chamber pairs. At the tag, the 19 entries share **12** distinct `shortName`s (e.g., `FDI` and `Fratelli d'Italia` both → `"FdI"`), and Phase 10's chips are built on that dedup. A read-only fact-check of `git show 8b16be1:Politici/Data/parties.json` settles the timing: at `8b16be1` (Phase 6) the file already carries the schema `{value, shortName, colorHex}` on all 19 entries, with 19 unique `value`s and **12** unique `shortName`s — 7 shortNames each shared by exactly 2 `value` entries (FdI, FI, IV, Lega, M5S, Misto, PD) — and `git diff 8b16be1 v2.0-prototype -- Politici/Data/parties.json` returns no output (identical blob hashes): the file is byte-for-byte unchanged between Phase 6 and the tag. The shared shortNames therefore date to Phase 6's creation, as display strings without color-entry merging — fully consistent with the stated non-merge decision — and Phase 10's "colors/shortNames" polish left this file untouched. Both the tag-state facts and the timing are now [E1]. Zero runtime consequence; recorded resolved.

**C11 — `make all` already includes `fetch`.** The documented one-command refresh is `make fetch && make all`, but `all`'s dependency list starts with `fetch`, so the shorthand fetches twice. Harmless (fetch is idempotent onto the cache) but inelegant, and a trap if fetch ever becomes expensive or rate-limited. One-line Makefile or README fix. [E1]

**C12 — Accessibility completion: user report vs. repository state.** `docs/v2/a11y-checklist.md` lists five human checks as **pending** (full VoiceOver walkthroughs of both flows; an Accessibility Inspector pass over all 9 screens; a max-size Dynamic Type re-walk; a Reduce Motion toggle; a rotor-Links check). The commissioning brief reports the user performed the final checks and found them working. Both are recorded as stated: [E5] user-reported completion, repository-pending on paper. If the walkthrough results matter for V3's accessibility baseline, they should be written into the checklist (or a follow-up note) so the repo agrees with reality.

**C13 — "96 passing tests" as a release claim.** Subsumed by C4 but worth its own line since the number appears in release-facing prose: any external statement of the test count should either say "92 test methods" (static) or "96 reported passing" (runtime) with the definition attached, until C4 is reconciled.

---

## 2. Missing artifacts

**G1 — The originating prompt/summary artifacts are absent from the Project.** Four document families the commissioning brief names as sources do not exist in the provided material and were confirmed absent by search: the **Initial Kickoff Prompt** (v1), the **original v1 Phase 1–4 prompts**, the **"Politica — Project Summary"**, and the **raw Claude Code completion summaries** for any phase. Everything attributed to them in Documents A/B is therefore labeled [U] or [E3] and cross-checked against git where possible. If these exist in chat history or local files, archiving them (even unedited) would upgrade a dozen [U] items — notably items 1–3 and 5–6 of the failure log.

**G2 — `docs/releases/v2.0-prototype.md` was planned and does not exist.** The docs-phase prompt requested a separate release-note file; `git ls-tree` at the tag confirms its absence. `CHANGELOG.md` exists and covers the content. The brief states the GitHub Release description was assembled manually outside the repo — itself unverifiable (E6/U, see U-list). Options: backfill the file from the CHANGELOG entry, or amend the release process doc to bless CHANGELOG-only.

**G3 — No Phase 10 report.** Every phase from 5 onward has a committed `docs/v2/*.md` report except Phase 10 (`8a1aa90`) — a verified absence and the one break in the self-documentation discipline. Its narrative (audit-found-styling-done; list view as the real gap) survives only as [E3]. A short retrospective note would close the set.

**G4 — Diagnostic probe scripts were not preserved.** The standalone `swiftc` probes that diagnosed the `MKMultiPolygon` behavior (and the v1-era harnesses) were run outside the repo and never committed. The *findings* are fully preserved in code comments and tests; the probes themselves are gone. Future probes worth keeping could live under a gitignored-except-by-choice `tools/probes/`.

**G5 — v1's intra-phase history is unrecoverable.** v1 landed as effectively one squashed commit (`6d3b866`); its four-phase internal progression, orderings, and any failed intermediate states exist only in narrative. Nothing to fix retroactively; recorded so no one goes looking.

**G6 — `tools/raw/SOURCES.txt` is gitignored.** Deliberate (the whole cache is), but it means the only human-maintained provenance record for the manually downloaded ISTAT file survives solely via quotation in a phase report — which is exactly how the C5 date discrepancy became unresolvable. Consider committing `SOURCES.txt` (it contains no bulk data) or mirroring its content into `docs/DATA_SOURCES.md`.

**G7 — The original commissioning brief itself is not archived in the repository.** The archived transcript preserves a single Human turn whose text is empty and whose attachment content is not inlined; every [U]-labeled wording in Document A §20 and in this document therefore rests on the authoring session's in-context reading and is **not independently re-derivable from git alone** — except the naming/alias instruction, which the evidence report's §2 independently records. Action: archive the brief verbatim (even raw) under `docs/history/` alongside this pack, so [U]-labeled claims regain an inspectable source.

---

## 3. Unverifiable items ([E6] / [U] register)

Consolidated list of everything Documents A/B assert only with a caveat, or decline to assert:

1. **Failure-log items 1–2** (the v1 `DistrictFeatureCollection` harness loop; the CoreData-logging/white-screen episode): consistent with verified facts (`Item.swift` present in `3ab4e58`, gone by `6d3b866`; no persistence framework at either release; the documented harness *method*), but the loops themselves have no surviving artifact. [U]
2. **Failure-log item 3's discovery story** (finding `xcode-select` at CommandLineTools): the `DEVELOPER_DIR` mechanism is everywhere [E1/E2]; the discovery narrative is not. [U]
3. **The RDF-export detour** (item 5's "historical people export too broad"): the SPARQL pivot and the user's curl verification are corroborated by the addendum; the characterization of the abandoned path is brief-only. [U]
4. **403 / HTTP→HTTPS specifics** of the Senato UA episode (see C3). [U]
5. **The app icon's Canva origin** (brief): `icon.png` exists in-repo; its provenance is stated nowhere in committed material. [U]
6. **Repository visibility (private), tag push, and the GitHub Release's existence/URL**: local git corroborates pushed, synchronized branches and the ff-merge; nothing local can attest visibility, a pushed tag's remote presence, or a Release object. [E6]
7. **Whether v1.0.0 was ever *intended* to be tagged** (vs. label-only by design). [E6]
8. **The deployment-target 26.5 rationale** for twelve phases of non-action despite being flagged in the first audit. [E6]
9. **Prior awareness of the dead Senato legend entry** before the evidence audit surfaced it. [E6]
10. **Whether the Phase 8 external three-college spot-check was performed** (required manual step; no committed attestation). [E6]
11. **Whether the docs-phase fresh-clone README walkthrough was performed** (same status). [E6]
12. **Whether a CLGeocoder deprecation warning was ever actually observed** (C2). [E6]
13. **The user's accessibility walkthrough details** beyond "performed, working" (C12). [E5, uncorroborated in-repo]
14. **Exact wordings of the acquisition-phase briefs** the reports quote against (e.g., the lowercase `"camera"` chamber value Phase 7 says it corrected; the `districtId: null` instruction): the reports' quotations are the only surviving record — the prompts themselves are G1-absent. [E3-quoted]
15. **CI**: no evidence any CI was ever configured (a plan-optional item); asserted only as an absence of evidence. [E6]

---

## 4. Questions — the short list that would settle the record

For the **user**:

1. Tagging: retro-tag `6d3b866` as annotated `v1.0.0` (message marked retrospective), or keep v1 as a documentation-only label? (C1)
2. Confirm: is the repo private, was `v2.0-prototype` pushed, and does a GitHub Release exist? If so, paste its URL into `CHANGELOG.md` or a release note. (U-6, G2)
3. Was a CLGeocoder deprecation warning ever actually seen? If yes, on which Xcode/SDK, and roughly what text? If unsure, the record stays as the audit wrote it. (C2)
4. Senato legend entry on the map: intentional forward-looking UI, or remove until Senato boundaries exist? (item 9 of the E6 list)
5. Deployment target: lower to 17.0 now, or is there a reason to hold at 26.5? (U-8)
6. Do the originals behind G1 (kickoff prompt, v1 phase prompts, project summary, completion summaries) survive in chat history or on disk? If yes, archiving them — even raw — upgrades a dozen [U] labels. Additionally: should the exact original commissioning brief itself be archived verbatim under `docs/history/`, so the [U]-labeled wordings become independently re-derivable? (G1, G7)
7. Should your accessibility walkthrough results be written into `a11y-checklist.md` so the repo stops saying "pending"? (C12)

For **Claude Code** (each ≤10 minutes, mechanical):

8. Run one `xcodebuild test` with full result logging and reconcile 92 static methods vs. 96–97 reported test cases; write the explanation into the checklist or CHANGELOG. (C4)
9. Fix or confirm the ISTAT `RetrievedAt` year in `tools/raw/SOURCES.txt`, and consider committing that file (or mirroring it into `docs/DATA_SOURCES.md`). (C5, G6)
10. One-line fix for the `make fetch && make all` double-fetch (drop `fetch` from `all`, or fix the README shorthand). (C11)
11. Backfill the two missing docs if desired: a short `docs/v2/05-representative-ui.md` retrospective for Phase 10, and either `docs/releases/v2.0-prototype.md` from the CHANGELOG entry or a written decision that CHANGELOG-only is the process. (G2, G3)
12. Correct the stale `Representative.districtId` doc comment (one line, Document A §10). 

None of these blocks V3 planning; items 1, 2, 5, and 8 are the ones a V3 conversation would most benefit from having answered first.

*End of Document C.*
