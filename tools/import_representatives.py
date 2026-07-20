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
- attendanceRate is always null — nothing in the raw data maps to it.
  stableSourceId is the bare numeric id from the source URI, stripped of
  this app's own "p"/"s" prefix (e.g. sourceUrl
  ".../persona.rdf/p307394" -> stableSourceId "307394"; ".../senatore/1103"
  -> "1103") — the source system's own identifier, decoupled from this
  app's id-prefixing convention, verified unique across all records before
  adopting this as an invariant (no Camera/Senato numeric-id collisions).
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

Phase 8 addition — collegio uninominale linkage (see
docs/v2/03-linkage-report.md for the full investigation):

- electionType/districtId are now derived, not always null. ?tipoElezione
  ("maggioritario" / "maggioritario suppletiva" / "proporzionale") on the
  election resource classifies each mandate; ?collegioUninominale (the
  election's dcterms:spatial, present ONLY for maggioritario(-suppletiva)
  mandates) gives the exact uninominale collegio as "CIRCOSCRIZIONE - U0N"
  — structurally identical to districts.geojson's circoscrizione+subCode
  pair once both sides are case/accent-normalized. Estero mandates (the 4
  overseas macro-constituencies) are tipoElezione "proporzionale" with no
  spatial value; they're distinguished from domestic plurinominale by their
  ?collegio (dc:coverage) literal matching one of the 4 known Estero names.
- The MINUS on ?mandato ocd:endDate in the query itself already restricts
  to the currently in-office mandate per person (see the .rq file's own
  comment) — no additional current-mandate filtering happens here.
Phase 17 addition — Senato mandates + collegio uninominale linkage (see
docs/v3/17-senato-mandates.md; the v2-era "Senato is untouched" rule is
superseded):

- Every senator record carries "mandate" = the verbatim osr:tipoMandato
  literal (KNOWN_TIPO_MANDATO); Camera records omit the key entirely.
- Senators whose osr:tipoElezione starts with "Eletto uninominale" (73 of
  201 currently-serving at import time) are linked to their real Senato
  collegio via osr:collegioElezione — parse rule and the single
  Valle d'Aosta naming alias per docs/v3/15b-senato-link-probe.md §4.
  Proporzionale/estero/life senators keep districtId null, mirroring
  Camera's plurinominale/estero pattern.
- Senators' electionType stays null even though osr:tipoElezione now
  exists in the cache: mapping "Eletto proporzionale ..." onto Camera's
  "plurinominale" case would be a new cross-chamber semantic best-fit
  that hasn't been decided — tipoElezione is consumed at import time for
  linkage eligibility only (flagged as an open decision in the Phase 17
  report).
