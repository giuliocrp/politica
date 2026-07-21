# V3 Phase 14 — Pipeline Hardening

Restructures the `tools/` Makefile so `all` is fully offline against the
`tools/raw/` cache, adds a `refresh` target for the deliberate
network-touching path, moves `validate` to the terminal position,
implements and calibrates the per-feature vertex report/gate that was
planned in v2 but never built (`docs/history/POLITICA_HISTORY_GAPS_AND_CONFLICTS.md`,
finding **C7**), establishes a committed `tools/probes/` convention
(closing finding **G4**), and commits a provenance mirror at
`tools/SOURCES.md`. Also fixes one real pipeline defect discovered while
verifying this phase's own "no unreviewed data change" requirement (§7).

## 1. Makefile target graph — before

```
.PHONY: fetch import validate manifest boundaries all

fetch:      tools/fetch_camera.py, tools/fetch_senato.py, tools/fetch_camera_votes.py   [NETWORK]
import:     tools/import_representatives.py, tools/import_votes.py                       [offline]
validate:   tools/validate_data.py                                                       [offline]
manifest:   tools/make_manifest.py                                                       [offline]
boundaries: tools/build_boundaries.sh (-> tools/import_boundaries.py)                     [offline]

all: fetch import validate manifest boundaries
```

Two defects, both audited and confirmed before this phase began:

- `all` depended on `fetch`, so the README's documented one-command
  refresh shorthand (`make fetch && make all`) performed a double fetch.
- `validate` ran **before** `manifest` and `boundaries` in `all`'s
  dependency order, so it checked `districts.geojson`/`representatives.json`
  from *before* this run's `boundaries`/`manifest` steps regenerated them
  — not this run's actual final output.

No target other than `fetch` touched the network — confirmed by grepping
every `tools/*.py` file for `urllib`/`requests`/`socket`/`urlopen`/`http.client`/`httpx`:
only `tools/sparql_client.py` (the shared client) and the three
`fetch_*.py` scripts matched. `tools/import_boundaries.py` imports a
function from `sparql_client.py` (`stamp_fetch_metadata`, for local
timestamp bookkeeping — see §7), but that import does not touch the
network; it was a false lead when first grepping, resolved by reading the
function itself.

## 2. Makefile target graph — after

```
.PHONY: fetch import validate manifest boundaries all refresh

fetch:      unchanged                                                                    [NETWORK]
import:     unchanged                                                                    [offline]
manifest:   unchanged                                                                    [offline]
boundaries: unchanged invocation; tools/import_boundaries.py now also prints
            a per-feature vertex report and enforces MAX_VERTICES_PER_FEATURE [offline]
validate:   unchanged                                                                    [offline]

all:     import boundaries manifest validate   (validate last; no fetch)                 [offline]
refresh: fetch all                                                                        [NETWORK]
```

`make -n all` (dry-run plan, verified):

```
python3 tools/import_representatives.py
python3 tools/import_votes.py
./tools/build_boundaries.sh
python3 tools/make_manifest.py
python3 tools/validate_data.py
```

Exactly import → boundaries → manifest → validate, in that order, no
fetch. `make -n refresh` prepends the three fetch scripts and otherwise
matches `all`'s plan exactly.

`refresh` and `fetch` are the only two targets that reach the network —
re-confirmed by the same grep as §1 (no `tools/*.py` file other than the
three `fetch_*.py` scripts and `sparql_client.py` itself touches a
network primitive).

## 3. README.md / CLAUDE.md sync

Surgical, not a rewrite — only lines made inaccurate by this phase's
Makefile change, plus one unrelated line found stale while editing the
same section:

- README's "Data pipeline" command block: reordered to match the new
  `all` (manifest before validate, validate last), replaced `make all`'s
  description (`fetch + import + validate + manifest + boundaries` →
  the actual offline order), replaced the `make fetch && make all`
  one-command-refresh shorthand with `make refresh`, and added a line
  stating plainly that `refresh`/`fetch` are the only two network-touching
  targets.
- The "All data is a snapshot" known-limitation bullet: `make fetch && make all`
  → `make refresh`.
- `CLAUDE.md`'s "Data Files" section: the parenthetical make-target list
  updated to describe `all` (offline, bundling import/boundaries/manifest/validate)
  vs. `refresh` (fetch + all), instead of listing five flat targets with no
  stated relationship.
