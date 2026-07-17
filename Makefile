.PHONY: fetch import validate manifest all

PYTHON := python3

# Fetches raw SPARQL data from dati.camera.it and dati.senato.it.
# Requires network access. Writes only under tools/raw/.
fetch:
	$(PYTHON) tools/fetch_camera.py
	$(PYTHON) tools/fetch_senato.py

# Merges tools/raw/*.json into Politici/Data/representatives.json.
# Offline — uses cached raw/ output from `make fetch`.
import:
	$(PYTHON) tools/import_representatives.py

# Structural validation of Politici/Data/representatives.json.
validate:
	$(PYTHON) tools/validate_data.py

# Regenerates Politici/Data/sources.json with the current source list.
manifest:
	$(PYTHON) tools/make_manifest.py

all: fetch import validate manifest
