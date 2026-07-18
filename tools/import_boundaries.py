#!/usr/bin/env python3
"""Transforms the ogr2ogr-produced intermediate GeoJSON
(tools/raw/camera_collegi_uninominali_wgs84.geojson) into
Politici/Data/districts.geojson with schema-v2 properties.

Offline — makes no network calls and doesn't invoke ogr2ogr itself; that's
tools/build_boundaries.sh's job (`make boundaries`), which calls this script
right after the shapefile conversion.

Design notes:

- id = CU20_COD, cast to string (it's an integer in the shapefile).
- name = CU20_DEN, unmodified.
- chamber = "Camera" — capitalized, matching Chamber's Swift raw value
  exactly (Politici/Models/District.swift declares `case camera = "Camera"`,
  case-sensitive; "camera" lowercase would fail to decode).
- collegioType = "uninominale" — this script only ever processes the Camera
  uninominali layer (Senato boundaries are out of scope for this phase).
- region = CU20_C1. NOTE: despite the field's suggestive name, CU20_C1 is
  NOT a geographic region — it's the within-plurinominale sub-collegio
  suffix (e.g. "U01"), literally the tail of CU20_DEN ("Piemonte 1 - U01").
  Carried over literally anyway since it's real, non-fabricated source
  data — see docs/v2/03-boundaries-audit.md for the full finding.
- provenance = "official", sourceName = "ISTAT" — both known facts about
  this pipeline, not fetched fields.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sparql_client import stamp_fetch_metadata  # noqa: E402

ROOT = Path(__file__).parent.parent
INTERMEDIATE_PATH = Path(__file__).parent / "raw" / "camera_collegi_uninominali_wgs84.geojson"
DATA_DIR = ROOT / "Politici" / "Data"
OUTPUT_PATH = DATA_DIR / "districts.geojson"
SAMPLE_BACKUP_PATH = DATA_DIR / "districts.sample.geojson"

SOURCE_NAME = "ISTAT"
MAX_OUTPUT_BYTES = 3 * 1024 * 1024


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
        region = (props.get("CU20_C1") or "").strip() or None

        if not district_id or not name:
            fail(f"feature con id o nome mancante: {props}")
        if district_id in seen_ids:
            fail(f"id duplicato dopo la conversione: {district_id}")
        seen_ids.add(district_id)

        features.append(
            {
                "type": "Feature",
                "properties": {
                    "id": district_id,
                    "name": name,
                    "chamber": "Camera",
                    "collegioType": "uninominale",
                    "region": region,
                    "provenance": "official",
                    "sourceName": SOURCE_NAME,
                },
                "geometry": geometry,
            }
        )

    features.sort(key=lambda f: f["properties"]["id"])

    if len(features) != 147:
        fail(f"attesi 147 collegi, trovati {len(features)} — controlla il layer sorgente")

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
    stamp_fetch_metadata("istat")

    size_kb = len(serialized_bytes) / 1024
    print(f"OK: {len(features)} collegi scritti in {OUTPUT_PATH.relative_to(ROOT)} ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
