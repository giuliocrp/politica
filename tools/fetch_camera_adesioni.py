#!/usr/bin/env python3
"""Fetches Camera dei Deputati parliamentary-group membership intervals
("adesioni") for the currently-serving XIX-Legislature deputies from the
official dati.camera.it SPARQL endpoint, saving the raw SPARQL-JSON response
to tools/raw/camera_adesioni_sparql.json.

The query itself lives in tools/queries/camera_adesioni.rq (versioned,
documented separately). It returns one row per ocd:aderisce interval — the
full open+closed group-membership history of each of the 400 current
deputies (Phase 28 — docs/v4/28-membership-history.md).

Minimal-scope fetch: this ONE query only, not the whole pipeline. Matches
the deputies/votes fetch/import split (see tools/fetch_camera.py) — this
script only caches what the source holds; tools/import_memberships.py is the
offline step that enforces every quality gate (parseable dates, one open
interval per deputy, group reconciliation, referential integrity).

Network required. Does not write anything under Data/.

Honesty rule: on any HTTP error, malformed response, or empty result set
(after retries — see tools/sparql_client.py), this script prints a clear
diagnostic and exits non-zero without writing the raw file (a stale/partial
raw file is worse than none — import would silently run against old data).
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparql_client import RAW_DIR, SPARQLFetchError, fetch_sparql, load_query, stamp_fetch_metadata  # noqa: E402

ENDPOINT = "https://dati.camera.it/sparql"
OUTPUT_PATH = RAW_DIR / "camera_adesioni_sparql.json"


def main():
    query = load_query("camera_adesioni.rq")

    try:
        payload, count = fetch_sparql(ENDPOINT, query, label="camera_adesioni")
    except SPARQLFetchError as error:
        print(f"ERRORE: {error}", file=sys.stderr)
        print(
            "\nNessun file scritto in tools/raw/. Verifica la connessione di rete "
            "e riprova con: python3 tools/fetch_camera_adesioni.py",
            file=sys.stderr,
        )
        sys.exit(1)

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    stamp_fetch_metadata("camera_adesioni")

    print(f"OK: {count} intervalli di adesione salvati in {OUTPUT_PATH.relative_to(Path(__file__).parent.parent)}")


if __name__ == "__main__":
    main()
