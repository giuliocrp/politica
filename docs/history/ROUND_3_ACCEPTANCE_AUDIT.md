# Round-3 Acceptance Audit — Final

**Re-verification record.** A full diff of the corrected upload against the Round-3 copy shows exactly two changed lines and nothing else (line count unchanged at 1,202). (1) "on the five" — zero occurrences remain. (2) §20 item 23 (line 1000) now reads "`.frame(minHeight: 44).contentShape(Rectangle())` on four of the five controls; Home's footer link via added bottom padding" — matching §7.11(5), §16, and the checklist evidence; the mechanism split is now consistent in all three locations. (3) The only other edit is the advisory R3-2 clarification at §7.5 (line 389): "(no hardcoded numbers)" was replaced with "the data-derived Home stat counts update automatically; the separate 'Camere del Parlamento' card is a static hardcoded \"2\" as documented in §15" — the first half remains the [E2] phase-doc consequence, correctly narrowed to the data-derived counts; the second half is the fact-check's [E1] tag-state finding, anchored by explicit cross-reference to §15 rather than asserted as a Phase-5-ref observation. No new unsupported claim, no structural change.

## Findings
None remaining.

## Verdict
READY FOR V3 ARCHITECTURE

**Explicitly disclosed unresolved questions acceptable to carry into V3 planning** (all honestly documented in Document C, restated in Documents A §23 / B §11):

1. **92 vs 96–97 test count** (C4/C13): 92 statically countable methods [E1] vs 96–97 observed passing [E4]; unreconciled by definition-of-counting; resolvable with one instrumented `xcodebuild test` run read line-by-line.
2. **ISTAT retrieval-year clash** (C5, G6): `RetrievedAt: 2025-07-18` in `tools/raw/SOURCES.txt` as quoted vs `2026-07-18` in the shipped manifest and `DATA_SOURCES.md`; neither value machine-attested; one-edit fix once the correct year is confirmed.
3. **No `v1.0.0` tag** (C1, Q1): "v1.0.0" is a documentation-only label on `6d3b866`; retro-tag or codify label-only status.
4. **Repository visibility, tag push, GitHub Release existence/URL** (U-6, Q2): pushed, synchronized branches corroborated locally [E1]; visibility/Release remain [E6]/[U].
5. **CLGeocoder deprecation-warning history** (C2, Q3): audit found no deprecation in the targeted SDK; the brief's warning claim stands downgraded to unverified; architecture unaffected either way.
6. **Senato map-legend entry** (Q4; E6-9): dead content at the tag; intentional forward-looking UI vs removal undecided, prior awareness unverifiable.
7. **Deployment target 26.5 rationale** (U-8, Q5): flagged in the first audit, untouched for twelve phases, reason undocumented; lower-to-17.0 decision pending.
8. **G1 originals and brief archiving** (G1, G7, Q6): the v1 kickoff prompt, v1 phase prompts, project summary, and raw completion summaries remain absent (a dozen [U] items upgradeable if they survive); the commissioning brief is now preserved in the pack as `HISTORY_PACK_COMMISSIONING_BRIEF.md`, with in-repo archiving under `docs/history/` still the open Q6 decision.
9. **Senato data unknowns**: the ISTAT Senato uninominale sibling layer's fields/CRS sit unexamined in the cache and its feature count is not recorded in the available material — any layer growth must re-run the performance test and restate the byte-budget policy first; Senato SPARQL election/college predicates never explored.
10. **Votes-ontology forward questions**: whether older votazioni carry attos (the combined-title path is unexercised by shipped data); ontology stability; whether XIX remains the current legislature at V3 build time; license pages due re-verification.
11. **C3 [U] specifics**: the HTTP→HTTPS redirect and literal "403" of the Senato UA episode remain brief-only; the substantive fact (default `Python-urllib` UA rejected, descriptive UA required) is [E1/E2] and settled.
12. **Accessibility completion record** (C12, Q7): the five pending checklist items are user-reported complete and working [E5] while the repository still records them as pending; writing results into `a11y-checklist.md` closes the gap.
13. **Disclosed plan-vs-shipped deviations and minor debt, carried as recorded**: mapshaper/Visvalingam → ogr2ogr/Douglas-Peucker with no committed rationale (C6); per-feature vertex gate planned, never evidenced (C7); explainer shipped on Home vs the plan's DistrictDetailView (C9); `make all` already includes `fetch` (C11); missing `docs/releases/v2.0-prototype.md` (G2) and Phase-10 report (G3); unpreserved diagnostic probes (G4); unrecoverable v1 intra-phase history (G5); the stale `Representative.districtId` doc comment (Q12); Phase 8's external spot-check and the fresh-clone README walkthrough unattested (E6-10/11); no CI evidenced (U-15).

None of these blocks V3 planning; every one is accurately characterized, correctly labeled ([E1]–[E6]/[U]), and traceable to Document C. The pack's remaining claims all trace to the evidence hierarchy, and the C10 shortName question stands resolved [E1] via the archived fact-check.

*End of round-3 final audit.*
