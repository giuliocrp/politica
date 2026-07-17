#!/usr/bin/env python3
"""Merges tools/raw/*_sparql.json into Data/representatives.json (schema v2).

Offline — reads only cached files under tools/raw/; run tools/fetch_camera.py
and tools/fetch_senato.py first (or `make fetch`).

Design notes / judgment calls (none of these are specified field-by-field in
the raw SPARQL data, so they're documented here rather than left implicit):

- Person id: Camera persona URIs already end in a "p"-prefixed segment
  (.../persona.rdf/p307394 -> "p307394"); Senato senatore URIs do not
  (.../senatore/32 -> "32"), so "s" is prepended here to get "s32".
- party = sigla for Camera (Camera's query returns both; sigla is the
  canonical short id per the acquisition brief). Senato's gruppi query has
  no ?sigla variable at all, so party = nomeGruppo there — there's nothing
  to prefer over, and inventing an acronym would be fabrication.
- parliamentaryGroup = nomeGruppo, kept exactly as returned. Camera's
  nomeGruppo values are truncated at "(" in the source data (a known
  upstream quirk) — this script does not attempt to "fix" truncated text,
  since guessing the missing suffix would itself be fabrication.
- photoName is set to the app's existing SF Symbol fallback
  ("person.crop.circle.fill"), NOT the real ?foto URL. The app renders
  photoName via SwiftUI's Image(systemName:); pointing it at a real HTTP(S)
  photo URL would either render nothing (systemName lookup failure) or
  require the app to fetch remote images at runtime, which conflicts with
  the project's local-first/no-networking-code constraint. Real photo URLs
  ARE preserved in tools/raw/ for a possible future phase that revisits
  this trade-off explicitly.
- districtId is always null (the acquisition brief is explicit: mapping
  collegio/commissione text to this app's 5 sample districts is out of
  scope here). The raw ?collegio text is likewise not carried into
  representatives.json, since there's no field for it in the current
  schema and it would be misleading to imply it's used for anything.
- attendanceRate and stableSourceId are always null — nothing in the raw
  data maps to them without inventing a meaning for stableSourceId that
  the acquisition brief never defined.
- legislature = "XIX" for every record — not fetched as a field (Camera's
  query doesn't even select it), but it's exactly what both queries are
  scoped to via their WHERE clauses, so stating it isn't fabrication.
- electionType is omitted; Representative's tolerant decoder defaults an
  absent/null electionType to .sconosciuto, which is honest here — this
  data doesn't tell us uninominale vs. plurinominale vs. estero.
- Camera cognome/nome arrive upper-cased ("AIELLO", "DAVIDE"); Senato's do
  not ("Alberti Casellati", "Maria Elisabetta"). Camera names are
  title-cased here purely for consistent display — this can mis-capitalize
  apostrophed or multi-word surnames (e.g. "D'Alessandro" -> "D'alessandro"),
  a known, disclosed imperfection, not silently swept under the rug.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
RAW_DIR = Path(__file__).parent / "raw"
DATA_DIR = ROOT / "Politici" / "Data"
OUTPUT_PATH = DATA_DIR / "representatives.json"
SAMPLE_BACKUP_PATH = DATA_DIR / "representatives.sample.json"

FALLBACK_PHOTO_NAME = "person.crop.circle.fill"
LEGISLATURE = "XIX"


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def load_raw(filename):
    path = RAW_DIR / filename
    if not path.exists():
        fail(
            f"manca {path.relative_to(ROOT)} — esegui prima 'make fetch' "
            "(o tools/fetch_camera.py / tools/fetch_senato.py)"
        )
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} non è JSON valido: {error}")


def bindings_of(payload):
    return payload.get("results", {}).get("bindings", [])


def value(binding, var):
    entry = binding.get(var)
    if entry is None:
        return None
    v = entry.get("value")
    return v if v else None


def id_segment(uri):
    return uri.rstrip("/").rsplit("/", 1)[-1]


def title_case_italian(name):
    # See module docstring: a known-imperfect but non-fabricating normalization.
    return name.title() if name else name


def import_camera():
    payload = load_raw("camera_deputati_sparql.json")
    people = {}
    order = []

    for binding in bindings_of(payload):
        persona_uri = value(binding, "persona")
        if not persona_uri:
            continue
        person_id = id_segment(persona_uri)

        if person_id not in people:
            order.append(person_id)
            people[person_id] = {
                "id": person_id,
                "cognome": value(binding, "cognome"),
                "nome": value(binding, "nome"),
                "sigla": value(binding, "sigla"),
                "nomeGruppo": value(binding, "nomeGruppo"),
                "sourceUrl": persona_uri,
                "committees": set(),
            }

        commissione = value(binding, "commissione")
        if commissione:
            people[person_id]["committees"].add(commissione)

    records = []
    for person_id in order:
        p = people[person_id]
        nome = title_case_italian(p["nome"]) or ""
        cognome = title_case_italian(p["cognome"]) or ""
        records.append(
            {
                "id": person_id,
                "name": f"{nome} {cognome}".strip(),
                "chamber": "Camera",
                "districtId": None,
                "party": p["sigla"] or p["nomeGruppo"] or "",
                "parliamentaryGroup": p["nomeGruppo"] or p["sigla"] or "",
                "committees": sorted(p["committees"]),
                "attendanceRate": None,
                "photoName": FALLBACK_PHOTO_NAME,
                "provenance": "official",
                "legislature": LEGISLATURE,
                "electionType": None,
                "stableSourceId": None,
                "sourceUrl": p["sourceUrl"],
            }
        )
    return records


def import_senato():
    senatori_payload = load_raw("senato_senatori_sparql.json")
    gruppi_payload = load_raw("senato_gruppi_sparql.json")
    commissioni_payload = load_raw("senato_commissioni_sparql.json")

    people = {}
    order = []

    for binding in bindings_of(senatori_payload):
        senatore_uri = value(binding, "senatore")
        if not senatore_uri:
            continue
        # The senatori query has no active-mandate filter (unlike the Camera
        # query's MINUS on ended group memberships), so it returns everyone
        # who was ever part of legislature XIX — including senators whose
        # mandate has since ended (resignation, death, replacement). A
        # non-null fineMandato means that's the case; including them would
        # present former/deceased senators as current, which is exactly the
        # kind of "presenting stale data as current" this app must avoid.
        if value(binding, "fineMandato"):
            continue
        person_id = "s" + id_segment(senatore_uri)
        if person_id in people:
            continue
        order.append(person_id)
        people[person_id] = {
            "id": person_id,
            "nome": value(binding, "nome"),
            "cognome": value(binding, "cognome"),
            "sourceUrl": senatore_uri,
            "nomeGruppo": None,
            "committees": set(),
        }

    for binding in bindings_of(gruppi_payload):
        senatore_uri = value(binding, "senatore")
        if not senatore_uri:
            continue
        person_id = "s" + id_segment(senatore_uri)
        nome_gruppo = value(binding, "nomeGruppo")
        if person_id in people and nome_gruppo and not people[person_id]["nomeGruppo"]:
            people[person_id]["nomeGruppo"] = nome_gruppo

    for binding in bindings_of(commissioni_payload):
        senatore_uri = value(binding, "senatore")
        if not senatore_uri:
            continue
        person_id = "s" + id_segment(senatore_uri)
        dizione = value(binding, "dizione")
        if person_id in people and dizione:
            people[person_id]["committees"].add(dizione)

    records = []
    for person_id in order:
        p = people[person_id]
        # Senato's raw names are already properly cased — no title-casing needed.
        name = f"{p['nome'] or ''} {p['cognome'] or ''}".strip()
        # Senato's gruppi query has no ?sigla at all — nothing to prefer over.
        party = p["nomeGruppo"] or ""
        records.append(
            {
                "id": person_id,
                "name": name,
                "chamber": "Senato",
                "districtId": None,
                "party": party,
                "parliamentaryGroup": party,
                "committees": sorted(p["committees"]),
                "attendanceRate": None,
                "photoName": FALLBACK_PHOTO_NAME,
                "provenance": "official",
                "legislature": LEGISLATURE,
                "electionType": None,
                "stableSourceId": None,
                "sourceUrl": p["sourceUrl"],
            }
        )
    return records


def main():
    camera_records = import_camera()
    senato_records = import_senato()
    all_records = camera_records + senato_records

    if not all_records:
        fail("nessun record importato da tools/raw/ — controlla i file grezzi prima di sovrascrivere Data/")

    ids = [r["id"] for r in all_records]
    if len(ids) != len(set(ids)):
        duplicates = sorted({i for i in ids if ids.count(i) > 1})
        fail(f"id duplicati dopo l'unione: {duplicates}")

    all_records.sort(key=lambda r: r["id"])

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if OUTPUT_PATH.exists() and not SAMPLE_BACKUP_PATH.exists():
        SAMPLE_BACKUP_PATH.write_text(OUTPUT_PATH.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {OUTPUT_PATH.name} preservato come {SAMPLE_BACKUP_PATH.name}")

    serialized = json.dumps(all_records, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    OUTPUT_PATH.write_text(serialized, encoding="utf-8")

    camera_count = len(camera_records)
    senato_count = len(senato_records)
    print(
        f"OK: {len(all_records)} rappresentanti scritti in "
        f"{OUTPUT_PATH.relative_to(ROOT)} ({camera_count} Camera, {senato_count} Senato)"
    )


if __name__ == "__main__":
    main()
