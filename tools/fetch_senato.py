#!/usr/bin/env python3
"""Fetches current Senato della Repubblica membership data from the official
dati.senato.it SPARQL endpoint (XIX Legislature): senators, current group
memberships, and current committee memberships — three separate queries
(tools/queries/senato_*.rq), merged locally by tools/import_representatives.py.

Network required. Does not write anything under Data/.

Honesty rule: on any HTTP error, malformed response, or empty result set for
ANY of the three queries (after retries — see tools/sparql_client.py), this
script prints a clear diagnostic and exits non-zero. It does not write
partial output — all three raw files are written only after all three
queries succeed, so a failure on query 2 or 3 never leaves query 1's raw
file describing a fetch that only partially succeeded.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparql_client import RAW_DIR, SPARQLFetchError, fetch_sparql, load_query, stamp_fetch_metadata  # noqa: E402

ENDPOINT = "https://dati.senato.it/sparql"

QUERIES = [
    ("senatori", "senato_senatori.rq", RAW_DIR / "senato_senatori_sparql.json"),
    ("gruppi", "senato_gruppi.rq", RAW_DIR / "senato_gruppi_sparql.json"),
    ("commissioni", "senato_commissioni.rq", RAW_DIR / "senato_commissioni_sparql.json"),
]


def main():
    results = []
    for label, query_filename, output_path in QUERIES:
        query = load_query(query_filename)
        try:
            payload, count = fetch_sparql(ENDPOINT, query, label=label)
        except SPARQLFetchError as error:
            print(f"ERRORE: {error}", file=sys.stderr)
            print(
                "\nNessun file scritto in tools/raw/. Verifica la connessione di rete "
                "e riprova con: python3 tools/fetch_senato.py",
                file=sys.stderr,
            )
            sys.exit(1)
        results.append((payload, count, output_path))

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for payload, count, output_path in results:
        output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"OK: {count} binding salvati in {output_path.relative_to(Path(__file__).parent.parent)}")

    stamp_fetch_metadata("senato")


if __name__ == "__main__":
    main()