"""

import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).parent.parent
RAW_DIR = Path(__file__).parent / "raw"
DATA_DIR = ROOT / "Politici" / "Data"
OUTPUT_PATH = DATA_DIR / "representatives.json"
SAMPLE_BACKUP_PATH = DATA_DIR / "representatives.sample.json"
DISTRICTS_PATH = DATA_DIR / "districts.geojson"
DISTRICTS_SENATO_PATH = DATA_DIR / "districts_senato.geojson"

FALLBACK_PHOTO_NAME = "person.crop.circle.fill"
LEGISLATURE = "XIX"

# The 4 Camera Estero (overseas) macro-constituencies — proporzionale-only,
# no uninominale component. Verified via live SPARQL introspection (see
# docs/v2/03-linkage-report.md): every current proporzionale mandate whose
# ?collegio (dc:coverage) is one of these has no dcterms:spatial at all.
ESTERO_COVERAGE_VALUES = {
    "EUROPA",
    "AMERICA MERIDIONALE",
    "AMERICA SETTENTRIONALE E CENTRALE",
    "AFRICA ASIA OCEANIA ANTARTIDE",
}

# Camera mandate election-type literals that represent a collegio
# uninominale seat (an original majoritarian win, or a by-election
# replacement — both represent the same collegio going forward).
UNINOMINALE_TIPO_ELEZIONE = {"maggioritario", "maggioritario suppletiva"}

MIN_LINKED_COLLEGI = 133  # 90% of 147 — see docs/v2/03-linkage-report.md

# Phase 17 Senato collegio linkage (docs/v3/15b-senato-link-probe.md §4):
# a senator links to a collegio iff their osr:tipoElezione starts with this
# prefix — exactly those senators carry osr:collegioElezione (verified:
# count(uninominale) == count(collegioElezione present) == 73, not a
# partial overlap). Proporzionale/estero/life senators keep districtId null,
# mirroring Camera's plurinominale/estero pattern.
SENATO_UNINOMINALE_PREFIX = "Eletto uninominale"

# collegioElezione's structure: "{REGIONE} - {U0N}" optionally followed by
# " (city detail)" — the detail can itself contain " - ", so strip it first.
SENATO_COLLEGIO_RE = re.compile(r"^(?P<regione>.+) - (?P<sub>U\d+)$")

# The single verified naming variant between the two sources: SPARQL gives
# the Italian-only "VALLE D'AOSTA", ISTAT's SU20_DEN is the bilingual
# "Valle d'aosta/Vallée d'Aoste". That region has exactly one Senato
# collegio, so this one-entry alias is unambiguous. Any OTHER mismatch
# fails the import loudly — extending this table requires the same
# per-entry verification the 15b probe did, not ad hoc fuzzy matching.
SENATO_REGIONE_ALIASES = {
    "VALLE D'AOSTA": "Valle d'aosta/Vallée d'Aoste".upper(),
}

MIN_LINKED_SENATO = 66  # ceil(0.9 × 73) — same 90% convention as MIN_LINKED_COLLEGI

# The complete osr:tipoMandato vocabulary observed in the Senato source
# (verbatim literals — see docs/v3/15-senato-exploration.md §7a). These are
# written to representatives.json exactly as-is; the app decodes them via
# MandateType's matching raw values. Anything outside this set fails the
# import loudly rather than being best-guessed or written as "sconosciuto".
KNOWN_TIPO_MANDATO = {
    "elettivo",
    "a vita, di nomina del Presidente della Repubblica",
    "di diritto e a vita, Presidente emerito della Repubblica",
}


def normalize_circoscrizione(name):
    """Case/accent/punctuation-insensitive key for matching a circoscrizione
    name across the two independent sources (ISTAT shapefile denominazione
    vs. Camera SPARQL dcterms:spatial). Also strips a bilingual "/Secondo
    Nome" suffix (e.g. districts.geojson's "Valle d'aosta/Vallée d'Aoste" vs
    SPARQL's Italian-only "VALLE D'AOSTA") — verified this doesn't cause any
    false collision across the 28 circoscrizioni (see the linkage report)."""
    name = name.split("/", 1)[0]
    name = unicodedata.normalize("NFKD", name)
    name = "".join(c for c in name if not unicodedata.combining(c))
    name = name.upper()
    return re.sub(r"[^A-Z0-9]+", " ", name).strip()


def load_uninominale_index():
    """(circoscrizione_norm, subCode) -> CU20_COD for every shipping Camera
    uninominale collegio. Fails loudly if districts.geojson is missing or
    doesn't carry the Phase 8 circoscrizione/subCode properties — run
    'make boundaries' first."""
    if not DISTRICTS_PATH.exists():
        fail(f"manca {DISTRICTS_PATH.relative_to(ROOT)} — esegui prima 'make boundaries'")

    collection = json.loads(DISTRICTS_PATH.read_text(encoding="utf-8"))
    index = {}
    all_ids = set()
    for feature in collection.get("features", []):
        props = feature.get("properties", {})
        if props.get("chamber") != "Camera" or props.get("collegioType") != "uninominale":
            continue
        circoscrizione = props.get("circoscrizione")
        sub_code = props.get("subCode")
        district_id = props.get("id")
        if not circoscrizione or not sub_code or not district_id:
            fail(
                f"{DISTRICTS_PATH.relative_to(ROOT)}: collegio {district_id!r} senza "
                "circoscrizione/subCode — esegui 'make boundaries' con la pipeline aggiornata"
            )
        key = (normalize_circoscrizione(circoscrizione), sub_code)
        if key in index:
            fail(f"chiave (circoscrizione, subCode) duplicata dopo la normalizzazione: {key}")
        index[key] = district_id
        all_ids.add(district_id)
    return index, all_ids


def load_senato_uninominale_index():
    """(regione_uppercased, subCode) -> "S"-prefixed id for every shipping
    Senato uninominale collegio, plus the full id set. Unlike Camera's
    accent-stripping normalize_circoscrizione, this match is deliberately
    strict (plain .upper() equality + the one disclosed alias): the 15b
    probe verified 73/73 resolve this way, and a looser normalization would
    silently absorb future naming drift instead of surfacing it."""
    if not DISTRICTS_SENATO_PATH.exists():
        fail(f"manca {DISTRICTS_SENATO_PATH.relative_to(ROOT)} — esegui prima 'make boundaries-senato'")

    collection = json.loads(DISTRICTS_SENATO_PATH.read_text(encoding="utf-8"))
    index = {}
    all_ids = set()
    for feature in collection.get("features", []):
        props = feature.get("properties", {})
        if props.get("chamber") != "Senato" or props.get("collegioType") != "uninominale":
            continue
        regione = props.get("regione")
        sub_code = props.get("subCode")
        district_id = props.get("id")
        if not regione or not sub_code or not district_id:
            fail(
                f"{DISTRICTS_SENATO_PATH.relative_to(ROOT)}: collegio {district_id!r} senza "
                "regione/subCode — esegui 'make boundaries-senato' con la pipeline aggiornata"
            )
        key = (regione.upper(), sub_code)
        if key in index:
            fail(f"chiave (regione, subCode) duplicata in {DISTRICTS_SENATO_PATH.name}: {key}")
        index[key] = district_id
        all_ids.add(district_id)
    return index, all_ids


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


def import_camera(uninominale_index, all_uninominale_ids):
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
                "collegio": value(binding, "collegio"),
                "tipoElezione": value(binding, "tipoElezione"),
                "collegioUninominale": value(binding, "collegioUninominale"),
            }

        commissione = value(binding, "commissione")
        if commissione:
            people[person_id]["committees"].add(commissione)

    linked_ids = {}  # district_id -> person_id, to catch >1 deputy per collegio
    unmatched = []  # maggioritario(-suppletiva) mandates with no structural match
    by_election_holders = []  # currently-serving deputies who arrived via a by-election

    records = []
    for person_id in order:
        p = people[person_id]
        nome = title_case_italian(p["nome"]) or ""
        cognome = title_case_italian(p["cognome"]) or ""
        full_name = f"{nome} {cognome}".strip()

        district_id = None
        election_type = None
        tipo = p["tipoElezione"]

        if tipo in UNINOMINALE_TIPO_ELEZIONE:
            election_type = "uninominale"
            spatial = p["collegioUninominale"]
            if spatial and " - " in spatial:
                circ, sub_code = spatial.rsplit(" - ", 1)
                district_id = uninominale_index.get((normalize_circoscrizione(circ), sub_code))
            if district_id is None:
                unmatched.append(
                    {"name": full_name, "personId": person_id, "tipoElezione": tipo, "spatial": spatial}
                )
            else:
                if district_id in linked_ids:
                    fail(
                        f"collegio {district_id} già collegato a "
                        f"{linked_ids[district_id]!r}: doppio deputato uninominale corrente "
                        f"trovato anche per {person_id!r} — controlla i dati sorgente"
                    )
                linked_ids[district_id] = person_id
                if tipo == "maggioritario suppletiva":
                    by_election_holders.append({"name": full_name, "districtId": district_id})
        elif tipo == "proporzionale":
            coverage = (p["collegio"] or "").strip().upper()
            election_type = "estero" if coverage in ESTERO_COVERAGE_VALUES else "plurinominale"
        # else: tipo is None (no ?el bound at all) — electionType stays None,
        # honestly reflecting "we don't know" (decodes to .sconosciuto).

        records.append(
            {
                "id": person_id,
                "name": full_name,
                "chamber": "Camera",
                "districtId": district_id,
                "party": p["sigla"] or p["nomeGruppo"] or "",
                "parliamentaryGroup": p["nomeGruppo"] or p["sigla"] or "",
                "committees": sorted(p["committees"]),
                "attendanceRate": None,
                "photoName": FALLBACK_PHOTO_NAME,
                "provenance": "official",
                "legislature": LEGISLATURE,
                "electionType": election_type,
                "stableSourceId": person_id[1:],  # strip the leading "p"
                "sourceUrl": p["sourceUrl"],
            }
        )

    vacant_ids = sorted(all_uninominale_ids - set(linked_ids))
    linkage_report = {
        "linkedCount": len(linked_ids),
        "totalUninominale": len(all_uninominale_ids),
        "unmatched": unmatched,
        "vacant": vacant_ids,
        "byElection": by_election_holders,
    }
    return records, linkage_report


def link_senato_collegio(person_id, name, collegio_elezione, index):
    """Resolves one osr:collegioElezione literal to an "S"-prefixed district
    id via the 15b-verified parse rule. Any failure here (unparseable
    literal, no index match beyond the disclosed alias) means the source
    moved — fail loudly, never guess."""
    if not collegio_elezione:
        fail(
            f"senatore {person_id} ({name}): tipoElezione uninominale ma "
            "collegioElezione assente — la sorgente è cambiata (vedi "
            "docs/v3/15b-senato-link-probe.md §3), rivedi prima di importare"
        )
    prefix = collegio_elezione.split(" (", 1)[0]
    match = SENATO_COLLEGIO_RE.match(prefix)
    if not match:
        fail(
            f"senatore {person_id} ({name}): collegioElezione {collegio_elezione!r} "
            "non corrisponde al formato atteso '{REGIONE} - U0N' — rivedi la regola di parsing"
        )
    regione = match.group("regione").upper()
    regione = SENATO_REGIONE_ALIASES.get(regione, regione)
    district_id = index.get((regione, match.group("sub")))
    if district_id is None:
        fail(
            f"senatore {person_id} ({name}): ({regione!r}, {match.group('sub')!r}) non "
            "corrisponde a nessun collegio in districts_senato.geojson — variante di "
            "denominazione nuova? Va verificata e documentata, non aggiunta d'ufficio agli alias"
        )
    return district_id


def import_senato(uninominale_index, all_uninominale_ids):
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
        # tipoMandato is a mandatory triple in senato_senatori.rq, so a
        # missing value would mean the query/source structure changed out
        # from under us — fail loudly either way (missing or unknown),
        # never write a guessed or "sconosciuto" mandate.
        tipo_mandato = value(binding, "tipoMandato")
        if tipo_mandato not in KNOWN_TIPO_MANDATO:
            fail(
                f"senatore {person_id}: tipoMandato {tipo_mandato!r} non è nel "
                "vocabolario noto (vedi KNOWN_TIPO_MANDATO / "
                "docs/v3/15-senato-exploration.md) — sorgente cambiata, rivedi prima di importare"
            )
        order.append(person_id)
        people[person_id] = {
            "id": person_id,
            "nome": value(binding, "nome"),
            "cognome": value(binding, "cognome"),
            "sourceUrl": senatore_uri,
            "nomeGruppo": None,
            "committees": set(),
            "tipoMandato": tipo_mandato,
            "tipoElezione": value(binding, "tipoElezione"),
            "collegioElezione": value(binding, "collegioElezione"),
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

    linked_ids = {}  # district_id -> person_id, to catch >1 senator per collegio
    records = []
    for person_id in order:
        p = people[person_id]
        # Senato's raw names are already properly cased — no title-casing needed.
        name = f"{p['nome'] or ''} {p['cognome'] or ''}".strip()
        # Senato's gruppi query has no ?sigla at all — nothing to prefer over.
        party = p["nomeGruppo"] or ""

        district_id = None
        if (p["tipoElezione"] or "").startswith(SENATO_UNINOMINALE_PREFIX):
            district_id = link_senato_collegio(person_id, name, p["collegioElezione"], uninominale_index)
            if district_id in linked_ids:
                fail(
                    f"collegio {district_id} già collegato a {linked_ids[district_id]!r}: "
                    f"doppio senatore uninominale corrente trovato anche per {person_id!r} — "
                    "controlla i dati sorgente"
                )
            linked_ids[district_id] = person_id

        records.append(
            {
                "id": person_id,
                "name": name,
                "chamber": "Senato",
                "districtId": district_id,
                "party": party,
                "parliamentaryGroup": party,
                "committees": sorted(p["committees"]),
                "attendanceRate": None,
                "photoName": FALLBACK_PHOTO_NAME,
                "provenance": "official",
                "legislature": LEGISLATURE,
                "electionType": None,
                # Senato-only key (Phase 17), carried verbatim from
                # osr:tipoMandato. Camera records don't get a null here —
                # the key is absent entirely, same chamber-conditional-key
                # convention as districts' circoscrizione/regione.
                "mandate": p["tipoMandato"],
                "stableSourceId": person_id[1:],  # strip the leading "s"
                "sourceUrl": p["sourceUrl"],
            }
        )

    linkage_report = {
        "linkedCount": len(linked_ids),
        "totalUninominale": len(all_uninominale_ids),
        "vacant": sorted(all_uninominale_ids - set(linked_ids)),
    }
    return records, linkage_report


def main():
    uninominale_index, all_uninominale_ids = load_uninominale_index()
    camera_records, linkage_report = import_camera(uninominale_index, all_uninominale_ids)
    senato_index, all_senato_ids = load_senato_uninominale_index()
    senato_records, senato_linkage = import_senato(senato_index, all_senato_ids)
    all_records = camera_records + senato_records

    if not all_records:
        fail("nessun record importato da tools/raw/ — controlla i file grezzi prima di sovrascrivere Data/")

    ids = [r["id"] for r in all_records]
    if len(ids) != len(set(ids)):
        duplicates = sorted({i for i in ids if ids.count(i) > 1})
        fail(f"id duplicati dopo l'unione: {duplicates}")

    stable_ids = [r["stableSourceId"] for r in all_records]
    if len(stable_ids) != len(set(stable_ids)):
        duplicates = sorted({i for i in stable_ids if stable_ids.count(i) > 1})
        fail(f"stableSourceId duplicati dopo l'unione: {duplicates}")

    mandate_counts = {}
    for record in senato_records:
        mandate_counts[record["mandate"]] = mandate_counts.get(record["mandate"], 0) + 1
    print("Mandati Senato (tipoMandato, verbatim):")
    for tipo in sorted(mandate_counts):
        print(f"  {tipo!r}: {mandate_counts[tipo]}")

    print(
        f"Collegamento collegio uninominale -> deputato: {linkage_report['linkedCount']}/"
        f"{linkage_report['totalUninominale']}"
    )
    if linkage_report["unmatched"]:
        print(f"  non risolti (join strutturale fallito): {len(linkage_report['unmatched'])}")
        for u in linkage_report["unmatched"]:
            print(f"    - {u['name']} ({u['personId']}): tipoElezione={u['tipoElezione']!r} spatial={u['spatial']!r}")
    if linkage_report["vacant"]:
        print(f"  collegi senza deputato corrente: {len(linkage_report['vacant'])}: {linkage_report['vacant']}")
    if linkage_report["byElection"]:
        print(f"  deputati subentrati per elezione suppletiva: {len(linkage_report['byElection'])}")
        for be in linkage_report["byElection"]:
            print(f"    - {be['name']} (collegio {be['districtId']})")

    if linkage_report["linkedCount"] < MIN_LINKED_COLLEGI:
        fail(
            f"solo {linkage_report['linkedCount']}/{linkage_report['totalUninominale']} collegi collegati "
            f"(minimo richiesto: {MIN_LINKED_COLLEGI}, il 90% di {linkage_report['totalUninominale']}) — "
            "nessun file scritto. Rivedi docs/v2/03-linkage-report.md e la logica di join prima di rieseguire."
        )

    print(
        f"Collegamento collegio uninominale -> senatore: {senato_linkage['linkedCount']}/"
        f"{senato_linkage['totalUninominale']}"
    )
    if senato_linkage["vacant"]:
        print(
            f"  collegi Senato senza senatore corrente: {len(senato_linkage['vacant'])}: "
            f"{senato_linkage['vacant']}"
        )

    if senato_linkage["linkedCount"] < MIN_LINKED_SENATO:
        fail(
            f"solo {senato_linkage['linkedCount']} senatori collegati "
            f"(minimo richiesto: {MIN_LINKED_SENATO}, il 90% dei 73 seggi uninominali "
            "verificati in docs/v3/15b-senato-link-probe.md) — nessun file scritto. "
            "Rivedi la logica di join prima di rieseguire."
        )

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
