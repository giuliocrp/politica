#!/usr/bin/env python3
"""Phase 27 metadata-only window probe — NETWORK-TOUCHING, run once under an
explicit, user-approved refetch-protocol decision (see
docs/v4/27-votes-stratified.md; never part of `make fetch`/`make refresh`).

Fetches a deep window of Camera Assemblea XIX votazione METADATA (URI, date,
segreta, finale, atto label) — NO per-deputy positions — paging with
LIMIT/OFFSET over the total, stable ORDER BY DESC(?date) ?v so paging is
deterministic. Pages until the accumulated non-secret window spans at least
MIN_SPAN_DAYS (≥6 months + headroom) or a page returns fewer than PAGE_SIZE
rows (end of data), with a hard page cap for safety.

Answers open question Q3 (dati.camera.it OFFSET/paging behaviour): each page
is cross-checked against the previous one for URI overlap and date
monotonicity, and the findings are printed. The raw accumulated response
lands in tools/probes/output/ (gitignored) and is NEVER an import source —
tools/select_votes_scope.py (offline) reads it to choose the URI list.
"""

import json
import sys
from collections import Counter
from datetime import date
from pathlib import Path

TOOLS_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(TOOLS_DIR))
from sparql_client import SPARQLFetchError, fetch_sparql  # noqa: E402

PROBES_DIR = Path(__file__).parent
OUTPUT_DIR = PROBES_DIR / "output"
ENDPOINT = "https://dati.camera.it/sparql"
QUERY_FILE = PROBES_DIR / "probe_camera_votes_metadata_window.rq"

PAGE_SIZE = 2000
MAX_PAGES = 8            # hard safety cap: at most 16,000 rows fetched
MIN_SPAN_DAYS = 215      # ≥ ~7 months, headroom over the 6-month gate line


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def load_query_body():
    text = QUERY_FILE.read_text(encoding="utf-8")
    return "\n".join(l for l in text.splitlines() if not l.strip().startswith("#")).strip()


def to_ordinal(yyyymmdd):
    return date(int(yyyymmdd[0:4]), int(yyyymmdd[4:6]), int(yyyymmdd[6:8])).toordinal()


def main():
    body = load_query_body()
    all_bindings = []
    seen_uris = set()
    prev_last_date = None
    q3_notes = []

    print(f"Finestra metadati paginata (PAGE_SIZE={PAGE_SIZE}, ORDER BY DESC(date) ?v)...")
    for page in range(MAX_PAGES):
        offset = page * PAGE_SIZE
        query = f"{body}\nLIMIT {PAGE_SIZE}\nOFFSET {offset}"
        try:
            payload, count = fetch_sparql(ENDPOINT, query, label=f"metadata_window_p{page}")
        except SPARQLFetchError as error:
            fail(str(error))
        rows = payload["results"]["bindings"]
        page_uris = [b["v"]["value"] for b in rows]
        page_dates = [b["date"]["value"] for b in rows]

        # Q3 checks: overlap with everything seen so far, and date monotonicity.
        overlap = sum(1 for u in page_uris if u in seen_uris)
        first_date, last_date = (page_dates[0], page_dates[-1]) if page_dates else (None, None)
        mono_ok = all(page_dates[i] >= page_dates[i + 1] for i in range(len(page_dates) - 1))
        boundary_ok = prev_last_date is None or first_date is None or first_date <= prev_last_date
        print(
            f"  pagina {page + 1} (OFFSET {offset}): {count} righe, "
            f"date {last_date}..{first_date}, overlap_URI={overlap}, "
            f"monotona={mono_ok}, confine_ok={boundary_ok}"
        )
        q3_notes.append({
            "page": page + 1, "offset": offset, "rows": count,
            "overlap_with_seen": overlap, "date_first": first_date,
            "date_last": last_date, "monotonic": mono_ok, "boundary_ok": boundary_ok,
        })

        for b in rows:
            u = b["v"]["value"]
            if u not in seen_uris:
                seen_uris.add(u)
                all_bindings.append(b)
        prev_last_date = last_date if last_date else prev_last_date

        if count < PAGE_SIZE:
            print("  (pagina non piena — fine dei dati)")
            break

        # Enough non-secret depth yet?
        nonsecret_dates = [b["date"]["value"] for b in all_bindings if b["segreta"]["value"] == "0"]
        if nonsecret_dates:
            span = to_ordinal(max(nonsecret_dates)) - to_ordinal(min(nonsecret_dates))
            if span >= MIN_SPAN_DAYS:
                print(f"  (raggiunta profondità: {span} giorni di span non-segreto ≥ {MIN_SPAN_DAYS})")
                break

    # Summary over the accumulated, de-duplicated window.
    nonsecret = [b for b in all_bindings if b["segreta"]["value"] == "0"]
    secret = [b for b in all_bindings if b["segreta"]["value"] != "0"]
    ns_dates = sorted(b["date"]["value"] for b in nonsecret)
    ns_sittings = {b["v"]["value"].rsplit("/", 1)[-1].split("_")[1] for b in nonsecret}
    ns_atto = [b for b in nonsecret if b.get("attoLabel", {}).get("value")]
    ns_atti = {b["attoLabel"]["value"] for b in ns_atto}
    ns_finale = [b for b in nonsecret if b.get("finale", {}).get("value") == "1"]
    ns_finale_atto = [b for b in ns_atto if b.get("finale", {}).get("value") == "1"]
    span_days = to_ordinal(ns_dates[-1]) - to_ordinal(ns_dates[0]) if ns_dates else 0
    per_sitting = Counter(b["v"]["value"].rsplit("/", 1)[-1].split("_")[1] for b in nonsecret)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUTPUT_DIR / "camera_votes_metadata_window.json"
    out_path.write_text(
        json.dumps({"q3_pages": q3_notes, "results": {"bindings": all_bindings}},
                   ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("\n=== Finestra metadati (deduplicata) ===")
    print(f"votazioni totali:        {len(all_bindings)}")
    print(f"  non segrete:           {len(nonsecret)}")
    print(f"  segrete (escluse):     {len(secret)}")
    print(f"span non-segreto:        {ns_dates[0]}..{ns_dates[-1]}  ({span_days} giorni ≈ {span_days/30.4:.1f} mesi)")
    print(f"sedute distinte (n.s.):  {len(ns_sittings)}")
    print(f"atto-bearing (n.s.):     {len(ns_atto)}  su {len(nonsecret)}  (atti distinti: {len(ns_atti)})")
    print(f"voti finali (n.s.):      {len(ns_finale)}  (di cui atto-bearing: {len(ns_finale_atto)})")
    print(f"media voti n.s./seduta:  {len(nonsecret)/max(1,len(ns_sittings)):.1f}")
    print(f"\nsalvato in {out_path.relative_to(TOOLS_DIR.parent)}")


if __name__ == "__main__":
    main()
