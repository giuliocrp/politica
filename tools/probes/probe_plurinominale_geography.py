#!/usr/bin/env python3
"""Phase 25 GO-PLURI gate probe — fully offline (reads only the local ISTAT
shapefiles under tools/raw/collegi/, the cached
tools/raw/camera_deputati_sparql.json, and the shipped
representatives.json/districts.geojson). Runs the same ogr2ogr
reproject+simplify that tools/build_boundaries.sh will run, enumerates both
plurinominale layers' codes, runs the full deputy->collegio match, measures
per-feature vertex maxima and the would-be schema-v2 output byte size, and
checks the new ids against every shipped boundary id. Prints per-condition
(a)-(e) evidence, writes the full enumeration + linkage table to
tools/probes/output/ (gitignored), and exits non-zero if any hard condition
fails.

Runs ogr2ogr itself (unlike the import pipeline, which splits that into
build_boundaries.sh) so the whole gate is one committed, re-runnable script;
intermediates land in tools/probes/output/ and are never an import source.

The GO-PLURI gate (docs/plan/phase-25.md), evaluated here:

(a) Layer schema fields are exactly those Phase 23's ogrinfo dumps recorded
    (CP20_COD/CP20_DEN/CP20_C1 for Camera, SP20_* for Senato) — asserted
    present, no name-based guessing.
(b) Q1 fully explained: 50 Camera features = 49 named + 1 null-attribute
    placeholder, 27 Senato = 26 + 1; each placeholder's POP_2011 matches the
    Regioni_Senato hypothesis (Valle d'Aosta for Camera; Valle d'Aosta +
    Trentino-Alto Adige for Senato). Any *other* extra/unexplained feature
    is NO-GO.
(c) Every one of the distinct deputy P-suffix coverage values resolves to
    exactly one Camera plurinominale feature under the existing
    normalize_circoscrizione (no new ad-hoc alias); every P-suffix deputy
    resolves, and each resolution is consistent with the deputy's shipped
    circoscrizione.
(d) Byte/vertex maxima measured at the candidate 1000m tolerance BEFORE any
    importer change — printed for the tolerance/descope decision.
(e) Estero deputies and the structurally-bare records carry no resolvable
    P-code (so no collegioPlurinominale); senators are Camera-linkage-exempt
    by construction.
"""

import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

TOOLS_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(TOOLS_DIR))
from import_representatives import (  # noqa: E402
    ESTERO_COVERAGE_VALUES,
    normalize_circoscrizione,
)

ROOT = TOOLS_DIR.parent
COLLEGI = TOOLS_DIR / "raw" / "collegi"
RAW_CAMERA = TOOLS_DIR / "raw" / "camera_deputati_sparql.json"
REPRESENTATIVES = ROOT / "Politici" / "Data" / "representatives.json"
DISTRICTS_CAMERA = ROOT / "Politici" / "Data" / "districts.geojson"
DISTRICTS_SENATO = ROOT / "Politici" / "Data" / "districts_senato.geojson"
OUTPUT_DIR = Path(__file__).parent / "output"

# Candidate tolerance for the new layers — the same 1000m the uninominale
# layers use (docs/v2/03-boundaries-audit.md); condition (d) measures whether
# it holds for the (larger, unioned) plurinominale polygons or must be
# coarsened for these layers only.
SIMPLIFY_TOLERANCE_METERS = 1000
MAX_OUTPUT_BYTES = 3 * 1024 * 1024
MAX_VERTICES_PER_FEATURE = 1500

# The two plurinominale layers, plus the Regioni_Senato layer used only to
# cross-check the placeholder rows' POP_2011 (condition b).
LAYERS = {
    "camera-plurinominale": {
        "shapefile": COLLEGI / "CAMERA_CollegiPLURINOMINALI_2020" / "CAMERA_CollegiPLURINOMINALI_2020.shp",
        "code_field": "CP20_COD",
        "denom_field": "CP20_DEN",
        "subcode_field": "CP20_C1",
        "chamber": "Camera",
        "grouping_property": "circoscrizione",
        "id_prefix": "CP",
        "raw_feature_count": 50,
        "expected_named": 49,
    },
    "senato-plurinominale": {
        "shapefile": COLLEGI / "SENATO_CollegiPLURINOMINALI_2020" / "SENATO_CollegiPLURINOMINALI_2020.shp",
        "code_field": "SP20_COD",
        "denom_field": "SP20_DEN",
        "subcode_field": "SP20_C1",
        "chamber": "Senato",
        "grouping_property": "regione",
        "id_prefix": "SP",
        "raw_feature_count": 27,
        "expected_named": 26,
    },
}
REGIONI_SENATO = COLLEGI / "Regioni_Senato" / "Regioni_Senato_2020.shp"

