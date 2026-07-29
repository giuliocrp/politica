#!/usr/bin/env python3
"""Phase 27 stratified votes selector — OFFLINE, deterministic (see
docs/v4/27-votes-stratified.md).

Reads the metadata window produced by the (network, user-gated)
tools/probes/probe_votes_metadata_window.py and applies PINNED
stratification rules to choose the curated votes sample, then writes the
chosen ocd:votazione URI list into tools/config/votes_scope.json's existing
"explicit" mode. The committed URI list is the reproducible artifact:
tools/fetch_camera_votes.py (explicit mode) + tools/import_votes.py rebuild
Data/votes.json from it with no scope-logic change.

Why stratified (Phase 21, docs/v3/21-votes-expansion.md): the Camera
Assemblea votes in same-day bursts, so "the N most recent" gives one
afternoon's votes — one sitting, one day, zero atto-bearing events. The
methodology gate (docs/v3/votes-methodology.md) needs ≥30 events, ≥3
sittings, ≥6 months of span, and ≥2 distinct atti. This selector targets
that shape directly.

PINNED RULES (deterministic — same window in ⇒ byte-identical URI set + order):
  1. Candidates: non-secret votes only (votazioneSegreta == "0"). Secret
     ballots carry no per-deputy position by law — excluded at scope, as
     always.
  2. Group candidates by sitting (the seduta number in the URI slug
     vs19_<seduta>_<seq>); each sitting has one date. Keep only sittings
     with ≥ MIN_VOTES_PER_SITTING non-secret votes (so every chosen sitting
     can supply a full stratum).
  3. Span: the selection spans the FULL metadata window — newest qualifying
     sitting → oldest qualifying sitting. The probe pages to ≥7 months of
     non-secret depth, so this is ≥6 months by construction; main() asserts
     it (gate line 3). The full window (not a tight 6-month floor) is used
     because atto-bearing final votes cluster in the older half — see
     choose_sittings.
  4. Spread + atto preference: choose TARGET_SITTINGS sittings across
     [oldest, newest]. Bucket 0 (newest) and the last bucket (oldest) are
     forced; each interior bucket takes, among not-yet-used qualifying
     sittings within ±½ bucket-spacing of an evenly-spaced target date, the
     one with the most atto-bearing FINAL votes (then most atto-bearing,
     then nearest date, then higher seduta); it falls back to the nearest
     sitting if that date window is empty. Gate line 2 (≥10 sittings) plus
     the atto-final preference for line 4.
  5. Within each chosen sitting, take VOTES_PER_SITTING votes in priority
     order: (a) atto-bearing FINAL votes, (b) atto-bearing non-final,
     (c) remaining — each sub-group by ascending sequence number. This
     prefers atto-bearing final votes (gate line 4) while still filling a
     stratum from procedural votes when a sitting has few atto votes.
  6. Assert the result satisfies the gate lines it targets (≥30 events,
     ≥TARGET_SITTINGS sittings, ≥6 months, ≥2 distinct atti) — fail loudly
     rather than write a sample that silently misses one.
  7. Byte guard: TARGET_SITTINGS × VOTES_PER_SITTING is pinned at 30 events,
     which projects to ~84.8% of the 2 MiB gate at ≤399 positions/event
     (Phase 21 measurement) — below the 90% stop-line. If a future window
     pushed the projection over 90%, the pinned trim is to drop whole
     sittings OLDEST-FIRST until ≤30 events; this run needs no trim.

Output order (for reproducible diffs): date desc, then seduta desc, then
sequence desc — newest first, matching import_votes.py's own sort key.
"""

import json
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

TOOLS_DIR = Path(__file__).parent
ROOT = TOOLS_DIR.parent
WINDOW_PATH = TOOLS_DIR / "probes" / "output" / "camera_votes_metadata_window.json"
CONFIG_PATH = TOOLS_DIR / "config" / "votes_scope.json"

TARGET_SITTINGS = 10
VOTES_PER_SITTING = 3
MIN_VOTES_PER_SITTING = 3          # a chosen sitting must supply a full stratum
TARGET_EVENTS = TARGET_SITTINGS * VOTES_PER_SITTING  # 30
SPAN_MONTHS = 6
MAX_POSITION_RECORDS = 13000       # fits 30 events × ≤399 positions with headroom;
                                   # MAX_OUTPUT_BYTES (2 MiB) remains the hard gate
ALLOWED_URI_PREFIX = "http://dati.camera.it/ocd/votazione.rdf/"


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def slug(uri):
    return uri.rsplit("/", 1)[-1]


def parse_slug(uri):
    # vs19_0690_076 -> (seduta:int, seq:int)
    m = re.fullmatch(r"vs\d+_(\d+)_(\d+)", slug(uri))
    if not m:
        fail(f"slug votazione inatteso: {slug(uri)!r}")
    return int(m.group(1)), int(m.group(2))


