# Historical Documentation Pack — Commissioning Brief

## Status
User-authored external planning artifact.

This file preserves the exact prompt used to commission the historical
documentation pack for Politica v1.0.0 and v2.0-prototype.

It is not source code, git evidence, or a record of shipped behavior.
It is retained only to preserve the provenance of claims labelled `[U]`
(user-reported) in the historical dossier.

## Source
Copied verbatim from the project planning conversation.

## Exact commissioning brief
You are a principal iOS architect, civic-data systems architect, software
historian, technical writer, and engineering decision-record author.

MISSION:
Produce the definitive, source-grounded implementation history of the two
completed Politica releases.

This is NOT yet a V3 architecture task.

The resulting documents will become the factual input to a separate Fable 5
conversation that will architect V3. Therefore, accuracy, traceability,
architectural detail, and a clear separation between plans and actual shipped
implementation are more important than brevity.

CANONICAL RELEASE NAMES:
1. v1.0.0 — original fictional/sample-data prototype
2. v2.0-prototype — real-data and accessibility prototype

If product-generation aliases are useful, use:
- Generation V0 = repository release v1.0.0
- Generation V1 = repository release v2.0-prototype

However, every major heading and comparison must retain the canonical Git tag
so there is no ambiguity when V3 is planned later.

PROJECT IDENTITY:
- User-facing app display name: Politica
- In-app identity may include Politica / Politica Italia
- Xcode project, target, and scheme: Politici
- The naming difference is intentional.
- Never imply that the Xcode project was renamed.
- Private GitHub repository
- Native iOS application using Swift, SwiftUI, MapKit, Codable, bundled
  JSON/GeoJSON, and developer-side Python/geospatial tooling

AVAILABLE PROJECT CONTEXT:
Use all relevant files available in this Claude Project, especially:

- implementation-evidence-v1-v2.md
- README.md
- CHANGELOG.md
- CLAUDE.md
- DATA_SOURCES.md
- docs/v2/00-audit.md
- docs/v2/01-real-data-import.md
- docs/v2/02-post-import-audit.md
- docs/v2/03-linkage-report.md
- docs/v2/04-votes-import.md
- docs/v2/a11y-checklist.md
- Politica — Project Summary
- Initial Kickoff Prompt
- Original Phase 1–4 prompts
- Politica v2 master implementation plan
- Politica v2 plan addendum
- Any Claude Code phase-completion summaries included in the Project

SOURCE-OF-TRUTH PRIORITY:
When sources conflict, use this order:

1. Source-grounded repository evidence from
   implementation-evidence-v1-v2.md
2. Source code/data/tests at the relevant Git tag, if included in evidence
3. Git commit/tag history
4. Current committed README, CHANGELOG, CLAUDE.md, DATA_SOURCES.md, and
   docs/v2/
5. Claude Code completion reports
6. Original phase prompts and master plans

A prompt or plan proves only intent. It does not prove implementation.

CONFLICT RULE:
If two sources disagree:
- do not silently choose one
- state the conflict
- identify the higher-priority evidence
- document the final conclusion and confidence level

Do not invent missing facts. Use:
“Non verificabile dal materiale disponibile”
when necessary, and state what evidence would resolve it.

KNOWN HISTORICAL FRAMEWORK TO VALIDATE:

ORIGINAL v1.0.0 RELEASE:
- Began as a local-first SwiftUI/MapKit prototype.
- Used bundled fictional/sample JSON and simplified GeoJSON.
- Included approximately 5 districts, 14 fictional representatives, and
  37 fictional vote-position records.
- Implemented models, local data services, point-in-polygon matching,
  geocoding with an Apple-framework path plus a five-city fallback, typed
  NavigationStack routing, interactive map, district detail, representative
  profile, and vote history.
- Used Italian user-facing copy.
- Removed or avoided unnecessary SwiftData/CoreData persistence.
- Configured a Canva-generated app icon.
- Kept the Xcode project name Politici while changing the user-facing display
  name to Politica.
- Was build-verified and manually exercised in an iPhone simulator.
- Had little or no meaningful automated test coverage at release.
- All political content and geography remained fictional/sample.

V2.0-PROTOTYPE:
- Added repo audit and CLAUDE.md guardrails.
- Bootstrapped meaningful XCTest coverage.
- Introduced schema-v2 provenance and tolerant decoding.
- Added manifest-driven “Informazioni e fonti”.
- Added MapKit address autocomplete behind a protocol seam.
- Replaced fictional representatives with official Camera/Senato data.
- Pivoted from the original manually downloaded raw-adapter concept to a
  developer-side SPARQL fetch → gitignored cache → offline import pipeline.
