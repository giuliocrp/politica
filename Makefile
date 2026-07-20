.PHONY: fetch import validate manifest boundaries boundaries-senato all refresh

PYTHON := python3

# Fetches raw SPARQL data from dati.camera.it and dati.senato.it.
# Requires network access. Writes only under tools/raw/. This is the only
# target in this Makefile that touches the network — `all` never depends
# on it (see below); use `refresh` when you deliberately want a re-fetch.
fetch:
	$(PYTHON) tools/fetch_camera.py
	$(PYTHON) tools/fetch_senato.py
	$(PYTHON) tools/fetch_camera_votes.py

# Merges tools/raw/*.json into Politici/Data/representatives.json and
# Politici/Data/votes.json. Offline — uses cached raw/ output from `make fetch`.
import:
	$(PYTHON) tools/import_representatives.py
	$(PYTHON) tools/import_votes.py

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

# Fully offline: rebuilds every generated Data/*.json(.geojson) file from
# the tools/raw/ cache left by a previous `make fetch`, in dependency
# order, with validate last so it checks this run's actual final output.
# Does NOT fetch — see `refresh` for that.
all: import boundaries boundaries-senato manifest validate

# Deliberate, network-touching refresh: fetch fresh data, then rebuild
# everything from it. This is the only target besides `fetch` itself that
# reaches the network.
refresh: fetch all
