"""Shared SPARQL-over-HTTP-GET client used by fetch_camera.py and
fetch_senato.py: query loading from tools/queries/*.rq, a descriptive
User-Agent, a request timeout, and retry/backoff on transient failures.

Also home to `stamp_fetch_metadata`, a small generically-useful helper for
recording "when was source X's raw data last (re)generated" into
tools/raw/.fetch_metadata.json — reused by tools/import_boundaries.py even
though that pipeline doesn't touch the network (it processes an
already-downloaded local shapefile), since the metadata format and
tools/make_manifest.py's consumption of it are identical either way.

Not a script — imported by the fetch and boundary-import scripts.
"""

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

TOOLS_DIR = Path(__file__).parent
QUERIES_DIR = TOOLS_DIR / "queries"
RAW_DIR = TOOLS_DIR / "raw"
FETCH_METADATA_PATH = RAW_DIR / ".fetch_metadata.json"

# Honestly identifies this tool rather than spoofing a browser. A descriptive
# UA works fine against both endpoints (verified live) — the earlier 403
# from dati.senato.it was specifically about the default bare
# `Python-urllib/x.y` UA, not a blanket non-browser block.
USER_AGENT = "PoliticaApp-DataPipeline/1.0 (tools/fetch_*.py; civic-tech prototype, non-commercial)"

TIMEOUT_SECONDS = 60
MAX_ATTEMPTS = 3
INITIAL_BACKOFF_SECONDS = 2


class SPARQLFetchError(Exception):
    """Raised when a query could not be fetched (after retries, where applicable)."""


def load_query(filename):
    """Loads a query from tools/queries/<filename>, stripping '#'-prefixed
    header comments (metadata for humans, not part of the SPARQL itself)."""
    text = (QUERIES_DIR / filename).read_text(encoding="utf-8")
    lines = [line for line in text.splitlines() if not line.strip().startswith("#")]
    return "\n".join(lines).strip()


def fetch_sparql(endpoint, query, label):
    """Runs one SPARQL query with retry/backoff on transient failures.

    Returns (payload, binding_count). Raises SPARQLFetchError with a clear
    Italian diagnostic on permanent failure. 4xx HTTP errors are never
    retried (a client/query error won't fix itself); 5xx and network-level
    errors get up to MAX_ATTEMPTS with exponential backoff.
    """
    url = f"{endpoint}?{urllib.parse.urlencode({'query': query})}"
    last_error = None

    for attempt in range(1, MAX_ATTEMPTS + 1):
        request = urllib.request.Request(
            url,
            headers={"Accept": "application/sparql-results+json", "User-Agent": USER_AGENT},
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
                status = response.status
                body = response.read()
        except urllib.error.HTTPError as error:
            if 400 <= error.code < 500:
                raise SPARQLFetchError(
                    f"query '{label}' — l'endpoint {endpoint} ha risposto con HTTP "
                    f"{error.code} ({error.reason}); errore del client, non verrà ritentato"
                ) from error
            last_error = f"HTTP {error.code} ({error.reason})"
        except urllib.error.URLError as error:
            last_error = str(error.reason)
        else:
            if status != 200:
                last_error = f"HTTP {status} inatteso"
            else:
                try:
                    payload = json.loads(body)
                except json.JSONDecodeError as error:
                    raise SPARQLFetchError(
                        f"query '{label}' — la risposta di {endpoint} non è JSON valido: {error}"
                    ) from error

                bindings = payload.get("results", {}).get("bindings", [])
                if not bindings:
                    raise SPARQLFetchError(
                        f"query '{label}' ha restituito zero risultati — "
                        "verifica che la query sia ancora corretta"
                    )
                return payload, len(bindings)

        if attempt < MAX_ATTEMPTS:
            backoff = INITIAL_BACKOFF_SECONDS * (2 ** (attempt - 1))
            print(
                f"  tentativo {attempt}/{MAX_ATTEMPTS} per '{label}' fallito "
                f"({last_error}); nuovo tentativo tra {backoff}s..."
            )
            time.sleep(backoff)

    raise SPARQLFetchError(
        f"query '{label}' — impossibile raggiungere {endpoint} dopo "
        f"{MAX_ATTEMPTS} tentativi: {last_error}"
    )


def stamp_fetch_metadata(source_key):
    """Records today's date as when `source_key` (e.g. "camera", "senato")
    was last successfully fetched, so tools/make_manifest.py can stamp
    sources.json's retrievedAt from the actual fetch time instead of
    whenever the manifest happens to be regenerated. Merges into the
    existing metadata file rather than overwriting other sources' entries.
    """
    metadata = {}
    if FETCH_METADATA_PATH.exists():
        try:
            metadata = json.loads(FETCH_METADATA_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            metadata = {}

    metadata[source_key] = {"fetchedAt": date.today().isoformat()}

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    FETCH_METADATA_PATH.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