- Preserved app-runtime local-first behavior.
- Added real ISTAT Camera uninominale geometry.
- Added MultiPolygon/hole support and bounding-box-prefiltered spatial tests.
- Linked all 147 Camera uninominale colleges to current deputies.
- Imported a bundle-budgeted subset of official Camera roll-call positions.
- Added complete representative browsing, party filtering, initials avatars,
  electoral-system explanation, and accessibility support.
- Finished with 96 passing tests, subject to verification from the evidence.

IMPORTANT IMPLEMENTATION FEEDBACK AND CORRECTION LOOPS TO INCLUDE:

1. Early model/data verification initially failed because the standalone
   compile check did not include DistrictFeatureCollection; rerunning with all
   model files succeeded and verified 5/14/37 records.

2. Initial simulator runs showed CoreData/SQLite logging and a white screen.
   The logs were associated with template/simulator behavior, while the white
   screen reflected that early phases had not yet implemented the complete UI.
   The final architecture did not use CoreData or SwiftData.

3. Claude Code initially could not use xcodebuild because xcode-select pointed
   to CommandLineTools. It discovered Xcode.app and used a command-scoped
   DEVELOPER_DIR rather than changing global machine configuration.

4. iOS 26 reported CLGeocoder deprecation warnings. Later architecture kept
   geocoding behind GeocodingProviding and introduced MapKit autocomplete,
   preserving a migration seam.

5. Camera’s historical RDF people export was too broad and relationally
   awkward for the prototype. Verified Camera and Senato SPARQL endpoints
   became the practical developer-side source.

6. The Senato HTTP endpoint redirected to HTTPS, and Python requests required
   a descriptive/browser-like User-Agent to avoid HTTP 403.

7. Real representatives forced districtId to become optional because linkage
   had not yet landed. Null was chosen over invented geography.

8. Shipping fictional votes became orphaned after real representatives
   replaced REP-style IDs. The temporary weakened cross-reference assertion
   was later reversed: fictional votes moved to votes.sample.json, shipping
   votes became an honest empty collection, and full referential integrity was
   reinstated before real votes landed.

9. Real party values initially exposed naming differences between Camera
   siglas and Senato full group names. Data-derived party styling and
   short-name grouping resolved this without logos.

10. The ISTAT source shapefile contained 147 features in EPSG:32632. It was
    reprojected to EPSG:4326, simplified, and emitted as approximately 1.1 MB
    of bundled GeoJSON.

11. MKGeoJSONDecoder returned a MultiPolygon as one MKMultiPolygon rather than
    flattened MKPolygon entries. The first implementation silently omitted
    56 of 147 multi-part districts until standalone probes exposed and fixed
    the issue.

12. CU20_C1 was initially labeled as region but was actually a U01-style
    sub-college suffix. The pipeline was corrected to emit subCode and a
    truthful circoscrizione parsed from verified CU20_DEN structure.

13. Camera’s original ?collegio field represented plurinominale rather than
    the desired uninominale granularity. Ontology introspection found
    typeElezione plus dcterms:spatial, enabling a structural join to the ISTAT
    circoscrizione/subCode key.

14. Linkage reached 147/147 with zero ambiguity, two documented by-election
    holders, and zero vacancies. A 90% minimum quality gate remains enforced.

15. Vote exploration found that generic procedural text did not contain the
    true act title. Titles came from associated atto labels and required
    mechanical cleanup of source artifacts.

16. Secret-ballot records were excluded because their per-deputy records
    disclose only that a deputy voted, not the position. This was treated as
    a secrecy constraint, not missing data to guess.

17. The nominal 25-vote scope exceeded the approximately 2 MB bundle budget.
    The importer stopped on complete vote boundaries and shipped 12 vote
    events containing 4,788 positions at approximately 1.79 MB.

18. Manual data verification reportedly matched two deputies’ positions on an
    official Camera record. Lorenzo Fontana correctly had no imported
    positions, exercising the honest empty state.

19. Phase 10 discovered that party styling was already complete, contrary to
    the prompt’s premise, while the true missing product feature was a way to
    browse all 601 representatives. RepresentativeListView was added instead
    of duplicating existing styling.

20. Party chips use deduplicated short names so Camera siglas and Senato full
    spellings can map to one user-facing filter.

21. The map’s SpatialTapGesture polygons had no discoverable VoiceOver path.
    CollegiListView was therefore architecturally necessary, not merely an
    accessibility convenience.

22. Vote rows deliberately keep the nested “Fonte” Link separate from the
    combined VoiceOver element so the link remains independently reachable.

23. Dynamic Type review found little explicit truncation; custom hit-target
    and accessibility improvements were still added and manually verified by
    the user.

