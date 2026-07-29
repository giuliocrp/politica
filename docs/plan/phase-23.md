# Phase 23 — V4 Baseline Audit & Hygiene

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** nothing.
> **Network:** none. **Report:** `docs/v4/23-baseline-audit.md`.
> **Commit:** `chore(v4): phase 23 — baseline audit (branch, tests, bundle, raw-layer inventory)`

## Objectives & deliverables

Freeze the V4 starting point so every later phase measures against
verified fact: (1) confirm branch ancestry (`v4` from post-merge `main`,
expected `3dc224e` — re-verify, don't trust the plan); (2) re-pin the
dual test baseline with one fresh full run; (3) bundle-size inventory
table (per-file bytes, % of each gate); (4) full `tools/raw/` inventory
including `ogrinfo -ro -so` schema dumps for **all five** not-yet-imported
shapefile layers (both plurinominale layers + `Circoscrizioni_Camera`,
`Regioni_Senato`, `UT_Collegi2020` — answers Q2, feeds Phase 25); (5)
restate the methodology-gate status and the commissioning-brief gap (Q6).
Deliverable: the report. No app/pipeline/data changes — any hygiene issue
found is listed, and fixed only if trivially safe, with the fix documented.

## Technical requirements

`ogrinfo` (already used in v3); the verification trio; no new tooling.
Field names AND 2–3 sample attribute rows per layer must be captured —
Phase 25's gate is written against these dumps.

## Known risks & edge cases

- The 50/27 plurinominale feature counts may include placeholder features
  with null/special codes — the dump must make that visible (Q1 stays
  open for Phase 25; this phase only supplies evidence).
- If `v4` ≠ `origin/main` tip, or the working tree is dirty: stop,
  reconcile with the user, document — nothing else proceeds.

## Validation strategy

Every number in the report reproduced by a quoted command and its output.

## Test specifications (strict acceptance criteria)

1. Full suite green at exactly **136 declared / 139 runtime**, with the
   arithmetic restated (94/97 + per-phase deliberate additions).
2. Report contains the five-layer `ogrinfo` dumps verbatim, plus the
   bundle table with bytes and gate percentages.
3. `git status` clean except the report (and `docs/plan/README.md`
   status flip).
4. Report committed in the phase commit with the pinned message.

**Standing constraints (non-negotiable):**
- Never rename the Xcode project ("Politici"), target, scheme, or bundle identifier.
- All user-facing strings must be in Italian.
- The app runtime is strictly local-first: no network calls from the app.
- Developer tools may query official public endpoints only, and only inside tools/.
- Never fabricate political data, geography, or licensing information.
- If data is missing or ambiguous, stop and document it.

**Verification command trio:**
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | grep iPhone
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'platform=iOS Simulator,name=<SimName>' test
```
