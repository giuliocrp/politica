#!/usr/bin/env python3
"""Phase 30 GO-COMUNI feasibility + validation probe (offline).

Reads the already-local ISTAT 2020 collegi package layer `UT_Collegi2020`
(the comune-level base table every collegi layer aggregates from — see
docs/v4/23-baseline-audit.md §4.6), derives ONE interior point per comune,
and:

  1. measures the resulting compact `comuni.json` in bytes (byte-gate
     evidence for the phase);
  2. runs a FULL-TABLE dry run: resolves every comune's point against the
     SHIPPED, simplified collegi polygons (Politici/Data/districts.geojson
     Camera-uninominale + districts_senato.geojson) via point-in-polygon,
     and reports the nil rate (points landing outside every polygon) plus
     the accuracy rate (resolved Camera collegio id == the comune's own
     source CU20_COD, the ground truth carried on each row).

No network. Reads only local files under tools/raw/ and Politici/Data/.
Writes a summary to stdout and (optionally) a candidate comuni.json under
tools/probes/output/ (gitignored — never an import source).

The producing import path (tools/import_comuni.py) reuses the SAME
interior-point method decided here; this probe exists to supply the gate's
measured evidence before any bundled artifact is written.
"""
import json
import os
import sys
from collections import defaultdict

from osgeo import ogr, osr

ogr.UseExceptions()
osr.UseExceptions()

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHP = os.path.join(ROOT, "tools/raw/collegi/UT_Collegi2020/UT_Collegi2020.shp")
CAMERA_GEOJSON = os.path.join(ROOT, "Politici/Data/districts.geojson")
SENATO_GEOJSON = os.path.join(ROOT, "Politici/Data/districts_senato.geojson")
OUT_DIR = os.path.join(ROOT, "tools/probes/output")
COORD_DECIMALS = 5


def build_transform():
    src = osr.SpatialReference()
    src.ImportFromEPSG(32632)  # WGS 84 / UTM zone 32N (the layer's CRS)
    dst = osr.SpatialReference()
    dst.ImportFromEPSG(4326)
    # Force lon/lat (traditional GIS) axis order so output matches GeoJSON.
    dst.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    src.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    return osr.CoordinateTransformation(src, dst)


def polygon_parts(geom):
    if geom.GetGeometryName() == "MULTIPOLYGON":
        return [geom.GetGeometryRef(i).Clone() for i in range(geom.GetGeometryCount())]
    return [geom.Clone()]


def extract_comuni():
    """One record per distinct PRO_COM; interior point of the comune's LARGEST
    polygon part (6 large comuni are split into sub-comunal rows; island comuni
    are MultiPolygons). Returns list of dicts with source ground-truth collegio
    codes. Mirrors tools/import_comuni.py::extract_records exactly, plus the
    CU20/SU20 ground-truth codes used only for the accuracy cross-check."""
    ds = ogr.Open(SHP)
    lyr = ds.GetLayer(0)
    geoms = defaultdict(list)
    meta = {}
    cu_codes = defaultdict(set)  # PRO_COM -> {CU20_COD, ...} (Camera uninom.)
    su_codes = defaultdict(set)  # PRO_COM -> {SU20_COD, ...} (Senato uninom.)
    for f in lyr:
        pc = f.GetField("PRO_COM")
        g = f.GetGeometryRef()
        if g is None:
            continue
        geoms[pc].extend(polygon_parts(g))
        meta[pc] = {
            "name": f.GetField("DEN_COM"),
            "province": f.GetField("DEN_P_CM"),
            "region": f.GetField("DEN_REG"),
        }
        cu = f.GetField("CU20_COD")
        su = f.GetField("SU20_COD")
        if cu:
            cu_codes[pc].add(str(cu))
        if su:
            su_codes[pc].add("S" + str(su))
    tx = build_transform()
    out = []
    centroid_nil_selfcheck = 0
    for pc, parts in geoms.items():
        largest = max(parts, key=lambda g: g.GetArea())
        cen = largest.Centroid()
        if largest.Contains(cen) is False:
            centroid_nil_selfcheck += 1
        pt = largest.PointOnSurface()  # guaranteed inside the chosen part
        pt.Transform(tx)
        lon, lat = pt.GetX(), pt.GetY()
        out.append({
            "pro_com": pc,
            "name": meta[pc]["name"],
            "province": meta[pc]["province"],
            "region": meta[pc]["region"],
            "lat": round(lat, COORD_DECIMALS),
            "lon": round(lon, COORD_DECIMALS),
            "cu_codes": sorted(cu_codes[pc]),
            "su_codes": sorted(su_codes[pc]),
        })
    out.sort(key=lambda r: (r["name"], r["province"]))
    return out, centroid_nil_selfcheck


