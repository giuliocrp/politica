#!/usr/bin/env python3
"""Phase 30B GO-ASSIGN gate probe (offline).

Phase 30 resolved a comune name GEOMETRICALLY (interior point ->
point-in-polygon against the shipped, 1000 m-simplified collegi) and used the
ISTAT source's own comune -> collegio assignment (`CU20_COD` / `SU20_COD` on
every `UT_Collegi2020` row) only to *grade* that result. Phase 30B proposes to
invert that for name lookups: cite the publisher's assignment instead of
deriving a guess from simplified geometry.

This probe supplies the measured evidence for the five GO-ASSIGN conditions,
BEFORE any importer/model/service change, per docs/plan/phase-30b.md:

  (a) field coverage  — CU20_COD / SU20_COD populated on every row and every
      comune (an unpopulated row is NO-GO: a partial field cannot replace a
      total one);
  (b) referential integrity — every distinct published code is ALREADY a
      shipped district id, both chambers (one unresolvable code is NO-GO; no
      aliases may be added to close a gap);
  (c) the multi-collegio set — every comune the source assigns to more than
      one uninominale collegio, named, with POP_2011 populations and their
      share of the national POP_2011 total (POP_2011 is the CENSUS-2011
      population field carried by this layer — the same field Phase 25 used
      for placeholder detection — NOT a current figure);
  (d) byte measurements of the candidate schemas, so the new per-file gate is
      set on a measurement rather than a projection;
  (e) the full before/after resolution diff, comune by comune, both chambers
      — "before" is the SHIPPED Politici/Data/comuni.json coordinate resolved
      against the SHIPPED collegi polygons (i.e. exactly what the app answers
      today), "after" is the source assignment. An unexplained additional
      change is NO-GO.

No network. Reads only local files under tools/raw/ and Politici/Data/.
Writes its summary to stdout; tools/probes/output/ is gitignored and is never
an import source.
"""
import json
import os
import sys
from collections import defaultdict

from osgeo import ogr

ogr.UseExceptions()

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHP = os.path.join(ROOT, "tools/raw/collegi/UT_Collegi2020/UT_Collegi2020.shp")
CAMERA_GEOJSON = os.path.join(ROOT, "Politici/Data/districts.geojson")
SENATO_GEOJSON = os.path.join(ROOT, "Politici/Data/districts_senato.geojson")
SHIPPED_COMUNI = os.path.join(ROOT, "Politici/Data/comuni.json")


# --------------------------------------------------------------------------
# Source side — attributes only (no geometry work: the "before" answers come
# from the already-shipped comuni.json coordinates).
# --------------------------------------------------------------------------

def read_source():
    """Per-comune published assignment + population, keyed on PRO_COM.

    Returns (comuni, row_stats) where comuni maps PRO_COM -> dict with name,
    province, camera (sorted list of CU20 codes), senato (sorted list of
    "S"-prefixed SU20 codes), pop (summed POP_2011 over the comune's rows),
    rows (row count), and the CP20/SP20/CIRC fields used only for the
    schema-C byte measurement.
    """
    ds = ogr.Open(SHP)
    layer = ds.GetLayer(0)

    comuni = {}
    rows_total = 0
    rows_missing_cu = 0
    rows_missing_su = 0
    for feature in layer:
        rows_total += 1
        code = feature.GetField("PRO_COM")
        cu = feature.GetField("CU20_COD")
        su = feature.GetField("SU20_COD")
        if cu in (None, 0, ""):
            rows_missing_cu += 1
        if su in (None, 0, ""):
            rows_missing_su += 1
        entry = comuni.setdefault(code, {
            "name": feature.GetField("DEN_COM"),
            "province": feature.GetField("DEN_P_CM"),
            "camera": set(),
            "senato": set(),
            "camera_den": {},
            "senato_den": {},
            "cam_pluri": set(),
            "sen_pluri": set(),
            "circ": set(),
            "pop": 0,
            "rows": 0,
        })
        entry["rows"] += 1
        entry["pop"] += feature.GetField("POP_2011") or 0
        if cu not in (None, 0, ""):
            entry["camera"].add(str(cu))
            entry["camera_den"][str(cu)] = feature.GetField("CU20_DEN")
        if su not in (None, 0, ""):
            entry["senato"].add("S" + str(su))
            entry["senato_den"]["S" + str(su)] = feature.GetField("SU20_DEN")
        cp = feature.GetField("CP20_COD")
        sp = feature.GetField("SP20_COD")
        circ = feature.GetField("CIRC_DEN")
        if cp not in (None, 0, ""):
            entry["cam_pluri"].add(str(cp))
        if sp not in (None, 0, ""):
            entry["sen_pluri"].add("S" + str(sp))
        if circ:
            entry["circ"].add(circ)

    for entry in comuni.values():
        entry["camera"] = sorted(entry["camera"])
        entry["senato"] = sorted(entry["senato"])
        entry["cam_pluri"] = sorted(entry["cam_pluri"])
        entry["sen_pluri"] = sorted(entry["sen_pluri"])
        entry["circ"] = sorted(entry["circ"])

    return comuni, {
        "rows_total": rows_total,
        "rows_missing_cu": rows_missing_cu,
        "rows_missing_su": rows_missing_su,
    }


