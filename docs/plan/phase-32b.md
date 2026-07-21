# Phase 32B — Record Decisions and Tag [runs only on explicit approval]

> Read `docs/plan/00-baseline-and-rules.md` first. **Depends on:** 32A
> committed and its pending-decisions block answered. **Network:** none
> (push commands printed, never executed). **Report:** dated addendum to
> `docs/v4/32-release.md`. **Commit:**
> `docs(v4): phase 32b — record release decisions; tag v4.0-prototype (local)`

## Objectives & deliverables

Record the user's answers, commit **before** tagging, create the local
annotated `v4.0-prototype` tag on that final commit (so the tag contains
the complete release record), and hand over the push commands.

## Hard gates

- Explicit approval for the tag must be in front of the executing
  session, **quoted verbatim** in the addendum — absent that, the phase
  must not run. (Precedent note: an instruction to "proceed with 32B"
  given in direct response to the printed pending-decisions block counts,
  per the v3 22B record.)
- Unanswered items are recorded as explicitly *pending user decision* —
  never guessed, never dropped.
- Existing tags (`v1.0.0`, `v2.0-prototype`, `v3.0-prototype`) are never
  touched.

## Execution order (the ordering discipline is the phase's entire point)

1. Write the "Decisions received" addendum (approval + per-item status).
2. Update the CHANGELOG release-actions subsection to match.
3. Commit (docs-only).
4. Run the verification trio on the committed state.
5. `git tag -a v4.0-prototype` at HEAD, message referencing
   `docs/releases/v4.0-prototype.md`.
6. Print — do not execute — the push commands, re-derived from actual
   remote state at execution time (the user performs all remote
   actions personally):
   ```
   git push origin v4
   git push origin v4.0-prototype
   ```

## Test specifications (strict acceptance criteria)

1. Approval and answers quoted; unanswered items explicitly pending.
2. The decisions commit precedes the tag; `git tag --points-at HEAD`
   lists `v4.0-prototype`.
3. `git tag -n` shows all prior tags untouched.
4. Clean tree; nothing pushed (`git log @{u}..` shows only what the user
   will push); commands printed exactly as above (adjusted only for
   observed remote state).
5. Build + tests green on the tagged state.

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
