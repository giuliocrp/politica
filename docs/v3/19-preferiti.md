# V3 Phase 19 — Preferiti (Local Favorites)

App-only phase, no gates: `git status` at commit time shows zero changes
under `tools/` or `Politici/Data/` (acceptance criterion 4, verified).

## What shipped

- **`FavoritesStore`** protocol + **`UserDefaultsFavoritesStore`**
  (`Politici/Services/FavoritesStore.swift`), registered as the seventh
  service in `ServiceContainer.live`. Payload contract, pinned and
  test-asserted: JSON `{"schemaVersion":1,"representativeIds":[...]}`
  under the key `"favorites.v1"`. First run (no payload) is empty with no
  warning; a corrupt or unrecognized-schema payload self-heals to empty
  with a console warning (and key removal), never a crash or a guess.
  Ids are deduplicated order-preservingly on load *and* on write.
- **Toolbar star** on `RepresentativeProfileView` (shown only when the
  representative resolves): pinned accessibility labels
  `"Aggiungi ai preferiti"` / `"Rimuovi dai preferiti"`, the `isSelected`
  trait when starred, explicit ≥44 pt frame + `contentShape`, and
  `.navigationBarTrailing` placement matching `HomeView`'s existing
  toolbar idiom.
- **`PreferitiView`** + new `AppRoute.preferiti` case wired in
  `ContentView`: starred representatives in starring order, reusing
  `RepresentativeRow`, navigating to profiles; empty state via the
  codebase's established `ContentUnavailableView` idiom with the pinned
  strings `"Nessun preferito."` and `"Tocca la stella sul profilo di un
  rappresentante per aggiungerlo."`.
- **Home entry card** with the dynamic favorites count, joining the stats
  area — which became a 2×2 `LazyVGrid` (four cards in the previous
  single `HStack` would cramp on smaller widths; layout change disclosed
  here).
- **Unresolvable ids** (a starred representative missing from a future
  dataset) are skipped at render by a pure function
  (`PreferitiView.resolvedFavorites(ids:lookup:)`) and deliberately
  retained in the store — hiding is reversible, deleting user data is not.

## Decision recorded: observation model = `@Observable`

The plan left this as an in-phase choice between `@Observable` (permitted
since the 13B move to the iOS 17.0 target) and `ObservableObject` (the
codebase's one pre-existing reactive pattern, `AddressAutocompleteService`).

**Chosen: `@Observable`.** Rationale: every view reaches services through
the container property `@Environment(\.services)`, and the container
exposes the store as protocol-typed `any FavoritesStore`. With
`@Observable`, SwiftUI's body-evaluation tracking fires on the concrete
object's property accesses regardless of access path or static type — the
star icon, the Preferiti list, and the Home count all update with zero
new property wrappers and zero concrete types leaked into views. The
`ObservableObject` alternative only publishes through
`@ObservedObject`/`@StateObject`/`@EnvironmentObject` wrappers, which
require a concrete (or generic) `ObservableObject`-conforming type — it
fights both the container idiom and the protocol boundary.
`AddressAutocompleteService` stays `ObservableObject` untouched: it works,
and migrating it is not this phase's scope. Verified in practice by the
store tests plus the existing suite (no view-update regressions).

## Tests

Deliberate additions (+7 declared), all against a suite-scoped
`UserDefaults(suiteName:)` with `removePersistentDomain` in
setUp/tearDown — the real standard defaults are never touched:

| Test | What it pins |
|---|---|
| `testFirstRunIsEmpty` | absent payload → empty, not an error path |
| `testToggleRoundTrip` | star/unstar semantics, starring order preserved |
| `testPersistenceAcrossInstances` | relaunch model: second instance over the same defaults reads the first's writes |
| `testCorruptPayloadResetsToEmptyAndStaysUsable` | garbage bytes → empty + store still functional and persisting |
| `testUnrecognizedSchemaVersionResetsToEmpty` | schemaVersion 999 treated as uninterpretable, not guessed |
| `testLoadedDuplicatesAreDeduplicatedPreservingFirstOccurrence` | hand-written duplicated payload → deduped load |
| `testResolvedFavoritesSkipsUnresolvableIdsAndLeavesStoreUntouched` | the pure resolution function skips unknowns, preserves order, never mutates the store |

**Suite: 131 runtime cases passed, 0 failures, exit 0** — declared 128
(109 baseline + 12 from Phases 17–18 + 7 here), runtime 131 (112 + 19),
×4 `testLaunch` cause unchanged. No infrastructure flake this time.

Verification trio: build **BUILD SUCCEEDED**; iPhone 17 Pro simulator;
test exit 0.

## Acceptance criteria walk

1. ✅ Persistence across (modeled) relaunch, corrupt self-heal with
   warning, dedup — all unit-verified.
2. ✅ Star, Preferiti screen, empty state, Home count with the pinned
   Italian strings and accessibility attributes. As in Phases 17–18,
   live-simulator visual checks were not performed in this headless
   session; the claims rest on the tested store/pure function and the
   established view idioms, with the human checks listed for 22A.
3. ✅ Store fully unit-tested via suite-scoped defaults (table above).
4. ✅ Zero `tools/`/`Politici/Data/` changes.
5. ✅ Suite green, zero regressions, +7 deliberate; this report committed
   in the phase commit.

## New a11y surfaces for the 22A checklist

- The profile toolbar star: label pair
  `"Aggiungi ai preferiti"`/`"Rimuovi dai preferiti"`, `isSelected` trait
  reflecting state, 44 pt target (human check: VoiceOver announces the
  state change on toggle).
- `PreferitiView`: rows are the already-labeled `RepresentativeRow`;
  empty state is a `ContentUnavailableView` (human check: title +
  description both read).
- The Home "Preferiti" stat card: combined element with dynamic count
  (human check: count re-announced after starring; card hint
  `"Apre l'elenco dei preferiti"`).
- The stats grid reflow (HStack → 2×2 LazyVGrid) — verify VoiceOver order
  remains Collegi → Rappresentanti → Camere → Preferiti.