PLURI_SUFFIX_RE = re.compile(r"^(?P<circ>.+) - (?P<sub>P\d+)$")


def count_vertices(geometry):
    t = geometry.get("type")
    coords = geometry.get("coordinates", [])
    if t == "Polygon":
        return sum(len(ring) for ring in coords)
    if t == "MultiPolygon":
        return sum(len(ring) for poly in coords for ring in poly)
    return 0


def ogr_to_geojson(shapefile, out_path, simplify=None):
    out_path.unlink(missing_ok=True)
    cmd = ["ogr2ogr", "-f", "GeoJSON", "-t_srs", "EPSG:4326"]
    if simplify is not None:
        cmd += ["-simplify", str(simplify)]
    cmd += [str(out_path), str(shapefile)]
    subprocess.run(cmd, check=True, capture_output=True)
    return json.loads(out_path.read_text(encoding="utf-8"))


def is_placeholder(props, code_field, denom_field):
    """A null-attribute residual polygon: code 0 and no denominazione."""
    code = str(props.get(code_field, "")).strip()
    denom = props.get(denom_field)
    return code in ("", "0") or not denom


def build_layer(layer_key, cfg):
    """Reproject+simplify one plurinominale layer, split placeholders from
    named collegi, and build (feature records, index, measurements)."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    intermediate = OUTPUT_DIR / f"{layer_key}_wgs84.geojson"
    raw = ogr_to_geojson(cfg["shapefile"], intermediate, simplify=SIMPLIFY_TOLERANCE_METERS)
    raw_features = raw["features"]

    problems = []
    # (a) schema fields present exactly as Phase 23 recorded
    sample_props = raw_features[0]["properties"]
    for field in (cfg["code_field"], cfg["denom_field"], cfg["subcode_field"]):
        if field not in sample_props:
            problems.append(f"(a) {layer_key}: campo atteso {field!r} assente dallo shapefile")

    placeholders = []
    named = []
    seen_ids = set()
    for f in raw_features:
        props = f.get("properties", {})
        if is_placeholder(props, cfg["code_field"], cfg["denom_field"]):
            placeholders.append(props)
            continue
        raw_code = str(props[cfg["code_field"]]).strip()
        district_id = f"{cfg['id_prefix']}{raw_code}"
        name = (props[cfg["denom_field"]] or "").strip()
        sub_code = (props.get(cfg["subcode_field"]) or "").strip() or None
        if district_id in seen_ids:
            problems.append(f"(b) {layer_key}: id duplicato {district_id}")
        seen_ids.add(district_id)
        # grouping = denom prefix before " - <subCode>", same parse as uninominale
        if sub_code and name.endswith(f" - {sub_code}"):
            grouping_value = name[: -(len(sub_code) + 3)].strip()
        else:
            problems.append(f"(b) {layer_key}: {name!r} non termina con ' - {sub_code}'")
            grouping_value = None
        # Would-be schema-v2 properties (byte-identical to what import writes)
        out_props = {
            "id": district_id,
            "name": name,
            "chamber": cfg["chamber"],
            "collegioType": "plurinominale",
            "subCode": sub_code,
            cfg["grouping_property"]: grouping_value,
            "provenance": "official",
            "sourceName": "ISTAT",
        }
        named.append({
            "props": out_props,
            "geometry": f["geometry"],
            "vertices": count_vertices(f["geometry"]),
            "grouping": grouping_value,
            "sub_code": sub_code,
        })

    named.sort(key=lambda r: r["props"]["id"])

    # (d) measurements — max vertices + would-be serialized byte size
    max_vertices = max((r["vertices"] for r in named), default=0)
    max_vertex_feature = max(named, key=lambda r: r["vertices"], default=None)
    collection = {
        "type": "FeatureCollection",
        "features": [
            {"type": "Feature", "properties": r["props"], "geometry": r["geometry"]}
            for r in named
        ],
    }
    serialized = json.dumps(collection, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    output_bytes = len(serialized.encode("utf-8"))

    return {
        "problems": problems,
        "named": named,
        "placeholders": placeholders,
        "seen_ids": seen_ids,
        "max_vertices": max_vertices,
        "max_vertex_feature": max_vertex_feature,
        "output_bytes": output_bytes,
        "multipolygon_count": sum(
            1 for r in named if r["geometry"].get("type") == "MultiPolygon"
        ),
    }


def regioni_pop_2011():
    """POP_2011 by short region name from Regioni_Senato_2020 — the reference
    for condition (b)'s placeholder cross-check."""
    intermediate = OUTPUT_DIR / "regioni_senato_wgs84.geojson"
    raw = ogr_to_geojson(REGIONI_SENATO, intermediate)
    return {f["properties"]["DEN_REG"]: f["properties"]["POP_2011"] for f in raw["features"]}


