# Data Source Provenance

Committed mirror of `tools/raw/SOURCES.txt`, the human-maintained
provenance record for the pipeline's data sources. `tools/raw/` is
gitignored (it's a fetch/download cache — see the "Data Files" section of
`CLAUDE.md`), so `SOURCES.txt` itself has never been version-controlled;
its content previously survived only by quotation in `docs/v2/*.md` and
`docs/DATA_SOURCES.md`. This file exists so that provenance record has a
durable, diffable, committed home independent of any one machine's local
cache.

**`tools/raw/SOURCES.txt` remains the working-cache copy** — it's what
`tools/build_boundaries.sh` and the fetch scripts' surrounding tooling
actually reference on a machine that has run `make fetch`/`make refresh`.
This file is a point-in-time mirror of it, not a replacement: if the two
ever diverge (e.g. after a future `make refresh` updates
`RetrievedAt`), `tools/raw/SOURCES.txt` on the machine that ran the
refresh is the more current source of truth, and this file should be
updated to match as part of that refresh's own commit — don't let this
file silently drift stale.

`RetrievedAt` below reflects the Phase 13 correction of a one-year typo
found in the working-cache file (`2025-07-18` → `2026-07-18`); see
`docs/v3/13-baseline-audit.md` §7 for the filesystem-timestamp evidence
that established which side was wrong.

---

# Camera dei Deputati
Name: Deputati XIX Legislatura (via SPARQL endpoint)
URL: https://dati.camera.it/sparql
Endpoint: https://dati.camera.it/sparql
License: CC BY 4.0
LicenseURL: https://creativecommons.org/licenses/by/4.0/
RetrievedAt: 2026-07-18
Notes: Queried via SPARQL for XIX Legislature. Filter uses ocd:rif_leg <http://dati.camera.it/ocd/legislatura.rdf/repubblica_19\>. Group name literals may be truncated at parentheses in source data — use sigla as primary identifier.

# Camera dei Deputati — Votazioni
Name: Votazioni Assemblea XIX Legislatura (via SPARQL endpoint)
URL: https://dati.camera.it/sparql
Endpoint: https://dati.camera.it/sparql
License: CC BY 4.0
LicenseURL: https://creativecommons.org/licenses/by/4.0/
RetrievedAt: 2026-07-22
Notes: Assemblea non-secret roll-call votes, XIX Legislature, with every deputy's per-vote position. Separate cache (camera_votazioni_sparql.json) from the deputies fetch above; refetched independently. 2026-07-22 (v4 Phase 27): switched from "most recent N" to a stratified selection (tools/select_votes_scope.py from a metadata-window probe, writing votes_scope.json explicit mode) — 30 votes across 10 sittings over ~9 months; detail fetched in chunks of 10 URIs/request. Legislature XIX re-verified current at fetch time. See docs/v4/27-votes-stratified.md.

# Camera dei Deputati — Adesioni ai gruppi parlamentari
Name: Adesioni ai gruppi parlamentari XIX Legislatura (via SPARQL endpoint)
URL: https://dati.camera.it/sparql
Endpoint: https://dati.camera.it/sparql
License: CC BY 4.0
LicenseURL: https://creativecommons.org/licenses/by/4.0/
RetrievedAt: 2026-07-22
Notes: Per-deputy ocd:aderisce group-membership intervals (ocd:startDate / optional ocd:endDate / ocd:rif_gruppoParlamentare) for the 400 current XIX deputies — 468 intervals, half-open [start, end). Separate cache (camera_adesioni_sparql.json) from the deputies and votes fetches above; minimal-scope fetch (camera_adesioni.rq only). 2026-07-22 (v4 Phase 28): new source; shape verified first by probe (ocd:startDate is the discovered start predicate; adesione is a blank node). Legislature XIX re-verified current at fetch time; deputies and votes caches untouched. See docs/v4/28-membership-history.md.

# Senato della Repubblica
Name: Senatori XIX Legislatura (via SPARQL endpoint)
URL: https://dati.senato.it/sparql
Endpoint: http://dati.senato.it/sparql
License: CC BY 3.0
LicenseURL: https://creativecommons.org/licenses/by/3.0/
RetrievedAt: 2026-07-21
Notes: Queried via SPARQL for XIX Legislature. Filter uses FILTER(?legislatura=19) on the mandate resource. Three separate queries needed: senators, group memberships (ocd:aderisce), committees (osr:afferisce). Merged locally by senator URI. 2026-07-21 (v3 Phase 17): senatori query extended with OPTIONAL osr:tipoElezione / osr:regioneElezione / osr:collegioElezione for the collegio-uninominale linkage; Senato-only refetch (Camera and votes caches untouched).

# ISTAT — Collegi Elettorali
Name: Basi geografiche dei collegi elettorali (D.Lgs. 177/2020)
URL: https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2
License: CC BY 4.0
LicenseURL: https://creativecommons.org/licenses/by/4.0/
RetrievedAt: 2026-07-18
Notes: Shapefile format, one manual download batch covering every layer. Camera + Senato collegi uninominali layers (v2/v3 Phase 16) and Camera + Senato collegi plurinominali layers (v4 Phase 25) used for district boundaries. Requires reprojection to EPSG:4326 and simplification for mobile.
