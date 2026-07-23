.PHONY: fetch import validate manifest boundaries boundaries-senato boundaries-plurinominale-camera boundaries-plurinominale-senato all refresh

PYTHON := python3

# Fetches raw SPARQL data from dati.camera.it and dati.senato.it.
# Requires network access. Writes only under tools/raw/. This is the only
# target in this Makefile that touches the network — `all` never depends
# on it (see below); use `refresh` when you deliberately want a re-fetch.
fetch:
	$(PYTHON) tools/fetch_camera.py
	$(PYTHON) tools/fetch_senato.py
	$(PYTHON) tools/fetch_camera_votes.py
	$(PYTHON) tools/fetch_camera_adesioni.py

# Merges tools/raw/*.json into Politici/Data/representatives.json,
# Politici/Data/votes.json and Politici/Data/memberships_camera.json. Offline —
# uses cached raw/ output from `make fetch`. import_memberships.py runs LAST:
# it reads the just-built representatives.json to scope + reconcile the
# per-deputy group-membership intervals (Phase 28).
import:
	$(PYTHON) tools/import_representatives.py
	$(PYTHON) tools/import_votes.py
	$(PYTHON) tools/import_memberships.py

# Structural + referential-integrity validation of everything the steps
# above produce (representatives.json, districts.geojson, votes.json).
# Run last in `all` so it checks the final state of every generated file,
# not a stale one from before this run. Exits non-zero on any violation,
# which fails the `make all`/`make refresh` run.
validate:
	$(PYTHON) tools/validate_data.py

# Regenerates Politici/Data/sources.json with the current source list.
manifest:
	$(PYTHON) tools/make_manifest.py

# Builds Politici/Data/districts.geojson from the ISTAT Camera
# collegi-uninominali shapefile (reproject, simplify, convert via ogr2ogr,
# then schema-v2 transform). Offline — processes an already-downloaded
# local shapefile under tools/raw/collegi/, no network.
boundaries:
	./tools/build_boundaries.sh camera

# Builds Politici/Data/districts_senato.geojson from the ISTAT Senato
# collegi-uninominali shapefile — same pipeline as `boundaries`, Senato
# layer (Phase 16; see docs/v3/16-senato-boundaries.md). Offline.
boundaries-senato:
	./tools/build_boundaries.sh senato

# Builds Politici/Data/districts_plurinominali_camera.geojson /
# districts_plurinominali_senato.geojson from the ISTAT plurinominale
# shapefiles — same pipeline as the uninominale targets (Phase 25; see
# docs/v4/25-plurinominale-geography.md). Offline.
boundaries-plurinominale-camera:
	./tools/build_boundaries.sh camera-plurinominale

boundaries-plurinominale-senato:
	./tools/build_boundaries.sh senato-plurinominale

# Fully offline: rebuilds every generated Data/*.json(.geojson) file from
# the tools/raw/ cache left by a previous `make fetch`, in dependency
# order, with validate last so it checks this run's actual final output.
# The four boundary targets run before import: import_representatives.py's
# plurinominale linkage (Phase 25) reads districts_plurinominali_camera.geojson,
# so that file must be current when import runs.
# Does NOT fetch — see `refresh` for that.
all: boundaries boundaries-senato boundaries-plurinominale-camera boundaries-plurinominale-senato import manifest validate

# Deliberate, network-touching refresh: fetch fresh data, then rebuild
# everything from it. This is the only target besides `fetch` itself that
# reaches the network.
refresh: fetch all
