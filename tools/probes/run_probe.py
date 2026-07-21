#!/usr/bin/env python3
"""Runs a single SPARQL probe file from tools/probes/*.rq against a live
endpoint and saves the raw JSON response under tools/probes/output/
(gitignored) — the network-touching counterpart to the probe *design*
files, used only under an explicit, deliberate refetch-protocol decision
(never part of `make fetch`/`make refresh`, never run automatically).

Reuses tools/sparql_client.py's shared fetch machinery (retry/backoff,
descriptive User-Agent, 4xx-never-retried) rather than a bespoke request,
so a probe run behaves identically to a real fetch script in every way
that matters (timeouts, retries, error messages) — the only difference is
where the output goes.

Usage: python3 tools/probes/run_probe.py <probe_file.rq> <endpoint_url> [output_name.json]
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from sparql_client import fetch_sparql, SPARQLFetchError  # noqa: E402

PROBES_DIR = Path(__file__).parent
OUTPUT_DIR = PROBES_DIR / "output"


def load_probe_query(path):
    """Strips '#'-prefixed header comments, same convention as
    sparql_client.load_query for tools/queries/*.rq."""
    text = path.read_text(encoding="utf-8")
    lines = [line for line in text.splitlines() if not line.strip().startswith("#")]
    return "\n".join(lines).strip()


def main():
    if len(sys.argv) < 3:
        print(f"uso: {sys.argv[0]} <probe_file.rq> <endpoint_url> [output_name.json]", file=sys.stderr)
        sys.exit(2)

    probe_path = Path(sys.argv[1])
    if not probe_path.is_absolute():
        probe_path = PROBES_DIR / probe_path.name
    endpoint = sys.argv[2]
    output_name = sys.argv[3] if len(sys.argv) > 3 else probe_path.with_suffix(".json").name

    if not probe_path.exists():
        print(f"ERRORE: probe non trovato: {probe_path}", file=sys.stderr)
        sys.exit(1)

    query = load_probe_query(probe_path)
    label = probe_path.stem

    print(f"Esecuzione probe '{label}' contro {endpoint}...")
    try:
        payload, binding_count = fetch_sparql(endpoint, query, label)
    except SPARQLFetchError as error:
        print(f"ERRORE: {error}", file=sys.stderr)
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / output_name
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"OK: {binding_count} binding salvati in {output_path.relative_to(PROBES_DIR.parent.parent)}")


if __name__ == "__main__":
    main()
