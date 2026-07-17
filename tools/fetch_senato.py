#!/usr/bin/env python3
"""Fetches current Senato della Repubblica membership data from the official
dati.senato.it SPARQL endpoint (XIX Legislature): senators, current group
memberships, and current committee memberships, as three separate queries
merged locally by import_representatives.py.

Network required. Does not write anything under Data/.

Honesty rule: on any HTTP error, malformed response, or empty result set for
ANY of the three queries, this script prints a clear diagnostic and exits
non-zero. It does not write partial output — if query 3 fails after 1 and 2
succeeded, none of the three raw files are left in an inconsistent state
relative to each other (all three are written only after all three succeed).
"""

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ENDPOINT = "https://dati.senato.it/sparql"
RAW_DIR = Path(__file__).parent / "raw"

# dati.senato.it rejects the default `Python-urllib/x.y` User-Agent with
# HTTP 403 (confirmed against the live endpoint); a browser-like UA is
# required, not just defensive.
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
)

SENATORI_QUERY = """
PREFIX osr:  <http://dati.senato.it/osr/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT DISTINCT ?senatore ?foto ?nome ?cognome ?legislatura
                ?inizioMandato ?fineMandato ?tipoMandato
                ?tipoFineMandato ?dataNascita ?cittaNascita
                ?provinciaNascita ?nazioneNascita
WHERE {
  ?senatore a osr:Senatore ;
            foaf:firstName ?nome ;
            foaf:lastName  ?cognome ;
            foaf:depiction ?foto ;
            osr:cittaNascita ?cittaNascita ;
            osr:provinciaNascita ?provinciaNascita ;
            osr:nazioneNascita ?nazioneNascita ;
            osr:dataNascita ?dataNascita ;
            osr:mandato ?mandato .
  ?mandato osr:tipoMandato ?tipoMandato ;
           osr:inizio ?inizioMandato ;
           osr:legislatura ?legislatura .
  OPTIONAL { ?mandato osr:fine ?fineMandato. }
  OPTIONAL { ?mandato osr:tipoFineMandato ?tipoFineMandato. }
  FILTER(?legislatura = 19)
} ORDER BY ?cognome ?nome
""".strip()

GRUPPI_QUERY = """
PREFIX osr:  <http://dati.senato.it/osr/>
PREFIX ocd:  <http://dati.camera.it/ocd/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT DISTINCT ?gruppo ?nomeGruppo ?senatore ?nome ?cognome ?carica ?inizioAdesione
WHERE {
  ?gruppo a ocd:gruppoParlamentare ;
          osr:denominazione ?denominazione .
  ?denominazione osr:titolo ?nomeGruppo .
  ?adesioneGruppo a ocd:adesioneGruppo ;
                  osr:carica ?carica ;
                  osr:inizio ?inizioAdesione ;
                  osr:gruppo ?gruppo .
  ?senatore ocd:aderisce ?adesioneGruppo ;
            a osr:Senatore ;
            foaf:firstName ?nome ;
            foaf:lastName ?cognome .
  OPTIONAL { ?adesioneGruppo osr:fine ?fineAdesione }
  OPTIONAL { ?denominazione osr:fine ?fineDenominazione }
  FILTER(!bound(?fineAdesione) && !bound(?fineDenominazione))
} ORDER BY ?nomeGruppo ?cognome
""".strip()

COMMISSIONI_QUERY = """
PREFIX osr:  <http://dati.senato.it/osr/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT DISTINCT ?senatore ?nome ?cognome ?inizioAfferenza ?carica ?commissione ?dizione
WHERE {
  ?senatore osr:afferisce ?afferenza ;
            a osr:Senatore ;
            foaf:firstName ?nome ;
            foaf:lastName ?cognome .
  ?afferenza osr:inizio ?inizioAfferenza ;
             osr:commissione ?commissione ;
             osr:carica ?carica .
  ?commissione osr:denominazione ?denominazione .
  ?denominazione osr:titolo ?dizione .
  OPTIONAL { ?denominazione osr:fine ?dataFine }
  OPTIONAL { ?afferenza osr:fine ?fineAfferenza }
  FILTER(!bound(?fineAfferenza) && !bound(?dataFine))
} ORDER BY ?commissione ?cognome
""".strip()

QUERIES = [
    ("senatori", SENATORI_QUERY, RAW_DIR / "senato_senatori_sparql.json"),
    ("gruppi", GRUPPI_QUERY, RAW_DIR / "senato_gruppi_sparql.json"),
    ("commissioni", COMMISSIONI_QUERY, RAW_DIR / "senato_commissioni_sparql.json"),
]


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    print(
        "\nNessun file scritto in tools/raw/. Verifica la connessione di rete "
        "e riprova con: python3 tools/fetch_senato.py",
        file=sys.stderr,
    )
    sys.exit(1)


def run_query(label, query):
    url = f"{ENDPOINT}?{urllib.parse.urlencode({'query': query})}"
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
        fail(f"query '{label}' — l'endpoint {ENDPOINT} ha risposto con HTTP {error.code} ({error.reason})")
    except urllib.error.URLError as error:
        fail(f"query '{label}' — impossibile raggiungere {ENDPOINT}: {error.reason}")

    if status != 200:
        fail(f"query '{label}' — l'endpoint {ENDPOINT} ha risposto con HTTP {status}, atteso 200")

    try:
        payload = json.loads(body)
    except json.JSONDecodeError as error:
        fail(f"query '{label}' — la risposta di {ENDPOINT} non è JSON valido: {error}")

    bindings = payload.get("results", {}).get("bindings", [])
    if not bindings:
        fail(f"query '{label}' ha restituito zero risultati — verifica che la query sia ancora corretta")

    return payload, len(bindings)


def main():
    # Run all three queries fully before writing anything, so a failure on
    # query 2 or 3 never leaves query 1's raw file describing a fetch that
    # only partially succeeded.
    results = []
    for label, query, output_path in QUERIES:
        payload, count = run_query(label, query)
        results.append((label, payload, count, output_path))

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for label, payload, count, output_path in results:
        output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"OK: {count} binding salvati in {output_path.relative_to(Path(__file__).parent.parent)}")


if __name__ == "__main__":
    main()