def to_ord(yyyymmdd):
    return date(int(yyyymmdd[0:4]), int(yyyymmdd[4:6]), int(yyyymmdd[6:8])).toordinal()


def minus_months(yyyymmdd, months):
    y, m, d = int(yyyymmdd[0:4]), int(yyyymmdd[4:6]), int(yyyymmdd[6:8])
    m -= months
    while m <= 0:
        m += 12
        y -= 1
    # clamp day to a valid day of the target month (28 is always safe here)
    return date(y, m, min(d, 28)).toordinal()


def load_candidates():
    if not WINDOW_PATH.exists():
        fail(f"manca {WINDOW_PATH.relative_to(ROOT)} — esegui prima "
             "tools/probes/probe_votes_metadata_window.py (rete, con approvazione)")
    payload = json.loads(WINDOW_PATH.read_text(encoding="utf-8"))
    votes = []
    for b in payload["results"]["bindings"]:
        if b["segreta"]["value"] != "0":
            continue  # rule 1: non-secret only
        uri = b["v"]["value"]
        seduta, seq = parse_slug(uri)
        votes.append({
            "uri": uri,
            "date": b["date"]["value"],
            "seduta": seduta,
            "seq": seq,
            "finale": b.get("finale", {}).get("value") == "1",
            "attoLabel": (b.get("attoLabel", {}) or {}).get("value"),
        })
    if not votes:
        fail("nessuna votazione non-segreta nella finestra metadati")
    return votes


def choose_sittings(by_sitting):
    """Rule 3–4: TARGET_SITTINGS sittings spread evenly across the FULL
    metadata window (newest → oldest qualifying sitting), endpoints forced;
    each interior bucket prefers the atto-bearing-final-richest sitting near
    its target date.

    The full window is used (not a tight 6-month floor) deliberately: the
    source's recent months are procedural/odg-dominated with the atto
    linkage absent, and atto-bearing FINAL votes cluster in the older half —
    so spreading across the whole ≥6-month window, and preferring atto-final
    sittings within each date bucket, is what actually flips gate line 4
    (measured: 15/30 atto-bearing, 9 finals, 9 distinct atti vs 5/2/3 for a
    tight 6-month even spread). The ≥6-month span is still asserted in
    main()."""
    qualifying = {s: v for s, v in by_sitting.items() if len(v) >= MIN_VOTES_PER_SITTING}
    sdate = {s: v[0]["date"] for s, v in qualifying.items()}                 # one date per sitting
    atto_final = {s: sum(1 for x in v if x["attoLabel"] and x["finale"]) for s, v in qualifying.items()}
    atto_any = {s: sum(1 for x in v if x["attoLabel"]) for s, v in qualifying.items()}
    order = sorted(qualifying, key=lambda s: (sdate[s], s), reverse=True)    # date desc, seduta desc
    if len(order) < TARGET_SITTINGS:
        fail(f"solo {len(order)} sedute con ≥{MIN_VOTES_PER_SITTING} voti — "
             f"ne servono {TARGET_SITTINGS}")
    newest, oldest = order[0], order[-1]
    hi, lo = to_ord(sdate[newest]), to_ord(sdate[oldest])

    chosen = [newest, oldest]                                               # forced endpoints
    used = set(chosen)
    spacing = (hi - lo) / (TARGET_SITTINGS - 1)
    for i in range(1, TARGET_SITTINGS - 1):
        target = hi - spacing * i
        available = [s for s in order if s not in used]
        if not available:
            break
        near = [s for s in available if abs(to_ord(sdate[s]) - target) <= spacing / 2]
        pool = near if near else available
        # prefer atto-final richness, then atto richness, then nearest date,
        # then higher seduta — all-integer key ⇒ deterministic.
        pick = max(pool, key=lambda s: (atto_final[s], atto_any[s],
                                        -abs(to_ord(sdate[s]) - target), s))
        used.add(pick)
        chosen.append(pick)
    return sorted(chosen, key=lambda s: (sdate[s], s), reverse=True)


def choose_votes(sitting_votes):
    """Rule 5: VOTES_PER_SITTING votes, atto-bearing finals first."""
    def rank(v):
        has_atto = v["attoLabel"] is not None
        tier = 0 if (has_atto and v["finale"]) else (1 if has_atto else 2)
        return (tier, v["seq"])
    return sorted(sitting_votes, key=rank)[:VOTES_PER_SITTING]