24. The final documentation prompt requested a separate release-note file, but
    the actual repository may contain only CHANGELOG.md and not
    docs/releases/v2.0-prototype.md. The GitHub release description was then
    assembled manually. Verify and document this rather than claiming the
    missing file exists.

25. The final accessibility checks—VoiceOver, Dynamic Type, representative
    flow, college-list flow, and Fonti e dati—were manually completed by the
    user and reported as working.

26. Both releases and the v2 branch/tag were pushed to the private GitHub
    repository; v2 was merged into main and published as a private GitHub
    Release. Treat this as user-reported unless repository evidence confirms
    it.

Do not accept any item above blindly. Validate it against the evidence
hierarchy and label its confidence.

PRIMARY OUTPUT:
Produce a large Markdown dossier titled:

# Politica Engineering and Product History
## From v1.0.0 Sample Prototype to v2.0-prototype Real-Data Release

The dossier must explain WHAT was implemented, HOW it works, WHY key choices
were made, HOW problems were diagnosed, and HOW each major claim was verified.

REQUIRED STRUCTURE:

# 1. Executive Summary
- Product purpose
- Two-release evolution
- Current maturity
- What “local-first” means in this project

# 2. Canonical Naming and Version Map
- Politica vs Politici
- Git tags
- Optional V0/V1 aliases
- Why canonical tag names should remain authoritative

# 3. Methodology and Evidence
- Source hierarchy
- Confidence labels
- Limits of reconstruction
- Plan versus implementation distinction

# 4. Chronological Timeline
For every significant commit/phase:
- date
- commit/tag
- pre-phase state
- intended outcome
- actual implementation
- verification
- deviations
- consequence for the next phase

# 5. Release v1.0.0 — Original Prototype
Cover in detail:
- product scope
- architecture
- project structure
- models
- sample data
- services
- point-in-polygon
- geocoding
- SwiftUI navigation
- every screen
- MapKit interaction
- Italian UX
- icon/display name
- documentation
- build/simulator verification
- missing tests
- limitations
- what v1 proved

# 6. Transition from v1 to v2
- Why real data changed the engineering problem
- Guardrails introduced
- Honesty/provenance requirements
- Why direct runtime APIs were rejected
- Why SwiftData/backend/push stayed out
- Testing-first strategy

# 7. Release v2.0-prototype — Phase-by-Phase History
Create one substantial subsection per phase:
- Phase 0: audit and CLAUDE.md
- Phase 1: test bootstrap
- Phase 2: schema/provenance/manifest
- Phase 3: attribution
- Phase 4: geocoding modernization
- Phase 5: real representatives and SPARQL pipeline
- Phase 6: integrity reconciliation, empty states, party styling, pipeline hygiene
- Phase 7: ISTAT boundaries and MultiPolygon engine
- Phase 8: representative-to-collegio linkage
- Phase 9: curated official votes
- Phase 10: full representative UI and explainer
- Phase 11: accessibility
- Final documentation, merge, tag, and release

For each phase use this exact template:
- Starting state/problem
- Original plan
- Evidence discovered during implementation
- Actual implementation
- Important files/types/scripts
- Data/schema impact
- Testing and verification
- Manual QA
- Deviations from plan
- Remaining limitation
- Commit/tag evidence
- Lesson for future architecture

# 8. Final v2 Runtime Architecture
Explain:
- App entry point
- ServiceContainer and dependency injection
- model/service/view boundaries
- typed navigation routes
- local bundle loading
- runtime network boundary
- error/empty-state strategy

Include a text or Mermaid architecture diagram plus a plain-text equivalent.

# 9. Developer-Side Data Architecture
Explain:
- SPARQL fetch
- raw cache
- offline import
- validation
- manifest generation
- boundary generation
- deterministic outputs
- fail-loud behavior
- Makefile workflow
- gitignore policy

Include a data-flow diagram.

# 10. Data Model Evolution
Provide v1→v2 tables for:
- District
- Representative
- Vote
- provenance
- election type
- source IDs
- optionality
- tolerant enum decoding
- source manifest
- sample fixture conventions

# 11. Geospatial Architecture
Explain deeply:
- v1 rectangles and ray casting
- ISTAT shapefile
- CRS conversion
- simplification
- schema correction
- MKGeoJSONDecoder
- Polygon/MultiPolygon/hole handling
- bbox prefilter
- point-in-polygon
- address resolution
- map rendering
- performance and tests

# 12. Parliamentary Data Import
Cover Camera and Senato separately:
- endpoints
- query shapes
- current-mandate semantics
- group/committee aggregation
- IDs
- exclusions
- null handling
- photo policy
- count semantics
- offline runtime result

