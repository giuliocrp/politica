#!/usr/bin/env python3
"""Merges tools/raw/camera_votazioni_sparql.json into Data/votes.json
(schema v2). Offline — reads only the cached raw file; run
tools/fetch_camera_votes.py first (or `make fetch`).

Design notes / judgment calls (see docs/v2/04-votes-import.md for the full
SPARQL schema investigation this is based on):

- representativeId: the per-deputy ocd:voto entity's ocd:rif_deputato URI
  ends in "d{numericId}_19" — {numericId} is exactly the same source
  identifier already used as Representative.stableSourceId (see
  tools/import_representatives.py). A voto record whose deputato numeric id
  isn't a *Camera* stableSourceId in the current Data/representatives.json
  is dropped — counted and logged, never guessed at. This naturally excludes
  historical votes' departed predecessors; in practice, for the "most
  recent N votes" scope, the drop count is expected to be 0 or near it.
- vote (VoteChoice) / result (VoteResult): both decode tolerantly in the
  Swift model (unrecognized raw value -> .sconosciuto), but that requires an
  EXACT raw-value string match ("Favorevole"/"Contrario"/"Astenuto"/
  "Assente" / "Approvato"/"Respinto") — Self(rawValue:) is not fuzzy. So the
  observed SPARQL vocabulary is translated explicitly here (see
  RAW_VOTE_CHOICE / RAW_VOTE_RESULT below) rather than passed through
  as-is. Any value NOT in the observed table maps to "Sconosciuto" with a
  logged warning — never a crash, never a guess at what a new value means.
- title: dc:title on ocd:votazione is a generic procedural template
  ("Votazione Articolo 6 ", "Votazione finale ") — NEVER the actual bill/
  motion text, confirmed across every sample checked. The real subject
  lives on the associated atto's rdfs:label (?attoLabel here), which has
  two disclosed, purely-mechanical source-data artifacts: an HTML entity
  encoding (e.g. "&agrave;") and a literal trailing `^^<xsd:string-uri>`
  string that leaked into the label value itself (not proper RDF typing).
  Both are cleaned deterministically (html.unescape + regex strip) — this
  is normalization of a known encoding glitch, not invented content. Not
  every votazione has an associated atto (organizational votes, etc.);
  title falls back to the trimmed dc:title alone in that case.
- sourceUrl: dc:relation on ocd:votazione, when present, is a real,
  directly-published deep link to that vote's official "scheda votazione"
  page — used verbatim. Never constructed from a template; left null on the
  rare votazione missing it.
- Only Camera is in scope. Senato votes are explicitly out of scope for
  this phase (see the phase brief) — votes.json carries no Senato records
  either way, matching the existing empty-file state this replaces.

Phase 20 (docs/v3/20-vote-browsing.md) — normalized output schema:

- votes.json is now {"events":[...],"positions":[...]} instead of a flat
  position array. Each event carries the source's own votazione URI slug
  as its id (e.g. "vs19_690_076" — the very key this script always grouped
  by internally, now carried into the output instead of dropped), plus the
  once-per-event fields (title/date/result/sourceUrl/provenance); each
  position carries only {id, voteEventId, representativeId, vote}. Chosen
  by measurement, not preference: adding voteEventId to the flat shape
  measured 2,045,946 B (97.6% of the 2 MiB gate — inside the plan's
  "<~5% headroom" trigger), the normalized shape 711,439 B (33.9%).
  The included-event scope is unchanged — this is a shape change only.
"""

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
RAW_DIR = Path(__file__).parent / "raw"
CONFIG_PATH = Path(__file__).parent / "config" / "votes_scope.json"
DATA_DIR = ROOT / "Politici" / "Data"
REPRESENTATIVES_PATH = DATA_DIR / "representatives.json"
OUTPUT_PATH = DATA_DIR / "votes.json"
SAMPLE_BACKUP_PATH = DATA_DIR / "votes.sample.json"
RAW_VOTAZIONI_PATH = RAW_DIR / "camera_votazioni_sparql.json"

MAX_OUTPUT_BYTES = 2 * 1024 * 1024  # ~2MB bundle budget (task brief)

# Observed raw dc:type -> VoteChoice raw value. See docs/v2/04-votes-import.md
# for how each was found (a live GROUP BY dc:type over real votazioni).
# "Non ha votato" genuinely conflates "absent" and "present but didn't
# press a button" — the graph doesn't distinguish them at this predicate —
# mapped to the closest existing VoteChoice case, .assente, as a disclosed,
# non-fabricating best fit (not a guess about *why* — just the fact that no
# favorevole/contrario/astensione was recorded).
RAW_VOTE_CHOICE = {
    "Favorevole": "Favorevole",
    "Contrario": "Contrario",
    "Astensione": "Astenuto",
    "Non ha votato": "Assente",
}

