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
DISTRICTS_SENATO_PATH = ROOT / "Politici" / "Data" / "districts_senato.geojson"
DISTRICTS_PLURINOMINALI_CAMERA_PATH = ROOT / "Politici" / "Data" / "districts_plurinominali_camera.geojson"
DISTRICTS_PLURINOMINALI_SENATO_PATH = ROOT / "Politici" / "Data" / "districts_plurinominali_senato.geojson"
VOTES_PATH = ROOT / "Politici" / "Data" / "votes.json"

# Phase 20 normalized schema (docs/v3/20-vote-browsing.md): votes.json is
# {"events":[...],"positions":[...]} — event fields live once per event,
# positions reference their event via the source-backed voteEventId (the
# votazione URI slug, e.g. "vs19_690_076").
REQUIRED_VOTE_EVENT_KEYS = {
    "id",
    "title",
    "date",
    "result",
    "sourceUrl",
    "provenance",
}
REQUIRED_VOTE_POSITION_KEYS = {
    "id",
    "voteEventId",
    "representativeId",
    "vote",
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

# The three verbatim osr:tipoMandato literals (Phase 17 — see
# docs/v3/15-senato-exploration.md §7a and tools/import_representatives.py's
# KNOWN_TIPO_MANDATO). "mandate" is a Senato-only key: required on every
# senator record, forbidden on Camera records (chamber-conditional-key
# convention, like districts' circoscrizione/regione).
MANDATE_ELETTIVO = "elettivo"
MANDATE_A_VITA = "a vita, di nomina del Presidente della Repubblica"
MANDATE_EMERITO = "di diritto e a vita, Presidente emerito della Repubblica"
VALID_MANDATE_TYPES = {MANDATE_ELETTIVO, MANDATE_A_VITA, MANDATE_EMERITO}

# Phase 18 (docs/v3/18-plurinominale-context.md): "circoscrizione" is a
# Camera-only key — required on every deputy, forbidden on senators. The
# measured electionType distribution of the current import (147 uninominale
# = 145 maggioritario + 2 suppletiva; 253 proporzionale = 245 plurinominale
# + 8 estero, per the GO-CIRC gate evidence). "Estero" is the pinned
# circoscrizione value for estero deputies; domestic values are checked
# against districts.geojson's own circoscrizione set in
# validate_circoscrizione() rather than a hardcoded list.
EXPECTED_CAMERA_UNINOMINALE = 147
EXPECTED_CAMERA_PLURINOMINALE = 245
EXPECTED_CAMERA_ESTERO = 8
CIRCOSCRIZIONE_ESTERO = "Estero"

# Phase 25 (docs/v4/25-plurinominale-geography.md): "collegioPlurinominale" is
# a Camera-only, field-conditional key — present on every deputy whose
# dc:coverage is a "{CIRC} - P0N" literal (the GO-PLURI probe measured 389:
# 144 uninominale + 245 plurinominale), absent (not null) on the 8 estero and
# the 3 bare records (Valle d'Aosta + 2 suppletiva), and never on any
# senator. Every plurinominale deputy must carry it; every estero deputy must
# not. Values are resolved against districts_plurinominali_camera.geojson in
# validate_collegio_plurinominale() rather than a hardcoded list.
EXPECTED_CAMERA_WITH_COLLEGIO_PLURINOMINALE = 389

# "circoscrizione"/"regione" are deliberately NOT in this base set: Camera
# features carry "circoscrizione" and Senato features carry "regione", never
# both (see tools/import_boundaries.py) — checked separately, per chamber,
# below rather than required unconditionally on every feature.
REQUIRED_DISTRICT_PROPERTY_KEYS = {
    "id",
    "name",
    "chamber",
    "collegioType",
    "subCode",
    "provenance",
    "sourceName",
}
VALID_COLLEGIO_TYPES = {"uninominale", "plurinominale", "sconosciuto"}
# See docs/v2/03-boundaries-audit.md: 147 is ISTAT's exact feature count for
# the Camera collegi-uninominali layer.
EXPECTED_DISTRICT_COUNT = 147
# See docs/v3/15-senato-exploration.md: 74 is ISTAT's exact feature count
# for the Senato collegi-uninominali layer (verified via ogrinfo).
EXPECTED_SENATO_DISTRICT_COUNT = 74
# Phase 25 (docs/v4/25-plurinominale-geography.md): 49 named Camera / 26 named
# Senato plurinominale collegi — each raw ISTAT layer's remaining
# null-attribute placeholder feature (Q1) is dropped at import, not counted.
EXPECTED_CAMERA_PLURINOMINALE_DISTRICT_COUNT = 49
EXPECTED_SENATO_PLURINOMINALE_DISTRICT_COUNT = 26
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

        # "mandate" is chamber-conditional (Phase 17): required verbatim
        # vocabulary on every senator, forbidden (absent, not null) on
        # every deputy. "circoscrizione" is its Camera-side mirror
        # (Phase 18): required non-empty on every deputy, forbidden on
        # every senator.
        if record["chamber"] == "Senato":
            if "mandate" not in record:
                errors.append(f"{label}: chiave 'mandate' mancante (obbligatoria per i senatori)")
            elif record["mandate"] not in VALID_MANDATE_TYPES:
                errors.append(f"{label}: 'mandate' non valido: {record['mandate']!r}")
            if "circoscrizione" in record:
                errors.append(f"{label}: chiave 'circoscrizione' presente su un record Senato — deve essere assente")
            # collegioPlurinominale is Camera-only (Phase 25).
            if "collegioPlurinominale" in record:
                errors.append(f"{label}: chiave 'collegioPlurinominale' presente su un record Senato — deve essere assente")
        elif record["chamber"] == "Camera":
            if "mandate" in record:
                errors.append(f"{label}: chiave 'mandate' presente su un record Camera — deve essere assente")
            if "circoscrizione" not in record:
                errors.append(f"{label}: chiave 'circoscrizione' mancante (obbligatoria per i deputati)")
            elif not isinstance(record["circoscrizione"], str) or not record["circoscrizione"].strip():
                errors.append(f"{label}: 'circoscrizione' deve essere una stringa non vuota")
            # collegioPlurinominale (Phase 25): a field-conditional key. When
            # present it must be a non-empty string; every plurinominale
            # deputy must carry it; every estero deputy must not (the disclosed
            # absence also covers the 3 bare uninominale records, checked via
            # the 389 total below rather than per-record).
            has_pluri = "collegioPlurinominale" in record
            if has_pluri and (not isinstance(record["collegioPlurinominale"], str) or not record["collegioPlurinominale"].strip()):
                errors.append(f"{label}: 'collegioPlurinominale' deve essere una stringa non vuota")
            if record.get("electionType") == "plurinominale" and not has_pluri:
                errors.append(f"{label}: deputato plurinominale senza 'collegioPlurinominale'")
            if record.get("circoscrizione") == CIRCOSCRIZIONE_ESTERO and has_pluri:
                errors.append(f"{label}: deputato Estero con 'collegioPlurinominale' — deve essere assente")

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

    # Mandate arithmetic (Phase 17 — docs/v3/17-senato-mandates.md): the
    # three-term sum must account for every senator (robust against a new
    # vocabulary term slipping in as an untyped extra), and a serving
    # Presidente-emerito mandate would mean the source's data moved in a way
    # that needs human review, not a silent pass — its only known bearer's
    # mandate is ended, so serving count must be exactly 0.
    senato_records = [r for r in records if r["chamber"] == "Senato"]
    elettivo_count = sum(1 for r in senato_records if r.get("mandate") == MANDATE_ELETTIVO)
    a_vita_count = sum(1 for r in senato_records if r.get("mandate") == MANDATE_A_VITA)
    emerito_count = sum(1 for r in senato_records if r.get("mandate") == MANDATE_EMERITO)
    if elettivo_count + a_vita_count + emerito_count != senato_count:
        errors.append(
            f"representatives.json: mandati Senato {elettivo_count} elettivo + "
            f"{a_vita_count} a vita + {emerito_count} emerito != {senato_count} senatori totali"
        )
    if emerito_count != 0:
        errors.append(
            f"representatives.json: {emerito_count} senatori in carica con mandato "
            "'di diritto e a vita, Presidente emerito della Repubblica' — atteso 0, "
            "la sorgente è cambiata: rivedi prima di accettare"
        )

    # Phase 18: the measured electionType distribution and the
    # estero<->"Estero" correspondence — the set of deputies whose
    # circoscrizione is "Estero" must be exactly the set with
    # electionType "estero" (each identifies the other, no drift).
    camera_records = [r for r in records if r["chamber"] == "Camera"]
    uninominale_count = sum(1 for r in camera_records if r["electionType"] == "uninominale")
    plurinominale_count = sum(1 for r in camera_records if r["electionType"] == "plurinominale")
    estero_count = sum(1 for r in camera_records if r["electionType"] == "estero")
    for expected, actual, label_name in (
        (EXPECTED_CAMERA_UNINOMINALE, uninominale_count, "uninominale"),
        (EXPECTED_CAMERA_PLURINOMINALE, plurinominale_count, "plurinominale"),
        (EXPECTED_CAMERA_ESTERO, estero_count, "estero"),
    ):
        if actual != expected:
            errors.append(
                f"representatives.json: deputati {label_name} = {actual}, atteso {expected} "
                "(vedi docs/v3/18-plurinominale-context.md)"
            )
    estero_circ_ids = {r["id"] for r in camera_records if r.get("circoscrizione") == CIRCOSCRIZIONE_ESTERO}
    estero_type_ids = {r["id"] for r in camera_records if r["electionType"] == "estero"}
    if estero_circ_ids != estero_type_ids:
        errors.append(
            "representatives.json: insieme circoscrizione='Estero' != insieme electionType='estero' "
            f"(solo circ: {sorted(estero_circ_ids - estero_type_ids)}, "
            f"solo tipo: {sorted(estero_type_ids - estero_circ_ids)})"
        )

    # Phase 25: exactly 389 deputies carry collegioPlurinominale (144
    # uninominale + 245 plurinominale; the 8 estero + 3 bare carry none) — a
    # drift detector against the GO-PLURI gate evidence.
    with_pluri_count = sum(1 for r in camera_records if "collegioPlurinominale" in r)
    if with_pluri_count != EXPECTED_CAMERA_WITH_COLLEGIO_PLURINOMINALE:
        errors.append(
            f"representatives.json: deputati con collegioPlurinominale = {with_pluri_count}, "
            f"atteso {EXPECTED_CAMERA_WITH_COLLEGIO_PLURINOMINALE} "
            "(vedi docs/v4/25-plurinominale-geography.md)"
        )

    if not errors:
        official_count = sum(1 for r in records if r["provenance"] == "official")
        sample_count = sum(1 for r in records if r["provenance"] == "sample")
        with_district = sum(1 for r in records if r["districtId"] is not None)
        print(f"OK: {len(records)} record validi in {REPRESENTATIVES_PATH.relative_to(ROOT)}")
        print(f"  Camera: {camera_count}  Senato: {senato_count}")
        print(f"  provenance official: {official_count}  sample: {sample_count}")
        print(f"  con districtId assegnato: {with_district}")
        print(f"  mandati Senato: elettivo {elettivo_count}  a vita {a_vita_count}  emerito {emerito_count}")
        print(
            f"  deputati per tipo: uninominale {uninominale_count}  "
            f"plurinominale {plurinominale_count}  estero {estero_count}"
        )
        print(f"  deputati con collegioPlurinominale: {with_pluri_count}")

    return errors


def validate_districts_file(path, expected_chamber, expected_collegio_type, expected_count, grouping_property, missing_hint):
    """Structural validation for one boundaries file — the two uninominale
    files (Camera districts.geojson / Senato districts_senato.geojson, Phase
    16) and the two plurinominale files (districts_plurinominali_camera.geojson
    / districts_plurinominali_senato.geojson, Phase 25). Every feature must be
    the file's own chamber AND collegioType, carry its chamber's grouping
    property, and the count must match. Returns (errors, feature_ids)."""
    errors = []

    if not path.exists():
        return [f"{path.relative_to(ROOT)}: file non trovato — esegui prima '{missing_hint}'"], set()

    file_size = path.stat().st_size
    if file_size > MAX_DISTRICTS_FILE_BYTES:
        errors.append(
            f"{path.relative_to(ROOT)}: {file_size / 1024 / 1024:.2f} MB, "
            "supera il limite di 3 MB"
        )

    try:
        collection = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return errors + [f"{path.relative_to(ROOT)}: JSON non valido: {error}"], set()

    if collection.get("type") != "FeatureCollection":
        return errors + [f"{path.relative_to(ROOT)}: non è una FeatureCollection GeoJSON"], set()

    features = collection.get("features", [])
    if not features:
        errors.append(f"{path.relative_to(ROOT)}: nessuna feature")

    seen_ids = set()
    chamber_count = 0
    for index, feature in enumerate(features):
        label = f"{path.name} feature #{index}"
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
        elif props["chamber"] == expected_chamber:
            chamber_count += 1
        else:
            errors.append(f"{label}: 'chamber' atteso {expected_chamber!r}, trovato {props['chamber']!r}")

        if props["collegioType"] not in VALID_COLLEGIO_TYPES:
            errors.append(f"{label}: 'collegioType' non valido: {props['collegioType']!r}")
        elif props["collegioType"] != expected_collegio_type:
            errors.append(
                f"{label}: 'collegioType' atteso {expected_collegio_type!r}, trovato {props['collegioType']!r}"
            )

        if props["chamber"] == expected_chamber and props["collegioType"] == expected_collegio_type:
            grouping_value = props.get(grouping_property)
            if not isinstance(grouping_value, str) or not grouping_value.strip():
                errors.append(f"{label}: '{grouping_property}' deve essere una stringa non vuota")
            if not isinstance(props["subCode"], str) or not props["subCode"].strip():
                errors.append(f"{label}: 'subCode' deve essere una stringa non vuota")

        if props["provenance"] not in VALID_PROVENANCE:
            errors.append(f"{label}: 'provenance' non valido: {props['provenance']!r}")

        geometry = feature.get("geometry")
        if geometry is None or geometry.get("type") not in ("Polygon", "MultiPolygon"):
            errors.append(f"{label}: geometria mancante o non Polygon/MultiPolygon")

    if not errors and chamber_count != expected_count:
        errors.append(
            f"{path.name}: totale {expected_chamber} = {chamber_count}, atteso {expected_count}"
        )

    if not errors:
        multipolygon_count = sum(
            1 for f in features if f.get("geometry", {}).get("type") == "MultiPolygon"
        )
        print(f"OK: {len(features)} collegi validi in {path.relative_to(ROOT)} ({file_size / 1024:.0f} KB)")
        print(f"  {expected_chamber}: {chamber_count}  MultiPolygon (isole/parti multiple): {multipolygon_count}")

    return errors, seen_ids


def validate_districts():
    """Validates all four boundary files (Camera/Senato uninominali — Phase
    16; Camera/Senato plurinominali — Phase 25) and their cross-file id
    uniqueness (147 + 74 + 49 + 26 = 296 unique ids expected; any id shared
    between two files would silently alias two real, distinct collegi onto the
    same id — see the unconditional id-prefix policy in
    tools/import_boundaries.py: bare numeric / "S" / "CP" / "SP")."""
    files = [
        (DISTRICTS_PATH, "Camera", "uninominale", EXPECTED_DISTRICT_COUNT, "circoscrizione", "make boundaries"),
        (DISTRICTS_SENATO_PATH, "Senato", "uninominale", EXPECTED_SENATO_DISTRICT_COUNT, "regione", "make boundaries-senato"),
        (DISTRICTS_PLURINOMINALI_CAMERA_PATH, "Camera", "plurinominale",
         EXPECTED_CAMERA_PLURINOMINALE_DISTRICT_COUNT, "circoscrizione", "make boundaries-plurinominale-camera"),
        (DISTRICTS_PLURINOMINALI_SENATO_PATH, "Senato", "plurinominale",
         EXPECTED_SENATO_PLURINOMINALE_DISTRICT_COUNT, "regione", "make boundaries-plurinominale-senato"),
    ]

    errors = []
    ids_per_file = []
    any_file_error = False
    for path, chamber, collegio_type, expected_count, grouping, hint in files:
        file_errors, file_ids = validate_districts_file(
            path, chamber, collegio_type, expected_count, grouping, hint
        )
        errors += file_errors
        ids_per_file.append((path.name, file_ids))
        any_file_error = any_file_error or bool(file_errors)

    if not any_file_error:
        # Pairwise collision check across all four files.
        colliding = set()
        for i in range(len(ids_per_file)):
            for j in range(i + 1, len(ids_per_file)):
                colliding |= ids_per_file[i][1] & ids_per_file[j][1]
        if colliding:
            errors.append(f"id in collisione tra i file di confine: {sorted(colliding)}")
        else:
            total = sum(len(ids) for _, ids in ids_per_file)
            breakdown = " + ".join(f"{name} {len(ids)}" for name, ids in ids_per_file)
            print(f"OK: id univoci tra tutti i file di confine — {total} collegi totali ({breakdown})")

    return errors


def validate_linkage():
    """Cross-references representatives.json's districtId against the
    shipping uninominale collegio ids, per chamber (Phase 17): a deputy's
    districtId must be a Camera collegio, a senator's a Senato one — a
    cross-chamber assignment would be a real defect even though the ids
    can't collide (S-prefix). Only meaningful if the files already passed
    their own structural checks, so main() only calls this when
    validate_representatives()/validate_districts() were both clean."""
    errors = []

    records = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    uninominale_ids_by_chamber = {}
    for chamber, path in (("Camera", DISTRICTS_PATH), ("Senato", DISTRICTS_SENATO_PATH)):
        collection = json.loads(path.read_text(encoding="utf-8"))
        uninominale_ids_by_chamber[chamber] = {
            f["properties"]["id"]
            for f in collection["features"]
            if f["properties"]["chamber"] == chamber and f["properties"]["collegioType"] == "uninominale"
        }

    district_of_member = {"Camera": {}, "Senato": {}}
    for record in records:
        district_id = record["districtId"]
        if district_id is None:
            continue
        chamber = record["chamber"]
        label = f"representatives.json id={record['id']}"
        if district_id not in uninominale_ids_by_chamber[chamber]:
            errors.append(
                f"{label}: districtId {district_id!r} non corrisponde a nessun "
                f"collegio uninominale {chamber}"
            )
            continue
        claimed = district_of_member[chamber]
        if district_id in claimed:
            errors.append(
                f"{label}: collegio {district_id} già assegnato a "
                f"{claimed[district_id]!r} — più di un rappresentante corrente per lo stesso collegio"
            )
        else:
            claimed[district_id] = record["id"]

    if not errors:
        for chamber, member_noun in (("Camera", "deputato"), ("Senato", "senatore")):
            print(
                f"OK: collegamento coerente — {len(district_of_member[chamber])}/"
                f"{len(uninominale_ids_by_chamber[chamber])} "
                f"collegi uninominali {chamber} con un {member_noun} corrente"
            )

    return errors


def validate_circoscrizione():
    """Phase 18 cross-file checks: every deputy's circoscrizione is either
    "Estero" or one of districts.geojson's own shipped circoscrizione
    values (the reference set is the real data, not a hardcoded list), and
    every *linked* uninominale deputy's circoscrizione equals their
    collegio's shipped property exactly. Only meaningful once both files
    passed their own structural checks, so main() gates the call."""
    errors = []

    records = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    collection = json.loads(DISTRICTS_PATH.read_text(encoding="utf-8"))
    circoscrizione_of_district = {
        f["properties"]["id"]: f["properties"]["circoscrizione"]
        for f in collection["features"]
        if f["properties"]["chamber"] == "Camera" and f["properties"]["collegioType"] == "uninominale"
    }
    valid_values = set(circoscrizione_of_district.values()) | {CIRCOSCRIZIONE_ESTERO}

    observed = set()
    for record in records:
        if record["chamber"] != "Camera":
            continue
        label = f"representatives.json id={record['id']}"
        circoscrizione = record.get("circoscrizione")
        observed.add(circoscrizione)
        if circoscrizione not in valid_values:
            errors.append(
                f"{label}: circoscrizione {circoscrizione!r} non è né 'Estero' né una "
                "circoscrizione di districts.geojson"
            )
        district_id = record["districtId"]
        if district_id is not None and circoscrizione != circoscrizione_of_district.get(district_id):
            errors.append(
                f"{label}: circoscrizione {circoscrizione!r} != "
                f"{circoscrizione_of_district.get(district_id)!r} del collegio {district_id}"
            )

    if not errors:
        print(
            f"OK: circoscrizioni deputati coerenti — {len(observed)} valori osservati "
            f"({len(valid_values)} ammessi: {len(valid_values) - 1} da districts.geojson + 'Estero')"
        )

    return errors


def validate_collegio_plurinominale():
    """Phase 25 cross-file checks (docs/v4/25-plurinominale-geography.md):
    every deputy's collegioPlurinominale (when present) is a real Camera
    plurinominale district id, and equals a collegio whose own circoscrizione
    matches the deputy's; and every one of the 49 plurinominale collegi is
    named by at least one deputy (the drift detector — the GO-PLURI probe
    found full 49/49 coverage). Only meaningful once both files passed their
    own structural checks, so main() gates the call."""
    errors = []

    records = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    collection = json.loads(DISTRICTS_PLURINOMINALI_CAMERA_PATH.read_text(encoding="utf-8"))
    circoscrizione_of_district = {
        f["properties"]["id"]: f["properties"].get("circoscrizione")
        for f in collection["features"]
        if f["properties"]["chamber"] == "Camera" and f["properties"]["collegioType"] == "plurinominale"
    }

    covered = set()
    for record in records:
        if record["chamber"] != "Camera" or "collegioPlurinominale" not in record:
            continue
        label = f"representatives.json id={record['id']}"
        district_id = record["collegioPlurinominale"]
        if district_id not in circoscrizione_of_district:
            errors.append(
                f"{label}: collegioPlurinominale {district_id!r} non corrisponde a nessun "
                "collegio in districts_plurinominali_camera.geojson"
            )
            continue
        covered.add(district_id)
        if record.get("circoscrizione") != circoscrizione_of_district[district_id]:
            errors.append(
                f"{label}: circoscrizione {record.get('circoscrizione')!r} != "
                f"{circoscrizione_of_district[district_id]!r} del collegio plurinominale {district_id}"
            )

    uncovered = set(circoscrizione_of_district) - covered
    if uncovered:
        errors.append(
            f"districts_plurinominali_camera.geojson: {len(uncovered)} collegi senza alcun "
            f"deputato collegato: {sorted(uncovered)}"
        )

    if not errors:
        print(
            f"OK: collegi plurinominali coerenti — {len(covered)}/{len(circoscrizione_of_district)} "
            "collegi Camera con almeno un deputato, circoscrizioni concordi"
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
        payload = json.loads(VOTES_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return errors + [f"{VOTES_PATH.relative_to(ROOT)}: JSON non valido: {error}"]

    if not isinstance(payload, dict) or set(payload.keys()) != {"events", "positions"}:
        return errors + [
            f"{VOTES_PATH.relative_to(ROOT)}: atteso un oggetto con esattamente le chiavi "
            "'events' e 'positions' (schema Fase 20)"
        ]

    events = payload["events"]
    positions = payload["positions"]
    if not isinstance(events, list) or not events:
        errors.append(f"{VOTES_PATH.relative_to(ROOT)}: 'events' deve essere un array non vuoto")
        return errors
    if not isinstance(positions, list) or not positions:
        errors.append(f"{VOTES_PATH.relative_to(ROOT)}: 'positions' deve essere un array non vuoto")
        return errors

    seen_event_ids = set()
    for index, event in enumerate(events):
        label = f"votes.json event #{index} (id={event.get('id', '?') if isinstance(event, dict) else '?'})"
        if not isinstance(event, dict):
            errors.append(f"{label}: non è un oggetto JSON")
            continue
        missing = REQUIRED_VOTE_EVENT_KEYS - event.keys()
        if missing:
            errors.append(f"{label}: chiavi mancanti: {sorted(missing)}")
            continue
        event_id = event["id"]
        if not isinstance(event_id, str) or not event_id:
            errors.append(f"{label}: 'id' deve essere una stringa non vuota")
        elif event_id in seen_event_ids:
            errors.append(f"{label}: id evento duplicato")
        else:
            seen_event_ids.add(event_id)
        if not isinstance(event["title"], str) or not event["title"].strip():
            errors.append(f"{label}: 'title' deve essere una stringa non vuota")
        if not isinstance(event["date"], str) or not DATE_RE.fullmatch(event["date"]):
            errors.append(f"{label}: 'date' deve essere nel formato yyyy-MM-dd, trovato {event.get('date')!r}")
        if event["result"] not in VALID_VOTE_RESULTS:
            errors.append(f"{label}: 'result' non valido: {event['result']!r}")
        source_url = event["sourceUrl"]
        if source_url is not None and not (isinstance(source_url, str) and source_url.startswith("http")):
            errors.append(f"{label}: 'sourceUrl' deve essere null o un URL http(s)")
        if event["provenance"] not in VALID_PROVENANCE:
            errors.append(f"{label}: 'provenance' non valido: {event['provenance']!r}")

    seen_position_ids = set()
    position_event_ids = set()
    for index, position in enumerate(positions):
        label = f"votes.json position #{index} (id={position.get('id', '?') if isinstance(position, dict) else '?'})"
        if not isinstance(position, dict):
            errors.append(f"{label}: non è un oggetto JSON")
            continue
        missing = REQUIRED_VOTE_POSITION_KEYS - position.keys()
        if missing:
            errors.append(f"{label}: chiavi mancanti: {sorted(missing)}")
            continue
        position_id = position["id"]
        if not isinstance(position_id, str) or not position_id:
            errors.append(f"{label}: 'id' deve essere una stringa non vuota")
        elif position_id in seen_position_ids:
            errors.append(f"{label}: id posizione duplicato")
        else:
            seen_position_ids.add(position_id)
        event_ref = position["voteEventId"]
        if not isinstance(event_ref, str) or not event_ref:
            errors.append(f"{label}: 'voteEventId' deve essere una stringa non vuota")
        else:
            position_event_ids.add(event_ref)
        if not isinstance(position["representativeId"], str) or not position["representativeId"]:
            errors.append(f"{label}: 'representativeId' deve essere una stringa non vuota")
        if position["vote"] not in VALID_VOTE_CHOICES:
            errors.append(f"{label}: 'vote' non valido: {position['vote']!r}")

    # Phase 20 invariants: every position references an existing event and
    # every event has at least one position — the distinct voteEventId set
    # must be exactly the event-id set. (Each id mapping to exactly one
    # (date, title, result, sourceUrl) tuple is structural in this schema:
    # the tuple lives once, on the event record, and event ids are unique.)
    if not errors:
        orphaned = position_event_ids - seen_event_ids
        if orphaned:
            errors.append(f"votes.json: voteEventId senza evento corrispondente: {sorted(orphaned)}")
        unreferenced = seen_event_ids - position_event_ids
        if unreferenced:
            errors.append(f"votes.json: eventi senza alcuna posizione: {sorted(unreferenced)}")

    if not errors:
        print(
            f"OK: {len(positions)} posizioni in {len(events)} votazioni valide in "
            f"{VOTES_PATH.relative_to(ROOT)} ({file_size / 1024:.0f} KB)"
        )

    return errors


def validate_votes_reference_representatives():
    """Every vote.representativeId must exist in representatives.json — the
    referential-integrity invariant reinstated at full strength now that
    votes.json ships real, non-empty data (see docs/v2/04-votes-import.md).
    Only meaningful once both files already passed their own structural
    checks, so main() only calls this when they were both clean."""
    representatives = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    positions = json.loads(VOTES_PATH.read_text(encoding="utf-8"))["positions"]
    representative_ids = {r["id"] for r in representatives}

    unresolved = sorted({p["representativeId"] for p in positions} - representative_ids)
    if unresolved:
        return [f"votes.json: representativeId non trovati in representatives.json: {unresolved}"]

    distinct_representatives_with_votes = {p["representativeId"] for p in positions}
    print(
        f"OK: integrità referenziale voti coerente — {len(positions)} posizioni, "
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
        all_errors += validate_circoscrizione()
        all_errors += validate_collegio_plurinominale()

    if not representative_errors and not vote_errors:
        all_errors += validate_votes_reference_representatives()

    if all_errors:
        print(f"ERRORE: {len(all_errors)} problema/i:", file=sys.stderr)
        for error in all_errors:
            print(f"  - {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
