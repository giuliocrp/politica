#!/usr/bin/env python3
"""Builds Politici/Data/comuni.json — the offline comuni-centroid geocoding
table (v4 Phase 30 — docs/v4/30-comuni-geocoding.md).

Source: the `UT_Collegi2020` layer of the ISTAT 2020 collegi shapefile
package already local under tools/raw/collegi/ (the comune-level base table
every collegi layer aggregates from — see docs/v4/23-baseline-audit.md §4.6).
It is the SAME D.Lgs. 177/2020 ISTAT release, CC BY 4.0, that already backs
the four bundled district boundary files — no new acquisition, no new
licence, and a comuni vintage identical BY CONSTRUCTION to the collegi bases
this table is resolved against (Phase 30 GO-COMUNI gate condition (b)).

For each of the 7,904 distinct comuni (keyed on PRO_COM) the script collects
every polygon part — six large comuni (Roma, Milano, Napoli, Palermo, Genova,
Torino) are split into sub-comunal rows, and island comuni are MultiPolygons —
picks the LARGEST part by area, and takes ONE interior point of it via OGR
`PointOnSurface`. Two deliberate choices, both measured against the shipped
collegi:
  * PointOnSurface (a representative point guaranteed to lie inside the
    geometry), NOT the mathematical centroid: the plain centroid of the chosen
    part falls outside it for 89 of the 7,904 comuni (concave shapes, island
    municipalities).
  * the largest PART, not the union of parts: a point in the whole-comune
    union can land in a sliver GAP between the independently-simplified collegi
    (whole-comune Roma did exactly that — nil against every Camera collegio),
    whereas a point deep inside the comune's largest single landmass stays
    inside its collegio after simplification. This drops the both-chambers nil
    rate from 2 to 1 and makes every one of the six split comuni resolve. For a
    split comune (which by definition spans several collegi and has no single
    "correct" one) the point lands in the collegio containing its largest
    territorial part — an inherent, documented limitation, not an error.
The point is reprojected EPSG:32632 -> EPSG:4326 and rounded to 5 dp (~1.1 m,
ample for point-in-polygon into the 1000 m-simplified collegi).

Offline: reads only the local shapefile, writes only Politici/Data/comuni.json.
Fails loudly (no output written) if the shapefile is missing or the byte gate
is exceeded. The producing method here is the one the GO-COMUNI probe
(tools/probes/probe_comuni_centroids.py) measured: 99.92% of centroids
resolve against the shipped Camera-uninominale polygons, 99.97% of those to
the comune's own source collegio; both-chambers nil = 2 (Isole Tremiti,
Ponza — islands the 1000 m simplification drops).

Run via `make comuni` (also part of the offline `make all`).
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

from osgeo import ogr, osr

ogr.UseExceptions()
osr.UseExceptions()

sys.path.insert(0, str(Path(__file__).parent))
from sparql_client import stamp_fetch_metadata_if_absent  # noqa: E402

ROOT = Path(__file__).parent.parent
SHAPEFILE = ROOT / "tools" / "raw" / "collegi" / "UT_Collegi2020" / "UT_Collegi2020.shp"
OUTPUT_PATH = ROOT / "Politici" / "Data" / "comuni.json"

SCHEMA_VERSION = 1
COORD_DECIMALS = 5

# Measured 568.2 KiB (581,847 B) for the 7,904 comuni at 5 dp (GO-COMUNI
# probe, docs/v4/30-comuni-geocoding.md). The 768 KiB gate is a coarse drift
# backstop (~35% headroom) — the coordinate precision is fixed and the comune
# count is a stable ISTAT-2020 fact, so this file's size does not drift under
# re-runs; the gate exists to catch a schema/regeneration accident, not to
# tune size. Well under the ~10 MiB soft bundle ceiling either way.
MAX_OUTPUT_BYTES = 768 * 1024

# Same D.Lgs. 177/2020 ISTAT release as the collegi boundaries — reuse the
# shared "istat" fetch-metadata key (already stamped 2026-07-18 from the
# boundaries import) so make_manifest.py reads the real, historical retrieval
# date, exactly as import_boundaries.py does. stamp_fetch_metadata_if_absent
# leaves an existing entry alone, so this never advances the date.
FETCH_METADATA_KEY = "istat"


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def build_transform():
    src = osr.SpatialReference()
    src.ImportFromEPSG(32632)  # WGS 84 / UTM zone 32N — the layer's CRS
    dst = osr.SpatialReference()
    dst.ImportFromEPSG(4326)
    # Force lon/lat (traditional GIS) axis order to match GeoJSON convention.
    src.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    dst.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    return osr.CoordinateTransformation(src, dst)


def polygon_parts(geom):
    """Every constituent Polygon of a geometry (a MultiPolygon decomposes into
    its members; a Polygon yields itself) so the largest single landmass can be
    chosen across a comune's rows and any multi-island geometry."""
    if geom.GetGeometryName() == "MULTIPOLYGON":
        return [geom.GetGeometryRef(i).Clone() for i in range(geom.GetGeometryCount())]
    return [geom.Clone()]


