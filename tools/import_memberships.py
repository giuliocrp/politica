#!/usr/bin/env python3
"""Merges tools/raw/camera_adesioni_sparql.json into
Data/memberships_camera.json — the per-deputy parliamentary-group membership
INTERVALS that make group-at-vote-date computable (Phase 28 —
docs/v4/28-membership-history.md; methodology gate line 6,
docs/v3/votes-methodology.md).

Offline — reads only cached files under tools/raw/ (run
tools/fetch_camera_adesioni.py first, or `make fetch`) plus the already-built
Data/representatives.json (for scoping + reconciliation), so it must run
AFTER tools/import_representatives.py.

Output schema (normalized interval file; the group-at-date JOIN is computed
in the app by MembershipService, never denormalized onto votes.json —
that would breach votes.json's own byte gate):

    {
      "schemaVersion": 1,
      "memberships": [
        { "id", "representativeId", "groupName", "groupSigla",
          "start" (yyyy-MM-dd), "end" (yyyy-MM-dd | null) }, ...
      ]
    }

Design notes / judgment calls (documented here, not left implicit):

- id is COMPOSED ("m_<personId>_<startYYYYMMDD>"), not source-backed: the
  source ocd:aderisce node is a BLANK NODE whose label is not stable across
  requests (verified — Phase 28 probe), so relying on it would be
  non-deterministic. Uniqueness of the composed key is asserted below (no
  person has two intervals sharing a startDate — verified 0 collisions).
- groupName = the group entity's dc:title, kept EXACTLY as returned. It
  carries the same documented source truncation-at-"(" quirk the deputies
  import preserves (e.g. "MISTO (MISTO) (18.10.2022" — an unterminated
  parenthesis). This script does NOT repair it (reconstructing the missing
  suffix would be fabrication). groupSigla = dcterms:alternative (clean:
  "MISTO", "FDI", ...) — the field any UI should render; groupName is kept
  for provenance/traceability, disclosed as source-defective.
- Interval semantics are HALF-OPEN [start, end): start inclusive, end
  exclusive. Evidenced, not chosen (Phase 28 probe): the source uses
  same-day handoff (a switcher's old endDate == the new startDate, on every
  one of the observed handoffs), so half-open is the only rule that yields a
  unique group on the switch day (the closed rule double-resolves; e.g.
  p301459 on 2026-05-20). The importer enforces non-overlap under this rule.

Honesty rule: any structural surprise (a persona not in representatives.json,
a serving deputy with no interval or !=1 open interval, a missing/unparseable
startDate or group, an id collision, an overlap, or an open interval whose
group can't be reconciled to the shipped gruppo) fails loudly and writes
nothing — a silently-wrong membership file is worse than none.
"""

import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).parent.parent
RAW_PATH = ROOT / "tools" / "raw" / "camera_adesioni_sparql.json"
REPRESENTATIVES_PATH = ROOT / "Politici" / "Data" / "representatives.json"
OUTPUT_PATH = ROOT / "Politici" / "Data" / "memberships_camera.json"

SCHEMA_VERSION = 1


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    print("\nNessun file scritto in Data/. Correggi la causa e riesegui.", file=sys.stderr)
    sys.exit(1)


def value(binding, var):
    node = binding.get(var)
    if node is None:
        return None
    v = node.get("value")
    if v is None:
        return None
    v = v.strip()
    return v or None


def person_id(uri):
    # http://dati.camera.it/ocd/persona.rdf/p307394 -> p307394
    return uri.rsplit("/", 1)[-1]


def parse_ymd(raw):
    """Source dates are YYYYMMDD strings (e.g. '20221018'). Returns an ISO
    'yyyy-MM-dd' string, or None if raw is falsy; fails loudly on a present
    but unparseable value (never guesses)."""
    if not raw:
        return None
    if len(raw) == 8 and raw.isdigit():
        y, m, d = raw[:4], raw[4:6], raw[6:8]
        try:
            date(int(y), int(m), int(d))
        except ValueError:
            fail(f"data non valida nel sorgente: {raw!r}")
        return f"{y}-{m}-{d}"
    fail(f"formato data inatteso nel sorgente (atteso YYYYMMDD): {raw!r}")


def normalize_group_name(name):
    """The documented normalization for reconciling the open interval's group
    dc:title against representatives.json's parliamentaryGroup: strip, then
    compare by prefix. Both strings come from the same group entity's
    dc:title and carry the identical source truncation-at-"(" quirk, so in
    practice they are equal — but prefix-comparison is the spec'd, quirk-safe
    rule (Phase 28), never exact-string equality."""
    return (name or "").strip()


def load_json(path, label):
    if not path.exists():
        fail(f"manca {path.relative_to(ROOT)} — {label}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} non è JSON valido: {error}")


