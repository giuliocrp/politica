# Phase 30 — Offline Geocoding: Comuni Centroids [GO-COMUNI, USER-GATED acquisition]

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 23.
> **Network/acquisition: USER-GATED** — the ISTAT comuni dataset is
> acquired like the collegi shapefiles were (manual download into
> `tools/raw/`, approved and documented), or via an approved fetch if the
> product turns out to be directly fetchable (Q5).
> **Report:** `docs/v4/30-comuni-geocoding.md`.
> **Commit:** `feat(v4): phase 30 — offline comuni-centroid geocoding (gated)`

> **User guidance (from the Phase 29 handoff, 2026-07-23) — binds this phase:**
> - **Gate size against measured reality, not this file's estimate.** `Data/`
>   (real-only, excl. `*.sample.*`) is **~5.50 MiB** as of Phase 29 (Phase 27's
>   5.40 + Phase 28's memberships) against the ~10 MiB soft ceiling — the
>   `comuni.json` estimate here (~400–600 KB) and the ceiling headroom must both
>   be re-measured against that current figure at execution time, because this
>   spec predates Phases 25/27/28.
> - **Q5 licensing is the live constraint, and an unverifiable licence is a
>   NO-GO, not a footnote.** "Never fabricate licensing information" (CLAUDE.md
>   #4) means: if the actual ISTAT product page does not carry a verifiable,
>   CC-BY-compatible licence quotable verbatim, the GO-COMUNI gate fails —
>   document it and stop, do not proceed on an assumed or reconstructed licence.
> - **Acquisition is user-gated and manual (not a SPARQL fetch).** Before it
>   begins, the session must state **exactly which file it needs and from which
>   official URL/page**, and get approval quoted verbatim — the same shape as
>   the collegi-shapefile acquisition, no downloading first and reconciling
>   later.

## Objectives & deliverables

Replace the 5-city fallback ceiling: a bundled table of all Italian
comuni (~7,900) with centroid coordinates, so any comune name resolves
offline to a coordinate → collegio via the existing point-in-polygon
path. Deliverables: acquisition record + provenance entries
(`sources.json` manifest, `docs/DATA_SOURCES.md`, `tools/SOURCES.md`,
license quoted from the actual ISTAT product page), a `comuni.json`
generated artifact with its own measured byte gate, a new
`GeocodingService` tier (CLGeocoder → comuni table → existing 5-city
table retained as final tier unless the phase documents removing it),
and the report.

## Technical requirements

- Acquisition mirrors the collegi-shapefile pattern
  (`stamp_fetch_metadata_if_absent`, raw files gitignored).
- Centroids computed via ogr from ISTAT geometry, or taken from an
  ISTAT-published coordinate table — whichever the actual product
  provides, decided from inspection (Q5), never mixed silently.
- Compact schema `{name, province, lat, lon}`; size measured and a real
  validator gate constant added from that measurement + stated headroom
  (estimate ~400–600 KB — an estimate, not a limit).
- Name normalization reuses the established accent/punctuation-fold
  approach; bilingual names match either side of the `/`.
- Homonym comuni (real cases exist) are disambiguated by province: the
  lookup returns candidates; the UI disambiguates.

## Known risks & edge cases — the GO-COMUNI gate

(a) Product identified with license verified CC BY-compatible, quoted.
(b) Comuni vintage consistency with the 2020 collegi bases checked;
mergers/renames since the snapshot enumerated and documented.
(c) Full-table dry run: every centroid resolved against both chambers'
polygons; the nil rate (coastal/enclave centroids landing outside any
polygon) **measured** — the phase then decides disclose-vs-snap with the
decision documented; a high nil rate is a NO-GO trigger, not a
special-case opportunity.
(d) The new tier must not regress address-level results: CLGeocoder
still wins when available.

## Validation strategy

Committed offline probe: full-table resolution report (match/nil
counts); spot verification of ≥10 known comuni against their real
collegi from official sources, quoted in the report **before** the
integration tests hardcode them.

## Test specifications (strict acceptance criteria)

1. Manifest + provenance entries complete; license verbatim; the
   acquisition approval quoted.
2. `comuni.json` within its documented measured gate; validator green.
3. Lookup unit tests: exact match; accent-insensitive; bilingual;
   homonym returns all candidates; unknown returns empty.
4. Integration tests: the ≥10 probe-verified comune → collegio-id pairs.
5. Tier-order test: CLGeocoder result preferred when present; comuni
   table used when it fails; final fallback intact (or its removal
   documented and tested).
6. Suite green vs the current baseline plus documented additions.

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
