#!/usr/bin/env python3
"""Transforms the ogr2ogr-produced intermediate GeoJSON
(tools/raw/camera_collegi_uninominali_wgs84.geojson) into
Politici/Data/districts.geojson with schema-v2 properties.

Offline — makes no network calls and doesn't invoke ogr2ogr itself; that's
tools/build_boundaries.sh's job (`make boundaries`), which calls this script
right after the shapefile conversion.

Also prints a per-feature vertex report and enforces
MAX_VERTICES_PER_FEATURE (Phase 14), alongside the pre-existing
MAX_OUTPUT_BYTES whole-file budget — both gates run before anything is
written, so a violation of either leaves Politici/Data/districts.geojson
untouched.

Design notes:

- id = CU20_COD, cast to string (it's an integer in the shapefile).
- name = CU20_DEN, unmodified.
- chamber = "Camera" — capitalized, matching Chamber's Swift raw value
  exactly (Politici/Models/District.swift declares `case camera = "Camera"`,
  case-sensitive; "camera" lowercase would fail to decode).
- collegioType = "uninominale" — this script only ever processes the Camera
  uninominali layer (Senato boundaries are out of scope for this phase).
- subCode = CU20_C1 — the within-circoscrizione uninominale sequence suffix
  (e.g. "U01"), literally the tail of CU20_DEN ("Piemonte 1 - U01").
- circoscrizione = the CU20_DEN prefix before " - U0N" (e.g. "Piemonte 1",
  "Lazio 2", "Sardegna"). The shapefile has no dedicated circoscrizione
  field (confirmed via full `ogrinfo -so` schema dump — see
  docs/v2/03-linkage-report.md); CU20_DEN's prefix was verified to match,
  1:1 across all 147 rows with zero exceptions, the 28 official Camera
  electoral circoscrizioni established by D.Lgs. 177/2020 (Piemonte 1/2,
  Lombardia 1-4, Veneto 1/2, Lazio 1/2, Campania 1/2, Sicilia 1/2, and one
  circoscrizione per each other region) — see the linkage report for the
  verification. This replaces the previous, misleading "region" property
  (which held CU20_C1 — a sub-collegio suffix, not a region).
- provenance = "official", sourceName = "ISTAT" — both known facts about
  this pipeline, not fetched fields.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparql_client import stamp_fetch_metadata_if_absent  # noqa: E402

ROOT = Path(__file__).parent.parent
INTERMEDIATE_PATH = Path(__file__).parent / "raw" / "camera_collegi_uninominali_wgs84.geojson"
DATA_DIR = ROOT / "Politici" / "Data"
OUTPUT_PATH = DATA_DIR / "districts.geojson"
SAMPLE_BACKUP_PATH = DATA_DIR / "districts.sample.geojson"

SOURCE_NAME = "ISTAT"
MAX_OUTPUT_BYTES = 3 * 1024 * 1024

# Per-feature vertex budget (Phase 14 — this was planned alongside the byte
# budget above but never implemented or measured; see
# docs/v3/14-pipeline-hardening.md). Calibrated against the actual shipped
# geometry at the 1000m ogr2ogr simplify tolerance: the observed maximum is
# 695 vertices (feature 200004), well under 1500 with more than 2x headroom,
# so the originally-planned 1500 is kept rather than tightened. Re-measure
# and reconsider this constant if SIMPLIFY_TOLERANCE_METERS in
# tools/build_boundaries.sh ever changes.
MAX_VERTICES_PER_FEATURE = 1500


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
    if not INTERMEDIATE_PATH.exists():
        fail(
            f"manca {INTERMEDIATE_PATH.relative_to(ROOT)} — esegui 'make boundaries' "
            "(non questo script direttamente), che genera prima il GeoJSON intermedio con ogr2ogr"
        )

    try:
        raw = json.loads(INTERMEDIATE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{INTERMEDIATE_PATH.relative_to(ROOT)} non è JSON valido: {error}")

    raw_features = raw.get("features", [])
    if not raw_features:
        fail(f"{INTERMEDIATE_PATH.relative_to(ROOT)} non contiene feature")

    features = []
    seen_ids = set()
    for raw_feature in raw_features:
        props = raw_feature.get("properties", {})
        geometry = raw_feature.get("geometry")
        if geometry is None:
            fail(f"feature senza geometria: {props}")

        district_id = str(props.get("CU20_COD", "")).strip()
        name = (props.get("CU20_DEN") or "").strip()
        sub_code = (props.get("CU20_C1") or "").strip() or None

        if not district_id or not name:
            fail(f"feature con id o nome mancante: {props}")
        if district_id in seen_ids:
            fail(f"id duplicato dopo la conversione: {district_id}")
        seen_ids.add(district_id)

        # circoscrizione = CU20_DEN prefix before " - <subCode>" — verified
        # against the official 28-circoscrizione list (D.Lgs. 177/2020); see
        # docs/v2/03-linkage-report.md.
        if sub_code and name.endswith(f" - {sub_code}"):
            circoscrizione = name[: -(len(sub_code) + 3)].strip()
        else:
            fail(f"CU20_DEN '{name}' non termina con ' - {sub_code}' come atteso: impossibile derivare la circoscrizione")

        features.append(
            {
                "type": "Feature",
                "properties": {
                    "id": district_id,
                    "name": name,
                    "chamber": "Camera",
                    "collegioType": "uninominale",
                    "subCode": sub_code,
                    "circoscrizione": circoscrizione,
                    "provenance": "official",
                    "sourceName": SOURCE_NAME,
                },
                "geometry": geometry,
            }
        )

    features.sort(key=lambda f: f["properties"]["id"])

    if len(features) != 147:
        fail(f"attesi 147 collegi, trovati {len(features)} — controlla il layer sorgente")

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
    if OUTPUT_PATH.exists() and not SAMPLE_BACKUP_PATH.exists():
        SAMPLE_BACKUP_PATH.write_text(OUTPUT_PATH.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {OUTPUT_PATH.name} preservato come {SAMPLE_BACKUP_PATH.name}")

    OUTPUT_PATH.write_bytes(serialized_bytes)
    # if_absent, not the unconditional stamp_fetch_metadata: this script
    # runs offline against an already-downloaded shapefile every time
    # `make boundaries` runs, so it must not advance "istat"'s recorded
    # fetch date on every re-run — only the first time (Phase 14 fix; a
    # prior unconditional stamp here silently drifted the shipped
    # retrievedAt forward on every rebuild — see
    # docs/v3/14-pipeline-hardening.md).
    stamp_fetch_metadata_if_absent("istat")

    size_kb = len(serialized_bytes) / 1024
    print(f"OK: {len(features)} collegi scritti in {OUTPUT_PATH.relative_to(ROOT)} ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
