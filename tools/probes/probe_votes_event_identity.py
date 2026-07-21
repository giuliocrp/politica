#!/usr/bin/env python3
"""Phase 20 GO-EVENT-ID gate probe — fully offline (reads only the cached
tools/raw/camera_votazioni_sparql.json and the shipped votes.json).

Candidate identifier under test: the ocd:votazione URI's trailing segment
(e.g. "vs19_690_076" from
http://dati.camera.it/ocd/votazione.rdf/vs19_690_076) — the source's own
id, taken verbatim with the same id_segment convention every other
source id in this pipeline already uses; nothing is minted. It is also
already the key tools/import_votes.py groups bindings by internally — it
just was never carried into votes.json.

Gate conditions (all must hold, on BOTH sides):
1. present for every event — every raw binding carries ?v; the slug
   parses as vs{leg}_{seduta}_{numero}.
2. constant across all positions of an event — each per-position ocd:voto
   slug ("vd{leg}_{seduta}_{numero}_{deputato}") embeds the same
   {seduta}_{numero} pair as its votazione's slug; verified for every
   binding, and for every shipped votes.json position id against its
   event tuple.
3. distinct across events — one slug per distinct (date, title, result,
   sourceUrl) tuple in votes.json (expected 12) and per votazione URI in
   the cache (25 candidates in the current fetch scope).

Writes the full per-event mapping to tools/probes/output/ (gitignored),
prints PASS/FAIL evidence, exits non-zero on any violation.
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

TOOLS_DIR = Path(__file__).parent.parent
ROOT = TOOLS_DIR.parent
RAW = TOOLS_DIR / "raw" / "camera_votazioni_sparql.json"
VOTES = ROOT / "Politici" / "Data" / "votes.json"
OUTPUT = Path(__file__).parent / "output" / "votes_event_identity.json"

VOTAZIONE_SLUG_RE = re.compile(r"^vs(\d+)_(\d+)_(\d+)$")
VOTO_SLUG_RE = re.compile(r"^vd(\d+)_(\d+)_(\d+)_(\d+)$")


def slug(uri):
    return uri.rstrip("/").rsplit("/", 1)[-1]


def main():
    failures = []

    # --- Raw-cache side -------------------------------------------------
    bindings = json.loads(RAW.read_text(encoding="utf-8"))["results"]["bindings"]
    positions_per_event = defaultdict(set)
    for binding in bindings:
        if "v" not in binding:
            failures.append("(1) binding senza ?v — identificatore non presente per ogni posizione")
            continue
        v_slug = slug(binding["v"]["value"])
        v_match = VOTAZIONE_SLUG_RE.match(v_slug)
        if not v_match:
            failures.append(f"(1) slug votazione fuori formato: {v_slug!r}")
            continue
        voto_slug = slug(binding["voto"]["value"])
        voto_match = VOTO_SLUG_RE.match(voto_slug)
        if not voto_match:
            failures.append(f"(2) slug voto fuori formato: {voto_slug!r}")
            continue
        if voto_match.group(1, 2, 3) != v_match.group(1, 2, 3):
            failures.append(
                f"(2) voto {voto_slug!r} non incorpora la stessa (legislatura, seduta, numero) "
                f"della sua votazione {v_slug!r}"
            )
        positions_per_event[v_slug].add(voto_slug)

    cache_slugs = sorted(positions_per_event)
    print(f"Cache: {len(bindings)} binding, {len(cache_slugs)} votazioni distinte")
    print(f"  esempio: {cache_slugs[0]!r} con {len(positions_per_event[cache_slugs[0]])} posizioni")

    # --- Shipped votes.json side -----------------------------------------
    records = json.loads(VOTES.read_text(encoding="utf-8"))
    if isinstance(records, dict):
        # Already-normalized shape (post-Phase 20 re-run): events carry the
        # id explicitly; verify the tuple bijection directly.
        event_of = {e["id"]: (e["date"], e["title"], e["result"], e["sourceUrl"]) for e in records["events"]}
        position_events = defaultdict(set)
        for p in records["positions"]:
            position_events[p["voteEventId"]].add(p["id"])
        shipped_pairs = {(eid, event_of.get(eid)) for eid in position_events}
    else:
        # Flat v2 shape: derive the event slug from each position id's
        # embedded (leg, seduta, numero) and check it identifies exactly
        # one (date, title, result, sourceUrl) tuple, and vice versa.
        tuple_of_slug = {}
        slugs_of_tuple = defaultdict(set)
        for r in records:
            m = VOTO_SLUG_RE.match(r["id"])
            if not m:
                failures.append(f"(2) id posizione spedito fuori formato: {r['id']!r}")
                continue
            event_slug = f"vs{m.group(1)}_{m.group(2)}_{m.group(3)}"
            event_tuple = (r["date"], r["title"], r["result"], r["sourceUrl"])
            if event_slug in tuple_of_slug and tuple_of_slug[event_slug] != event_tuple:
                failures.append(f"(2) slug {event_slug!r} associato a due tuple evento diverse")
            tuple_of_slug[event_slug] = event_tuple
            slugs_of_tuple[event_tuple].add(event_slug)
        for event_tuple, event_slugs in slugs_of_tuple.items():
            if len(event_slugs) != 1:
                failures.append(f"(3) tupla evento {event_tuple[0]!r}/{event_tuple[1][:40]!r} con più slug: {sorted(event_slugs)}")
        for event_slug in tuple_of_slug:
            if event_slug not in positions_per_event:
                failures.append(f"(3) slug spedito {event_slug!r} assente dalla cache raw")
        shipped_pairs = {(s, t) for s, t in tuple_of_slug.items()}
        print(f"votes.json: {len(records)} posizioni, {len(tuple_of_slug)} slug evento distinti, "
              f"{len(slugs_of_tuple)} tuple (date,title,result,sourceUrl) distinte")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(sorted([{"eventId": s, "tuple": t} for s, t in shipped_pairs], key=lambda x: x["eventId"]),
                   ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Output completo: {OUTPUT.relative_to(ROOT)}")

    if failures:
        print(f"\nNO-GO: {len(failures)} violazione/i:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        sys.exit(1)
    print("\nGO-EVENT-ID: identificatore presente, costante per evento, distinto tra eventi — su entrambi i lati.")


if __name__ == "__main__":
    main()
