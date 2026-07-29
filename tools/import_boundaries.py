#!/usr/bin/env python3
"""Transforms an ogr2ogr-produced intermediate GeoJSON into the final
schema-v2 boundaries file for one layer, selected via --chamber:

- Camera uninominale (tools/raw/camera_collegi_uninominali_wgs84.geojson ->
  Politici/Data/districts.geojson)
- Senato uninominale (tools/raw/senato_collegi_uninominali_wgs84.geojson ->
  Politici/Data/districts_senato.geojson)
- Camera plurinominale (Phase 25 —
  tools/raw/camera_collegi_plurinominali_wgs84.geojson ->
  Politici/Data/districts_plurinominali_camera.geojson)
- Senato plurinominale (Phase 25 ->
  Politici/Data/districts_plurinominali_senato.geojson)

Offline — makes no network calls and doesn't invoke ogr2ogr itself; that's
tools/build_boundaries.sh's job (`make boundaries` / `make boundaries-senato`
/ `make boundaries-plurinominale-camera` / `make boundaries-plurinominale-senato`),
which calls this script right after the shapefile conversion.

Also prints a per-feature vertex report and enforces
MAX_VERTICES_PER_FEATURE (Phase 14), alongside the pre-existing
MAX_OUTPUT_BYTES whole-file budget — both gates run before anything is
written, so a violation of either leaves the target file untouched.

Design notes — Camera:

- id = CU20_COD, cast to string (it's an integer in the shapefile).
- name = CU20_DEN, unmodified.
- chamber = "Camera" — capitalized, matching Chamber's Swift raw value
  exactly (Politici/Models/District.swift declares `case camera = "Camera"`,
  case-sensitive; "camera" lowercase would fail to decode).
- collegioType = "uninominale".
- subCode = CU20_C1 — the within-circoscrizione uninominale sequence suffix
  (e.g. "U01"), literally the tail of CU20_DEN ("Piemonte 1 - U01").
- circoscrizione = the CU20_DEN prefix before " - U0N" (e.g. "Piemonte 1",
  "Lazio 2", "Sardegna"). The shapefile has no dedicated circoscrizione
  field (confirmed via full `ogrinfo -so` schema dump — see
  docs/v2/03-linkage-report.md); CU20_DEN's prefix was verified to match,
  1:1 across all 147 rows with zero exceptions, the 28 official Camera
  electoral circoscrizioni established by D.Lgs. 177/2020.
- provenance = "official", sourceName = "ISTAT".

Design notes — Senato (Phase 16, see docs/v3/15-senato-exploration.md for
the exploration that established these, and docs/v3/16-senato-boundaries.md
for this implementation):

- id = "S" + SU20_COD. The plain numeric SU20_COD collides with 32 of the
  147 Camera ids (verified in Phase 15) — the "S" prefix is applied
  unconditionally, not just where a collision exists, so a Senato id is
  never ambiguous with a Camera one regardless of which specific codes
  happen to collide this year. Camera ids are NEVER modified — 147 existing
  representatives.json districtId references depend on them exactly as
  shipped.
- chamber = "Senato".
- collegioType = "uninominale" (Senato's own uninominale layer, distinct
  from its plurinominale layer, which this script never touches).
- regione = the SU20_DEN prefix before " - U0N" (e.g. "Piemonte",
  "Lombardia", "Sardegna") — one of Italy's 20 UNSPLIT administrative
  regions. Deliberately NOT called "circoscrizione": Phase 15 verified
  Senato's SU20_DEN grouping is a different concept from Camera's
  circoscrizione (which splits larger regions into multiple numbered
  circoscrizioni) — reusing that field name for Senato would misrepresent
  the source structure. circoscrizione is left null for every Senato
  feature; regione is left null for every Camera feature.
- subCode = SU20_C1, same shape as Camera's.
- provenance = "official", sourceName = "ISTAT" (same source dataset as
  Camera — see tools/SOURCES.md's single "ISTAT — Collegi Elettorali"
  entry, which covers both layers).

Design notes — plurinominale (Phase 25, see docs/v4/25-plurinominale-geography.md
and the GO-PLURI probe tools/probes/probe_plurinominale_geography.py):

- Two more layers from the SAME ISTAT D.Lgs. 177/2020 release: Camera
  (CAMERA_CollegiPLURINOMINALI_2020 -> districts_plurinominali_camera.geojson,
  49 collegi) and Senato (SENATO_CollegiPLURINOMINALI_2020 ->
  districts_plurinominali_senato.geojson, 26 collegi).
- collegioType = "plurinominale" (config-driven now, was hardcoded).
- id = "CP" + CP20_COD (Camera) / "SP" + SP20_COD (Senato), applied
  UNCONDITIONALLY. The probe collision-checked all 75 new ids against the
  221 shipped uninominale ids and the two new files against each other: zero
  collisions, 296 unique ids across all four boundary files. (Camera
  uninominale ids are bare numerics like "120101"; Senato uninominale are
  "S"+digit like "S120001"; "CP"/"SP"+digit never alias either or each
  other.)
- grouping = circoscrizione (Camera, e.g. "Piemonte 1") / regione (Senato,
  e.g. "Piemonte"), parsed from the DEN prefix exactly like the uninominale
  layers — the same "{grouping} - {subCode}" structure, with subCode now a
  "P0N" plurinominale code instead of "U0N".
- Each raw layer carries ONE extra null-attribute placeholder feature
  (OBJECTID=1, COD=0, DEN/C1 null): a residual polygon over the territory
  with no plurinominale collegio — Valle d'Aosta for Camera, Valle d'Aosta +
  Trentino-Alto Adige for Senato (Q1, confirmed by POP_2011 cross-check
  against Regioni_Senato_2020 in the probe). It is SKIPPED here
  (expected_placeholders), not written as a collegio; finding a different
  count of placeholders fails the import loudly.
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparql_client import stamp_fetch_metadata_if_absent  # noqa: E402

ROOT = Path(__file__).parent.parent
RAW_DIR = Path(__file__).parent / "raw"
DATA_DIR = ROOT / "Politici" / "Data"

SOURCE_NAME = "ISTAT"
MAX_OUTPUT_BYTES = 3 * 1024 * 1024

# Per-feature vertex budget (Phase 14 — planned alongside the byte budget
# above but never implemented or measured until then; see
# docs/v3/14-pipeline-hardening.md). Calibrated against the Camera geometry
# at the 1000m ogr2ogr simplify tolerance: observed maximum 695 vertices,
# well under 1500 with more than 2x headroom, so the originally-planned 1500
# was kept. Phase 16 re-measured against the Senato geometry at the same
# tolerance (observed maximum 800 vertices — see
# docs/v3/16-senato-boundaries.md) and confirmed the same gate value still
# holds with headroom for both chambers. Phase 25 re-measured against BOTH
# plurinominale layers at the same 1000m tolerance (observed maximum 994
# vertices — Sardegna P01, for both Camera and Senato — and ~749 KB / ~595 KB
# output, all well under both gates; see the GO-PLURI probe and
# docs/v4/25-plurinominale-geography.md) and again found no reason to
# diverge. Re-measure and reconsider if any layer's SIMPLIFY_TOLERANCE_METERS
# (tools/build_boundaries.sh) changes.
MAX_VERTICES_PER_FEATURE = 1500

# Both layers come from the same D.Lgs. 177/2020 ISTAT release, downloaded
# together in one manual batch — tools/SOURCES.md records a single "ISTAT —
# Collegi Elettorali" source entry covering both. They therefore share one
# fetch-metadata key ("istat"), not two: using a distinct key for Senato
# would make stamp_fetch_metadata_if_absent stamp it with *today's* date on
# this phase's first run, which would be wrong — the real retrieval date is
# 2026-07-18 (Phase 13), already recorded under the "istat" key from the
# Camera import. Reusing that key keeps both chambers' manifest entries
# reading the same, correct, historical date.
FETCH_METADATA_KEY = "istat"

# Each config declares its layer's fields, the schema-v2 collegioType it
# emits, its id prefix, and how many null-attribute placeholder rows to skip
# (0 for the uninominale layers, 1 for each plurinominale layer — see the
# plurinominale design note above).
CHAMBER_CONFIGS = {
    "camera": {
        "intermediate_path": RAW_DIR / "camera_collegi_uninominali_wgs84.geojson",
        "output_path": DATA_DIR / "districts.geojson",
        "sample_backup_path": DATA_DIR / "districts.sample.geojson",
        "code_field": "CU20_COD",
        "denom_field": "CU20_DEN",
        "subcode_field": "CU20_C1",
        "chamber_value": "Camera",
        "collegio_type": "uninominale",
        "expected_count": 147,
        "expected_placeholders": 0,
        "id_prefix": "",
        "grouping_property": "circoscrizione",
    },
    "senato": {
        "intermediate_path": RAW_DIR / "senato_collegi_uninominali_wgs84.geojson",
        "output_path": DATA_DIR / "districts_senato.geojson",
        "sample_backup_path": None,
        "code_field": "SU20_COD",
        "denom_field": "SU20_DEN",
        "subcode_field": "SU20_C1",
        "chamber_value": "Senato",
        "collegio_type": "uninominale",
        "expected_count": 74,
        "expected_placeholders": 0,
        "id_prefix": "S",
        "grouping_property": "regione",
    },
    "camera-plurinominale": {
        "intermediate_path": RAW_DIR / "camera_collegi_plurinominali_wgs84.geojson",
        "output_path": DATA_DIR / "districts_plurinominali_camera.geojson",
        "sample_backup_path": None,
        "code_field": "CP20_COD",
        "denom_field": "CP20_DEN",
        "subcode_field": "CP20_C1",
        "chamber_value": "Camera",
        "collegio_type": "plurinominale",
        "expected_count": 49,
        "expected_placeholders": 1,
        "id_prefix": "CP",
        "grouping_property": "circoscrizione",
    },
    "senato-plurinominale": {
        "intermediate_path": RAW_DIR / "senato_collegi_plurinominali_wgs84.geojson",
        "output_path": DATA_DIR / "districts_plurinominali_senato.geojson",
        "sample_backup_path": None,
        "code_field": "SP20_COD",
        "denom_field": "SP20_DEN",
        "subcode_field": "SP20_C1",
        "chamber_value": "Senato",
        "collegio_type": "plurinominale",
        "expected_count": 26,
        "expected_placeholders": 1,
        "id_prefix": "SP",
        "grouping_property": "regione",
    },
}


def count_vertices(geometry):
    """Counts coordinate pairs (vertices) in a Polygon or MultiPolygon
    geometry, summing every ring (exterior + holes) — the same unit
    Douglas-Peucker simplification reduces, so it's a direct measure of what
    tools/build_boundaries.sh's SIMPLIFY_TOLERANCE_METERS controls."""
    geometry_type = geometry.get("type")
    coordinates = geometry.get("coordinates", [])
    if geometry_type == "Polygon":
        return sum(len(ring) for ring in coordinates)
    if geometry_type == "MultiPolygon":
        return sum(len(ring) for polygon in coordinates for ring in polygon)
    return 0


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--chamber", choices=sorted(CHAMBER_CONFIGS), default="camera",
        help="quale layer ISTAT importare (default: camera)",
    )
    args = parser.parse_args()
    config = CHAMBER_CONFIGS[args.chamber]

    intermediate_path = config["intermediate_path"]
    output_path = config["output_path"]
    code_field = config["code_field"]
    denom_field = config["denom_field"]
    subcode_field = config["subcode_field"]
    chamber_value = config["chamber_value"]
    collegio_type = config["collegio_type"]
    expected_count = config["expected_count"]
    expected_placeholders = config["expected_placeholders"]
    id_prefix = config["id_prefix"]
    grouping_property = config["grouping_property"]

    if not intermediate_path.exists():
        fail(
            f"manca {intermediate_path.relative_to(ROOT)} — esegui 'make boundaries' o "
            "'make boundaries-senato' (non questo script direttamente), che genera prima "
            "il GeoJSON intermedio con ogr2ogr"
        )

    try:
        raw = json.loads(intermediate_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{intermediate_path.relative_to(ROOT)} non è JSON valido: {error}")

    raw_features = raw.get("features", [])
    if not raw_features:
        fail(f"{intermediate_path.relative_to(ROOT)} non contiene feature")

    features = []
    seen_ids = set()
    skipped_placeholders = 0
    for raw_feature in raw_features:
        props = raw_feature.get("properties", {})
        geometry = raw_feature.get("geometry")
        if geometry is None:
            fail(f"feature senza geometria: {props}")

        raw_code = str(props.get(code_field, "")).strip()
        district_id = f"{id_prefix}{raw_code}"
        name = (props.get(denom_field) or "").strip()
        sub_code = (props.get(subcode_field) or "").strip() or None

        # A null-attribute placeholder row (code 0 / no denominazione) is the
        # residual polygon over territory with no plurinominale collegio (see
        # the plurinominale design note): skip exactly the expected number,
        # counting them, and fail later if the count is wrong — never write it
        # as a collegio, never silently drop an unexpected one.
        if raw_code in ("", "0") or not name:
            skipped_placeholders += 1
            continue
        if district_id in seen_ids:
            fail(f"id duplicato dopo la conversione: {district_id}")
        seen_ids.add(district_id)

        # grouping value = denom_field prefix before " - <subCode>" — same
        # structural parse for both chambers; verified against the official
        # circoscrizioni (Camera) / regioni (Senato) lists — see
        # docs/v2/03-linkage-report.md and docs/v3/15-senato-exploration.md.
        if sub_code and name.endswith(f" - {sub_code}"):
            grouping_value = name[: -(len(sub_code) + 3)].strip()
        else:
            fail(f"{denom_field} '{name}' non termina con ' - {sub_code}' come atteso: impossibile derivare {grouping_property}")

        properties = {
            "id": district_id,
            "name": name,
            "chamber": chamber_value,
            "collegioType": collegio_type,
            "subCode": sub_code,
            # Only the grouping key this chamber actually uses is present —
            # not both keys with the unused one set to null. Camera features
            # therefore carry the exact same property key set as before this
            # phase (byte-identical output); Senato features carry "regione"
            # instead of "circoscrizione", never both. Swift's District model
            # decodes either as an absent-tolerant Optional, so a missing key
            # behaves identically to an explicit null there.
            grouping_property: grouping_value,
            "provenance": "official",
            "sourceName": SOURCE_NAME,
        }

        features.append({"type": "Feature", "properties": properties, "geometry": geometry})

    features.sort(key=lambda f: f["properties"]["id"])

    if skipped_placeholders != expected_placeholders:
        fail(
            f"saltate {skipped_placeholders} righe segnaposto (id/nome assenti), "
            f"attese {expected_placeholders} — layer sorgente inatteso, nulla è stato scritto"
        )
    if len(features) != expected_count:
        fail(f"attesi {expected_count} collegi, trovati {len(features)} — controlla il layer sorgente")

    vertex_counts = [
        (f["properties"]["id"], f["properties"]["name"], count_vertices(f["geometry"]))
        for f in features
    ]
    vertex_counts.sort(key=lambda entry: entry[2], reverse=True)

    print(f"Report vertici per collegio ({len(vertex_counts)} feature, soglia {MAX_VERTICES_PER_FEATURE}):")
    for district_id, name, vertex_count in vertex_counts:
        print(f"  {district_id}\t{vertex_count}\t{name}")

    max_id, max_name, max_vertex_count = vertex_counts[0]
    print(f"Massimo: {max_id} ({max_name}) — {max_vertex_count} vertici")

    if max_vertex_count > MAX_VERTICES_PER_FEATURE:
        fail(
            f"il collegio {max_id} ({max_name}) ha {max_vertex_count} vertici, "
            f"supera il limite di {MAX_VERTICES_PER_FEATURE} per feature — aumenta "
            "SIMPLIFY_TOLERANCE_METERS in tools/build_boundaries.sh (nulla è stato scritto)"
        )

    collection = {"type": "FeatureCollection", "features": features}
    serialized = json.dumps(collection, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    serialized_bytes = serialized.encode("utf-8")

    if len(serialized_bytes) > MAX_OUTPUT_BYTES:
        fail(
            f"il file risultante sarebbe {len(serialized_bytes) / 1024 / 1024:.2f} MB, "
            "supera il limite di 3 MB — aumenta SIMPLIFY_TOLERANCE_METERS in "
            "tools/build_boundaries.sh (nulla è stato scritto)"
        )

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    sample_backup_path = config["sample_backup_path"]
    if sample_backup_path is not None and output_path.exists() and not sample_backup_path.exists():
        sample_backup_path.write_text(output_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {output_path.name} preservato come {sample_backup_path.name}")

    output_path.write_bytes(serialized_bytes)
    # if_absent, not the unconditional stamp_fetch_metadata: this script
    # runs offline against an already-downloaded shapefile every time
    # `make boundaries`/`make boundaries-senato` runs, so it must not
    # advance "istat"'s recorded fetch date on every re-run — only the
    # first time (Phase 14 fix; a prior unconditional stamp here silently
    # drifted the shipped retrievedAt forward on every rebuild — see
    # docs/v3/14-pipeline-hardening.md).
    stamp_fetch_metadata_if_absent(FETCH_METADATA_KEY)

    size_kb = len(serialized_bytes) / 1024
    print(f"OK: {len(features)} collegi scritti in {output_path.relative_to(ROOT)} ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
