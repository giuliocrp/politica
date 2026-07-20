#!/usr/bin/env bash
# Builds Politici/Data/districts.geojson (Camera) or
# Politici/Data/districts_senato.geojson (Senato) from the official ISTAT
# collegi-uninominali shapefile: reproject EPSG:32632 -> EPSG:4326, simplify
# for mobile, convert to GeoJSON via ogr2ogr, then hand off to
# tools/import_boundaries.py --chamber <chamber> to emit the final
# schema-v2 file — which also prints a per-feature vertex report and
# enforces the vertex/byte budgets (see MAX_VERTICES_PER_FEATURE /
# MAX_OUTPUT_BYTES there).
#
# Usage: tools/build_boundaries.sh [camera|senato]   (default: camera)
#
# Offline — processes an already-downloaded local shapefile, no network.
# Run via `make boundaries` (Camera) / `make boundaries-senato` (Senato).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHAMBER="${1:-camera}"

# Calibrated against the live shapefile. Camera: docs/v2/03-boundaries-audit.md.
# Senato reuses the same value — Phase 16 measured 800 max vertices / ~333 KB
# intermediate at this tolerance (well under both gates, islands preserved)
# and found no reason to diverge from Camera's calibration; see
# docs/v3/16-senato-boundaries.md.
SIMPLIFY_TOLERANCE_METERS=1000

fail() {
    echo "ERRORE: $1" >&2
    exit 1
}

command -v ogr2ogr >/dev/null 2>&1 || fail "ogr2ogr non è installato (richiesto: GDAL — 'brew install gdal')."

case "$CHAMBER" in
    camera)
        SHAPEFILE="$ROOT_DIR/tools/raw/collegi/CAMERA_CollegiUNINOMINALI_2020/CAMERA_CollegiUNINOMINALI_2020.shp"
        INTERMEDIATE_GEOJSON="$ROOT_DIR/tools/raw/camera_collegi_uninominali_wgs84.geojson"
        DOWNLOAD_HINT="layer Camera collegi uninominali (CAMERA_CollegiUNINOMINALI_2020)"
        ;;
    senato)
        SHAPEFILE="$ROOT_DIR/tools/raw/collegi/SENATO_CollegiUNINOMINALI_2020/SENATO_CollegiUNINOMINALI_2020.shp"
        INTERMEDIATE_GEOJSON="$ROOT_DIR/tools/raw/senato_collegi_uninominali_wgs84.geojson"
        DOWNLOAD_HINT="layer Senato collegi uninominali (SENATO_CollegiUNINOMINALI_2020)"
        ;;
    *)
        fail "valore non valido: '$CHAMBER' (atteso 'camera' o 'senato')"
        ;;
esac

if [ ! -f "$SHAPEFILE" ]; then
    fail "shapefile mancante: ${SHAPEFILE#"$ROOT_DIR"/}. Scarica i dati ISTAT dei collegi elettorali (D.Lgs. 177/2020, $DOWNLOAD_HINT) e posizionali sotto tools/raw/collegi/ — vedi tools/SOURCES.md."
fi

echo "Riproiezione EPSG:32632 -> EPSG:4326 e semplificazione (tolleranza ${SIMPLIFY_TOLERANCE_METERS}m, $CHAMBER)..."
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

python3 "$ROOT_DIR/tools/import_boundaries.py" --chamber "$CHAMBER"
