# Probes

Standalone diagnostic scripts used to verify a runtime/library behavior
before committing to an implementation approach — the kind of thing v2
Phase 7 did with ad hoc `swiftc`-compiled scripts to confirm that
`MKGeoJSONDecoder` represents a GeoJSON `MultiPolygon` as one
`MKMultiPolygon`, not flattened `MKPolygon` entries. That specific probe
was run outside the repository and never committed, so only its
*finding* survived (in a code comment and a test), not the diagnostic
script itself — a documented gap (`docs/history/POLITICA_HISTORY_GAPS_AND_CONFLICTS.md`,
finding G4). This directory exists so the next one doesn't disappear the
same way.

## Convention

- **Probe scripts are committed.** If you write a standalone script to
  answer a factual question about a data source, framework, or library
  behavior (e.g. "what does `ogrinfo` actually report for this
  shapefile's schema," "does this decoder flatten MultiPolygon or wrap
  it"), and the answer mattered enough to change an implementation
  decision, commit the script here — not just the conclusion in a doc or
  code comment. The script is what lets a future phase (or a skeptical
  reader) re-run the check instead of trusting a paraphrase.
- **Probe outputs are gitignored.** A probe's output (a dumped schema, a
  JSON blob, a screenshot, a log) is disposable — regenerate it by
  re-running the script. Write output files under `tools/probes/output/`,
  which `.gitignore` excludes wholesale (`tools/probes/output/`) — the
  directory itself doesn't need to exist in git; a probe script creates it
  on demand. Do not write probe output directly into `tools/probes/`
  alongside the scripts, and do not commit probe output files.
- Name each probe descriptively (e.g. `probe_geojson_multipolygon_decode.swift`,
  `probe_shapefile_schema.sh`) and give it a one-line header comment
  stating the question it answers and, if the answer is now known, what
  it found — so a probe that already did its job is still legible without
  re-running it.
- A probe is scratch-diagnostic, not test coverage. If a finding is worth
  asserting permanently, it still belongs in a real `PoliticiTests` test
  or a pipeline validation check (`tools/validate_data.py`) — the probe
  is what got you there, not a replacement for it.