# --------------------------------------------------------------------------
# Shipped side — the geometric answer the app gives TODAY.
# --------------------------------------------------------------------------

def load_polygons(path):
    ds = ogr.Open(path)
    layer = ds.GetLayer(0)
    polys = []
    for feature in layer:
        geom = feature.GetGeometryRef()
        if geom is None:
            continue
        polys.append((feature.GetField("id"), geom.Clone()))
    return polys


def resolve(lon, lat, polys):
    point = ogr.Geometry(ogr.wkbPoint)
    point.AddPoint_2D(lon, lat)
    for pid, geom in polys:
        env = geom.GetEnvelope()  # (minX, maxX, minY, maxY)
        if not (env[0] <= lon <= env[1] and env[2] <= lat <= env[3]):
            continue
        if geom.Contains(point):
            return pid
    return None


def shipped_ids(path):
    ds = ogr.Open(path)
    layer = ds.GetLayer(0)
    return {feature.GetField("id") for feature in layer}


# --------------------------------------------------------------------------
# Candidate schemas — byte measurement for the new gate (condition (d)).
# --------------------------------------------------------------------------

def measure_schema(records, variant):
    """Serialize the candidate comuni.json exactly as the importer would
    (compact separators, ensure_ascii=False, trailing newline) and return the
    encoded length in bytes."""
    out = []
    for r in records:
        if variant == "A":  # always-array, explicit key names (candidate)
            out.append({"name": r["name"], "province": r["province"],
                        "lat": r["lat"], "lon": r["lon"],
                        "camera": r["camera"], "senato": r["senato"]})
        elif variant == "B":  # scalar-when-single, short keys (report §11.5 B)
            item = {"n": r["name"], "p": r["province"],
                    "lat": r["lat"], "lon": r["lon"]}
            item["c"] = r["camera"][0] if len(r["camera"]) == 1 else r["camera"]
            item["s"] = r["senato"][0] if len(r["senato"]) == 1 else r["senato"]
            out.append(item)
        elif variant == "C":  # A + _DEN names + plurinominale + circoscrizione
            out.append({"name": r["name"], "province": r["province"],
                        "lat": r["lat"], "lon": r["lon"],
                        "camera": r["camera"], "senato": r["senato"],
                        "cameraDen": [r["camera_den"][c] for c in r["camera"]],
                        "senatoDen": [r["senato_den"][s] for s in r["senato"]],
                        "cameraPlurinominale": r["cam_pluri"],
                        "senatoPlurinominale": r["sen_pluri"],
                        "circoscrizione": r["circ"]})
        elif variant == "D":  # always-array, short keys
            out.append({"name": r["name"], "province": r["province"],
                        "lat": r["lat"], "lon": r["lon"],
                        "c": r["camera"], "s": r["senato"]})
    blob = json.dumps({"schemaVersion": 2, "comuni": out},
                      ensure_ascii=False, separators=(",", ":")) + "\n"
    return len(blob.encode("utf-8"))


