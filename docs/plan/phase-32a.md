# Phase 32A — V4 Documentation, Accessibility Checklist, Release Prep

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** all
> executed phases (a missing phase report blocks 32B). **Network:** none.
> **Report:** `docs/v4/32-release.md`. **Commit:**
> `docs(v4): phase 32a — V4 documentation, accessibility checklist, release prep`
> **Ends by printing the pending-decisions block and STOPPING. No tag, no push.**

## Objectives & deliverables

Mirror of v3's 22A, adapted:

1. **Report-set verification**: every executed phase (23–31, as
   executed, including NOT-RUN/NO-GO outcomes) has its committed
   `docs/v4/*.md` report.
2. **A11y pass** → `docs/v4/a11y-checklist.md` (new file; v2/v3
   checklists referenced, never edited): every new V4 surface —
   plurinominale layer picker + pages + type filter, regione sections
   and profile lines, vote loading states, the metric line (if shipped),
   comuni disambiguation UI, staleness footer — each checked, reconciled
   against Phase 24's automated audits, with the honest remaining
   human-check list. **This includes the 62 `performAccessibilityAudit`
   findings Phase 24 recorded rather than fixed** — all in exactly three
   types (`.contrast`, `.dynamicType`, `.textClipped`), inventoried in
   [`docs/v4/24-ui-tests.md`](../v4/24-ui-tests.md) §5 and explicitly
   handed to this phase — each triaged here to a fix or a documented
   human-judgment deferral.
3. **README full refresh**: shipped state including every
   NO-GO/NOT-RUN/exit outcome stated plainly; stale-line sweep with the
   grep classes from 22A plus any new ones this cycle created.
4. **`docs/DATA_SOURCES.md`** cross-check vs manifest + `tools/SOURCES.md`
   (new comuni + membership sources included); fix only V4-introduced
   drift.
5. **`CHANGELOG.md`**: v4.0-prototype entry, per-phase with commit
   hashes from `git log` (quoted in the report; distinguish phase
   commits from any interstitial fixes), honest one-liners for
   non-shipping outcomes, plus the release-actions subsection with
   pending decisions and placeholders.
6. **`CLAUDE.md` refresh**: new durable conventions this cycle
   established (plurinominale id prefixes, membership normalization
   rule, comuni provenance, the new test-baseline definition from
   Phase 24, metric constant rule if shipped).
7. **`docs/releases/v4.0-prototype.md`** following the v3 note's
   structure (CHANGELOG canonical, tag-not-yet-created note).
8. Commissioning-brief status (Q6) restated.
9. **Final verification**: build + full suite; dual-definition counts
   recorded with the complete regression arithmetic from the Phase 24
   definition; zero regressions beyond documented deliberate changes.
10. Commit; clean tree; print the **PENDING USER DECISIONS** block —
    (a) approve 32B's local `v4.0-prototype` tag; (b) GitHub release /
    visibility intent (noting the user executes all remote actions
    personally); (c) brief archival if still open — and stop.

## Technical requirements / risks / validation

As 22A: hash recovery is mechanical but must be quoted; the a11y pass
discloses headless limits; frozen dirs (`docs/v2`, `docs/v3` phase
reports as historical records, `docs/history`) show zero diff — the
living v3 docs that ARE updated (methodology status, if Phase 27/29
touched it in their own commits) are exempt and listed.

## Test specifications (strict acceptance criteria)

1. Complete report set verified; gaps closed before commit.
2. `docs/v4/a11y-checklist.md` exists; frozen dirs zero-diff.
3. README/CLAUDE.md/CHANGELOG/DATA_SOURCES accurate; hashes correct per
   `git log`; stale-line sweep documented with zero survivors.
4. Final build + tests green; arithmetic shown.
5. `git tag` shows no new tag; nothing pushed; tree clean; the
   pending-decisions block printed and mirrored in CHANGELOG.
6. `docs/v4/32-release.md` + `docs/releases/v4.0-prototype.md` committed
   in the phase commit.

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