def main():
    payload = load_json(RAW_PATH, "esegui prima tools/fetch_camera_adesioni.py")
    bindings = payload.get("results", {}).get("bindings", [])
    if not bindings:
        fail("camera_adesioni_sparql.json non contiene risultati")

    representatives = load_json(REPRESENTATIVES_PATH, "esegui prima tools/import_representatives.py")
    camera = {r["id"]: r for r in representatives if r.get("chamber") == "Camera"}
    if not camera:
        fail("nessun deputato Camera in representatives.json")

    # 1. Parse every adesione row, scoping + validating field presence.
    memberships = []
    by_person = {}
    for binding in bindings:
        persona = value(binding, "persona")
        if not persona:
            fail("riga di adesione senza ?persona")
        pid = person_id(persona)

        # Referential integrity: every adesione's deputy must be a shipped
        # Camera deputy (the query already scopes to current deputies, but we
        # never trust that silently).
        if pid not in camera:
            fail(f"adesione per {pid!r} non presente tra i deputati Camera di representatives.json")

        name = value(binding, "nomeGruppo")
        sigla = value(binding, "sigla")
        if not name or not sigla:
            fail(f"adesione di {pid} senza gruppo (nomeGruppo={name!r}, sigla={sigla!r})")

        start_raw = value(binding, "startDate")
        if not start_raw:
            fail(f"adesione di {pid} (gruppo {sigla}) senza startDate — condizione NO-GO")
        start = parse_ymd(start_raw)
        end = parse_ymd(value(binding, "endDate"))  # None when absent (open interval)

        composed_id = f"m_{pid}_{start.replace('-', '')}"
        record = {
            "id": composed_id,
            "representativeId": pid,
            "groupName": name,
            "groupSigla": sigla,
            "start": start,
            "end": end,
        }
        memberships.append(record)
        by_person.setdefault(pid, []).append(record)

    # 2. Composed-id uniqueness (would only fail if a person had two intervals
    #    with the same startDate — asserted absent).
    ids = [m["id"] for m in memberships]
    if len(ids) != len(set(ids)):
        dupes = sorted({i for i in ids if ids.count(i) > 1})
        fail(f"id composto duplicato (una persona ha due intervalli con la stessa startDate): {dupes}")

    # 3. Every serving Camera deputy has >=1 interval (all 400 expected).
    missing = sorted(set(camera) - set(by_person))
    if missing:
        fail(f"{len(missing)} deputati Camera senza alcun intervallo di adesione: {missing[:10]}")

    # 4. Per-person invariants: exactly one open interval; non-overlapping
    #    under half-open [start, end); open interval reconciles with the
    #    shipped gruppo (sigla equality + name prefix-comparison).
    open_total = 0
    for pid, intervals in by_person.items():
        intervals.sort(key=lambda m: (m["start"], m["id"]))
        opens = [m for m in intervals if m["end"] is None]
        if len(opens) != 1:
            fail(f"deputato {pid}: {len(opens)} intervalli aperti, atteso esattamente 1")
        open_total += 1

        # Non-overlap under half-open: each closed interval must end no later
        # than the next interval starts, and only the last (by start) may be
        # open.
        for earlier, later in zip(intervals, intervals[1:]):
            if earlier["end"] is None:
                fail(f"deputato {pid}: un intervallo aperto precede un altro intervallo — ordinamento incoerente")
            if earlier["end"] > later["start"]:
                fail(
                    f"deputato {pid}: intervalli sovrapposti {earlier['start']}..{earlier['end']} "
                    f"e {later['start']}.. — violano [start, end)"
                )

        # Reconciliation of the (single) open interval with representatives.json.
        current = opens[0]
        rep = camera[pid]
        rep_sigla = (rep.get("party") or "").strip()
        rep_group = normalize_group_name(rep.get("parliamentaryGroup"))
        open_name = normalize_group_name(current["groupName"])
        if current["groupSigla"] != rep_sigla:
            fail(
                f"deputato {pid} ({rep.get('name')}): sigla dell'intervallo aperto "
                f"{current['groupSigla']!r} != party in representatives.json {rep_sigla!r}"
            )
        if not (rep_group.startswith(open_name) or open_name.startswith(rep_group)):
            fail(
                f"deputato {pid} ({rep.get('name')}): gruppo dell'intervallo aperto "
                f"{open_name!r} non è coerente (prefix) con parliamentaryGroup {rep_group!r}"
            )

    # 5. Deterministic ordering of the whole list before serializing (the
    #    source rows come off a blank-node graph with no guaranteed order;
    #    sort on the composed key so the artifact is byte-identical across
    #    re-imports — Phase 27 determinism precedent).
    memberships.sort(key=lambda m: (m["representativeId"], m["start"], m["id"]))

    output = {"schemaVersion": SCHEMA_VERSION, "memberships": memberships}
    serialized = json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    OUTPUT_PATH.write_text(serialized, encoding="utf-8")

    n_bytes = len(serialized.encode("utf-8"))
    switchers = sum(1 for iv in by_person.values() if len(iv) > 1)
    print(
        f"OK: {len(memberships)} intervalli ({open_total} aperti, "
        f"{len(memberships) - open_total} chiusi) per {len(by_person)} deputati "
        f"in {OUTPUT_PATH.relative_to(ROOT)} ({n_bytes / 1024:.1f} KiB)"
    )
    print(f"  deputati con più di un gruppo nel tempo: {switchers}")


if __name__ == "__main__":
    main()