RAW_VOTE_RESULT = {
    "1": "Approvato",
    "0": "Respinto",
}

ATTO_LABEL_ARTIFACT_RE = re.compile(r"\^\^https?://\S+\s*$")


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def id_segment(uri):
    return uri.rstrip("/").rsplit("/", 1)[-1]


def deputato_numeric_id(uri):
    # ".../deputato.rdf/d306139_19" -> "306139"
    segment = id_segment(uri)
    match = re.fullmatch(r"d(\d+)_\d+", segment)
    return match.group(1) if match else None


def clean_atto_label(label):
    if not label:
        return None
    cleaned = ATTO_LABEL_ARTIFACT_RE.sub("", label)
    cleaned = html.unescape(cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned or None


def build_title(raw_title, atto_label):
    procedural = re.sub(r"\s+", " ", (raw_title or "")).strip() or "Votazione"
    substantive = clean_atto_label(atto_label)
    if substantive:
        return f"{procedural} — {substantive}"
    return procedural


def parse_date(raw_date):
    # "20260715" -> "2026-07-15"
    if not raw_date or not re.fullmatch(r"\d{8}", raw_date):
        return None
    return f"{raw_date[0:4]}-{raw_date[4:6]}-{raw_date[6:8]}"


def votazione_sort_key(votazione):
    # Newest first: date desc, then the trailing sequence number in the URI
    # desc (breaks ties within the same sitting day in recording order).
    match = re.search(r"_(\d+)$", votazione["voteId"])
    sequence = int(match.group(1)) if match else 0
    return (votazione["date"], sequence)


def load_config():
    if not CONFIG_PATH.exists():
        fail(f"manca {CONFIG_PATH.relative_to(ROOT)}")
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def load_representative_ids():
    if not REPRESENTATIVES_PATH.exists():
        fail(f"manca {REPRESENTATIVES_PATH.relative_to(ROOT)} — esegui prima 'make import'")
    records = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    return {r["stableSourceId"] for r in records if r["chamber"] == "Camera"}


def group_by_votazione(bindings):
    votazioni = {}
    for binding in bindings:
        v_uri = binding["v"]["value"]
        vote_id = id_segment(v_uri)
        if vote_id not in votazioni:
            date = parse_date(binding["date"]["value"])
            if date is None:
                fail(f"votazione {vote_id}: data non nel formato atteso yyyyMMdd: {binding['date']['value']!r}")
            votazioni[vote_id] = {
                "voteId": vote_id,
                "title": build_title(binding["title"]["value"], binding.get("attoLabel", {}).get("value")),
                "date": date,
                "approvato": binding["approvato"]["value"],
                "sourceUrl": binding.get("relation", {}).get("value"),
                "positions": [],
            }
        votazioni[vote_id]["positions"].append(
            {
                "votoId": id_segment(binding["voto"]["value"]),
                "deputatoNumericId": deputato_numeric_id(binding["deputato"]["value"]),
                "tipoVoto": binding["tipoVoto"]["value"],
            }
        )
    return votazioni


def main():
    config = load_config()
    max_votes = config["maxVotes"]
    max_positions = config["maxPositionRecords"]

    if not RAW_VOTAZIONI_PATH.exists():
        fail(f"manca {RAW_VOTAZIONI_PATH.relative_to(ROOT)} — esegui prima 'make fetch' (o tools/fetch_camera_votes.py)")
    payload = json.loads(RAW_VOTAZIONI_PATH.read_text(encoding="utf-8"))
    bindings = payload.get("results", {}).get("bindings", [])
    if not bindings:
        fail(f"{RAW_VOTAZIONI_PATH.relative_to(ROOT)} non contiene righe")

    camera_stable_ids = load_representative_ids()
    votazioni = group_by_votazione(bindings)

    ordered = sorted(votazioni.values(), key=votazione_sort_key, reverse=True)

    included = []
    all_records = []
    event_records = []
    skipped_over_max_votes = []
    skipped_over_budget = []
    dropped_unmapped_deputy = 0
    unknown_vote_choice = set()
    unknown_vote_result = set()
    total_written = 0

    for index, votazione in enumerate(ordered):
        if len(included) >= max_votes:
            skipped_over_max_votes.extend(v["voteId"] for v in ordered[index:])
            break

        result = RAW_VOTE_RESULT.get(votazione["approvato"])
        if result is None:
            unknown_vote_result.add(votazione["approvato"])
            result = "Sconosciuto"

        records = []
        for position in votazione["positions"]:
            numeric_id = position["deputatoNumericId"]
            if numeric_id is None or numeric_id not in camera_stable_ids:
                dropped_unmapped_deputy += 1
                continue

            choice = RAW_VOTE_CHOICE.get(position["tipoVoto"])
            if choice is None:
                unknown_vote_choice.add(position["tipoVoto"])
                choice = "Sconosciuto"

            records.append(
                {
                    "id": position["votoId"],
                    "voteEventId": votazione["voteId"],
                    "representativeId": f"p{numeric_id}",
                    "vote": choice,
                }
            )

        if total_written + len(records) > max_positions:
            # Stop at the first vote that doesn't fit rather than skipping
            # ahead to a smaller/older one — keeps the included set a
            # simple, contiguous "the K most recent that fit," not a
            # bin-packed selection that's harder to explain or reproduce.
            skipped_over_budget.extend(v["voteId"] for v in ordered[index:])
            break

        included.append(votazione["voteId"])
        total_written += len(records)
        all_records.extend(records)
        event_records.append(
            {
                "id": votazione["voteId"],
                "title": votazione["title"],
                "date": votazione["date"],
                "result": result,
                "sourceUrl": votazione["sourceUrl"],
                "provenance": "official",
            }
        )

    if not included:
        fail("nessuna votazione rientra nei limiti configurati (maxVotes/maxPositionRecords) — nessun file scritto")

    all_records.sort(key=lambda r: (r["voteEventId"], r["id"]))

    ids = [r["id"] for r in all_records]
    if len(ids) != len(set(ids)):
        duplicates = sorted({i for i in ids if ids.count(i) > 1})
        fail(f"id voto duplicati: {duplicates}")

    # Phase 20 invariants, importer-side (the validator re-checks the
    # written file): unique event ids, and the positions' distinct
    # voteEventId set must be exactly the event-id set.
    event_ids = [e["id"] for e in event_records]
    if len(event_ids) != len(set(event_ids)):
        fail(f"id votazione duplicati: {sorted({i for i in event_ids if event_ids.count(i) > 1})}")
    if {r["voteEventId"] for r in all_records} != set(event_ids):
        fail("insieme voteEventId delle posizioni != insieme id degli eventi — incoerenza interna")

    all_known_representative_ids = {r["id"] for r in json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))}
    unresolved = sorted({r["representativeId"] for r in all_records} - all_known_representative_ids)
    if unresolved:
        fail(f"referential integrity: representativeId non presenti in representatives.json: {unresolved}")

    output = {"events": event_records, "positions": all_records}
    serialized = json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    serialized_bytes = serialized.encode("utf-8")

    if len(serialized_bytes) > MAX_OUTPUT_BYTES:
        fail(
            f"il file risultante sarebbe {len(serialized_bytes) / 1024 / 1024:.2f} MB, supera il "
            f"limite di {MAX_OUTPUT_BYTES / 1024 / 1024:.1f} MB — riduci maxPositionRecords/maxVotes "
            "in tools/config/votes_scope.json (nulla è stato scritto)"
        )

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if OUTPUT_PATH.exists() and not SAMPLE_BACKUP_PATH.exists():
        SAMPLE_BACKUP_PATH.write_text(OUTPUT_PATH.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {OUTPUT_PATH.name} preservato come {SAMPLE_BACKUP_PATH.name}")

    OUTPUT_PATH.write_bytes(serialized_bytes)

    size_kb = len(serialized_bytes) / 1024
    print(f"OK: {len(all_records)} posizioni + {len(event_records)} eventi scritti in {OUTPUT_PATH.relative_to(ROOT)} ({size_kb:.0f} KB)")
    print(f"  votazioni incluse: {len(included)}/{len(ordered)} candidate (maxVotes={max_votes}, maxPositionRecords={max_positions})")
    if skipped_over_max_votes:
        print(f"  votazioni escluse oltre maxVotes: {len(skipped_over_max_votes)}: {skipped_over_max_votes}")
    if skipped_over_budget:
        print(f"  votazioni escluse per budget posizioni: {len(skipped_over_budget)}: {skipped_over_budget}")
    if dropped_unmapped_deputy:
        print(f"  ATTENZIONE: {dropped_unmapped_deputy} posizioni scartate (deputato non in representatives.json)")
    if unknown_vote_choice:
        print(f"  ATTENZIONE: valori tipoVoto non riconosciuti (mappati a Sconosciuto): {sorted(unknown_vote_choice)}")
    if unknown_vote_result:
        print(f"  ATTENZIONE: valori approvato non riconosciuti (mappati a Sconosciuto): {sorted(unknown_vote_result)}")


if __name__ == "__main__":
    main()
