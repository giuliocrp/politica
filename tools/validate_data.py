#!/usr/bin/env python3
"""Structural validation of Data/representatives.json, Data/districts.geojson,
and Data/votes.json.

Offline — does not fetch anything. Checks each file is well-formed and
internally consistent, plus the votes<->representatives referential
integrity check (every vote.representativeId must exist in
representatives.json — see docs/v2/04-votes-import.md).

Exits non-zero with a clear diagnostic on any violation.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
REPRESENTATIVES_PATH = ROOT / "Politici" / "Data" / "representatives.json"
DISTRICTS_PATH = ROOT / "Politici" / "Data" / "districts.geojson"
VOTES_PATH = ROOT / "Politici" / "Data" / "votes.json"

REQUIRED_VOTE_KEYS = {
    "id",
    "representativeId",
    "title",
    "date",
    "vote",
    "result",
    "sourceUrl",
    "provenance",
}
VALID_VOTE_CHOICES = {"Favorevole", "Contrario", "Astenuto", "Assente", "Sconosciuto"}
VALID_VOTE_RESULTS = {"Approvato", "Respinto", "Sconosciuto"}
MAX_VOTES_FILE_BYTES = 2 * 1024 * 1024
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")

REQUIRED_REPRESENTATIVE_KEYS = {
    "id",
    "name",
    "chamber",
    "districtId",
    "party",
    "parliamentaryGroup",
    "committees",
    "attendanceRate",
    "photoName",
    "provenance",
    "legislature",
    "electionType",
    "stableSourceId",
    "sourceUrl",
}
VALID_CHAMBERS = {"Camera", "Senato"}
VALID_PROVENANCE = {"sample", "official"}

# See docs/v2/02-post-import-audit.md: 400 is the exact constitutional size
# of the Camera; 201 is Senato's currently-serving count (elected + the 5
# active life senators), verified directly against the raw SPARQL cache.
EXPECTED_CAMERA_REPRESENTATIVE_COUNT = 400
EXPECTED_SENATO_REPRESENTATIVE_COUNT = 201

REQUIRED_DISTRICT_PROPERTY_KEYS = {
    "id",
    "name",
    "chamber",
    "collegioType",
    "circoscrizione",
    "subCode",
    "provenance",
    "sourceName",
}
VALID_COLLEGIO_TYPES = {"uninominale", "plurinominale", "sconosciuto"}
# See docs/v2/03-boundaries-audit.md: 147 is ISTAT's exact feature count for
# the Camera collegi-uninominali layer.
EXPECTED_DISTRICT_COUNT = 147
MAX_DISTRICTS_FILE_BYTES = 3 * 1024 * 1024


def validate_representatives():
    errors = []

    if not REPRESENTATIVES_PATH.exists():
        return [f"{REPRESENTATIVES_PATH.relative_to(ROOT)}: file non trovato — esegui prima 'make import'"]

    try:
        records = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"{REPRESENTATIVES_PATH.relative_to(ROOT)}: JSON non valido: {error}"]

    if not isinstance(records, list):
        return [f"{REPRESENTATIVES_PATH.relative_to(ROOT)}: il contenuto non è un array JSON"]
    if not records:
        errors.append(f"{REPRESENTATIVES_PATH.relative_to(ROOT)}: l'array è vuoto")

    seen_ids = set()
    seen_stable_ids = set()
    for index, record in enumerate(records):
        label = f"representatives.json record #{index} (id={record.get('id', '?')})"

        if not isinstance(record, dict):
            errors.append(f"{label}: non è un oggetto JSON")
            continue

        missing = REQUIRED_REPRESENTATIVE_KEYS - record.keys()
        if missing:
            errors.append(f"{label}: chiavi mancanti: {sorted(missing)}")
            continue

        rec_id = record["id"]
        if not isinstance(rec_id, str) or not rec_id:
            errors.append(f"{label}: 'id' deve essere una stringa non vuota")
        elif rec_id in seen_ids:
            errors.append(f"{label}: id duplicato")
        else:
            seen_ids.add(rec_id)

        stable_id = record["stableSourceId"]
        if not isinstance(stable_id, str) or not stable_id:
            errors.append(f"{label}: 'stableSourceId' deve essere una stringa non vuota")
        elif stable_id in seen_stable_ids:
            errors.append(f"{label}: stableSourceId duplicato")
        else:
            seen_stable_ids.add(stable_id)

        if not isinstance(record["name"], str) or not record["name"].strip():
            errors.append(f"{label}: 'name' deve essere una stringa non vuota")

        if not isinstance(record["party"], str) or not record["party"].strip():
            errors.append(
                f"{label}: 'party' è vuoto — spesso un segnale che il mandato "
                "è terminato e il record non dovrebbe essere incluso"
            )

        if not isinstance(record["parliamentaryGroup"], str) or not record["parliamentaryGroup"].strip():
            errors.append(f"{label}: 'parliamentaryGroup' deve essere una stringa non vuota")

        if record["chamber"] not in VALID_CHAMBERS:
            errors.append(f"{label}: 'chamber' non valido: {record['chamber']!r}")

        if record["provenance"] not in VALID_PROVENANCE:
            errors.append(f"{label}: 'provenance' non valido: {record['provenance']!r}")

        if not isinstance(record["committees"], list) or not all(
            isinstance(c, str) for c in record["committees"]
        ):
            errors.append(f"{label}: 'committees' deve essere un array di stringhe")

        if record["districtId"] is not None and not isinstance(record["districtId"], str):
            errors.append(f"{label}: 'districtId' deve essere null o una stringa")

        if record["attendanceRate"] is not None and not isinstance(record["attendanceRate"], (int, float)):
            errors.append(f"{label}: 'attendanceRate' deve essere null o numerico")

        source_url = record["sourceUrl"]
        if source_url is not None and not (isinstance(source_url, str) and source_url.startswith("http")):
            errors.append(f"{label}: 'sourceUrl' deve essere null o un URL http(s)")

    if errors:
        return errors

    camera_count = sum(1 for r in records if r["chamber"] == "Camera")
    senato_count = sum(1 for r in records if r["chamber"] == "Senato")

    if camera_count != EXPECTED_CAMERA_REPRESENTATIVE_COUNT:
        errors.append(
            f"representatives.json: totale Camera = {camera_count}, atteso "
            f"{EXPECTED_CAMERA_REPRESENTATIVE_COUNT} (vedi docs/v2/02-post-import-audit.md)"
        )
    if senato_count != EXPECTED_SENATO_REPRESENTATIVE_COUNT:
        errors.append(
            f"representatives.json: totale Senato = {senato_count}, atteso "
            f"{EXPECTED_SENATO_REPRESENTATIVE_COUNT} (vedi docs/v2/02-post-import-audit.md)"
        )

    if not errors:
        official_count = sum(1 for r in records if r["provenance"] == "official")
        sample_count = sum(1 for r in records if r["provenance"] == "sample")
        with_district = sum(1 for r in records if r["districtId"] is not None)
        print(f"OK: {len(records)} record validi in {REPRESENTATIVES_PATH.relative_to(ROOT)}")
        print(f"  Camera: {camera_count}  Senato: {senato_count}")
        print(f"  provenance official: {official_count}  sample: {sample_count}")
        print(f"  con districtId assegnato: {with_district}")

    return errors


def validate_districts():
    errors = []

    if not DISTRICTS_PATH.exists():
        return [f"{DISTRICTS_PATH.relative_to(ROOT)}: file non trovato — esegui prima 'make boundaries'"]

    file_size = DISTRICTS_PATH.stat().st_size
    if file_size > MAX_DISTRICTS_FILE_BYTES:
        errors.append(
            f"{DISTRICTS_PATH.relative_to(ROOT)}: {file_size / 1024 / 1024:.2f} MB, "
            "supera il limite di 3 MB"
        )

    try:
        collection = json.loads(DISTRICTS_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return errors + [f"{DISTRICTS_PATH.relative_to(ROOT)}: JSON non valido: {error}"]

    if collection.get("type") != "FeatureCollection":
        return errors + [f"{DISTRICTS_PATH.relative_to(ROOT)}: non è una FeatureCollection GeoJSON"]

    features = collection.get("features", [])
    if not features:
        errors.append(f"{DISTRICTS_PATH.relative_to(ROOT)}: nessuna feature")

    seen_ids = set()
    camera_count = 0
    for index, feature in enumerate(features):
        label = f"districts.geojson feature #{index}"
        props = feature.get("properties", {})
        label = f"{label} (id={props.get('id', '?')})"

        missing = REQUIRED_DISTRICT_PROPERTY_KEYS - props.keys()
        if missing:
            errors.append(f"{label}: chiavi mancanti in 'properties': {sorted(missing)}")
            continue

        district_id = props["id"]
        if not isinstance(district_id, str) or not district_id:
            errors.append(f"{label}: 'id' deve essere una stringa non vuota")
        elif district_id in seen_ids:
            errors.append(f"{label}: id duplicato")
        else:
            seen_ids.add(district_id)

        if not isinstance(props["name"], str) or not props["name"].strip():
            errors.append(f"{label}: 'name' deve essere una stringa non vuota")

        if props["chamber"] not in VALID_CHAMBERS:
            errors.append(f"{label}: 'chamber' non valido: {props['chamber']!r}")
        elif props["chamber"] == "Camera":
            camera_count += 1

        if props["collegioType"] not in VALID_COLLEGIO_TYPES:
            errors.append(f"{label}: 'collegioType' non valido: {props['collegioType']!r}")

        if props["chamber"] == "Camera" and props["collegioType"] == "uninominale":
            if not isinstance(props["circoscrizione"], str) or not props["circoscrizione"].strip():
                errors.append(f"{label}: 'circoscrizione' deve essere una stringa non vuota")
            if not isinstance(props["subCode"], str) or not props["subCode"].strip():
                errors.append(f"{label}: 'subCode' deve essere una stringa non vuota")

        if props["provenance"] not in VALID_PROVENANCE:
            errors.append(f"{label}: 'provenance' non valido: {props['provenance']!r}")

        geometry = feature.get("geometry")
        if geometry is None or geometry.get("type") not in ("Polygon", "MultiPolygon"):
            errors.append(f"{label}: geometria mancante o non Polygon/MultiPolygon")

    if not errors and camera_count != EXPECTED_DISTRICT_COUNT:
        errors.append(
            f"districts.geojson: totale Camera = {camera_count}, atteso "
            f"{EXPECTED_DISTRICT_COUNT} (vedi docs/v2/03-boundaries-audit.md)"
        )

    if not errors:
        multipolygon_count = sum(
            1 for f in features if f.get("geometry", {}).get("type") == "MultiPolygon"
        )
        print(f"OK: {len(features)} collegi validi in {DISTRICTS_PATH.relative_to(ROOT)} ({file_size / 1024:.0f} KB)")
        print(f"  Camera: {camera_count}  MultiPolygon (isole/parti multiple): {multipolygon_count}")

    return errors


def validate_linkage():
    """Cross-references representatives.json's districtId against
    districts.geojson's shipping Camera uninominale ids. Only meaningful if
    both files already passed their own structural checks, so main() only
    calls this when validate_representatives()/validate_districts() were
    both clean."""
    errors = []

    records = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    collection = json.loads(DISTRICTS_PATH.read_text(encoding="utf-8"))
    uninominale_ids = {
        f["properties"]["id"]
        for f in collection["features"]
        if f["properties"]["chamber"] == "Camera" and f["properties"]["collegioType"] == "uninominale"
    }

    district_of_deputy = {}
    for record in records:
        district_id = record["districtId"]
        if district_id is None:
            continue
        label = f"representatives.json id={record['id']}"
        if district_id not in uninominale_ids:
            errors.append(f"{label}: districtId {district_id!r} non corrisponde a nessun collegio uninominale Camera")
            continue
        if district_id in district_of_deputy:
            errors.append(
                f"{label}: collegio {district_id} già assegnato a "
                f"{district_of_deputy[district_id]!r} — più di un deputato corrente per lo stesso collegio"
            )
        else:
            district_of_deputy[district_id] = record["id"]

    if not errors:
        print(
            f"OK: collegamento coerente — {len(district_of_deputy)}/{len(uninominale_ids)} "
            "collegi uninominali Camera con un deputato corrente"
        )

    return errors


def validate_votes():
    errors = []

    if not VOTES_PATH.exists():
        return [f"{VOTES_PATH.relative_to(ROOT)}: file non trovato — esegui prima 'make import'"]

    file_size = VOTES_PATH.stat().st_size
    if file_size > MAX_VOTES_FILE_BYTES:
        errors.append(
            f"{VOTES_PATH.relative_to(ROOT)}: {file_size / 1024 / 1024:.2f} MB, "
            f"supera il limite di {MAX_VOTES_FILE_BYTES / 1024 / 1024:.1f} MB"
        )

    try:
        records = json.loads(VOTES_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return errors + [f"{VOTES_PATH.relative_to(ROOT)}: JSON non valido: {error}"]

    if not isinstance(records, list):
        return errors + [f"{VOTES_PATH.relative_to(ROOT)}: il contenuto non è un array JSON"]

    seen_ids = set()
    for index, record in enumerate(records):
        label = f"votes.json record #{index} (id={record.get('id', '?')})"

        if not isinstance(record, dict):
            errors.append(f"{label}: non è un oggetto JSON")
            continue

        missing = REQUIRED_VOTE_KEYS - record.keys()
        if missing:
            errors.append(f"{label}: chiavi mancanti: {sorted(missing)}")
            continue

        vote_id = record["id"]
        if not isinstance(vote_id, str) or not vote_id:
            errors.append(f"{label}: 'id' deve essere una stringa non vuota")
        elif vote_id in seen_ids:
            errors.append(f"{label}: id duplicato")
        else:
            seen_ids.add(vote_id)

        if not isinstance(record["representativeId"], str) or not record["representativeId"]:
            errors.append(f"{label}: 'representativeId' deve essere una stringa non vuota")

        if not isinstance(record["title"], str) or not record["title"].strip():
            errors.append(f"{label}: 'title' deve essere una stringa non vuota")

        if not isinstance(record["date"], str) or not DATE_RE.fullmatch(record["date"]):
            errors.append(f"{label}: 'date' deve essere nel formato yyyy-MM-dd, trovato {record['date']!r}")

        if record["vote"] not in VALID_VOTE_CHOICES:
            errors.append(f"{label}: 'vote' non valido: {record['vote']!r}")

        if record["result"] not in VALID_VOTE_RESULTS:
            errors.append(f"{label}: 'result' non valido: {record['result']!r}")

        source_url = record["sourceUrl"]
        if source_url is not None and not (isinstance(source_url, str) and source_url.startswith("http")):
            errors.append(f"{label}: 'sourceUrl' deve essere null o un URL http(s)")

        if record["provenance"] not in VALID_PROVENANCE:
            errors.append(f"{label}: 'provenance' non valido: {record['provenance']!r}")

    if not errors:
        print(f"OK: {len(records)} posizioni valide in {VOTES_PATH.relative_to(ROOT)} ({file_size / 1024:.0f} KB)")

    return errors


def validate_votes_reference_representatives():
    """Every vote.representativeId must exist in representatives.json — the
    referential-integrity invariant reinstated at full strength now that
    votes.json ships real, non-empty data (see docs/v2/04-votes-import.md).
    Only meaningful once both files already passed their own structural
    checks, so main() only calls this when they were both clean."""
    representatives = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    votes = json.loads(VOTES_PATH.read_text(encoding="utf-8"))
    representative_ids = {r["id"] for r in representatives}

    unresolved = sorted({v["representativeId"] for v in votes} - representative_ids)
    if unresolved:
        return [f"votes.json: representativeId non trovati in representatives.json: {unresolved}"]

    distinct_representatives_with_votes = {v["representativeId"] for v in votes}
    print(
        f"OK: integrità referenziale voti coerente — {len(votes)} posizioni, "
        f"{len(distinct_representatives_with_votes)} rappresentanti coinvolti"
    )
    return []


def main():
    representative_errors = validate_representatives()
    district_errors = validate_districts()
    vote_errors = validate_votes()
    all_errors = representative_errors + district_errors + vote_errors

    if not representative_errors and not district_errors:
        all_errors += validate_linkage()

    if not representative_errors and not vote_errors:
        all_errors += validate_votes_reference_representatives()

    if all_errors:
        print(f"ERRORE: {len(all_errors)} problema/i:", file=sys.stderr)
        for error in all_errors:
            print(f"  - {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
