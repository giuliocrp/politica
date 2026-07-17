#!/usr/bin/env python3
"""Regenerates Data/sources.json (the SourcesManifest the app's "Informazioni
e fonti" screen renders), upserting entries by id so re-running this script
is safe and idempotent.

Offline — reads no network, no tools/raw/ files; the license/URL/date facts
for each source are fixed constants describing where that data category
comes from, matching the acquisition brief exactly.

Preserves the original "prototipo-dati-dimostrativi" entry, since
Data/districts.geojson and Data/votes.json are still fictional as of this
script — only representatives.json has real, officially-sourced data so far.
"""

import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).parent.parent
MANIFEST_PATH = ROOT / "Politici" / "Data" / "sources.json"

REAL_SOURCES = [
    {
        "id": "camera-dei-deputati-xix-legislatura",
        "name": "Camera dei Deputati — Open Data (XIX Legislatura)",
        "url": "https://dati.camera.it/sparql",
        "license": "CC BY 4.0",
        "retrievedAt": date.today().isoformat(),
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
        "retrievedAt": date.today().isoformat(),
        "notes": (
            "Dati su senatori, gruppi parlamentari e commissioni della XIX "
            "Legislatura, ottenuti tramite tre interrogazioni SPARQL "
            "all'endpoint ufficiale dati.senato.it. Il collegio elettorale "
            "non è ancora associato ai collegi campione di questo "
            "prototipo (districtId è null)."
        ),
    },
]


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def main():
    if not MANIFEST_PATH.exists():
        fail(f"{MANIFEST_PATH.relative_to(ROOT)} non esiste")

    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{MANIFEST_PATH.relative_to(ROOT)} non è JSON valido: {error}")

    sources_by_id = {s["id"]: s for s in manifest.get("sources", [])}
    for source in REAL_SOURCES:
        sources_by_id[source["id"]] = source

    manifest["schemaVersion"] = 2
    manifest["generatedAt"] = date.today().isoformat()
    manifest["sources"] = [sources_by_id[key] for key in sorted(sources_by_id)]

    serialized = json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    MANIFEST_PATH.write_text(serialized, encoding="utf-8")

    print(f"OK: {len(manifest['sources'])} fonti in {MANIFEST_PATH.relative_to(ROOT)}")
    for source in manifest["sources"]:
        print(f"  - {source['id']} ({source['license']})")


if __name__ == "__main__":
    main()
