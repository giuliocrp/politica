# Round-2 Audit — Discrepancy Report on the Three History Documents
### Strict source-grounded re-verification of `POLITICA_IMPLEMENTATION_HISTORY_V1_V2.md` (Doc A), `POLITICA_V3_FACTUAL_BASELINE.md` (Doc B), `POLITICA_HISTORY_GAPS_AND_CONFLICTS.md` (Doc C)

**Method.** Every load-bearing number, identifier, quoted string, constant, command, and license claim in the three documents was re-grepped against the source base in this Project: `implementation-evidence-v1-v2.md` (EV, highest priority), the seven `docs/v2/*` phase reports, `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `DATA_SOURCES.md`, and the two plans. The archived transcript of the authoring session was consulted for brief-dependent claims. Roughly 120 anchors were checked; the confirmations are tabulated in §11 so the corrections in §1–§10 can be read against what *did* hold. No document was modified.

**Result in one line: 6 corrective findings (3 substantive, 3 precision), 2 editorial tightenings, 1 new gap to add to Doc C — none structural — verdict NOT READY until those specific edits land (§12).**

---

## 1. Claims unsupported by the supplied evidence

**F1 — Home's third stat: value and dynamism invented.** *(the one genuine fabrication found)*
- **Where:** Doc A §15 (UI table, Home row): "Stats now 147 / 601 / 2, all dynamic"; Doc B §2: "Home (stats 147/601/2, all dynamic; …)".
- **Evidence:** EV:226 records only that v1 Home has "a 3-stat row"; EV:479/1016 name the v2 "Collegi campione" stat card; `02-post-import-audit.md`:28 names "Home's '601 Rappresentanti' stat" and its dynamic source. **No source anywhere identifies the third stat, gives it the value "2", or states that all three are dynamic.** The "147" on the collegi card is itself an inference from the dynamic-count design (reasonable, but the fully specified trio is over-claimed).
- **Corrected wording (both docs):** "3-stat row retained from v1; the 'Collegi campione' and 'Rappresentanti' stats reflect the live 147 and 601 counts ('601 Rappresentanti' verified dynamic at Phase 6); the third stat's identity is not recorded in the available material."
- **Confidence:** High (finding certain; the "2" has no source).

**F3 — "+74 Senato uninominali" is outside knowledge, not source-grounded.**
- **Where:** Doc A §23 ("adding Senato layers roughly doubles overlays … 147+74"); Doc B §13 ("+74 Senato uninominali roughly doubles overlays").
- **Evidence:** the token "74" appears nowhere in EV, README, DATA_SOURCES, or any phase doc. It is real-world true (D.Lgs. 177/2020) but the commission required exact counts only when supported; injecting it silently mixes tiers.
- **Corrected wording:** "adding the Senato uninominale layer (its feature count is not recorded in the available material — the sibling ISTAT layer sits unexamined in the cache) would add a second overlay layer of comparable order; re-run the performance test and restate the byte-budget policy before any growth."
- **Confidence:** High.

**F4 — AppRoute ordinal positions asserted without a source.**
- **Where:** Doc A §7.3 ("AppRoute case #6"), §7.10 ("case #7"), §7.11 ("case #8").
- **Evidence:** EV:224/406-408 list which cases exist and in which phase each was *added*; no source states the enum's declaration order. The ordinals assume declaration order ≡ chronological addition — plausible, unverified.
- **Corrected wording:** drop the ordinals: "new `.fontiEDati` route", "new `.representativeList` route", "new `.collegiList` route" (the 8-case total, which *is* verified, stays).
- **Confidence:** High that it's unsupported; the underlying guess may well be true.

*(Also filed here for completeness: F7's "12 votes" shorthand, treated under §9, and F8's brief-provenance note, treated under §10.)*

## 2. Exact counts that need verification

- **Already-open, correctly disclosed, unchanged by this audit:** 92 static test methods vs 96–97 observed passing (EV:1050-1058 — both numbers re-confirmed as stated; the documents' handling is correct and stays); the ISTAT `RetrievedAt: 2025-07-18` vs manifest `2026-07-18` year clash (03-boundaries-audit:14-15 vs EV manifest table — Doc C C5 correct as written).
- **New (from F1):** the identity/value of Home's third stat — verifiable in one `git show v2.0-prototype:Politici/Views/HomeView.swift`.
- **New (from F6, below):** whether `parties.json` at `8b16be1` already carried the shared 19→12 `shortName` values — verifiable via `git show 8b16be1:Politici/Data/parties.json`.
- **Everything else re-verified exactly** (see §11): no other count in the three documents required correction.

## 3. Planned features accidentally described as shipped

**None found.** A directed sweep confirmed every planned-but-not-shipped item is correctly marked in the documents: mapshaper/Visvalingam (deviation §7.7/C6 ✓), the per-feature vertex gate (absence flagged, C7 ✓), `docs/releases/v2.0-prototype.md` (verified absence ✓), the Phase 10 report (verified absence ✓), the atto-combined title path ("exists but not exercised by shipped data" ✓ per 04-votes:167-173), linkage rung (c) ("documented no-op, never reached" ✓), the explicit-URI votes mode ("supported, validated, unused" ✓), Reduce Motion ("verified no-op" ✓ per checklist), the fresh-clone README walkthrough and P8 external spot-check (E6-as-to-performance ✓).

## 4. Shipped features accidentally omitted

**Nothing material to V3 was omitted.** Two precision gaps *within* covered features:

**F5 — Hit-target fix mechanism over-generalized.**
- **Where:** Doc A §7.11(5) and §16: all five sub-44 pt controls "brought to ≥44 pt via `.frame(minHeight: 44).contentShape(Rectangle())`".
- **Evidence:** `a11y-checklist.md`:159-163 — four rows use exactly that treatment; the Home footer "Informazioni e fonti" link (~24 pt) row says **"added bottom padding to reach 44pt"** instead.
- **Corrected wording:** "four of the five via `.frame(minHeight: 44).contentShape(Rectangle())`; Home's footer link via added bottom padding."
- **Confidence:** High.

**F6 — `parties.json`'s `shortName` field under-described at Phase 6.**
- **Where:** Doc A §7.6 describes the 19 entries and contrast rule but omits the schema (`value`, `shortName`, `colorHex`); Doc C C10 frames the whole shortName question as open.
- **Evidence:** the addendum's Phase 6 spec (line 124) already lists `shortName` as a `parties.json` field, and the tag-state schema is `{value, shortName, colorHex}` (EV:428-429). So the **field** dates to P6 by plan; only whether the 19→12 **shared values** date to P6 or to P10's "polishes colors/shortNames" step (addendum:435) is undetermined.
- **Corrected wording:** §7.6 add "(fields `value`, `shortName`, `colorHex` per the addendum's spec)"; C10 narrow its open question to the *values*, and add the one-command resolution (`git show 8b16be1:Politici/Data/parties.json`).
- **Confidence:** High for the refinement; the narrowed question remains genuinely open.

## 5. Conflicts between git evidence, committed docs, and Claude Code reports

All twelve conflicts catalogued in Doc C were independently re-derived and **stand as written**: C1 no-v1-tag (EV §2-3 verbatim ✓), C2 CLGeocoder (00-audit:69 explicitly explains 26.5 as a template default and lists the app's ≤iOS-17 APIs — the audit-wins resolution is correct ✓), C3 `Python-urllib` vs "requests" (EV:762-763 ✓), C4 test counts (EV:1050-1058 ✓), C5 the 2025/2026 date (03-boundaries:14-15 ✓), C6 ogr2ogr Douglas-Peucker 1000 m (EV:781 ✓), C7 vertex gate absent ✓, C8 UA evolution ✓, C9 explainer location (master plan:795 proposes DistrictDetailView ✓; shipped on Home ✓), C10 (refined per F6), C11 `all` includes `fetch` (README:119/125 verbatim ✓), C12 a11y user-report vs pending checklist ✓. **No new inter-source conflict surfaced.**

## 6. Incorrect version naming

**None.** The V0/V1 alias direction matches the evidence report's own task-instructed map (EV §2: "v1.0.0 (alias: 'V0')", "v2.0-prototype (alias: 'V1')"); canonical names, the no-tag caveat, `6d3b866`/`72448dc`/`a7593ad…`, the Politici/Politica split, "Politica Italia" (README:1), and all 17 commit subjects/dates were re-verified verbatim against EV's chronological table.

## 7. Incorrect Makefile or data-refresh commands

**None.** `make fetch && make all` is the README's own shorthand (README:125, repeated :236); `all = fetch + import + validate + manifest + boundaries` verbatim (README:119); the `fetch` target comment quoted in Doc A §9.1 is verbatim (EV:682 "…network access. Writes only under tools/raw/."); "boundaries does not download the shapefile" ✓ (README:116/177-179); import fails loudly on a missing cache ✓ (EV:858); `validate` constants incl. `MAX_DISTRICTS_FILE_BYTES = 3MB` / `MAX_VOTES_FILE_BYTES = 2MB` ✓ (EV:718-724); `import_boundaries.py`'s own `MAX_OUTPUT_BYTES = 3MB` ✓ (EV:787); the DATA_SOURCES manual-re-sync warning ✓ (DATA_SOURCES:212); `DEVELOPER_DIR`-prefixed commands appear in README (:178/183/186) and CLAUDE.md (:47) exactly as claimed.

## 8. Licensing statements that exceed the evidence

**None.** The §18 manifest table matches EV's byte-compared table and DATA_SOURCES 1:1 (ids, names, licenses, dates; sample entry url "empty" ✓) — with **one precision defect**:

**F2 — ISTAT URL given as a placeholder where the exact value exists.**
- **Where:** Doc A §18, ISTAT row, url column: "ISTAT dataset page".
- **Evidence:** the manifest value is `https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2` (EV manifest table; DATA_SOURCES:118).
- **Corrected wording:** substitute the exact URL. (Doc B's §4 table doesn't repeat URLs — no change there.)
- **Confidence:** High.

The in-app disclaimer, both avvertenze, and the "app code license: unspecified unless a `LICENSE` file says otherwise" phrasing were all verified verbatim (EV:1205-1211; master plan:74/419/422; README:278-282). The "not legal advice" framing is intact in both A and the audit trail.

## 9. Ambiguity between vote events and per-deputy vote-position records

The distinction is defined correctly and prominently (Doc A §14 "Event vs. position, explicitly"; §21; Appendix C; Doc B §4, backed by EV:637-638's "12 unique parliamentary vote events (distinct sourceUrl)"). **Two residual shorthand spots (F7):**
- Doc A §4, timeline row 14: "**12 votes / 4,788 positions / 1,834 KB**" → "**12 vote events / 4,788 per-deputy positions / 1,834 KB**".
- Doc A Appendix A, P9 line: "12 real votes / 4,788 positions" → "12 real vote events / 4,788 positions".
- **Confidence:** High (editorial; low risk given the explicit definitions elsewhere, but the commission asked for *any* ambiguity).

## 10. Statements that could mislead a future V3 architect

- **F1** (an invented UI fact a V3 designer might build on), **F3** (an unsourced 74 that could seed a sizing estimate), **F4** (false precision inviting order-dependent code assumptions) — all covered above.
- **F8 — New gap for Doc C (add as G7): the commissioning brief itself is not archived.** The transcript preserves a single Human turn whose text is empty and whose attachment content is not inlined; every [U]-labeled wording in Doc A §20 and Doc C therefore rests on the authoring session's in-context reading, no longer independently re-derivable — except the naming/alias instruction, which the evidence report's §2 independently records. Corrected action: add G7 "archive the brief verbatim alongside the pack", and extend Q6 accordingly. **Confidence:** High.
- Reassuringly re-verified as *not* misleading: "no API newer than iOS 17 (`Map`/`MapPolygon`/`MapReader`, `NavigationStack`, `ContentUnavailableView`)" (EV:292-293 + 00-audit:69 — supported, contrary to this auditor's initial suspicion); "distinct `parliamentaryGroup` values 19" (EV:635); the ~0.07 s figure (README:84) and its <1 s test backing (EV:1072); the `iPhone 17 Pro`/no-`iPhone 15` simulator note (EV:1088-1089); the dead purple Senato legend (EV:1332); Doc B's ≈3.3 MB bundle figure (pure arithmetic on the three verified byte counts — acceptable as computed).

## 11. Re-verified anchors (confirmation record — no action needed)

| Anchor | Source hit |
|---|---|
| 17 commits, hashes/dates/subjects, linear, ff-merge, four refs at `72448dc`, tag object `a7593ad…` | EV §3 table + :80-128 |
| v1: 5/14/37; 3 C + 2 S districts; 9 C + 5 S reps; 7 parties (3+2+2+2+2+2+1); 32 files; 108-line README; `Item.swift` at `3ab4e58`, gone at `6d3b866` | EV:187/226/245-246/277 |
| v2 data: 147 (56 MP/91 P); 601 = 400 + 201 (196 + 5 a vita, Napolitano excluded); 19 party / 19 group / 12 shortName; 4,788 / 12 events (distinct sourceUrl); 2,938/980/836/34; Respinto ×4,788; 100% official; 5 manifest entries + exact ids/licenses/dates | EV:583/630-645; 02-post-import:89/113/117/127 |
| Bytes: 1,158,457 / 439,399 / 1,878,366; 1131 KB at P8; 1834 KB console output; 2.20 MB refused at 6000 → 5000; 13 excluded starting `vs19_690_054`; `vd19_690_076_50204`; `RifVotazione=690_76`; Foti/Bergamini; Fontana `p307591`; 399 coinvolti | EV:645/785; 03-linkage:69; 04-votes:153-238 |
| SPARQL: 55 literals / 1173 bindings; 414 − 14 = 400; 208 → 201; 145 + 2 + 245 + 8; 133 gate; 28 circoscrizioni; "up to 11" uninominali; Valle d'Aosta split; Centenaro 50202 / Di Rubba 50201 | 03-linkage:87-163; EV:704/919-926 |
| Votes ontology: `vs19_047_005`; 273–399/vote; 98 / 37,959 secret; 286/5/108; sitting 2026-07-15; bill 2822-A; "Votazione Ordine del giorno 9/2822-A E ABB/21" | 04-votes:15/58/85/103/167-173/228-229 |
| Pipeline: UA string + `Python-urllib` note; `TIMEOUT_SECONDS=60`/`MAX_ATTEMPTS=3`/`INITIAL_BACKOFF_SECONDS=2`; 4xx-no-retry; pre-write byte check; `MIN_LINKED_COLLEGI`; `__pycache__`/`*.pyc`; `load_fetch_metadata`; fetch-target comment verbatim | EV:682/704/715/729-767/787/924 |
| Tests: 52/52 at P6 entry; 92 = 91 + 1; 95 both targets; 96–97 observed; per-file method counts; weaken→vacuous→genuine test names; <1 s perf | 02-post-import:37; EV:589/1050-1072 |
| A11y: 1 pre-phase label; 9 screens; five controls (~31 pt chip, ~24 pt footer link) with per-row fixes; `-UIPreferredContentSizeCategoryName` M/XXXL via `xcrun simctl launch`; symbol/label table incl. slash.circle/questionmark; "Apre il profilo…"; "Filtra per…"; five pending checks | a11y-checklist:55-230; EV:1142-1178 |
| Strings: both empty states (addendum:129-131; EV:990); pre-P6 different strings (02-post-import:52); disclaimer + 2 avvertenze verbatim in-app (EV:1205-1211); "Confini dimostrativi…" + `REMOVE-IN-BOUNDARIES-PHASE` (addendum:136-138/234-235) |
| Misc: `SWIFT_VERSION 5.0`; 26.5 since first commit + template-default explanation; `ContentUnavailableView` in the ≤iOS-17 list; `.claude/settings.local.json` untracked; stale `districtId` comment; sources.json 1→3 at P5; "Keep a Changelog"; explainer planned on DistrictDetailView; V0/V1 alias map | EV:287-352 + §2; 00-audit:55-96; 01-real-data-import:61; CHANGELOG:5; master plan:795 |

---

## 12. Final verdict

**NOT READY** — until the following exact corrections are applied. All are surgical; nothing structural, and nothing in the git/data/architecture core changes.

1. **Doc A §15 + Doc B §2 (F1):** replace "stats 147/601/2, all dynamic" with the corrected wording in §1 (drop the invented third value; scope "dynamic" to what's evidenced).
2. **Doc A §18 (F2):** replace "ISTAT dataset page" with `https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2`.
3. **Doc A §23 + Doc B §13 (F3):** remove "74"/"147+74"/"roughly doubles"; use the count-not-recorded wording in §1.
4. **Doc A §7.3 / §7.10 / §7.11 (F4):** delete the three "(AppRoute case #N)" ordinals.
5. **Doc A §7.11(5) + §16 (F5):** four-via-frame+contentShape, footer-link-via-padding.
6. **Doc A §7.6 + Doc C C10 (F6):** add the `{value, shortName, colorHex}` schema note at P6; narrow C10 to the shared-values question and add the `git show 8b16be1:…/parties.json` resolution.
7. **Doc A §4 row 14 + Appendix A P9 line (F7):** "12 vote events / 4,788 per-deputy positions".
8. **Doc C (F8):** add gap G7 (brief not archived; [U] wordings not independently re-derivable) and extend Q6 to include archiving the brief itself.

After edits 1–8, the pack is **READY FOR V3 ARCHITECTURE**: every remaining claim traces to the evidence hierarchy or carries the correct E1–E6/[U] label, the disclosed open questions (92 vs 96–97; the 2025/2026 ISTAT date; C1/C2/C12) are accurately characterized, and no statement was found that would misdirect a V3 design.

*End of round-2 audit.*
