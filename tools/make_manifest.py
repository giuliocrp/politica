#!/usr/bin/env python3
"""Regenerates Data/sources.json (the SourcesManifest the app's "Informazioni
e fonti" screen renders), upserting entries by id so re-running this script
is safe and idempotent.

Offline — makes no network calls. Each real source's `retrievedAt` is read
from tools/raw/.fetch_metadata.json (written by tools/fetch_camera.py /
tools/fetch_senato.py at the moment they last successfully fetched — see
tools/sparql_client.py), so it reflects when the data was actually
retrieved, not whenever this script happens to run. `generatedAt` (the
manifest's own top-level field) is a different thing — when *this file* was
last regenerated — and is always today's date.

Preserves the original "prototipo-dati-dimostrativi" entry, since
Data/votes.json is still fictional as of this script — representatives.json
and (as of the boundaries phase) districts.geojson now have real,
officially-sourced data.
"""

import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).parent.parent
MANIFEST_PATH = ROOT / "Politici" / "Data" / "sources.json"
FETCH_METADATA_PATH = Path(__file__).parent / "raw" / ".fetch_metadata.json"


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def retrieved_at(source_key, fetch_metadata):
    """The real fetch date if available, else today's date as an honest
    fallback (e.g. a fresh checkout that regenerates the manifest before
    ever running `make fetch`)."""
    entry = fetch_metadata.get(source_key)
    if entry and entry.get("fetchedAt"):
        return entry["fetchedAt"]
    return date.today().isoformat()


def load_fetch_metadata():
    if not FETCH_METADATA_PATH.exists():
        return {}
    try:
        return json.loads(FETCH_METADATA_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def real_sources(fetch_metadata):
    return [
        {
            "id": "camera-dei-deputati-xix-legislatura",
            "name": "Camera dei Deputati — Open Data (XIX Legislatura)",
            "url": "https://dati.camera.it/sparql",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("camera", fetch_metadata),
            "notes": (
                "Dati su deputati, gruppi parlamentari e commissioni della XIX "
                "Legislatura, ottenuti tramite interrogazione SPARQL "
                "all'endpoint ufficiale dati.camera.it. Il collegio elettorale "
                "non è ancora associato ai collegi campione di questo "
                "prototipo (districtId è null)."
            ),
        },
        {
            "id": "senato-della-repubblica-xix-legislatura",
            "name": "Senato della Repubblica — Open Data (XIX Legislatura)",
            "url": "https://dati.senato.it/sparql",
            "license": "CC BY 3.0",
            "retrievedAt": retrieved_at("senato", fetch_metadata),
            "notes": (
                "Dati su senatori, gruppi parlamentari e commissioni della XIX "
                "Legislatura, ottenuti tramite tre interrogazioni SPARQL "
                "all'endpoint ufficiale dati.senato.it. Il collegio elettorale "
                "non è ancora associato ai collegi campione di questo "
                "prototipo (districtId è null)."
            ),
        },
        {
            "id": "istat-collegi-elettorali-camera-uninominali",
            "name": "ISTAT — Basi geografiche dei collegi elettorali (Camera, uninominali)",
            "url": "https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("istat", fetch_metadata),
            "notes": (
                "Confini geografici dei 147 collegi uninominali della Camera "
                "(D.Lgs. 177/2020), riproiettati da EPSG:32632 a EPSG:4326 e "
                "semplificati per l'uso su mobile. I confini del Senato non "
                "sono ancora inclusi in questo prototipo."
            ),
        },
    ]


def main():
    if not MANIFEST_PATH.exists():
        fail(f"{MANIFEST_PATH.relative_to(ROOT)} non esiste")

    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{MANIFEST_PATH.relative_to(ROOT)} non è JSON valido: {error}")

    fetch_metadata = load_fetch_metadata()

    sources_by_id = {s["id"]: s for s in manifest.get("sources", [])}
    for source in real_sources(fetch_metadata):
        sources_by_id[source["id"]] = source

    manifest["schemaVersion"] = 2
    manifest["generatedAt"] = date.today().isoformat()
    manifest["sources"] = [sources_by_id[key] for key in sorted(sources_by_id)]

    serialized = json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    MANIFEST_PATH.write_text(serialized, encoding="utf-8")

    print(f"OK: {len(manifest['sources'])} fonti in {MANIFEST_PATH.relative_to(ROOT)}")
    for source in manifest["sources"]:
        print(f"  - {source['id']} ({source['license']}, retrievedAt={source['retrievedAt']})")


if __name__ == "__main__":
    main()