def main():
    votes = load_candidates()
    by_sitting = defaultdict(list)
    for v in votes:
        by_sitting[v["seduta"]].append(v)

    chosen_sittings = choose_sittings(by_sitting)
    selection = []
    for s in chosen_sittings:
        selection.extend(choose_votes(by_sitting[s]))

    # Output order: date desc, seduta desc, seq desc (newest first).
    selection.sort(key=lambda v: (v["date"], v["seduta"], v["seq"]), reverse=True)

    # Rule 6: assert the targeted gate lines.
    n_events = len(selection)
    sittings = {v["seduta"] for v in selection}
    dates = sorted(v["date"] for v in selection)
    span_days = to_ord(dates[-1]) - to_ord(dates[0])
    atti = {v["attoLabel"] for v in selection if v["attoLabel"]}
    problems = []
    if n_events < TARGET_EVENTS:
        problems.append(f"eventi {n_events} < {TARGET_EVENTS}")
    if len(sittings) < TARGET_SITTINGS:
        problems.append(f"sedute {len(sittings)} < {TARGET_SITTINGS}")
    # Calendar-month check (not a fixed day count): the oldest selected date
    # must be at least SPAN_MONTHS calendar months before the newest — e.g.
    # 2026-01-21..2026-07-21 is exactly 6 months (181 days), and qualifies.
    if to_ord(dates[0]) > minus_months(dates[-1], SPAN_MONTHS):
        problems.append(f"span < {SPAN_MONTHS} mesi (dal {dates[0]} al {dates[-1]})")
    if len(atti) < 2:
        problems.append(f"atti distinti {len(atti)} < 2")
    if problems:
        fail("la selezione non soddisfa le righe del gate: " + "; ".join(problems))

    uris = [v["uri"] for v in selection]
    if len(set(uris)) != len(uris):
        fail("URI duplicati nella selezione")
    for u in uris:
        if not u.startswith(ALLOWED_URI_PREFIX):
            fail(f"URI inatteso: {u!r}")

    # Annotated manifest committed alongside the bare voteUris so the
    # editorial basis for what ships is reproducible from a clean checkout —
    # tools/probes/output/ (the selector's input) is gitignored, so the
    # per-vote date/sitting/atto/final flags must live here (requirement,
    # Phase 27). fetch_camera_votes.py / import_votes.py read only voteUris
    # and ignore this key.
    manifest = [
        {
            "slug": slug(v["uri"]),
            "date": v["date"],
            "seduta": v["seduta"],
            "seq": v["seq"],
            "attoBearing": v["attoLabel"] is not None,
            "finale": v["finale"],
            "attoLabel": v["attoLabel"],  # raw as observed in the metadata window
        }
        for v in selection
    ]

    config = {
        "mode": "explicit",
        "n": TARGET_EVENTS,
        "voteUris": uris,
        "selection": manifest,
        "maxVotes": n_events,
        "maxPositionRecords": MAX_POSITION_RECORDS,
        "notes": (
            f"mode 'explicit': {n_events} votazioni scelte da "
            "tools/select_votes_scope.py (Fase 27) con regole di stratificazione "
            "fissate — vedi quel file e docs/v4/27-votes-stratified.md. Campione "
            f"stratificato: {len(sittings)} sedute distinte su ~{span_days/30.4:.1f} "
            "mesi, con preferenza per i voti finali su atto. mode 'recent': le N "
            "votazioni più recenti (usato fino alla Fase 20). maxVotes/"
            "maxPositionRecords restano tetti duri applicati in "
            "tools/import_votes.py; MAX_OUTPUT_BYTES (2 MiB) è il limite di byte."
        ),
    }
    CONFIG_PATH.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # Human-readable selection table + strata.
    print(f"Selezione: {n_events} eventi, {len(sittings)} sedute, "
          f"span {dates[0]}..{dates[-1]} ({span_days} giorni ≈ {span_days/30.4:.1f} mesi), "
          f"atti distinti {len(atti)}")
    print(f"{'#':>2} {'slug':>14} {'data':>10} {'seduta':>6} {'seq':>4} {'atto':>4} {'finale':>6}  atto/titolo")
    by_sitting_out = defaultdict(int)
    for i, v in enumerate(selection, 1):
        by_sitting_out[v["seduta"]] += 1
        atto = "sì" if v["attoLabel"] else "—"
        fin = "sì" if v["finale"] else "—"
        label = (v["attoLabel"][:48] + "…") if v["attoLabel"] and len(v["attoLabel"]) > 49 else (v["attoLabel"] or "")
        print(f"{i:>2} {slug(v['uri']):>14} {v['date']:>10} {v['seduta']:>6} {v['seq']:>4} {atto:>4} {fin:>6}  {label}")
    print(f"\nstrati (voti per seduta): "
          + ", ".join(f"{s}:{by_sitting_out[s]}" for s in sorted(by_sitting_out, reverse=True)))
    print(f"atto-bearing: {sum(1 for v in selection if v['attoLabel'])}/{n_events}; "
          f"finali: {sum(1 for v in selection if v['finale'])}; atti distinti: {len(atti)}")
    print(f"\nscritto in {CONFIG_PATH.relative_to(ROOT)} (mode explicit, "
          f"maxVotes={n_events}, maxPositionRecords={MAX_POSITION_RECORDS})")


if __name__ == "__main__":
    main()
