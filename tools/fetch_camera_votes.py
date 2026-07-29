#!/usr/bin/env python3
"""Fetches a bounded, curated subset of Camera dei Deputati votazioni (XIX
Legislature, Assemblea, non-secret/"electronic" roll-call votes) plus every
per-deputy position recorded for them, from the official dati.camera.it
SPARQL endpoint. Saves the raw SPARQL-JSON response to
tools/raw/camera_votazioni_sparql.json.

Scope is controlled entirely by tools/config/votes_scope.json (mode
"recent": the N most recent qualifying votazioni; mode "explicit": a
hand-curated list of votazione URIs) — see that file and
docs/v2/04-votes-import.md for the scoping rationale (why "Assemblea" and
"non-secret" are both explicit filters, not incidental).

This script only decides WHICH votazioni to fetch and caches their full
detail (every per-deputy position, uncapped). It does not enforce the
maxPositionRecords budget — that's tools/import_votes.py's job (the offline,
deterministic step), matching this project's established fetch/import split
(see docs/v2/01-real-data-import.md): fetch caches what's asked for, import
holds the business logic and quality gates.

Network required. Does not write anything under Data/.

Honesty rule: on any HTTP error, malformed response, empty scope, or config
validation failure, this script prints a clear diagnostic and exits non-zero
without writing tools/raw/camera_votazioni_sparql.json.
"""

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).parent))
from sparql_client import RAW_DIR, SPARQLFetchError, fetch_sparql, load_query, stamp_fetch_metadata  # noqa: E402

ENDPOINT = "https://dati.camera.it/sparql"
OUTPUT_PATH = RAW_DIR / "camera_votazioni_sparql.json"
CONFIG_PATH = Path(__file__).parent / "config" / "votes_scope.json"

ALLOWED_URI_PREFIX = "http://dati.camera.it/ocd/votazione.rdf/"

# Detail is fetched in chunks of this many votazioni per request. A single
# 25-votazione shot returned 9,975 rows (Phase 21) — uncomfortably close to
# the ~10k-row result cap the Senato endpoint showed in Phase 15b, and a
# 30-votazione shot (~12k rows) could cross it and silently truncate. 10
# URIs/request (~3,990 rows/chunk) keeps every response far from any cap;
# the per-chunk row counts are printed so a truncation would be visible.
# Any chunk failing raises through fetch_detail -> fail() -> non-zero exit
# BEFORE anything is written, so a partial fetch is never cached.
DETAIL_CHUNK_SIZE = 10


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    print(
        "\nNessun file scritto in tools/raw/. Verifica tools/config/votes_scope.json e "
        "la connessione di rete, poi riprova con: python3 tools/fetch_camera_votes.py",
        file=sys.stderr,
    )
    sys.exit(1)


def load_config():
    if not CONFIG_PATH.exists():
        fail(f"manca {CONFIG_PATH.relative_to(Path(__file__).parent.parent)}")
    try:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{CONFIG_PATH.name} non è JSON valido: {error}")

    mode = config.get("mode")
    if mode not in ("recent", "explicit"):
        fail(f"votes_scope.json: 'mode' deve essere 'recent' o 'explicit', trovato {mode!r}")

    for key in ("n", "maxVotes", "maxPositionRecords"):
        value = config.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
            fail(f"votes_scope.json: '{key}' deve essere un intero positivo, trovato {value!r}")

    if mode == "explicit":
        uris = config.get("voteUris")
        if not isinstance(uris, list) or not uris:
            fail("votes_scope.json: mode 'explicit' richiede un 'voteUris' non vuoto")
        for uri in uris:
            if not isinstance(uri, str) or not uri.startswith(ALLOWED_URI_PREFIX):
                fail(f"votes_scope.json: voteUris contiene un URI non valido: {uri!r}")

    return config


def is_safe_uri(uri):
    """Defense in depth before string-interpolating into a VALUES clause,
    even though these URIs come from our own trusted config/SPARQL
    responses: must be exactly a bare http(s) URI under the expected host,
    no whitespace/angle-brackets/quotes that could break out of `<...>`."""
    if not isinstance(uri, str) or not uri.startswith(ALLOWED_URI_PREFIX):
        return False
    if any(c in uri for c in " \t\n<>\"'"):
        return False
    parsed = urlparse(uri)
    return parsed.scheme in ("http", "https") and parsed.netloc == "dati.camera.it"


def fetch_scope_candidates(limit):
    query = load_query("camera_votazioni_scope.rq") + f"\nLIMIT {limit}"
    try:
        payload, count = fetch_sparql(ENDPOINT, query, label="camera_votazioni_scope")
    except SPARQLFetchError as error:
        fail(str(error))
    bindings = payload["results"]["bindings"]
    uris = [b["v"]["value"] for b in bindings]
    if not all(is_safe_uri(uri) for uri in uris):
        fail("camera_votazioni_scope ha restituito un URI votazione inatteso — controlla l'endpoint")
    print(f"  {count} votazioni candidate trovate (mode 'recent')")
    return uris


def fetch_detail(uris):
    values_clause = "VALUES ?v { " + " ".join(f"<{uri}>" for uri in uris) + " }"
    template = load_query("camera_votazioni_dettaglio.rq")
    if "{{VALUES}}" not in template:
        fail("camera_votazioni_dettaglio.rq: manca il segnaposto {{VALUES}}")
    query = template.replace("{{VALUES}}", values_clause)
    try:
        payload, count = fetch_sparql(ENDPOINT, query, label="camera_votazioni_dettaglio")
    except SPARQLFetchError as error:
        fail(str(error))
    return payload, count


def main():
    config = load_config()
    mode = config["mode"]
    max_votes = config["maxVotes"]

    if mode == "recent":
        n = min(config["n"], max_votes)
        uris = fetch_scope_candidates(n)
    else:
        uris = config["voteUris"][:max_votes]
        if len(config["voteUris"]) > max_votes:
            print(f"  ATTENZIONE: voteUris ne elenca {len(config['voteUris'])}, troncato a maxVotes={max_votes}")

    if not uris:
        fail("nessuna votazione nello scope configurato — controlla tools/config/votes_scope.json")

    print(
        f"Recupero il dettaglio completo di {len(uris)} votazioni "
        f"(con tutte le posizioni per deputato), in chunk da {DETAIL_CHUNK_SIZE}..."
    )
    head = None
    all_bindings = []
    for start in range(0, len(uris), DETAIL_CHUNK_SIZE):
        chunk = uris[start:start + DETAIL_CHUNK_SIZE]
        # fetch_detail() calls fail() (non-zero exit, nothing written) on any
        # HTTP/parse error, so a failing chunk aborts before OUTPUT_PATH is
        # touched — never a partial cache.
        payload, rows = fetch_detail(chunk)
        print(f"  chunk {start // DETAIL_CHUNK_SIZE + 1}: {len(chunk)} votazioni, {rows} righe")
        if head is None:
            head = payload.get("head", {})
        all_bindings.extend(payload["results"]["bindings"])

    combined = {"head": head or {}, "results": {"bindings": all_bindings}}
    row_count = len(all_bindings)

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(combined, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    stamp_fetch_metadata("camera_votazioni")

    print(
        f"OK: {len(uris)} votazioni, {row_count} righe (votazione x deputato) salvate in "
        f"{OUTPUT_PATH.relative_to(Path(__file__).parent.parent)}"
    )
    print("Nota: nessun limite di posizioni applicato qui — tools/import_votes.py applica maxPositionRecords offline.")


if __name__ == "__main__":
    main()
