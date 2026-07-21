#!/usr/bin/env python3
"""Phase 21 scope probe — NETWORK-TOUCHING, run once under an explicit,
user-approved refetch-protocol decision (see docs/v3/21-votes-expansion.md;
never part of `make fetch`/`make refresh`).

Measures the four candidate scopes (the 20/30/40/50 most recent public
non-secret Camera Assemblea votazioni) and prints the decision table the
phase chooses from: attainable events, total positions (after the same
unmapped-deputy drop the real import applies), distinct sittings, distinct
atti + atto-bearing events, date span, secret exclusions inside the
window, dry-run normalized output bytes vs the 2 MiB gate, and the
projected full-bundle total from the *actual* current Data/ file sizes.

To mirror production rather than approximate it, this probe imports the
real pipeline's own functions: tools/import_votes.py's
group_by_votazione/votazione_sort_key (grouping + ordering) and
tools/fetch_camera_votes.py's fetch_detail/is_safe_uri (the VALUES-clause
detail fetch). Detail is fetched in chunks of 10 votazioni (~4,000 rows
each): the one prior single-shot fetch (25 events) returned 9,975 rows,
uncomfortably close to the ~10,000-row result cap observed on the *Senato*
endpoint in Phase 15b — chunking keeps every response far from any cap,
and the per-chunk row counts are printed so a truncation would be visible.

Raw responses land in tools/probes/output/ (gitignored) and are NEVER an
import source — if a scope is chosen, the real tools/fetch_camera_votes.py
runs afterwards under the refetch protocol.
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

TOOLS_DIR = Path(__file__).parent.parent
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))
from fetch_camera_votes import ENDPOINT, fetch_detail, is_safe_uri  # noqa: E402
from import_votes import RAW_VOTE_CHOICE, RAW_VOTE_RESULT, group_by_votazione, votazione_sort_key  # noqa: E402
from sparql_client import SPARQLFetchError, fetch_sparql, load_query  # noqa: E402

PROBES_DIR = Path(__file__).parent
OUTPUT_DIR = PROBES_DIR / "output"
DATA_DIR = ROOT / "Politici" / "Data"

CANDIDATE_SCOPES = [20, 30, 40, 50]
PROBE_WINDOW = max(CANDIDATE_SCOPES)
DETAIL_CHUNK_SIZE = 10
MAX_OUTPUT_BYTES = 2 * 1024 * 1024  # the standing per-file votes gate
SOFT_BUNDLE_BYTES = 10 * 1024 * 1024

BUNDLE_FILES = [
    "districts.geojson",
    "districts_senato.geojson",
    "representatives.json",
    "parties.json",
    "sources.json",
]


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def load_probe_query(name):
    text = (PROBES_DIR / name).read_text(encoding="utf-8")
    return "\n".join(l for l in text.splitlines() if not l.strip().startswith("#")).strip()


def simulate_import(ordered, scope, camera_stable_ids):
    """Exactly tools/import_votes.py's per-event record construction
    (unmapped-deputy drop, vocabulary mapping, normalized schema), over the
    `scope` most recent events, with no position cap — the probe's job is
    to measure what the cap SHOULD be."""
    events, positions = [], []
    dropped = 0
    for votazione in ordered[:scope]:
        result = RAW_VOTE_RESULT.get(votazione["approvato"], "Sconosciuto")
        for position in votazione["positions"]:
            numeric_id = position["deputatoNumericId"]
            if numeric_id is None or numeric_id not in camera_stable_ids:
                dropped += 1
                continue
            positions.append(
                {
                    "id": position["votoId"],
                    "voteEventId": votazione["voteId"],
                    "representativeId": f"p{numeric_id}",
                    "vote": RAW_VOTE_CHOICE.get(position["tipoVoto"], "Sconosciuto"),
                }
            )
        events.append(
            {
                "id": votazione["voteId"],
                "title": votazione["title"],
                "date": votazione["date"],
                "result": result,
                "sourceUrl": votazione["sourceUrl"],
                "provenance": "official",
            }
        )
    positions.sort(key=lambda r: (r["voteEventId"], r["id"]))
    serialized = json.dumps({"events": events, "positions": positions}, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    return events, positions, dropped, len(serialized.encode("utf-8"))


def main():
    # 1. Candidate window: the PROBE_WINDOW most recent non-secret votes.
    scope_query = load_query("camera_votazioni_scope.rq") + f"\nLIMIT {PROBE_WINDOW}"
    try:
        scope_payload, scope_count = fetch_sparql(ENDPOINT, scope_query, label="probe_votes_scope_window")
    except SPARQLFetchError as error:
        fail(str(error))
    scope_bindings = scope_payload["results"]["bindings"]
    uris = [b["v"]["value"] for b in scope_bindings]
    if not all(is_safe_uri(u) for u in uris):
        fail("URI votazione inatteso dalla scope query")
    window_dates = sorted(b["date"]["value"] for b in scope_bindings)
    print(f"Finestra candidata: {scope_count} votazioni non segrete, date {window_dates[0]}..{window_dates[-1]}")

    # 2. Secret exclusions inside the same window.
    secret_query = load_probe_query("probe_camera_votes_secret_window.rq") + f"\nLIMIT {PROBE_WINDOW * 3}"
    try:
        secret_payload, _ = fetch_sparql(ENDPOINT, secret_query, label="probe_votes_secret_window")
    except SPARQLFetchError as error:
        fail(str(error))
    secret_in_window = sum(
        1
        for b in secret_payload["results"]["bindings"]
        if b["segreta"]["value"] != "0" and b["date"]["value"] >= window_dates[0]
    )
    print(f"Votazioni segrete escluse nella stessa finestra temporale: {secret_in_window}")

    # 3. Detail, chunked; per-chunk row counts printed (cap watch).
    all_bindings = []
    for start in range(0, len(uris), DETAIL_CHUNK_SIZE):
        chunk = uris[start:start + DETAIL_CHUNK_SIZE]
        payload, rows = fetch_detail(chunk)
        print(f"  dettaglio chunk {start // DETAIL_CHUNK_SIZE + 1}: {len(chunk)} votazioni, {rows} righe")
        all_bindings.extend(payload["results"]["bindings"])

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUTPUT_DIR / "camera_votes_scope_window_detail.json").write_text(
        json.dumps({"results": {"bindings": all_bindings}}, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    # 4. Simulate the import per candidate scope.
    votazioni = group_by_votazione(all_bindings)
    ordered = sorted(votazioni.values(), key=votazione_sort_key, reverse=True)
    representatives = json.loads((DATA_DIR / "representatives.json").read_text(encoding="utf-8"))
    camera_stable_ids = {r["stableSourceId"] for r in representatives if r["chamber"] == "Camera"}

    other_bundle_bytes = sum((DATA_DIR / f).stat().st_size for f in BUNDLE_FILES)
    print(f"\nBundle Data/ attuale senza votes.json: {other_bundle_bytes:,} B")
    print(f"Gate per-file votes: {MAX_OUTPUT_BYTES:,} B; tetto morbido bundle: {SOFT_BUNDLE_BYTES:,} B\n")

    header = f"{'scope':>5} {'eventi':>6} {'posizioni':>9} {'scartate':>8} {'sedute':>6} {'atti(ev.)':>9} {'span':>23} {'bytes':>11} {'%gate':>6} {'bundle':>11}"
    print(header)
    print("-" * len(header))
    for scope in CANDIDATE_SCOPES:
        events, positions, dropped, dry_bytes = simulate_import(ordered, scope, camera_stable_ids)
        sittings = {e["id"].split("_")[1] for e in events}
        dates = sorted(e["date"] for e in events)
        atto_bearing = [e for e in events if " — " in e["title"]]
        atti = {e["title"].split(" — ", 1)[1] for e in atto_bearing}
        bundle = other_bundle_bytes + dry_bytes
        print(
            f"{scope:>5} {len(events):>6} {len(positions):>9} {dropped:>8} {len(sittings):>6} "
            f"{f'{len(atti)}({len(atto_bearing)})':>9} {f'{dates[0]}..{dates[-1]}':>23} "
            f"{dry_bytes:>11,} {dry_bytes / MAX_OUTPUT_BYTES * 100:>5.1f}% {bundle:>11,}"
        )

    print("\nNota: 'bytes' è il dry-run esatto dello schema normalizzato Fase 20 "
          "(stessi settaggi di serializzazione dell'import reale).")


if __name__ == "__main__":
    main()
