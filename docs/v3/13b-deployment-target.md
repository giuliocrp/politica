# V3 Phase 13b — Deployment Target Change (user-approved)

## Approval

Phase 13's recommendation (`docs/v3/13-baseline-audit.md`, §4):

> the real minimum deployment target this codebase requires is **iOS
> 17.0**, driven entirely by `MapView`'s SwiftUI Map API and one
> `.onChange` call site — both empirically confirmed to build and pass
> all tests at that floor. The current project value of 26.5 is an
> unexamined Xcode-template default with no technical justification
> found; lowering it to 17.0 would not require any source change
> (confirmed by this audit's own build/test run at that target) and would
> materially widen the set of devices the app can run on. […]
> **Deployment-target change requires explicit user approval; see
> Phase 13B.**

User approval, given explicitly in this session before any change was
made (`AskUserQuestion`, this phase):

> Question: "Phase 13's audit recommended lowering
> IPHONEOS_DEPLOYMENT_TARGET from 26.5 to 17.0 (the codebase's real
> technical floor, verified by a green build+test at that target). Do you
> approve applying this change now for Phase 13b?"
> Answer: **"Yes, apply iOS 17.0"**

Approved target: **17.0**.

## Before state

`grep -n "IPHONEOS_DEPLOYMENT_TARGET" Politici.xcodeproj/project.pbxproj`:

```
325:				IPHONEOS_DEPLOYMENT_TARGET = 26.5;
383:				IPHONEOS_DEPLOYMENT_TARGET = 26.5;
467:				IPHONEOS_DEPLOYMENT_TARGET = 26.5;
489:				IPHONEOS_DEPLOYMENT_TARGET = 26.5;
```

Structure, confirmed by reading the `PBXNativeTarget` /
`XCConfigurationList` / `XCBuildConfiguration` sections directly (not
assumed from line proximity):

| Occurrence | Scope | Config | Before |
|---|---|---|---|
| line 325 | `PBXProject "Politici"` (project-wide default) | Debug | 26.5 |
| line 383 | `PBXProject "Politici"` (project-wide default) | Release | 26.5 |
| line 467 | `PoliticiTests` target (explicit override) | Debug | 26.5 |
| line 489 | `PoliticiTests` target (explicit override) | Release | 26.5 |

The `Politici` app target and the `PoliticiUITests` target carry **no**
target-level `IPHONEOS_DEPLOYMENT_TARGET` key at all — both inherit the
project-wide default. Only `PoliticiTests` has an explicit per-target
override, and before this change it was redundant (set to the same value
the project default already provided).

## Change applied

All four occurrences set to `17.0` (project-wide default for
Debug/Release, and the `PoliticiTests` target-level override for
Debug/Release, normalized to the same value rather than left stale or
removed):

```
325:				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
383:				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
467:				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
489:				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
```

Effective deployment target for all three targets (`Politici`,
`PoliticiTests`, `PoliticiUITests`) after this change: **17.0**, uniformly
— two by inheritance from the project default, one by an explicit
override now consistent with it. No other `DEPLOYMENT_TARGET`-family key
exists anywhere in `project.pbxproj` (checked via `grep -n
"DEPLOYMENT_TARGET"`, 4/4 matches accounted for above).

## Verification transcript

### Build

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'generic/platform=iOS Simulator' build
```

Result: `** BUILD SUCCEEDED **`. No availability errors, no new warnings
introduced by the target change.

### Test

Simulator: `iPhone 17 Pro` (iOS 26.5 runtime — the simulator OS is
unrelated to the app's deployment target; it's simply the newest
available runtime, same device used for the Phase 13 baseline).

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Politici.xcodeproj -scheme Politici -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath <path>.xcresult test
```

Result: `** TEST SUCCEEDED **`, 0 failures.

`xcrun xcresulttool get test-results summary` on the resulting
`.xcresult`:

```json
{
  "failedTests": 0,
  "passedTests": 94,
  "result": "Passed",
  "totalTestCount": 94,
  "statistics": [
    { "title": "1 test ran with dynamic parameters", "subtitle": "4 test runs" },
    { "title": "1 test collected performance metrics", "subtitle": "1 test run" }
  ]
}
```

with `devicesAndConfigurations[0].passedTests: 97` at the
per-device-configuration level.

### Comparison against the Phase 13 dual-definition baseline

| Metric | Phase 13 baseline (26.5) | Phase 13b (17.0) | Match |
|---|---|---|---|
| Declared test methods (`totalTestCount`) | 94 | 94 | ✓ |
| Runtime test cases (device-level `passedTests`) | 97 | 97 | ✓ |
| Failed tests | 0 | 0 | ✓ |
| Cause of 94→97 gap | `testLaunch()` × 4 runs (`runsForEachTargetApplicationUIConfiguration`) | same | ✓ |

Exact match on every figure — no regression, no new skip/failure, no
change in the dynamic-parameters count. No availability error or
behavioral difference of any kind appeared, so no revert was necessary.

## Result

**Applied and kept.** The deployment target is committed at 17.0 for all
three targets. No source files required any change — Phase 13's audit
already established that empirically, and this phase's own from-scratch
build/test run against the actual committed change confirms it again.

## Diff scope

```
$ git diff --stat
 Politici.xcodeproj/project.pbxproj | 8 ++++----
```

No other file touched by this phase.
