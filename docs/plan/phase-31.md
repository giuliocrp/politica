# Phase 31 — Staleness Disclosure + Live-Refresh ADR

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 23.
> **Network:** none. **Report:** `docs/v4/31-live-refresh-adr.md`
> (the ADR is the report). **Commit:**
> `feat(v4): phase 31 — staleness disclosure + live-refresh ADR`

## Objectives & deliverables

Close the "data is a snapshot" / "possible live refresh" roadmap items
with a decision rather than continued drift:

1. An ADR-style document formally deciding live data refresh.
   Recommendation: **remains deferred** — it contradicts
   local-first-at-runtime as constituted; the ADR pins the concrete
   criteria under which it would be revisited (e.g. an explicit,
   user-initiated, clearly-labeled exception design). The user may
   overrule; either outcome is the ADR's content.
2. A minimal in-app staleness disclosure: a data-driven Home footer line
   "Dati aggiornati al {date}" where {date} = the max `retrievedAt`
   across `sources.json` — a fact, not a judgment. **No invented
   staleness threshold, no warning colors.**

## Technical requirements

Date from `ManifestService` (max over sources, excluding the sample
fixture's entry if a rule is needed — decided and documented in-phase),
formatted via the existing `DateFormatting` Italian-locale helpers.

## Known risks & edge cases

The only trap is inventing an "outdated after N months" rule — expressly
out of scope. If `ManifestService` fails to load (existing loadError
path), the footer line is simply absent — honest degradation, no
placeholder date.

## Validation strategy

ADR reviewed against the standing constraints (it must not soften
local-first); footer verified against a manifest fixture.

## Test specifications (strict acceptance criteria)

1. ADR committed with the decision and pinned revisit criteria.
2. Unit test: the footer string derives from a fixture manifest's max
   `retrievedAt` (fixture value verified independently); absent when the
   manifest fails to load.
3. String pinned in the report, Italian.
4. Suite green vs the current baseline plus documented additions.

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
