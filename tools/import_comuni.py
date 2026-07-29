#!/usr/bin/env python3
"""Builds Politici/Data/comuni.json — the offline comuni table backing both
comune-name lookups and the coordinate geocoding tier (v4 Phase 30 +
Phase 30B — docs/v4/30-comuni-geocoding.md, docs/v4/30b-comuni-assignment.md).

Source: the `UT_Collegi2020` layer of the ISTAT 2020 collegi shapefile
package already local under tools/raw/collegi/ (the comune-level base table
every collegi layer aggregates from — see docs/v4/23-baseline-audit.md §4.6).
It is the SAME D.Lgs. 177/2020 ISTAT release, CC BY 4.0, that already backs
the four bundled district boundary files — no new acquisition, no new
licence, and a comuni vintage identical BY CONSTRUCTION to the collegi bases
this table is resolved against (Phase 30 GO-COMUNI gate condition (b)).

Each record carries TWO independent things, for two deliberately distinct
resolution paths:

1. **The published collegio assignment** (schemaVersion 2, Phase 30B) —
   `camera` / `senato`, the source's own `CU20_COD` / `SU20_COD` for that
   comune, sorted, "S"-prefixed on the Senato side to match the shipped
   district ids. This is a SOURCED FACT, and it is what a comune-NAME query
   answers with. It is legitimately multi-valued: six comuni (Roma, Milano,
   Napoli, Torino, Palermo, Genova) genuinely span more than one uninominale
   collegio, so the array — never a single picked member — is the answer.
2. **One interior point** (`lat`/`lon`) — retained unchanged from Phase 30,
   because the COORDINATE path (CLGeocoder results, map taps, arbitrary
   points) still needs point-in-polygon and no assignment can serve it.

For each of the 7,904 distinct comuni (keyed on PRO_COM) the script collects
every polygon part — the six split comuni above are stored as sub-comunal
rows, and island comuni are MultiPolygons — picks the LARGEST part by area,
and takes ONE interior point of it via OGR `PointOnSurface`. Two deliberate
choices, both measured against the shipped collegi:
  * PointOnSurface (a representative point guaranteed to lie inside the
    geometry), NOT the mathematical centroid: the plain centroid of the chosen
    part falls outside it for 89 of the 7,904 comuni (concave shapes, island
    municipalities).
  * the largest PART, not the union of parts: a point in the whole-comune
    union can land in a sliver GAP between the independently-simplified collegi
    (whole-comune Roma did exactly that — nil against every Camera collegio),
    whereas a point deep inside the comune's largest single landmass stays
    inside its collegio after simplification. This drops the both-chambers nil
    rate from 2 to 1 and makes every one of the six split comuni resolve.
The point is reprojected EPSG:32632 -> EPSG:4326 and rounded to 5 dp (~1.1 m,
ample for point-in-polygon into the 1000 m-simplified collegi). Note the
interior point is NOT the comune's answer for a name query any more (Phase
30B): for a split comune it lands in whichever collegio holds the largest
territorial part, which is precisely the single-answer artefact the published
assignment removes from the name path.

Offline: reads only the local shapefile, writes only Politici/Data/comuni.json.
Fails loudly (no output written) if the shapefile is missing, if a comune
carries no published collegio code, or if the byte gate is exceeded. Records
and code arrays are explicitly sorted, so the artifact is byte-identical
across runs.

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

SCHEMA_VERSION = 2
COORD_DECIMALS = 5

# Measured 875.7 KiB (896,739 B) for the 7,904 comuni at schemaVersion 2
# (GO-ASSIGN probe, docs/v4/30b-comuni-assignment.md condition (d); the
# schemaVersion-1 coordinates-only file was 568.2 KiB). The 1.25 MiB gate is a
# coarse drift backstop (68.4% used, ~31% headroom — the same order as the
# other per-file gates) — the coordinate precision is fixed, the comune count
# is a stable ISTAT-2020 fact and the collegio codes are the shipped district
# ids, so this file's size does not drift under re-runs; the gate exists to
# catch a schema/regeneration accident, not to tune size. Well under the
# ~10 MiB soft bundle ceiling either way.
MAX_OUTPUT_BYTES = 1280 * 1024

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
    """One record per distinct PRO_COM — the source's published Camera/Senato
    uninominale collegio codes plus an interior point of that comune's LARGEST
    polygon part. Returns a list of {name, province, lat, lon, camera, senato}
    sorted by (name, province), with each code array sorted too."""
    ds = ogr.Open(str(SHAPEFILE))
    if ds is None:
        fail(f"impossibile aprire lo shapefile {SHAPEFILE.relative_to(ROOT)}")
    layer = ds.GetLayer(0)

    parts = defaultdict(list)
    camera_codes = defaultdict(set)
    senato_codes = defaultdict(set)
    meta = {}
    for feature in layer:
        code = feature.GetField("PRO_COM")
        geom = feature.GetGeometryRef()
        if geom is None:
            continue
        parts[code].extend(polygon_parts(geom))
        meta[code] = (feature.GetField("DEN_COM"), feature.GetField("DEN_P_CM"))
        # CU20_COD / SU20_COD are the publisher's own comune -> uninominale
        # collegio assignment, populated on all 8,213 rows (GO-ASSIGN (a)).
        # Senato ids are unconditionally "S"-prefixed in this project (32 of
        # the 74 raw ISTAT codes would otherwise collide with Camera ids).
        cu = feature.GetField("CU20_COD")
        su = feature.GetField("SU20_COD")
        if cu not in (None, 0, ""):
            camera_codes[code].add(str(cu))
        if su not in (None, 0, ""):
            senato_codes[code].add("S" + str(su))

    transform = build_transform()
    records = []
    for code, geoms in parts.items():
        largest = max(geoms, key=lambda g: g.GetArea())  # area in source metres²
        point = largest.PointOnSurface()
        point.Transform(transform)
        name, province = meta[code]
        if not name or not province:
            fail(f"comune {code} privo di nome o provincia — fonte inattesa")
        # A comune with no published assignment would have to be answered by
        # geometry or not at all — neither is acceptable once the name path
        # cites the source, so stop rather than ship a partial field.
        if not camera_codes[code] or not senato_codes[code]:
            fail(
                f"comune {code} ({name}) privo di collegio pubblicato "
                f"(CU20_COD/SU20_COD) — fonte inattesa"
            )
        records.append({
            "name": name,
            "province": province,
            "lat": round(point.GetY(), COORD_DECIMALS),
            "lon": round(point.GetX(), COORD_DECIMALS),
            "camera": sorted(camera_codes[code]),
            "senato": sorted(senato_codes[code]),
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
    multi = sum(1 for r in records if len(r["camera"]) > 1 or len(r["senato"]) > 1)
    print(
        f"OK: {len(records)} comuni in {OUTPUT_PATH.relative_to(ROOT)} "
        f"({len(encoded) / 1024:.1f} KiB) — {homonyms} nomi omonimi disambiguati per provincia, "
        f"{multi} comuni su più collegi uninominali"
    )


if __name__ == "__main__":
    main()