def load_polygons(path):
    """Return list of (id, ogr_geometry) from a shipped districts GeoJSON."""
    ds = ogr.Open(path)
    lyr = ds.GetLayer(0)
    polys = []
    for f in lyr:
        g = f.GetGeometryRef()
        if g is None:
            continue
        polys.append((f.GetField("id"), g.Clone()))
    return polys


def resolve(lon, lat, polys):
    pt = ogr.Geometry(ogr.wkbPoint)
    pt.AddPoint_2D(lon, lat)
    for pid, g in polys:
        env = g.GetEnvelope()  # (minX, maxX, minY, maxY)
        if not (env[0] <= lon <= env[1] and env[2] <= lat <= env[3]):
            continue
        if g.Contains(pt):
            return pid
    return None


def compact_json(records):
    """Shipped schema candidate: {name, province, lat, lon}. Homonyms kept
    (disambiguated by province downstream)."""
    payload = {
        "schemaVersion": 1,
        "comuni": [
            {"name": r["name"], "province": r["province"],
             "lat": r["lat"], "lon": r["lon"]}
            for r in records
        ],
    }
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def main():
    print("Extracting per-comune interior points from UT_Collegi2020 ...", file=sys.stderr)
    records, cen_selfcheck = extract_comuni()
    print(f"comuni: {len(records)}", file=sys.stderr)

    blob = compact_json(records)
    os.makedirs(OUT_DIR, exist_ok=True)
    cand_path = os.path.join(OUT_DIR, "comuni_candidate.json")
    with open(cand_path, "w", encoding="utf-8") as fh:
        fh.write(blob)
    size = len(blob.encode("utf-8"))

    camera = load_polygons(CAMERA_GEOJSON)
    senato = load_polygons(SENATO_GEOJSON)
    print(f"loaded polygons: Camera {len(camera)}, Senato {len(senato)}", file=sys.stderr)

    cam_nil = sen_nil = both_nil = 0
    cam_hit = cam_match = cam_mismatch = cam_nocode = 0
    sen_hit = 0
    mismatches = []
    nils = []
    for i, r in enumerate(records):
        cam = resolve(r["lon"], r["lat"], camera)
        sen = resolve(r["lon"], r["lat"], senato)
        if cam is None:
            cam_nil += 1
        else:
            cam_hit += 1
            if r["cu_codes"]:
                if cam in r["cu_codes"]:
                    cam_match += 1
                else:
                    cam_mismatch += 1
                    if len(mismatches) < 25:
                        mismatches.append((r["name"], r["province"], cam, r["cu_codes"]))
            else:
                cam_nocode += 1
        if sen is None:
            sen_nil += 1
        else:
            sen_hit += 1
        if cam is None and sen is None:
            both_nil += 1
            if len(nils) < 40:
                nils.append((r["name"], r["province"], r["lat"], r["lon"]))
        if (i + 1) % 1000 == 0:
            print(f"  ...{i+1}/{len(records)}", file=sys.stderr)

    n = len(records)
    print("\n================ PHASE 30 GO-COMUNI PROBE SUMMARY ================")
    print(f"source layer         : tools/raw/collegi/UT_Collegi2020 (ISTAT 2020, CC BY 4.0)")
    print(f"distinct comuni      : {n}")
    print(f"interior-point method: OGR PointOnSurface of the comune's LARGEST polygon part")
    print(f"centroid-outside self-check (plain Centroid fell outside the chosen part): {cen_selfcheck}")
    print(f"\ncomuni_candidate.json (compact {{name,province,lat,lon}}, {COORD_DECIMALS} dp): {size} bytes = {size/1024:.1f} KiB")
    print("\n--- Camera uninominale dry run ---")
    print(f"resolved (hit)  : {cam_hit}  ({100*cam_hit/n:.2f}%)")
    print(f"nil (outside)   : {cam_nil}  ({100*cam_nil/n:.2f}%)")
    print(f"  of hits: match source CU20_COD : {cam_match}  ({100*cam_match/max(cam_hit,1):.2f}% of hits)")
    print(f"          mismatch               : {cam_mismatch}  ({100*cam_mismatch/max(cam_hit,1):.2f}% of hits)")
    print(f"          comune had no CU code   : {cam_nocode}")
    print("\n--- Senato uninominale dry run ---")
    print(f"resolved (hit)  : {sen_hit}  ({100*sen_hit/n:.2f}%)")
    print(f"nil (outside)   : {sen_nil}  ({100*sen_nil/n:.2f}%)")
    print(f"\nboth-chambers nil: {both_nil}  ({100*both_nil/n:.2f}%)")
    print("\n--- sample Camera mismatches (resolved vs source codes) ---")
    for m in mismatches:
        print("   ", m)
    print("\n--- sample both-nil comuni (outside every shipped polygon) ---")
    for z in nils:
        print("   ", z)
    print("=================================================================")


if __name__ == "__main__":
    main()