def main():
    print("Reading UT_Collegi2020 attributes ...", file=sys.stderr)
    source, row_stats = read_source()
    print(f"comuni: {len(source)}", file=sys.stderr)

    shipped = json.loads(open(SHIPPED_COMUNI, encoding="utf-8").read())
    shipped_by_key = {(c["name"], c["province"]): c for c in shipped["comuni"]}

    # Join the shipped table (name, province — unique, Phase 30 §3) onto the
    # source rows so "before" and "after" are the same 7,904 comuni.
    joined = []
    unjoined = []
    for entry in source.values():
        key = (entry["name"], entry["province"])
        shipped_row = shipped_by_key.get(key)
        if shipped_row is None:
            unjoined.append(key)
            continue
        joined.append({**entry, "lat": shipped_row["lat"], "lon": shipped_row["lon"]})
    joined.sort(key=lambda r: (r["name"], r["province"]))

    n = len(joined)

    # ---------------- (a) field coverage ----------------
    no_cu = [r for r in joined if not r["camera"]]
    no_su = [r for r in joined if not r["senato"]]

    print("\n============== PHASE 30B GO-ASSIGN PROBE SUMMARY ==============")
    print(f"source layer          : tools/raw/collegi/UT_Collegi2020 (ISTAT 2020, CC BY 4.0)")
    print(f"shipped table         : Politici/Data/comuni.json (Phase 30, schemaVersion 1)")
    print(f"distinct comuni       : {len(source)}   joined to shipped table: {n}   unjoined: {len(unjoined)}")
    if unjoined:
        print(f"  UNJOINED (would break the diff): {unjoined[:10]}")

    print("\n--- (a) field coverage ---")
    print(f"rows in layer               : {row_stats['rows_total']}")
    print(f"rows with NO CU20_COD       : {row_stats['rows_missing_cu']}")
    print(f"rows with NO SU20_COD       : {row_stats['rows_missing_su']}")
    print(f"comuni with NO Camera code  : {len(no_cu)}  {[ (r['name'], r['province']) for r in no_cu[:10] ]}")
    print(f"comuni with NO Senato code  : {len(no_su)}  {[ (r['name'], r['province']) for r in no_su[:10] ]}")
    print(f"(a) VERDICT                 : {'PASS' if not (no_cu or no_su or row_stats['rows_missing_cu'] or row_stats['rows_missing_su']) else 'FAIL'}")

    # ---------------- (b) referential integrity ----------------
    camera_ids = shipped_ids(CAMERA_GEOJSON)
    senato_ids = shipped_ids(SENATO_GEOJSON)
    src_cam = sorted({c for r in joined for c in r["camera"]})
    src_sen = sorted({s for r in joined for s in r["senato"]})
    cam_missing = [c for c in src_cam if c not in camera_ids]
    sen_missing = [s for s in src_sen if s not in senato_ids]
    cam_unused = sorted(camera_ids - set(src_cam))
    sen_unused = sorted(senato_ids - set(src_sen))

    print("\n--- (b) referential integrity (published code -> shipped district id) ---")
    print(f"distinct published Camera codes : {len(src_cam)}   shipped Camera ids: {len(camera_ids)}")
    print(f"  published codes NOT shipped   : {cam_missing}")
    print(f"  shipped ids never published   : {cam_unused}")
    print(f"distinct published Senato codes : {len(src_sen)}   shipped Senato ids: {len(senato_ids)}")
    print(f"  published codes NOT shipped   : {sen_missing}")
    print(f"  shipped ids never published   : {sen_unused}")
    print(f"(b) VERDICT                     : {'PASS' if not cam_missing and not sen_missing else 'FAIL'}")

    # ---------------- (c) multi-collegio set ----------------
    national_pop = sum(r["pop"] for r in joined)
    multi_cam = sorted([r for r in joined if len(r["camera"]) > 1],
                       key=lambda r: -r["pop"])
    multi_sen = sorted([r for r in joined if len(r["senato"]) > 1],
                       key=lambda r: -r["pop"])
    multi_any = sorted({(r["name"], r["province"]) for r in multi_cam + multi_sen})
    multi_any_rows = sorted([r for r in joined if (r["name"], r["province"]) in multi_any],
                            key=lambda r: -r["pop"])
    multi_pop = sum(r["pop"] for r in multi_any_rows)

    print("\n--- (c) multi-collegio comuni (POP_2011 = ISTAT CENSUS-2011 field, NOT current) ---")
    print(f"national POP_2011 total (sum over all rows) : {national_pop}")
    print(f"comuni spanning >1 Camera uninominale       : {len(multi_cam)}")
    print(f"comuni spanning >1 Senato uninominale       : {len(multi_sen)}")
    print(f"comuni multi in EITHER chamber              : {len(multi_any_rows)}")
    print(f"population in those comuni                  : {multi_pop}  ({100*multi_pop/national_pop:.2f}% of national POP_2011)")
    for r in multi_any_rows:
        print(f"    {r['name']:<10} ({r['province']:<22}) pop={r['pop']:>9}  rows={r['rows']:>4}  "
              f"Camera x{len(r['camera'])} {r['camera']}  Senato x{len(r['senato'])} {r['senato']}")

    # ---------------- (e) before/after resolution diff ----------------
    print("\nResolving shipped coordinates against shipped polygons (the 'before') ...", file=sys.stderr)
    camera_polys = load_polygons(CAMERA_GEOJSON)
    senato_polys = load_polygons(SENATO_GEOJSON)

    changes_cam, changes_sen = [], []
    agree_cam = agree_sen = 0
    for i, r in enumerate(joined):
        before_c = resolve(r["lon"], r["lat"], camera_polys)
        before_s = resolve(r["lon"], r["lat"], senato_polys)
        after_c, after_s = r["camera"], r["senato"]
        # "unchanged" = geometry returned exactly the set the source publishes,
        # which for a single-valued comune means the same id. For a
        # multi-collegio comune geometry can only ever return one of many, so
        # it is BY CONSTRUCTION a change (it stops being presented as THE
        # answer) — classified separately below.
        if [before_c] == after_c:
            agree_cam += 1
        else:
            changes_cam.append((r, before_c, after_c))
        if [before_s] == after_s:
            agree_sen += 1
        else:
            changes_sen.append((r, before_s, after_s))
        if (i + 1) % 2000 == 0:
            print(f"  ...{i+1}/{n}", file=sys.stderr)

    def classify(before, after):
        if before is None:
            return "GAP-FILLED" if len(after) == 1 else "GAP-FILLED-MULTI"
        if len(after) > 1:
            return "MULTI (single answer -> set)" if before in after else "MULTI + CORRECTED"
        return "CORRECTED"

    print("\n--- (e) resolution diff, comune by comune ---")
    for label, changes, agree in (("CAMERA", changes_cam, agree_cam),
                                  ("SENATO", changes_sen, agree_sen)):
        print(f"\n  {label}: unchanged {agree}/{n}   changed {len(changes)}")
        for r, before, after in sorted(changes, key=lambda t: (t[0]["name"], t[0]["province"])):
            print(f"    {r['name']:<22} ({r['province']:<22}) "
                  f"before={str(before):<9} after={after}   [{classify(before, after)}]")

    # ------- test-expectation re-derivation (Phase 25 precedent) -------
    # The 14 comuni Phase 30's integration test hardcodes, plus every comune
    # the diff above changes. Printed from the SOURCE so the test's expected
    # ids are re-derived here rather than read back off the implementation.
    print("\n--- test-expectation re-derivation (published assignment, from source) ---")
    phase30_pairs = ["Roma", "Milano", "Napoli", "Torino", "Firenze", "Bologna", "Bari",
                     "Genova", "Venezia", "Aosta", "Trento", "Cagliari", "Bolzano", "Perugia",
                     # the six homonym names — the chooser path's test data
                     "Calliano", "Castro", "Livo", "Peglio", "Samone", "San Teodoro"]
    changed_names = sorted({r["name"] for r, _, _ in changes_cam + changes_sen})
    by_name = defaultdict(list)
    for r in joined:
        by_name[r["name"]].append(r)
    for name in phase30_pairs + [n for n in changed_names if n not in phase30_pairs]:
        for r in by_name.get(name, []):
            print(f"    {r['name']:<22} ({r['province']:<22}) camera={r['camera']}  senato={r['senato']}")

    # ---------------- (d) byte measurements ----------------
    print("\n--- (d) candidate-schema byte measurements ---")
    current = os.path.getsize(SHIPPED_COMUNI)
    print(f"current shipped comuni.json (schemaVersion 1) : {current} B = {current/1024:.1f} KiB")
    for variant, desc in (
        ("A", "always-array camera/senato codes, explicit keys"),
        ("B", "scalar-when-single, short keys (report §11.5 variant B)"),
        ("C", "A + _DEN names + plurinominale + circoscrizione"),
        ("D", "always-array codes, short keys c/s"),
    ):
        size = measure_schema(joined, variant)
        print(f"  variant {variant}: {size:>9} B = {size/1024:7.1f} KiB  "
              f"(+{100*(size-current)/current:5.1f}% vs current)  — {desc}")
    print("===============================================================")


if __name__ == "__main__":
    main()