# 13. Collegio Linkage
Explain:
- why the first field was wrong
- ontology exploration
- actual predicates
- key normalization
- exact/structural matching
- bilingual edge case
- quality gate
- 147/147 result
- by-elections/vacancies
- integrity tests

# 14. Votes Import
Explain:
- scope
- ontology exploration
- title derivation
- secret ballots
- position vocabulary
- event versus position distinction
- budget controls
- source links
- integrity
- manually verified examples
- honest empty states

# 15. UI and Navigation Evolution
Compare v1 and v2:
- Home
- map
- address search
- district detail
- representative profile
- vote history
- complete representative list
- party chips
- initials avatars
- election explainer
- attribution
- college list

# 16. Accessibility Evolution
Explain:
- original map limitation
- accessible list alternative
- VoiceOver element grouping
- nested-link decision
- vote symbols/non-color cues
- hit targets
- Dynamic Type
- manual user QA
- remaining accessibility limitations

# 17. Testing and Verification History
Include:
- standalone swiftc checks
- Xcode build evolution
- xcode-select/DEVELOPER_DIR issue
- simulator verification
- test-target bootstrap
- exact test categories
- test-count evolution where documented
- restored referential integrity
- manual versus automated coverage
- current final verification

# 18. Attribution, Licensing, and Product Honesty
Use exact manifest evidence:
- Camera
- Senato
- ISTAT
- sample fixtures
- licenses
- retrieval dates
- disclaimer
- staleness
- provenance labels
- no photos
- hidden attendance
- no emblems
- not legal advice

# 19. Decision Register
Create a table:
- decision
- alternatives
- evidence
- chosen approach
- consequences
- revisit conditions for V3

Include at minimum:
- bundled data vs runtime APIs
- SPARQL fetch/cache
- no SwiftData
- no backend
- optional districtId
- real geography before linkage
- Camera uninominale scope
- curated vote subset
- no portraits
- initials avatars
- map-list accessibility alternative
- private release/version strategy

# 20. Failure, Diagnosis, and Correction Log
For every important loop:
- symptom
- incorrect initial assumption
- diagnostic evidence
- root cause
- fix
- regression prevention
- V3 lesson

This section must include the 26 feedback items listed above where verified.

# 21. Release Comparison
Produce a concise matrix comparing v1.0.0 and v2.0-prototype:
- data
- map
- people
- votes
- geocoding
- UI
- tests
- accessibility
- legal/provenance
- pipeline
- limitations

# 22. Current Technical Debt and Known Limitations
Separate:
- intentional product scope
- technical debt
- data-source limitations
- operational limitations
- legal/content-policy considerations
- items that should become V3 candidates

# 23. V3 Factual Handoff
Do NOT architect V3 yet.

Provide:
- exact current baseline
- invariants V3 must preserve
- reusable extension seams
- fragile areas
- unresolved factual questions
- decisions that require user/product input
- data-source questions
- performance questions
- release/process lessons

# 24. Appendices
- Commit/tag map
- Current file/module map
- Data counts
- Makefile command reference
- Test categories
- Source manifest table
- Glossary of Italian parliamentary and geospatial terms
- Confidence/verification table

STYLE REQUIREMENTS:
- Professional technical-history style.
- Detailed but not repetitive.
- Avoid celebratory marketing language.
- Distinguish factual implementation from interpretation.
- Preserve Italian names for app screens and parliamentary terms.
- Explain technical terms in English where useful.
- Do not expose private local filesystem paths.
- Do not copy large source files or raw JSON.
- Do not invent legal conclusions.
- Use exact counts only when supported.
- Use tables where comparison is clearer.
- Use diagrams where architecture is clearer.
- Include enough technical detail that a different senior engineer could
  architect V3 without reopening the entire chat history.

OUTPUT PACK:
Produce three separate Markdown documents in your response:

DOCUMENT A:
POLITICA_IMPLEMENTATION_HISTORY_V1_V2.md
- The complete dossier described above.

DOCUMENT B:
POLITICA_V3_FACTUAL_BASELINE.md
- A compact but precise extraction of the current architecture, data,
  invariants, extension seams, limitations, and open questions.
- No V3 feature plan yet.
- Designed to be pasted into a new Fable V3 architecture conversation.

DOCUMENT C:
POLITICA_HISTORY_GAPS_AND_CONFLICTS.md
- Every unresolved contradiction, missing artifact, confidence concern, or
  fact that requires human confirmation.
- Include a short list of questions for the user or Claude Code.

LENGTH HANDLING:
Do not reduce technical detail just to fit one response.

If output limits are reached:
1. Finish the current heading cleanly.
2. End with:
   “CONTINUE FROM: <next exact heading>”
3. Wait for me to say “continue”.
4. Do not restart or summarize previous sections.
