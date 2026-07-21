# Phase 24 — Real UI Smoke Tests + Automated Accessibility Audits

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 23.
> **Network:** none. **Report:** `docs/v4/24-ui-tests.md`.
> **Commit:** `test(v4): phase 24 — real UI smoke flows + automated accessibility audits`

## Objectives & deliverables

Retire the "unmodified Xcode template boilerplate" README limitation:
replace `PoliticiUITests` with deterministic smoke flows plus iOS-17
`performAccessibilityAudit()` runs, converting the automatable part of
`docs/v3/a11y-checklist.md`'s pending human checks into CI-able tests.

Flows (each a named test):
1. Cold launch → Home: stat cards present, dynamic values non-empty.
2. Home → CollegiList → chamber switch → a Camera collegio detail —
   asserts the pinned "Eletto nel collegio uninominale" header and the
   plurinominale section header exist → deputy profile.
3. A Senato collegio detail → senator profile; a-vita badge asserted on
   one known life senator's profile (reached via list search, never map
   taps).
4. Profile star toggle → Home Preferiti count changes → Preferiti list
   shows the row.
5. Votazioni: scope line present with data-driven N, first row tallies,
   Fonte link exists.
6. VoteHistory: outcome chip + title search compose.
7. Address search screen renders its dual-result structure (offline
   fallback path only — no network reliance in tests).

Audits: `performAccessibilityAudit()` on Home, CollegiList,
DistrictDetail (both chambers), Profile, Preferiti, Votazioni,
VoteHistory.

## Technical requirements

- Navigation exclusively via accessibility identifiers/labels; add
  stable `accessibilityIdentifier`s where labels are dynamic
  (identifier-only view edits, zero behavior change).
- One permitted app change: a DEBUG-only launch argument (e.g.
  `-favoritesSuite <name>`) making `UserDefaultsFavoritesStore` use an
  ephemeral suite under UI test — mirrors the store's existing
  `UserDefaults` injection seam; inert in release builds.
- Assertion strings are the pinned Italian strings from the v3 reports —
  never re-invented copy.

## Known risks & edge cases

- Documented simulator-clone infrastructure flake (twice in v3):
  mitigate with few, slow-tolerant tests; if a retry policy is adopted it
  is documented in the report, never silent.
- `performAccessibilityAudit` false positives: exemptions only via the
  issue-handler closure with a per-exemption justification comment; a
  blanket ignore is prohibited.
- **This phase deliberately changes the test-count baseline** (template
  tests deleted, incl. the ×4 `testLaunch`): the new dual definition
  (declared/runtime and the cause of any gap) is recomputed and
  documented in the report, Phase-13-style, in the same commit. All
  later phases measure against the new definition.

## Validation strategy

Three consecutive local full-suite runs green (flake check). The report
maps each retired human-check item from `docs/v3/a11y-checklist.md` to
its automated counterpart, and honestly lists what still needs a human
(real-device VoiceOver traversal, Dynamic Type visual judgment, contrast
measurement).

## Test specifications (strict acceptance criteria)

1. Old template tests deleted; the 7 named flows implemented and green.
2. Every audited screen passes `performAccessibilityAudit()`; zero
   unjustified exemptions (each exemption has an in-code justification
   quoted in the report).
3. New baseline arithmetic documented term-by-term (old 136/139 → new
   N/M).
4. Unit-test suite untouched and green.
5. `git diff` confined to `PoliticiUITests/`, identifier-only view
   edits, the DEBUG launch-arg seam, docs, and the plan status flip.

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
