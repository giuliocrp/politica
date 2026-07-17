#!/usr/bin/env python3
"""Fetches current Camera dei Deputati membership data from the official
dati.camera.it SPARQL endpoint (XIX Legislature) and saves the raw
SPARQL-JSON response to tools/raw/camera_deputati_sparql.json.

Network required. Does not write anything under Data/ — see
tools/import_representatives.py for that step.

Honesty rule: on any HTTP error, malformed response, or empty result set,
this script prints a clear diagnostic and exits non-zero without writing
tools/raw/camera_deputati_sparql.json (a stale/partial raw file is worse
than no file, since import would silently run against old data).
"""

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ENDPOINT = "https://dati.camera.it/sparql"
OUTPUT_PATH = Path(__file__).parent / "raw" / "camera_deputati_sparql.json"

# A browser-like User-Agent is used defensively: dati.senato.it is known to
# reject the default `Python-urllib/x.y` UA with HTTP 403, and there's no
# reason to assume dati.camera.it's policy is stable/guaranteed either.
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
)

SPARQL_QUERY = """
PREFIX ocd:     <http://dati.camera.it/ocd/>
PREFIX foaf:    <http://xmlns.com/foaf/0.1/>
PREFIX dc:      <http://purl.org/dc/elements/1.1/>
PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX bio:     <http://purl.org/vocab/bio/0.1/>
SELECT DISTINCT ?persona ?cognome ?nome ?genere ?dataNascita
                ?collegio ?sigla ?nomeGruppo ?commissione ?foto
WHERE {
  ?d a ocd:deputato ;
     ocd:rif_leg <http://dati.camera.it/ocd/legislatura.rdf/repubblica_19> ;
     ocd:rif_mandatoCamera ?mandato ;
     ocd:aderisce ?aderisce ;
     foaf:surname ?cognome ;
     foaf:firstName ?nome .
  ?persona ocd:rif_mandatoCamera ?mandato ; a foaf:Person .
  OPTIONAL { ?d foaf:gender ?genere. }
  OPTIONAL { ?d foaf:depiction ?foto. }
  OPTIONAL { ?persona bio:Birth ?b. ?b bio:date ?dataNascita. }
  OPTIONAL { ?mandato ocd:rif_elezione ?el. ?el dc:coverage ?collegio. }
  ?aderisce ocd:rif_gruppoParlamentare ?gruppo .
  ?gruppo dc:title ?nomeGruppo ; dcterms:alternative ?sigla .
  MINUS { ?aderisce ocd:endDate ?fineAdesione. }
  OPTIONAL {
    ?d ocd:membro ?m .
    ?m ocd:rif_organo ?organo .
    ?organo dc:title ?commissione .
    MINUS { ?m ocd:endDate ?fineMembro. }
  }
}
ORDER BY ?cognome ?nome
""".strip()


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    print(
        "\nNessun file scritto in tools/raw/. Verifica la connessione di rete "
        "e riprova con: python3 tools/fetch_camera.py",
        file=sys.stderr,
    )
    sys.exit(1)


def main():
    url = f"{ENDPOINT}?{urllib.parse.urlencode({'query': SPARQL_QUERY})}"
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/sparql-results+json",
            "User-Agent": USER_AGENT,
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            status = response.status
            body = response.read()
    except urllib.error.HTTPError as error:
        fail(f"l'endpoint {ENDPOINT} ha risposto con HTTP {error.code} ({error.reason})")
    except urllib.error.URLError as error:
        fail(f"impossibile raggiungere {ENDPOINT}: {error.reason}")

    if status != 200:
        fail(f"l'endpoint {ENDPOINT} ha risposto con HTTP {status}, atteso 200")

    try:
        payload = json.loads(body)
    except json.JSONDecodeError as error:
        fail(f"la risposta di {ENDPOINT} non è JSON valido: {error}")

    bindings = payload.get("results", {}).get("bindings", [])
    if not bindings:
        fail(
            f"la query SPARQL a {ENDPOINT} ha restituito zero risultati — "
            "verifica che la query e la legislatura siano ancora corrette"
        )

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"OK: {len(bindings)} binding salvati in {OUTPUT_PATH.relative_to(Path(__file__).parent.parent)}")


if __name__ == "__main__":
    main()
