#!/usr/bin/env python3
"""Phase 18 GO-CIRC gate probe — fully offline (reads only the cached
tools/raw/camera_deputati_sparql.json, the shipped districts.geojson, and
representatives.json). Evaluates the five gate conditions of the Phase 18
plan against the *actual* cache, printing per-condition PASS/FAIL evidence
and writing the full parsed enumeration to tools/probes/output/
(gitignored). Exits non-zero if any condition fails.

Parse rule under test (the "explicit, source-backed rule" of condition a):

1. coverage in ESTERO_COVERAGE_VALUES (the 4 estero macro-constituency
   names, verified in v2 via live introspection — see
   docs/v2/03-linkage-report.md) -> "Estero".
2. coverage matching "^(.+) - P\\d+$" -> the prefix is the circoscrizione
   name, the suffix the plurinominale collegio code.
3. bare coverage (anything else) -> the whole literal is the
   circoscrizione name. Only two such values exist in the cache, both
   structurally explained (see the report): "VALLE D'AOSTA" (the one
   circoscrizione with no plurinominale collegio — its single seat is
   uninominale) and "VENETO 2" (borne by exactly the two "maggioritario
   suppletiva" deputies — by-election records carry no P-collegio).

Domestic names are matched to the 28 shipped districts.geojson
circoscrizione values via normalize_circoscrizione — the same Phase 8
normalization the uninominale linkage already uses (imported from
tools/import_representatives.py, not duplicated).
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

TOOLS_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(TOOLS_DIR))
from import_representatives import ESTERO_COVERAGE_VALUES, normalize_circoscrizione  # noqa: E402

ROOT = TOOLS_DIR.parent
RAW = TOOLS_DIR / "raw" / "camera_deputati_sparql.json"
DISTRICTS = ROOT / "Politici" / "Data" / "districts.geojson"
REPRESENTATIVES = ROOT / "Politici" / "Data" / "representatives.json"
OUTPUT = Path(__file__).parent / "output" / "camera_coverage_enumeration.json"

PLURI_SUFFIX_RE = re.compile(r"^(?P<circ>.+) - P\d+$")


def parse_coverage(coverage):
    """Returns ("Estero"|circoscrizione-name, category) per the module
    docstring's three-branch rule."""
    if coverage in ESTERO_COVERAGE_VALUES:
        return "Estero", "estero"
    match = PLURI_SUFFIX_RE.match(coverage)
    if match:
        return match.group("circ"), "suffixed"
    return coverage, "bare"


def main():
    bindings = json.loads(RAW.read_text(encoding="utf-8"))["results"]["bindings"]

    people = {}
    coverages_per_person = defaultdict(set)
    for x in bindings:
        pid = x["persona"]["value"].rstrip("/").rsplit("/", 1)[-1]
        coverage = x.get("collegio", {}).get("value")
        if coverage:
            coverages_per_person[pid].add(coverage)
        if pid not in people:
            people[pid] = {
                "coverage": coverage,
                "tipoElezione": x.get("tipoElezione", {}).get("value"),
            }

    features = json.loads(DISTRICTS.read_text(encoding="utf-8"))["features"]
    canonical = {}  # normalize(circoscrizione) -> shipped circoscrizione string
    for f in features:
        circ = f["properties"]["circoscrizione"]
        canonical[normalize_circoscrizione(circ)] = circ
    district_circ = {f["properties"]["id"]: f["properties"]["circoscrizione"] for f in features}

    representatives = json.loads(REPRESENTATIVES.read_text(encoding="utf-8"))
    district_of = {r["id"]: r["districtId"] for r in representatives if r["chamber"] == "Camera"}

    failures = []
    enumeration = []
    parsed_domestic = set()
    estero_count = 0
    bare_holders = []

    # (a) every literal parses; (b) parsed set within 28 ∪ {Estero}
    for pid, p in sorted(people.items()):
        coverage = p["coverage"]
        if not coverage:
            failures.append(f"(a) {pid}: nessun valore dc:coverage")
            continue
        name, category = parse_coverage(coverage)
        entry = {"personId": pid, "coverage": coverage, "category": category}
        if category == "estero":
            estero_count += 1
            entry["circoscrizione"] = "Estero"
        else:
            key = normalize_circoscrizione(name)
            if key not in canonical:
                failures.append(
                    f"(b) {pid}: {coverage!r} -> {name!r} non è tra le 28 circoscrizioni di districts.geojson"
                )
                entry["circoscrizione"] = None
            else:
                entry["circoscrizione"] = canonical[key]
                parsed_domestic.add(canonical[key])
            if category == "bare":
                bare_holders.append((pid, coverage, p["tipoElezione"]))
        enumeration.append(entry)

    # (a) continued: the bare values must be the two structurally-explained
    # ones, not new surprises.
    unexplained_bare = {
        cov for _, cov, tipo in bare_holders
        if not (cov == "VALLE D'AOSTA" or (cov == "VENETO 2" and tipo == "maggioritario suppletiva"))
    }
    if unexplained_bare:
        failures.append(f"(a) valori bare non spiegati: {sorted(unexplained_bare)}")

    # (c) uninominale cross-check against the shipped linkage
    checked = mismatched = 0
    by_circ = {e["personId"]: e["circoscrizione"] for e in enumeration}
    for r in representatives:
        if r["chamber"] != "Camera" or r["districtId"] is None:
            continue
        checked += 1
        derived = by_circ.get(r["id"])
        shipped = district_circ.get(r["districtId"])
        if derived != shipped:
            mismatched += 1
            failures.append(f"(c) {r['id']}: derivata {derived!r} != collegio {r['districtId']} ({shipped!r})")

    # (d) no deputy with >1 coverage; no normalization collision
    multi = {pid: sorted(v) for pid, v in coverages_per_person.items() if len(v) > 1}
    if multi:
        failures.append(f"(d) deputati con più di un dc:coverage: {multi}")
    if len(canonical) != len({f["properties"]["circoscrizione"] for f in features}):
        failures.append("(d) collisione di normalizzazione tra le 28 circoscrizioni")

    # (e) estero identified by its own value, borne only by proporzionale
    for pid, p in people.items():
        if p["coverage"] in ESTERO_COVERAGE_VALUES and p["tipoElezione"] != "proporzionale":
            failures.append(f"(e) {pid}: coverage estero {p['coverage']!r} con tipoElezione {p['tipoElezione']!r}")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(enumeration, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Deputati: {len(people)}  (coverage presente per tutti: {all(p['coverage'] for p in people.values())})")
    print(f"Valori dc:coverage distinti: {len({p['coverage'] for p in people.values()})}")
    print(f"  estero: {estero_count} deputati su {len(ESTERO_COVERAGE_VALUES)} valori")
    print(f"  bare: {[(cov, tipo) for _, cov, tipo in bare_holders]}")
    print(f"Circoscrizioni distinte derivate (domestiche): {len(parsed_domestic)}/28 presenti in districts.geojson")
    print(f"Cross-check uninominale (c): {checked - mismatched}/{checked} coerenti")
    print(f"Output completo: {OUTPUT.relative_to(ROOT)}")

    if failures:
        print(f"\nNO-GO: {len(failures)} violazione/i:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        sys.exit(1)
    print("\nGO-CIRC: tutte e cinque le condizioni (a)-(e) verificate.")


if __name__ == "__main__":
    main()
