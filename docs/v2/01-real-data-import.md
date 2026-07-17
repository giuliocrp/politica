# v2 Phase — Real Representative Data Import

Supersedes `docs/v2/00-audit.md`'s representative-data numbers (that doc is a
frozen snapshot and is intentionally not edited). This phase replaced
`Data/representatives.json`'s fictional content with real, officially-sourced
data fetched from the Camera dei Deputati and Senato della Repubblica open
data portals.

## What changed

- New `tools/` pipeline: `fetch_camera.py`, `fetch_senato.py`,
  `import_representatives.py`, `validate_data.py`, `make_manifest.py`, plus a
  root `Makefile` (`fetch` / `import` / `validate` / `manifest` / `all`).
- `Politici/Data/representatives.json` now holds **601 real records** (400
  Camera deputies + 201 Senato senators, XIX Legislature), each with
  `"provenance": "official"`.
- The original 14 fictional records are preserved at
  `Politici/Data/representatives.sample.json`.
- `Politici/Data/sources.json` gained two real source entries (Camera, CC BY
  4.0; Senato, CC BY 3.0) alongside the original sample-data entry.
- `Politici/Data/districts.geojson` and `Politici/Data/votes.json` are
  **unchanged** — still the original fictional data.

## Data record counts (post-import)

| File | Records | Notes |
|---|---|---|
| `districts.geojson` | 5 | unchanged, fictional |
| `representatives.json` | **601** (400 Camera, 201 Senato) | real, `provenance: official` |
| `representatives.sample.json` | 14 | preserved fictional backup |
| `votes.json` | 37 | unchanged, fictional, references the old `REP###` ids |
| `sources.json` | 3 sources | 1 fictional + 2 real (Camera, Senato) |

## Judgment calls made during import (not fully specified by the acquisition brief)

- **`Representative.districtId` became `String?`** (was non-optional
  `String`). The brief requires emitting `districtId: null` for every real
  record; decoding `null` into a non-optional `String` would throw and zero
  out the *entire* representatives array on load, not just the new records.
  This is the one required Swift model change; `RepresentativeService`'s
  filter predicate needed no change (`String? == String` compiles via
  Swift's optional promotion).
- **Senators whose XIX-legislature mandate had ended were excluded.** The
  given `senatori` query has no active-mandate filter (unlike the Camera
  query's `MINUS` on ended group memberships) — it returned 208 senators
  including 7 with a `fineMandato` (ended mandate) already recorded,
  among them Silvio Berlusconi and Giorgio Napolitano (both deceased).
  Presenting them as current representatives would be factually wrong, so
  `import_representatives.py` filters out any senator binding with a
  non-null `fineMandato`, leaving 201.
- **`photoName` is the existing SF Symbol fallback** (`"person.crop.circle.fill"`)
  for every real record, **not** the real `?foto` photo URL. The app renders
  `photoName` via `Image(systemName:)`; a real HTTP(S) URL there would either
  fail to resolve (broken avatars) or require the app to fetch remote images
  at runtime, which conflicts with the local-first/no-networking-code
  constraint. Real photo URLs are preserved in `tools/raw/*.json` for a
  future phase that might revisit this trade-off explicitly.
- **`party` = sigla for Camera** (e.g. `"FDI"`, `"M5S"`), **`party` = full
  group name for Senato** (its `gruppi` query has no `?sigla` variable at
  all — there's nothing to prefer over). `parliamentaryGroup` = the raw
  `nomeGruppo` value, kept exactly as returned including Camera's known
  truncation-at-`"("` quirk — no attempt is made to reconstruct the missing
  suffix, since guessing would be fabrication.
- **Camera surnames/first names are title-cased** for display consistency
  (Camera's raw data is upper-case; Senato's is already properly cased).
  This is a disclosed, imperfect normalization: some Camera source values
  encode accented final vowels as an apostrophe (e.g. `"MULE'"` for what is
  very likely "Mulè"), a known legacy-encoding quirk in the source data
  itself, not introduced by this pipeline. No attempt is made to guess the
  correct accented form — the apostrophe is preserved as-is.
- **`collegio` (electoral constituency free text) and `?foto`/birth-date/
  birth-place fields are not carried into `representatives.json`** — there's
  no schema slot for them. They remain available in `tools/raw/*.json` for a
  future schema extension.
- **`legislature` is set to `"XIX"`** for every record — not itself a query
  field, but exactly what both queries are scoped to via their `WHERE`
  clauses, so stating it isn't fabrication. **`electionType`,
  `attendanceRate`, and `stableSourceId` are `null`/omitted** — nothing in
  the raw data maps to them without inventing a meaning `stableSourceId`
  was never given.

## Known consequences on app behavior (not addressed in this phase)

- **Every sample district's representative list is now empty.** All 601 real
  representatives have `districtId: null` (mapping real people to this
  app's 5 sample rectangular districts is out of scope here); `DistrictDetailView`
  already has a graceful "Nessun rappresentante trovato per questo collegio."
  empty state, so this is not a crash — just an honest reflection of current
  data, pending a future district-mapping phase.
- **`votes.json` is now orphaned relative to real representatives.** Its
  `representativeId` values (`REP001`–`REP014`) don't match any id in the
  new `representatives.json` (`p######`/`s####`). `RepresentativeProfileView`
  and `VoteHistoryView` will show no votes for any real representative until
  `votes.json` is regenerated from real roll-call data in a future phase.
  `PoliticiTests` no longer asserts vote→representative referential
  integrity (see `DecodingTests.swift`/`SchemaV2Tests.swift` comments) —
  that coverage is intentionally dropped, not silently broken.
- **`PartyStyle.color(for:)` (in `DistrictDetailView.swift`) won't recognize
  sigla-based party codes** (`"FDI"`, `"M5S"`, etc.) or Senato's full group
  names — every real representative's avatar falls through to the existing
  `default: return .gray` case. Not a crash, just a less colorful fallback;
  `PartyStyle` was not touched in this phase (out of scope, purely cosmetic).
- **Home's stats card and any other dynamic counts now reflect ~601
  representatives** instead of 14 — this is automatic (the views already
  read counts from the services, no hardcoded numbers in view code).