- **Incidental fix, not part of this phase's stated scope but found while
  editing this same README section**: the "Known limitations" bullet
  still said `IPHONEOS_DEPLOYMENT_TARGET is 26.5 … flagged, never
  actioned` — stale since Phases 13/13B lowered it to 17.0 and actioned
  the flag. Corrected to state the current value and point at
  `docs/v3/13-baseline-audit.md`/`docs/v3/13b-deployment-target.md`.

No wholesale rewrite: the "Project structure" tree, the honesty-rules
bullets, and the v3 roadmap section were read and left untouched — none
of them assert anything this phase's changes made false.

## 4. Vertex report and gate

Planned in the v2 boundaries phase alongside the byte budget, never
implemented — confirmed absent by grepping the entire repo for
"vertex"/"vertice" before this phase (only historical-audit docs and
`Politici/Utilities/PointInPolygon.swift`'s unrelated `vertexI`/`vertexJ`
loop variables matched). Implemented in `tools/import_boundaries.py`:

- `count_vertices(geometry)` sums coordinate pairs across every ring
  (exterior + holes) of a `Polygon`, or every ring of every part of a
  `MultiPolygon` — the same unit Douglas-Peucker simplification reduces.
- Computed per feature, right after the 147-count check and before
  serialization; both gates (vertex and the pre-existing byte gate) run
  **before** anything is written, so a violation of either leaves
  `districts.geojson` untouched — matching the byte gate's existing
  "nulla è stato scritto" pattern.
- Printed report: every feature's id, vertex count, and name, sorted
  descending by count, then the maximum called out on its own line.

**Measurement against the actual shipped geometry** (`make boundaries`,
full output captured):

- 147 features, vertex counts ranging 6–695.
- Maximum: **695 vertices**, feature `200004` ("Sardegna - U04").
- Next highest: 273 (`60003`, Friuli-Venezia Giulia), 266 (`200002`,
  Sardegna), then a long tail — mean 73.4, median 64.

**Gate calibration:** the originally-planned threshold was ~1500. The
observed maximum (695) sits well below that — more than 2x headroom — so
per this phase's instruction ("use 1500 if the observed maximum sits
below it with headroom") the gate is set at **`MAX_VERTICES_PER_FEATURE = 1500`**,
not tightened further. Reasoning recorded directly in the constant's code
comment, including the instruction to re-measure if
`SIMPLIFY_TOLERANCE_METERS` (currently 1000 m, in `tools/build_boundaries.sh`)
ever changes, since that's what actually controls vertex density.

Passes cleanly on the shipped geometry (`Massimo: 200004 … — 695 vertici`,
no failure, `make boundaries` completed and wrote the file). The gate's
failure path was verified by code reading (identical structure to the
pre-existing, working byte-gate `fail()` call, same file, same function)
rather than by fabricating an artificially oversized geometry to trigger
it — constructing fake political-geography data to test a code path would
itself violate the "never fabricate geography" constraint, so this was a
deliberate choice, not an oversight.

## 5. `tools/probes/` convention

Closes `docs/history/POLITICA_HISTORY_GAPS_AND_CONFLICTS.md` finding
**G4** (v2's `MKGeoJSONDecoder`/`MKMultiPolygon` diagnostic probes were
run outside the repo and never preserved — only their *finding* survives,
in a code comment and a test). That document itself suggested the fix:
*"Future probes worth keeping could live under a gitignored-except-by-choice `tools/probes/`."*

Created `tools/probes/README.md` stating the convention: probe **scripts**
are committed (with a one-line header comment on the question they
answer); probe **output** is disposable and gitignored, written to
`tools/probes/output/` by convention. Added `tools/probes/output/` to
`.gitignore`. No probe scripts were written in this phase — the directory
and convention are the deliverable; the next diagnostic investigation is
what populates it.

## 6. `tools/SOURCES.md` provenance mirror

`tools/raw/SOURCES.txt` (the human-maintained provenance record for the
manually-downloaded ISTAT shapefile, plus the two SPARQL sources) is
gitignored — it has never been version-controlled, so its content
survived only by quotation in `docs/v2/*.md`/`docs/DATA_SOURCES.md`.
Created `tools/SOURCES.md` as a committed mirror of its current content
(all three `RetrievedAt` values already read `2026-07-18`, the Phase 13
correction — verified by reading the live file before mirroring it, not
assumed). The new file states explicitly that `tools/raw/SOURCES.txt`
remains the working-cache copy and the more current source of truth on
any machine that's run a refresh since this mirror was last updated —
this file is a snapshot, not a replacement.

