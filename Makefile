.PHONY: fetch import validate manifest boundaries all

PYTHON := python3

# Fetches raw SPARQL data from dati.camera.it and dati.senato.it.
# Requires network access. Writes only under tools/raw/.
fetch:
	$(PYTHON) tools/fetch_camera.py
	$(PYTHON) tools/fetch_senato.py
	$(PYTHON) tools/fetch_camera_votes.py

# Merges tools/raw/*.json into Politici/Data/representatives.json and
# Politici/Data/votes.json. Offline — uses cached raw/ output from `make fetch`.
import:
	$(PYTHON) tools/import_representatives.py
	$(PYTHON) tools/import_votes.py

# Structural validation of Politici/Data/representatives.json and
# Politici/Data/districts.geojson.
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
	./tools/build_boundaries.sh

all: fetch import validate manifest boundaries
