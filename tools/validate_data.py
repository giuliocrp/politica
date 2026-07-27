#!/usr/bin/env python3
"""Structural validation of Data/representatives.json, Data/districts.geojson,
Data/votes.json, Data/memberships_camera.json, and Data/comuni.json.

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
MEMBERSHIPS_PATH = ROOT / "Politici" / "Data" / "memberships_camera.json"
COMUNI_PATH = ROOT / "Politici" / "Data" / "comuni.json"

# Phase 28 (docs/v4/28-membership-history.md): memberships_camera.json is
# {"schemaVersion":1,"memberships":[...]} — per-deputy parliamentary-group
# intervals, half-open [start, end) with end==null for the single current
# interval. The composed id ("m_<personId>_<startYYYYMMDD>") is minted by
# import_memberships.py because the source ocd:aderisce node is a blank node.
REQUIRED_MEMBERSHIP_KEYS = {
    "id",
    "representativeId",
    "groupName",
    "groupSigla",
    "start",
    "end",
}
MEMBERSHIPS_SCHEMA_VERSION = 1
# Measured 108,917 B (106.4 KiB) at import for the 468 XIX intervals (Phase
# 28); the 256 KiB gate is a coarse drift backstop (~2.4x headroom, room for
# legitimate mid-legislature group-switching) — the precise scope guard is
# the referential-integrity check that every membership's deputy is a shipped
# Camera deputy, which no size bound could replace.
MAX_MEMBERSHIPS_FILE_BYTES = 256 * 1024

# Phase 30 (docs/v4/30-comuni-geocoding.md): comuni.json is
# {"schemaVersion":1,"comuni":[{"name","province","lat","lon"},...]} — one
# interior point per Italian comune (ISTAT UT_Collegi2020, 7,904 comuni),
# for offline comune-name -> coordinate -> collegio geocoding. Measured 568.2
# KiB; the 768 KiB gate is a coarse drift backstop (~35% headroom). Coordinate
# bounds are Italy's real extremes (Lampedusa 35.51 .. Predoi 47.04 lat;
# Bardonecchia 6.72 .. Salento 18.45 lon) with margin — a sanity check that a
# reprojection/axis-order accident can't slip a Null-Island coordinate through.
REQUIRED_COMUNE_KEYS = {"name", "province", "lat", "lon"}
COMUNI_SCHEMA_VERSION = 1
MAX_COMUNI_FILE_BYTES = 768 * 1024
COMUNI_LAT_RANGE = (35.0, 47.5)
COMUNI_LON_RANGE = (6.3, 19.0)
# The ISTAT-2020 comune count is 7,904; the window is a drift backstop only.
COMUNI_MIN_COUNT = 7000
COMUNI_MAX_COUNT = 8500

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

# Phase 26 (docs/v4/26-senato-regione.md): "regione" is a Senato-only,
# field-conditional key — the mirror of Camera's "circoscrizione". Present on
# the 196 elective senators (those with mandate "elettivo"), absent (not null)
# on the 5 a-vita senators and on every Camera record. "Estero" is the pinned
# regione value for the 2 overseas-constituency senators; domestic values are
# checked against districts_senato.geojson's own regione set in
# validate_regione() rather than a hardcoded list. The approved cross-chamber
# electionType mapping (osr:tipoElezione -> ElectionType, user-gated in the
# phase report) yields this Senato distribution — a drift detector against the
# GO-REG gate evidence, with the 5 a-vita carrying a null electionType.
EXPECTED_SENATO_WITH_REGIONE = 196
REGIONE_ESTERO = "Estero"
EXPECTED_SENATO_UNINOMINALE = 73
EXPECTED_SENATO_PLURINOMINALE = 121
EXPECTED_SENATO_ESTERO = 2

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
            # "regione" (Phase 26): Senato-only, field-conditional — present on
            # elective senators (mandate "elettivo"), absent (not null) on the
            # 5 a-vita. When present it must be a non-empty string; its
            # cross-file value is checked in validate_regione().
            has_regione = "regione" in record
            if has_regione and (not isinstance(record["regione"], str) or not record["regione"].strip()):
                errors.append(f"{label}: 'regione' deve essere una stringa non vuota")
            if record.get("mandate") == MANDATE_ELETTIVO and not has_regione:
                errors.append(f"{label}: senatore elettivo senza 'regione'")
            if record.get("mandate") in (MANDATE_A_VITA, MANDATE_EMERITO) and has_regione:
                errors.append(f"{label}: senatore a vita con 'regione' — deve essere assente")
        elif record["chamber"] == "Camera":
            if "mandate" in record:
                errors.append(f"{label}: chiave 'mandate' presente su un record Camera — deve essere assente")
            # "regione" is Senato-only (Phase 26) — the mirror of "mandate".
            if "regione" in record:
                errors.append(f"{label}: chiave 'regione' presente su un record Camera — deve essere assente")
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

    # Phase 26: the approved Senato electionType distribution (drift detector
    # against the GO-REG gate evidence) and the regione<->"Estero"
    # correspondence — the set of senators whose regione is "Estero" must be
    # exactly the set with electionType "estero" (each identifies the other,
    # no drift), mirroring Camera's Phase 18 estero check. The 5 a-vita carry a
    # null electionType (they aren't elected).
    senato_with_regione = sum(1 for r in senato_records if "regione" in r)
    if senato_with_regione != EXPECTED_SENATO_WITH_REGIONE:
        errors.append(
            f"representatives.json: senatori con 'regione' = {senato_with_regione}, atteso "
            f"{EXPECTED_SENATO_WITH_REGIONE} (i 196 elettivi — vedi docs/v4/26-senato-regione.md)"
        )
    sen_uninominale = sum(1 for r in senato_records if r["electionType"] == "uninominale")
    sen_plurinominale = sum(1 for r in senato_records if r["electionType"] == "plurinominale")
    sen_estero = sum(1 for r in senato_records if r["electionType"] == "estero")
    for expected, actual, label_name in (
        (EXPECTED_SENATO_UNINOMINALE, sen_uninominale, "uninominale"),
        (EXPECTED_SENATO_PLURINOMINALE, sen_plurinominale, "plurinominale"),
        (EXPECTED_SENATO_ESTERO, sen_estero, "estero"),
    ):
        if actual != expected:
            errors.append(
                f"representatives.json: senatori {label_name} = {actual}, atteso {expected} "
                "(vedi docs/v4/26-senato-regione.md)"
            )
    sen_estero_regione_ids = {r["id"] for r in senato_records if r.get("regione") == REGIONE_ESTERO}
    sen_estero_type_ids = {r["id"] for r in senato_records if r["electionType"] == "estero"}
    if sen_estero_regione_ids != sen_estero_type_ids:
        errors.append(
            "representatives.json: insieme regione='Estero' != insieme electionType='estero' (Senato) "
            f"(solo regione: {sorted(sen_estero_regione_ids - sen_estero_type_ids)}, "
            f"solo tipo: {sorted(sen_estero_type_ids - sen_estero_regione_ids)})"
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
        print(
            f"  senatori per tipo: uninominale {sen_uninominale}  "
            f"plurinominale {sen_plurinominale}  estero {sen_estero}  "
            f"(a-vita/null {senato_count - sen_uninominale - sen_plurinominale - sen_estero})"
        )
        print(f"  senatori con regione: {senato_with_regione}")

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


def validate_regione():
    """Phase 26 cross-file checks (docs/v4/26-senato-regione.md), the Senato
    mirror of validate_circoscrizione(): every senator's regione (when present)
    is either "Estero" or one of districts_senato.geojson's own shipped regione
    values (the reference set is the real data, not a hardcoded list), and
    every *linked* uninominale senator's regione equals their collegio's
    shipped property exactly (GO-REG condition (c)). Only meaningful once both
    files passed their own structural checks, so main() gates the call."""
    errors = []

    records = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    collection = json.loads(DISTRICTS_SENATO_PATH.read_text(encoding="utf-8"))
    regione_of_district = {
        f["properties"]["id"]: f["properties"]["regione"]
        for f in collection["features"]
        if f["properties"]["chamber"] == "Senato" and f["properties"]["collegioType"] == "uninominale"
    }
    valid_values = set(regione_of_district.values()) | {REGIONE_ESTERO}

    observed = set()
    for record in records:
        if record["chamber"] != "Senato" or "regione" not in record:
            continue
        label = f"representatives.json id={record['id']}"
        regione = record["regione"]
        observed.add(regione)
        if regione not in valid_values:
            errors.append(
                f"{label}: regione {regione!r} non è né 'Estero' né una "
                "regione di districts_senato.geojson"
            )
        district_id = record["districtId"]
        if district_id is not None and regione != regione_of_district.get(district_id):
            errors.append(
                f"{label}: regione {regione!r} != "
                f"{regione_of_district.get(district_id)!r} del collegio {district_id}"
            )

    if not errors:
        print(
            f"OK: regioni senatori coerenti — {len(observed)} valori osservati "
            f"({len(valid_values)} ammessi: {len(valid_values) - 1} da districts_senato.geojson + 'Estero')"
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


def _parse_iso(value):
    """A yyyy-MM-dd string -> datetime.date, or None if malformed. Used only
    for interval ordering/overlap checks; the format itself is validated
    separately via DATE_RE so a malformed value is reported, not silently
    skipped."""
    from datetime import date as _date
    try:
        parts = value.split("-")
        return _date(int(parts[0]), int(parts[1]), int(parts[2]))
    except (ValueError, IndexError, AttributeError):
        return None


def validate_memberships():
    """Structural + per-deputy interval invariants for
    memberships_camera.json (Phase 28 — docs/v4/28-membership-history.md):
    schema/byte gate, parseable dates, half-open [start, end) validity, and
    exactly one open (end==null) interval per deputy with non-overlapping
    intervals. The cross-file reconciliation with representatives.json lives
    in validate_memberships_reference_representatives() (called only when both
    files were independently clean)."""
    errors = []

    if not MEMBERSHIPS_PATH.exists():
        return [f"{MEMBERSHIPS_PATH.relative_to(ROOT)}: file non trovato — esegui prima 'make import'"]

    file_size = MEMBERSHIPS_PATH.stat().st_size
    if file_size > MAX_MEMBERSHIPS_FILE_BYTES:
        errors.append(
            f"{MEMBERSHIPS_PATH.relative_to(ROOT)}: {file_size / 1024:.1f} KiB, "
            f"supera il limite di {MAX_MEMBERSHIPS_FILE_BYTES / 1024:.0f} KiB"
        )

    try:
        payload = json.loads(MEMBERSHIPS_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return errors + [f"{MEMBERSHIPS_PATH.relative_to(ROOT)}: JSON non valido: {error}"]

    if not isinstance(payload, dict) or set(payload.keys()) != {"schemaVersion", "memberships"}:
        return errors + [
            f"{MEMBERSHIPS_PATH.relative_to(ROOT)}: atteso un oggetto con esattamente le chiavi "
            "'schemaVersion' e 'memberships' (Fase 28)"
        ]
    if payload["schemaVersion"] != MEMBERSHIPS_SCHEMA_VERSION:
        errors.append(
            f"{MEMBERSHIPS_PATH.relative_to(ROOT)}: schemaVersion "
            f"{payload['schemaVersion']!r}, atteso {MEMBERSHIPS_SCHEMA_VERSION}"
        )

    memberships = payload["memberships"]
    if not isinstance(memberships, list) or not memberships:
        errors.append(f"{MEMBERSHIPS_PATH.relative_to(ROOT)}: 'memberships' deve essere un array non vuoto")
        return errors

    seen_ids = set()
    by_person = {}
    for index, m in enumerate(memberships):
        label = f"memberships_camera.json #{index} (id={m.get('id', '?') if isinstance(m, dict) else '?'})"
        if not isinstance(m, dict):
            errors.append(f"{label}: non è un oggetto JSON")
            continue
        missing = REQUIRED_MEMBERSHIP_KEYS - m.keys()
        if missing:
            errors.append(f"{label}: chiavi mancanti: {sorted(missing)}")
            continue
        mid = m["id"]
        if not isinstance(mid, str) or not mid:
            errors.append(f"{label}: 'id' deve essere una stringa non vuota")
        elif mid in seen_ids:
            errors.append(f"{label}: id duplicato")
        else:
            seen_ids.add(mid)
        for key in ("representativeId", "groupName", "groupSigla"):
            if not isinstance(m[key], str) or not m[key].strip():
                errors.append(f"{label}: '{key}' deve essere una stringa non vuota")
        if not isinstance(m["start"], str) or not DATE_RE.fullmatch(m["start"]) or _parse_iso(m["start"]) is None:
            errors.append(f"{label}: 'start' deve essere una data yyyy-MM-dd valida, trovato {m.get('start')!r}")
        end = m["end"]
        if end is not None and (not isinstance(end, str) or not DATE_RE.fullmatch(end) or _parse_iso(end) is None):
            errors.append(f"{label}: 'end' deve essere null o una data yyyy-MM-dd valida, trovato {end!r}")
        # Half-open validity: a closed interval must have start < end.
        if isinstance(m["start"], str) and isinstance(end, str):
            s, e = _parse_iso(m["start"]), _parse_iso(end)
            if s is not None and e is not None and not (s < e):
                errors.append(f"{label}: intervallo non valido: start {m['start']} >= end {end}")
        if isinstance(m.get("representativeId"), str):
            by_person.setdefault(m["representativeId"], []).append(m)

    if errors:
        return errors

    # Per-deputy invariants: exactly one open interval; non-overlapping under
    # half-open [start, end) (a closed interval must end no later than the
    # next interval starts; only the latest-starting interval may be open).
    for pid, intervals in by_person.items():
        opens = [m for m in intervals if m["end"] is None]
        if len(opens) != 1:
            errors.append(f"memberships_camera.json: deputato {pid} ha {len(opens)} intervalli aperti, atteso 1")
        ordered = sorted(intervals, key=lambda m: (m["start"], m["id"]))
        for earlier, later in zip(ordered, ordered[1:]):
            if earlier["end"] is None:
                errors.append(f"memberships_camera.json: deputato {pid}: un intervallo aperto ne precede un altro")
                break
            if _parse_iso(earlier["end"]) > _parse_iso(later["start"]):
                errors.append(
                    f"memberships_camera.json: deputato {pid}: intervalli sovrapposti "
                    f"({earlier['start']}..{earlier['end']} / {later['start']}..)"
                )
                break

    if not errors:
        open_count = sum(1 for m in memberships if m["end"] is None)
        print(
            f"OK: {len(memberships)} intervalli di adesione ({open_count} aperti) per "
            f"{len(by_person)} deputati in {MEMBERSHIPS_PATH.relative_to(ROOT)} "
            f"({file_size / 1024:.1f} KiB)"
        )

    return errors


def validate_memberships_reference_representatives():
    """Cross-file invariants tying memberships_camera.json to
    representatives.json — the Phase 28 reconciliation (only called when both
    files passed their own structural checks):
      - every membership's deputy is a shipping Camera deputy;
      - every Camera deputy has >=1 interval;
      - the single open interval's group reconciles with the shipped gruppo
        (sigla equality + parliamentaryGroup prefix-comparison, the
        documented truncation-at-"(" normalization)."""
    representatives = json.loads(REPRESENTATIVES_PATH.read_text(encoding="utf-8"))
    camera = {r["id"]: r for r in representatives if r.get("chamber") == "Camera"}
    memberships = json.loads(MEMBERSHIPS_PATH.read_text(encoding="utf-8"))["memberships"]

    by_person = {}
    for m in memberships:
        by_person.setdefault(m["representativeId"], []).append(m)

    errors = []
    unknown = sorted(set(by_person) - set(camera))
    if unknown:
        errors.append(f"memberships_camera.json: representativeId non deputati Camera: {unknown}")
    missing = sorted(set(camera) - set(by_person))
    if missing:
        errors.append(f"memberships_camera.json: {len(missing)} deputati Camera senza intervalli: {missing[:10]}")
    if errors:
        return errors

    for pid, intervals in by_person.items():
        opens = [m for m in intervals if m["end"] is None]
        if len(opens) != 1:
            continue  # already reported by validate_memberships()
        current = opens[0]
        rep = camera[pid]
        rep_sigla = (rep.get("party") or "").strip()
        rep_group = (rep.get("parliamentaryGroup") or "").strip()
        open_name = (current["groupName"] or "").strip()
        if current["groupSigla"] != rep_sigla:
            errors.append(
                f"memberships_camera.json: deputato {pid} sigla aperta {current['groupSigla']!r} "
                f"!= party {rep_sigla!r}"
            )
        elif not (rep_group.startswith(open_name) or open_name.startswith(rep_group)):
            errors.append(
                f"memberships_camera.json: deputato {pid} gruppo aperto {open_name!r} "
                f"non coerente (prefix) con parliamentaryGroup {rep_group!r}"
            )

    if not errors:
        switchers = sum(1 for iv in by_person.values() if len(iv) > 1)
        print(
            f"OK: integrità referenziale adesioni coerente — {len(memberships)} intervalli, "
            f"{len(by_person)} deputati, {switchers} con più gruppi nel tempo"
        )
    return errors


def validate_comuni():
    """Structural + sanity invariants for comuni.json (Phase 30 —
    docs/v4/30-comuni-geocoding.md): schema/byte gate, exactly {name,
    province, lat, lon} per entry with correct types, non-empty name/province,
    coordinates inside Italy's bounds, (name, province) unique (the app's
    Comune id and the homonym-by-province disambiguation depend on it), and a
    coarse count window. The comune -> collegio resolution itself is proven by
    the offline full-table dry run in tools/probes/probe_comuni_centroids.py
    and pinned by the app's integration tests, not re-run here (this validator
    is deliberately osgeo-free)."""
    errors = []

    if not COMUNI_PATH.exists():
        return [f"{COMUNI_PATH.relative_to(ROOT)}: file non trovato — esegui prima 'make comuni'"]

    file_size = COMUNI_PATH.stat().st_size
    if file_size > MAX_COMUNI_FILE_BYTES:
        errors.append(
            f"{COMUNI_PATH.relative_to(ROOT)}: {file_size / 1024:.1f} KiB, "
            f"supera il limite di {MAX_COMUNI_FILE_BYTES / 1024:.0f} KiB"
        )

    try:
        payload = json.loads(COMUNI_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return errors + [f"{COMUNI_PATH.relative_to(ROOT)}: JSON non valido: {error}"]

    if not isinstance(payload, dict) or set(payload.keys()) != {"schemaVersion", "comuni"}:
        return errors + [
            f"{COMUNI_PATH.relative_to(ROOT)}: atteso un oggetto con esattamente le chiavi "
            "'schemaVersion' e 'comuni' (Fase 30)"
        ]
    if payload["schemaVersion"] != COMUNI_SCHEMA_VERSION:
        errors.append(
            f"{COMUNI_PATH.relative_to(ROOT)}: schemaVersion "
            f"{payload['schemaVersion']!r}, atteso {COMUNI_SCHEMA_VERSION}"
        )

    comuni = payload["comuni"]
    if not isinstance(comuni, list) or not comuni:
        errors.append(f"{COMUNI_PATH.relative_to(ROOT)}: 'comuni' deve essere un array non vuoto")
        return errors

    if not (COMUNI_MIN_COUNT <= len(comuni) <= COMUNI_MAX_COUNT):
        errors.append(
            f"{COMUNI_PATH.relative_to(ROOT)}: {len(comuni)} comuni fuori dalla finestra "
            f"attesa [{COMUNI_MIN_COUNT}, {COMUNI_MAX_COUNT}]"
        )

    lat_lo, lat_hi = COMUNI_LAT_RANGE
    lon_lo, lon_hi = COMUNI_LON_RANGE
    seen_keys = set()
    for index, c in enumerate(comuni):
        label = f"comuni.json #{index}"
        if not isinstance(c, dict):
            errors.append(f"{label}: non è un oggetto JSON")
            continue
        if set(c.keys()) != REQUIRED_COMUNE_KEYS:
            errors.append(f"{label}: chiavi {sorted(c.keys())}, attese {sorted(REQUIRED_COMUNE_KEYS)}")
            continue
        for key in ("name", "province"):
            if not isinstance(c[key], str) or not c[key].strip():
                errors.append(f"{label}: '{key}' deve essere una stringa non vuota")
        for key in ("lat", "lon"):
            if not isinstance(c[key], (int, float)) or isinstance(c[key], bool):
                errors.append(f"{label}: '{key}' deve essere numerico, trovato {c[key]!r}")
        if isinstance(c["lat"], (int, float)) and not (lat_lo <= c["lat"] <= lat_hi):
            errors.append(f"{label} ({c.get('name')}): lat {c['lat']} fuori dai limiti Italia {COMUNI_LAT_RANGE}")
        if isinstance(c["lon"], (int, float)) and not (lon_lo <= c["lon"] <= lon_hi):
            errors.append(f"{label} ({c.get('name')}): lon {c['lon']} fuori dai limiti Italia {COMUNI_LON_RANGE}")
        if isinstance(c.get("name"), str) and isinstance(c.get("province"), str):
            key = (c["name"], c["province"])
            if key in seen_keys:
                errors.append(f"{label}: coppia (name, province) duplicata: {key}")
            else:
                seen_keys.add(key)

    if not errors:
        homonyms = len(seen_keys) - len({name for name, _ in seen_keys})
        print(
            f"OK: {len(comuni)} comuni in {COMUNI_PATH.relative_to(ROOT)} "
            f"({file_size / 1024:.1f} KiB) — {homonyms} nomi omonimi disambiguati per provincia"
        )

    return errors


def main():
    representative_errors = validate_representatives()
    district_errors = validate_districts()
    vote_errors = validate_votes()
    membership_errors = validate_memberships()
    comuni_errors = validate_comuni()
    all_errors = representative_errors + district_errors + vote_errors + membership_errors + comuni_errors

    if not representative_errors and not district_errors:
        all_errors += validate_linkage()
        all_errors += validate_circoscrizione()
        all_errors += validate_regione()
        all_errors += validate_collegio_plurinominale()

    if not representative_errors and not vote_errors:
        all_errors += validate_votes_reference_representatives()

    if not representative_errors and not membership_errors:
        all_errors += validate_memberships_reference_representatives()

    if all_errors:
        print(f"ERRORE: {len(all_errors)} problema/i:", file=sys.stderr)
        for error in all_errors:
            print(f"  - {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
