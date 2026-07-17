#!/usr/bin/env python3
"""Structural validation of Data/representatives.json.

Offline — does not fetch anything. Checks the file is well-formed and
internally consistent; it does NOT check cross-references against
Data/votes.json, since votes.json is a separate, still-fictional dataset not
yet migrated to reference real representative ids (see tools/README.md).

Exits non-zero with a clear diagnostic on any violation.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
DATA_PATH = ROOT / "Politici" / "Data" / "representatives.json"

REQUIRED_KEYS = {
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


def fail(errors):
    print(f"ERRORE: {len(errors)} problema/i in {DATA_PATH.relative_to(ROOT)}:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    sys.exit(1)


def main():
    if not DATA_PATH.exists():
        fail([f"file non trovato — esegui prima 'make import'"])

    try:
        records = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail([f"JSON non valido: {error}"])

    errors = []

    if not isinstance(records, list):
        fail(["il contenuto non è un array JSON"])
    if not records:
        errors.append("l'array è vuoto")

    seen_ids = set()
    for index, record in enumerate(records):
        label = f"record #{index} (id={record.get('id', '?')})"

        if not isinstance(record, dict):
            errors.append(f"{label}: non è un oggetto JSON")
            continue

        missing = REQUIRED_KEYS - record.keys()
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

        if not isinstance(record["name"], str) or not record["name"].strip():
            errors.append(f"{label}: 'name' deve essere una stringa non vuota")

        if not isinstance(record["party"], str) or not record["party"].strip():
            errors.append(
                f"{label}: 'party' è vuoto — spesso un segnale che il mandato "
                "è terminato e il record non dovrebbe essere incluso"
            )

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
        fail(errors)

    camera_count = sum(1 for r in records if r["chamber"] == "Camera")
    senato_count = sum(1 for r in records if r["chamber"] == "Senato")
    official_count = sum(1 for r in records if r["provenance"] == "official")
    sample_count = sum(1 for r in records if r["provenance"] == "sample")
    with_district = sum(1 for r in records if r["districtId"] is not None)

    print(f"OK: {len(records)} record validi in {DATA_PATH.relative_to(ROOT)}")
    print(f"  Camera: {camera_count}  Senato: {senato_count}")
    print(f"  provenance official: {official_count}  sample: {sample_count}")
    print(f"  con districtId assegnato: {with_district}")


if __name__ == "__main__":
    main()
