#!/usr/bin/env python3
"""Fetches current Camera dei Deputati membership data from the official
dati.camera.it SPARQL endpoint (XIX Legislature) and saves the raw
SPARQL-JSON response to tools/raw/camera_deputati_sparql.json.

The query itself lives in tools/queries/camera_deputati.rq (versioned,
documented separately from this script).

Network required. Does not write anything under Data/ — see
tools/import_representatives.py for that step.

Honesty rule: on any HTTP error, malformed response, or empty result set
(after retries — see tools/sparql_client.py), this script prints a clear
diagnostic and exits non-zero without writing
tools/raw/camera_deputati_sparql.json (a stale/partial raw file is worse
than no file, since import would silently run against old data).
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparql_client import RAW_DIR, SPARQLFetchError, fetch_sparql, load_query, stamp_fetch_metadata  # noqa: E402

ENDPOINT = "https://dati.camera.it/sparql"
OUTPUT_PATH = RAW_DIR / "camera_deputati_sparql.json"


def main():
    query = load_query("camera_deputati.rq")

    try:
        payload, count = fetch_sparql(ENDPOINT, query, label="camera_deputati")
    except SPARQLFetchError as error:
        print(f"ERRORE: {error}", file=sys.stderr)
        print(
            "\nNessun file scritto in tools/raw/. Verifica la connessione di rete "
            "e riprova con: python3 tools/fetch_camera.py",
            file=sys.stderr,
        )
        sys.exit(1)

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    stamp_fetch_metadata("camera")

    print(f"OK: {count} binding salvati in {OUTPUT_PATH.relative_to(Path(__file__).parent.parent)}")


if __name__ == "__main__":
    main()
