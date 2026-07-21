#!/usr/bin/env python3
"""Phase 15 probe: measures ogr2ogr -simplify tolerance vs. output byte size
and per-feature vertex count for the Senato Camera-uninominale-equivalent
layer (SENATO_CollegiUNINOMINALI_2020), to find a tolerance that satisfies
the Phase 14 gates (MAX_OUTPUT_BYTES = 3 MB, MAX_VERTICES_PER_FEATURE = 1500)
while keeping at least one genuine multi-part island collegio as a
MultiPolygon after simplification.

Read-only against tools/raw/collegi/ — never modifies the source shapefile.
Writes intermediate GeoJSON under tools/probes/output/ (gitignored).

Usage: python3 tools/probes/probe_senato_simplify.py [tolerance_m ...]
Defaults to a small sweep anchored on the Camera-calibrated 1000m.
"""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SHAPEFILE = ROOT / "tools" / "raw" / "collegi" / "SENATO_CollegiUNINOMINALI_2020" / "SENATO_CollegiUNINOMINALI_2020.shp"
OUTPUT_DIR = Path(__file__).parent / "output"

# Sardegna's two Senato uninominale collegi (unsplit region, so both
# together cover Sardegna + the La Maddalena archipelago) — used as the
# island-preservation spot-check, since Sardegna was independently the
# Camera layer's own max-vertex/genuine-multipart case (Phase 14).
ISLAND_SPOT_CHECK_IDS = {"200001", "200002"}


def count_vertices(geometry):
    geometry_type = geometry.get("type")
    coordinates = geometry.get("coordinates", [])
    if geometry_type == "Polygon":
        return sum(len(ring) for ring in coordinates)
    if geometry_type == "MultiPolygon":
        return sum(len(ring) for polygon in coordinates for ring in polygon)
    return 0


def run_tolerance(tolerance_m):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUTPUT_DIR / f"senato_uninominale_simplify_{tolerance_m}m.geojson"
    out_path.unlink(missing_ok=True)

    subprocess.run(
        [
            "ogr2ogr", "-f", "GeoJSON",
            "-t_srs", "EPSG:4326",
            "-simplify", str(tolerance_m),
            str(out_path), str(SHAPEFILE),
        ],
        check=True,
        capture_output=True,
    )

    data = json.loads(out_path.read_text(encoding="utf-8"))
    features = data["features"]
    byte_size = out_path.stat().st_size

    vertex_counts = [(f["properties"]["SU20_COD"], count_vertices(f["geometry"])) for f in features]
    vertex_counts.sort(key=lambda entry: entry[1], reverse=True)
    max_id, max_count = vertex_counts[0]

    island_types = {
        f["properties"]["SU20_COD"]: f["geometry"]["type"]
        for f in features
        if str(f["properties"]["SU20_COD"]) in ISLAND_SPOT_CHECK_IDS
    }

    return {
        "tolerance_m": tolerance_m,
        "feature_count": len(features),
        "byte_size": byte_size,
        "max_vertex_id": max_id,
        "max_vertex_count": max_count,
        "island_spot_check": island_types,
    }


def main():
    tolerances = [int(x) for x in sys.argv[1:]] or [500, 1000, 1500, 2000]
    print(f"{'tolerance_m':>11} {'bytes':>10} {'KB':>8} {'max_vertices':>13} {'max_id':>8}  island_spot_check")
    for tolerance_m in tolerances:
        result = run_tolerance(tolerance_m)
        print(
            f"{result['tolerance_m']:>11} {result['byte_size']:>10} "
            f"{result['byte_size']/1024:>8.1f} {result['max_vertex_count']:>13} "
            f"{result['max_vertex_id']:>8}  {result['island_spot_check']}"
        )


if __name__ == "__main__":
    main()