def extract_records():
    """One record per distinct PRO_COM — an interior point of that comune's
    LARGEST polygon part. Returns a list of {name, province, lat, lon} sorted
    by (name, province)."""
    ds = ogr.Open(str(SHAPEFILE))
    if ds is None:
        fail(f"impossibile aprire lo shapefile {SHAPEFILE.relative_to(ROOT)}")
    layer = ds.GetLayer(0)

    parts = defaultdict(list)
    meta = {}
    for feature in layer:
        code = feature.GetField("PRO_COM")
        geom = feature.GetGeometryRef()
        if geom is None:
            continue
        parts[code].extend(polygon_parts(geom))
        meta[code] = (feature.GetField("DEN_COM"), feature.GetField("DEN_P_CM"))

    transform = build_transform()
    records = []
    for code, geoms in parts.items():
        largest = max(geoms, key=lambda g: g.GetArea())  # area in source metres²
        point = largest.PointOnSurface()
        point.Transform(transform)
        name, province = meta[code]
        if not name or not province:
            fail(f"comune {code} privo di nome o provincia — fonte inattesa")
        records.append({
            "name": name,
            "province": province,
            "lat": round(point.GetY(), COORD_DECIMALS),
            "lon": round(point.GetX(), COORD_DECIMALS),
        })
    records.sort(key=lambda r: (r["name"], r["province"]))
    return records


def main():
    if not SHAPEFILE.exists():
        fail(
            f"shapefile mancante: {SHAPEFILE.relative_to(ROOT)}. Scarica i dati "
            "ISTAT dei collegi elettorali (D.Lgs. 177/2020, layer UT_Collegi2020) "
            "e posizionali sotto tools/raw/collegi/ — vedi tools/SOURCES.md."
        )

    records = extract_records()

    # (name, province) is unique across all 7,904 comuni (verified Phase 30);
    # a collision would break the app's Comune id (name|province) and the
    # homonym-by-province disambiguation, so guard it here.
    keys = [(r["name"], r["province"]) for r in records]
    if len(set(keys)) != len(keys):
        fail("coppie (name, province) duplicate — la disambiguazione per provincia si romperebbe")

    payload = {"schemaVersion": SCHEMA_VERSION, "comuni": records}
    serialized = json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n"
    encoded = serialized.encode("utf-8")

    if len(encoded) > MAX_OUTPUT_BYTES:
        fail(
            f"comuni.json {len(encoded) / 1024:.1f} KiB supera il limite di "
            f"{MAX_OUTPUT_BYTES / 1024:.0f} KiB"
        )

    OUTPUT_PATH.write_bytes(encoded)
    stamp_fetch_metadata_if_absent(FETCH_METADATA_KEY)

    homonyms = len(keys) - len({r["name"] for r in records})
    print(
        f"OK: {len(records)} comuni in {OUTPUT_PATH.relative_to(ROOT)} "
        f"({len(encoded) / 1024:.1f} KiB) — {homonyms} nomi omonimi disambiguati per provincia"
    )


if __name__ == "__main__":
    main()