def main():
    failures = []
    layers = {}
    for key, cfg in LAYERS.items():
        result = build_layer(key, cfg)
        layers[key] = result
        failures.extend(result["problems"])

    pop = regioni_pop_2011()
    vda = pop.get("Valle d'Aosta")
    taa = pop.get("Trentino-Alto Adige")

    print("=" * 72)
    print("Fase 25 — sonda geografia plurinominale (GO-PLURI)")
    print("=" * 72)

    # ---- (a) + (b): feature accounting & placeholder explanation ----
    for key, cfg in LAYERS.items():
        r = layers[key]
        named_n = len(r["named"])
        ph = r["placeholders"]
        print(f"\n[{key}] {cfg['raw_feature_count']} feature grezze = "
              f"{named_n} con denominazione + {len(ph)} segnaposto")
        if named_n != cfg["expected_named"]:
            failures.append(
                f"(b) {key}: {named_n} collegi con nome, attesi {cfg['expected_named']}"
            )
        if len(ph) != 1:
            failures.append(f"(b) {key}: {len(ph)} righe segnaposto, atteso esattamente 1")
        for p in ph:
            pop_2011 = p.get("POP_2011")
            print(f"  segnaposto: OBJECTID={p.get('OBJECTID')} "
                  f"{cfg['code_field']}={p.get(cfg['code_field'])} "
                  f"{cfg['denom_field']}={p.get(cfg['denom_field'])!r} POP_2011={pop_2011}")
            if key == "camera-plurinominale":
                if pop_2011 != vda:
                    failures.append(
                        f"(b) camera: POP_2011 segnaposto {pop_2011} != Valle d'Aosta {vda}"
                    )
                else:
                    print(f"    POP_2011 == Valle d'Aosta ({vda}) ✓")
            else:
                if vda is None or taa is None or pop_2011 != vda + taa:
                    failures.append(
                        f"(b) senato: POP_2011 segnaposto {pop_2011} != VdA+TAA "
                        f"({vda}+{taa})"
                    )
                else:
                    print(f"    POP_2011 == Valle d'Aosta + Trentino-Alto Adige "
                          f"({vda}+{taa}={vda + taa}) ✓")

    # ---- (d): byte/vertex measurements ----
    print("\n--- (d) misure a tolleranza {}m ---".format(SIMPLIFY_TOLERANCE_METERS))
    for key, cfg in LAYERS.items():
        r = layers[key]
        mf = r["max_vertex_feature"]
        pct_bytes = 100 * r["output_bytes"] / MAX_OUTPUT_BYTES
        pct_vert = 100 * r["max_vertices"] / MAX_VERTICES_PER_FEATURE
        print(f"[{key}] output ~{r['output_bytes']} B "
              f"({r['output_bytes'] / 1024:.0f} KB, {pct_bytes:.1f}% del gate 3 MB); "
              f"max vertici {r['max_vertices']} "
              f"({mf['props']['id'] if mf else '-'} {mf['props']['name'] if mf else ''}, "
              f"{pct_vert:.1f}% del gate 1500); MultiPolygon {r['multipolygon_count']}")
        if r["output_bytes"] > MAX_OUTPUT_BYTES:
            failures.append(f"(d) {key}: {r['output_bytes']} B supera il gate 3 MB")
        if r["max_vertices"] > MAX_VERTICES_PER_FEATURE:
            failures.append(f"(d) {key}: {r['max_vertices']} vertici supera il gate 1500")

    # ---- id collision check across all shipped + new boundary files ----
    shipped_ids = set()
    for path in (DISTRICTS_CAMERA, DISTRICTS_SENATO):
        for f in json.loads(path.read_text(encoding="utf-8"))["features"]:
            shipped_ids.add(f["properties"]["id"])
    camera_pluri_ids = layers["camera-plurinominale"]["seen_ids"]
    senato_pluri_ids = layers["senato-plurinominale"]["seen_ids"]
    all_new = camera_pluri_ids | senato_pluri_ids
    print("\n--- id: collisioni tra file di confine ---")
    print(f"  shipped uninominali: {len(shipped_ids)}  nuovi plurinominali: {len(all_new)} "
          f"(Camera {len(camera_pluri_ids)} + Senato {len(senato_pluri_ids)})")
    collide_shipped = shipped_ids & all_new
    collide_between = camera_pluri_ids & senato_pluri_ids
    if collide_shipped:
        failures.append(f"(id) collisione con id già pubblicati: {sorted(collide_shipped)}")
    if collide_between:
        failures.append(f"(id) collisione Camera/Senato plurinominale: {sorted(collide_between)}")
    if not collide_shipped and not collide_between:
        total = len(shipped_ids) + len(all_new)
        print(f"  nessuna collisione — {total} id univoci su tutti i file di confine")

    # ---- (c) + (e): deputy -> plurinominale collegio linkage ----
    # Camera plurinominale index: (normalize(circoscrizione), subCode) -> id
    index = {}
    canonical_circ = {}
    for r in layers["camera-plurinominale"]["named"]:
        key = (normalize_circoscrizione(r["grouping"]), r["sub_code"])
        index[key] = r["props"]["id"]
        canonical_circ[normalize_circoscrizione(r["grouping"])] = r["grouping"]
    circ_of_pluri = {
        r["props"]["id"]: r["grouping"] for r in layers["camera-plurinominale"]["named"]
    }

    # deputy dc:coverage (P-code) from the raw cache; electionType/circoscrizione
    # from the shipped representatives.json.
    bindings = json.loads(RAW_CAMERA.read_text(encoding="utf-8"))["results"]["bindings"]
    coverage_of = {}
    for x in bindings:
        pid = x["persona"]["value"].rstrip("/").rsplit("/", 1)[-1]
        cov = x.get("collegio", {}).get("value")
        if pid not in coverage_of and cov:
            coverage_of[pid] = cov

    reps = json.loads(REPRESENTATIVES.read_text(encoding="utf-8"))
    deputies = [r for r in reps if r["chamber"] == "Camera"]

    distinct_suffix_values = set()
    resolved_features = set()
    linkage_rows = []
    would_link = 0
    tipo_counter = Counter()
    absent_records = {"estero": [], "bare": []}
    for r in deputies:
        pid = r["id"]
        cov = coverage_of.get(pid)
        etype = r["electionType"]
        circ = r.get("circoscrizione")
        m = PLURI_SUFFIX_RE.match(cov or "")
        if cov and cov.strip().upper() in ESTERO_COVERAGE_VALUES:
            absent_records["estero"].append(pid)
            continue
        if not m:
            absent_records["bare"].append((pid, cov))
            continue
        distinct_suffix_values.add(cov)
        sub = m.group("sub")
        circ_norm = normalize_circoscrizione(m.group("circ"))
        district_id = index.get((circ_norm, sub))
        tipo_counter[etype] += 1
        if district_id is None:
            failures.append(
                f"(c) {pid}: coverage {cov!r} -> ({circ_norm!r},{sub}) non risolve a nessun "
                "collegio plurinominale Camera"
            )
            continue
        resolved_features.add(district_id)
        would_link += 1
        # consistency: the resolved plurinominale collegio's circoscrizione
        # must equal the deputy's shipped circoscrizione
        if circ is not None and circ != circ_of_pluri[district_id]:
            failures.append(
                f"(c) {pid}: circoscrizione deputato {circ!r} != collegio {district_id} "
                f"({circ_of_pluri[district_id]!r})"
            )
        linkage_rows.append({
            "personId": pid,
            "electionType": etype,
            "coverage": cov,
            "collegioPlurinominale": district_id,
            "circoscrizione": circ,
        })

    named_camera = len(layers["camera-plurinominale"]["named"])
    print("\n--- (c) collegamento deputato -> collegio plurinominale ---")
    print(f"  deputati con coverage P-suffix collegati: {would_link}")
    print(f"    per electionType: {dict(tipo_counter)}")
    print(f"  valori P-suffix distinti: {len(distinct_suffix_values)} "
          f"(collegi Camera plurinominali con nome: {named_camera})")
    print(f"  feature plurinominali Camera coperte: {len(resolved_features)}/{named_camera}")
    if len(distinct_suffix_values) != named_camera:
        failures.append(
            f"(c) valori P-suffix distinti {len(distinct_suffix_values)} != "
            f"collegi con nome {named_camera}"
        )
    if len(resolved_features) != named_camera:
        failures.append(
            f"(c) solo {len(resolved_features)}/{named_camera} collegi plurinominali "
            "coperti da un deputato"
        )

    print("\n--- (e) record senza collegioPlurinominale ---")
    print(f"  estero (coverage macro-circoscrizione): {len(absent_records['estero'])}")
    print(f"  bare (nessun P-code): {len(absent_records['bare'])}  "
          f"{[c for _, c in absent_records['bare']]}")
    print("  senatori: esenti per costruzione (linkage Camera-only)")

    # Full enumeration to the gitignored output dir
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUTPUT_DIR / "plurinominale_linkage.json").write_text(
        json.dumps({
            "linkage": linkage_rows,
            "absent_estero": absent_records["estero"],
            "absent_bare": absent_records["bare"],
            "camera_features": [r["props"] for r in layers["camera-plurinominale"]["named"]],
            "senato_features": [r["props"] for r in layers["senato-plurinominale"]["named"]],
        }, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("\n" + "=" * 72)
    if failures:
        print(f"NO-GO: {len(failures)} violazione/i:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        sys.exit(1)
    print("GO-PLURI: condizioni (a)-(e) verificate.")


if __name__ == "__main__":
    main()