## 7. Byte-budget policy

Recorded here as the explicit, documented policy referenced by both
existing code gates and this phase's new one:

| Artifact | Budget | Enforced by |
|---|---|---|
| `Politici/Data/districts.geojson` | ≤ 3 MB | `tools/import_boundaries.py::MAX_OUTPUT_BYTES`, re-checked by `tools/validate_data.py::MAX_DISTRICTS_FILE_BYTES` |
| `Politici/Data/votes.json` | ≤ 2 MiB | `tools/validate_data.py::MAX_VOTES_FILE_BYTES` (this exact value; see below) |
| All bundled `Politici/Data/*` combined | soft target ≤ ~10 MB | not separately gated in code; a design ceiling, not a hard budget with its own check |

**Current actual total** (real shipping files —
`parties.json`/`representatives.json`/`sources.json`/`votes.json`/`districts.geojson`,
excluding the `*.sample.*` test-only fixtures, which are not part of the
data a real user downloads for the app's own use):

```
parties.json:          1.6 KB
representatives.json: 429.1 KB
sources.json:           2.7 KB
votes.json:          1834.3 KB
districts.geojson:  1131.3 KB
Total:               3399.1 KB  (~3.32 MB)
```

Comfortably inside the soft 10 MB ceiling, with `votes.json` (1.79 MiB) the
largest single file and already close to its own 2 MiB per-file cap —
consistent with `docs/v2/04-votes-import.md`'s account of that budget
being the actual constraint that capped the votes import at 12 events
instead of the nominal 25-event scope target.

**Rationale:**

- **App download size.** This is a lightweight civic-information
  prototype, not a data-heavy app — every bundled MB is paid by every
  installer on every update, with no server-side lazy-loading path (the
  app is local-first at runtime by standing constraint). A single-digit-MB
  total keeps the app trivially small to install and update.
- **Reviewable diffs.** Generated JSON/GeoJSON is committed, and this
  whole multi-phase program's working method depends on being able to
  `git diff` a pipeline re-run and actually read what changed (see §8
  below, where that exact practice caught a real bug). A byte budget in
  the low single-digit MB per file keeps a diff human-reviewable; a
  multi-hundred-MB file would make "inspect the full diff" an empty
  ritual no one can actually do.

**Revision protocol:** these numbers (3 MB / 2 MiB / ~10 MB soft total)
are this phase's explicit policy, not an accident of whatever the current
files happen to weigh. A later phase may revise them, but only with its
own documented decision (a written rationale in that phase's report) —
not by silently loosening a gate because a new dataset happens to be
larger. `MAX_VOTES_FILE_BYTES` in particular is called out in the v2
votes-import report as a live budget that "a later phase may explicitly
restate" if votes coverage is deliberately expanded — this phase changes
nothing about it, just restates it as still-current policy.

## 8. Offline verification — `make all` with the cache present

Ran `make all` twice against the existing `tools/raw/` cache (present on
this machine — confirmed in Phase 13). Full command output captured; key
excerpts:

- Neither run printed any `fetch_camera.py`/`fetch_senato.py`/`fetch_camera_votes.py`
  invocation — confirmed both by reading the full transcript and by `make -n all` (§2).
- Both runs completed with all steps' own `OK:`/validation-passed output,
  ending in `validate`'s five `OK:` lines (representatives, districts,
  votes, linkage, vote-referential-integrity) and no error.
- Vertex report printed as described in §4.

**First run's diff** (`git diff --stat -- Politici/Data/`):

```
Politici/Data/sources.json | 4 ++--
```

```diff
-  "generatedAt": "2026-07-18",
+  "generatedAt": "2026-07-20",
...
-      "retrievedAt": "2026-07-18",
+      "retrievedAt": "2026-07-20",
   (istat-collegi-elettorali-camera-uninominali entry)
```

**Investigated, not assumed metadata-only.** `generatedAt` bumping to
today is expected, harmless churn — `tools/make_manifest.py` sets it to
`date.today()` unconditionally by design, exactly the "manifest
generation timestamp" example this phase's own instructions call
acceptable. But the ISTAT source's `retrievedAt` advancing from
`2026-07-18` to `2026-07-20` is not that — it's a specific, dated,
user-visible provenance claim ("when was this data retrieved from ISTAT")
silently becoming false: `make boundaries` did no network fetch, the
ISTAT shapefile is a one-time manual download that sat unchanged in
`tools/raw/collegi/`, and nothing was actually retrieved today.

**Root cause, found by reading `tools/import_boundaries.py`:** its last
line called `sparql_client.stamp_fetch_metadata("istat")`
unconditionally, on every successful run — a helper designed for the
three real `fetch_*.py` scripts to record "I just fetched this," reused
here even though this script never fetches anything; it only transforms
an already-present local file. Confirmed **pre-existing**, not introduced
by this phase's own edits: `git show HEAD:tools/import_boundaries.py |
grep stamp_fetch_metadata` shows the same unconditional call at the
pre-phase-14 commit, before any of this phase's vertex-report changes
touched the file.

**Disposition — verified correction, not silent restoration alone**, per
this phase's own protocol ("commit no generated-data change… unless a
documented pipeline defect requires a verified correction"):

1. `Politici/Data/sources.json` was restored (`git checkout --`) — no
   generated-data change from this discovery is committed.
2. The local, gitignored `tools/raw/.fetch_metadata.json` cache (which
   had also been overwritten, `istat.fetchedAt` → `2026-07-20`) was
   restored to `2026-07-18` to match Phase 13's established-correct value.
3. Root cause fixed: `tools/sparql_client.py` gained
   `stamp_fetch_metadata_if_absent(source_key)` — writes only if no entry
   exists yet for that key, leaving an existing value untouched on
   repeat runs. `tools/import_boundaries.py` now calls this instead of
   the unconditional `stamp_fetch_metadata`, with a comment explaining
   why. The three real fetch scripts (`fetch_camera.py`, `fetch_senato.py`,
   `fetch_camera_votes.py`) are unchanged and still use the unconditional
   version, which is correct for them — they really do fetch every time
   they run.
4. **Re-ran `make all` a second time** to verify the fix: `sources.json`'s
   diff shrank to *only* `generatedAt` (the expected, harmless churn) —
   `istat`'s `retrievedAt` stayed at `2026-07-18` across the re-run.
   `git diff --stat -- Politici/Data/` confirmed exactly one line changed
   (`sources.json`, the `generatedAt` field only).
5. `Politici/Data/sources.json` restored again (`git checkout --`) after
   this second, confirming run — final working tree has **zero** diff
   under `Politici/Data/`.

No other bundled/generated file (`representatives.json`, `votes.json`,
`parties.json`, `representatives.sample.json`, `votes.sample.json`,
`districts.sample.geojson`) showed any diff across either run — fully
reproducible offline from the cache, as intended. No political-data value
(a representative, a vote, a district boundary) changed in either run;
only the provenance-metadata bug above, now fixed.

## 9. Fail-loud verification

`tools/raw/` moved aside (`mv tools/raw /tmp/…`), then `make all`:

```
$ make all
python3 tools/import_representatives.py
ERRORE: manca tools/raw/camera_deputati_sparql.json — esegui prima 'make fetch' (o tools/fetch_camera.py / tools/fetch_senato.py)
make: *** [import] Error 1
$ echo $?
2
```

Fails immediately at the first missing input, with a specific, actionable
Italian error message naming the exact missing file and the remedy — not
a silent success, not empty output, nonzero exit code (`make`'s own `***
[import] Error 1`, shell-visible as exit code 2). `tools/raw/` restored
(`mv` back) immediately after. Post-restore: `git status --short` shows
only this phase's intentional code/doc/probes changes — zero generated-data
drift from the fail-loud test itself (it errored before writing anything).

## Diff scope for this phase's commit

```
 .gitignore                 |  4 +++
 CLAUDE.md                  |  8 +++---
 Makefile                   | 24 ++++++++++++++----
 README.md                  | 35 +++++++++++++++++---------
 tools/build_boundaries.sh  |  4 ++-
 tools/import_boundaries.py | 61 ++++++++++++++++++++++++++++++++++++++++++++--
 tools/sparql_client.py     | 56 ++++++++++++++++++++++++++++++++----------
```

Plus new: `tools/SOURCES.md`, `tools/probes/README.md`,
`docs/v3/14-pipeline-hardening.md`, and the `.gitignore` entry for
`tools/probes/output/`.

**Zero files under `Politici/Data/` in this commit** — confirmed by
`git diff --stat -- Politici/Data/` returning empty immediately before
staging (§8, step 5). No file under `docs/v2/` or the pre-existing
`docs/history/` archive touched.
