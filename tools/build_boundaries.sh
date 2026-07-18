#!/usr/bin/env bash
# Builds Politici/Data/districts.geojson from the official ISTAT Camera
# collegi-uninominali shapefile: reproject EPSG:32632 -> EPSG:4326, simplify
# for mobile, convert to GeoJSON via ogr2ogr, then hand off to
# tools/import_boundaries.py to emit the final schema-v2 file.
#
# Offline — processes an already-downloaded local shapefile, no network.
# Run via `make boundaries`.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHAPEFILE="$ROOT_DIR/tools/raw/collegi/CAMERA_CollegiUNINOMINALI_2020/CAMERA_CollegiUNINOMINALI_2020.shp"
INTERMEDIATE_GEOJSON="$ROOT_DIR/tools/raw/camera_collegi_uninominali_wgs84.geojson"

# Calibrated against the live shapefile (see docs/v2/03-boundaries-audit.md):
# 1000m keeps every Sicilia/Sardegna island part intact and lands the final
# Data/districts.geojson comfortably under the 3MB budget.
SIMPLIFY_TOLERANCE_METERS=1000

fail() {
    echo "ERRORE: $1" >&2
    exit 1
}

command -v ogr2ogr >/dev/null 2>&1 || fail "ogr2ogr non è installato (richiesto: GDAL — 'brew install gdal')."

if [ ! -f "$SHAPEFILE" ]; then
    fail "shapefile mancante: ${SHAPEFILE#"$ROOT_DIR"/}. Scarica i dati ISTAT dei collegi elettorali (D.Lgs. 177/2020, layer Camera collegi uninominali) e posizionali in tools/raw/collegi/CAMERA_CollegiUNINOMINALI_2020/ — vedi docs/v2/03-boundaries-audit.md."
fi

echo "Riproiezione EPSG:32632 -> EPSG:4326 e semplificazione (tolleranza ${SIMPLIFY_TOLERANCE_METERS}m)..."
rm -f "$INTERMEDIATE_GEOJSON"
ogr2ogr -f GeoJSON \
    -t_srs EPSG:4326 \
    -simplify "$SIMPLIFY_TOLERANCE_METERS" \
    "$INTERMEDIATE_GEOJSON" \
    "$SHAPEFILE"

if [ ! -f "$INTERMEDIATE_GEOJSON" ]; then
    fail "ogr2ogr non ha prodotto ${INTERMEDIATE_GEOJSON#"$ROOT_DIR"/}"
fi

echo "OK: GeoJSON intermedio scritto in tools/raw/$(basename "$INTERMEDIATE_GEOJSON")"

python3 "$ROOT_DIR/tools/import_boundaries.py"
