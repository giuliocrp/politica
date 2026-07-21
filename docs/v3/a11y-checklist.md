# V3 Accessibility Checklist (Phase 22A)

New file for the V3 surfaces only. The v2 pass and its baseline findings
live in `docs/v2/a11y-checklist.md` (referenced, never edited — frozen
history). Everything below was verified by **code inspection in a headless
session** — the same disclosed limitation as every V3 phase report; the
"pending human checks" section at the bottom is the honest list of what
still needs a real device/simulator with VoiceOver and Dynamic Type
actually running.

Baseline facts re-verified this phase: still **zero custom animations**
anywhere in `Politici/Views/` (`grep withAnimation|.animation(` → 0), so
Reduce Motion still has nothing to gate; the v2-era structural limitation
is unchanged — **MapKit polygon overlays remain undiscoverable by
VoiceOver**, and `CollegiListView` remains the accessible alternative
path, now covering both chambers.

## Per-surface results

### Phase 16 — Senato boundaries / chamber-aware UI

| Surface | Verified in code | Result |
|---|---|---|
| `ChamberPicker` (MapView + CollegiListView) | Segmented `Picker` titled "Camera del Parlamento"; visible segments stay short ("Camera"/"Senato") with explicit per-segment `accessibilityLabel`s "Camera dei Deputati" / "Senato della Repubblica" | ✓ VoiceOver announces full chamber names |
| Per-chamber map caption | Plain static `Text` ("Collegi uninominali — {chamber}"), updates with the picker | ✓ readable static text |
| `AddressSearchView` dual-result rows | Each chamber's result row: combined element, ≥44 pt, hint "Apre i dettagli del collegio"; autocomplete suggestion rows likewise combined + ≥44 pt | ✓ |
| `AddressSearchView` not-found variant | Non-interactive `Text` ("Collegio {camera}: indirizzo non coperto dal prototipo per questa camera."), min-height 44, no fake affordance | ✓ honest, non-interactive |
| `DistrictDetailView` "Regione: {name}" line | Inside the header's `.accessibilityElement(children: .combine)` | ✓ read as part of the header |

### Phase 17 — mandates + Senato linkage

| Surface | Verified in code | Result |
|---|---|---|
| A-vita profile badge | `Label("A vita, di nomina del Presidente della Repubblica", systemImage: "star.circle.fill")` inside the profile header's combined element; gender-neutral source wording | ✓ text read with the header |
| Linked-senator rows on Senato district pages | The pre-existing, already-labeled `RepresentativeRow` (combined element + "Apre il profilo del rappresentante" hint) through the same path as deputies | ✓ nothing new to label |
| Uncovered-collegio empty state (S120002) | Pre-existing honest empty `Text` | ✓ unchanged |

### Phase 18 — plurinominale/estero context

| Surface | Verified in code | Result |
|---|---|---|
| "Eletto nel collegio uninominale" header (Camera pages) | Static headline `Text` | ✓ |
| Plurinominale section | Headline + explanatory caption as static `Text`s; deputy rows are `RepresentativeRow`; honest empty state ("Nessun deputato plurinominale…", reachable only on the Valle d'Aosta page) | ✓ |
| Profile "Circoscrizione: {name}" line | Inside the header's combined element (same as "Regione:") | ✓ |

### Phase 19 — Preferiti

| Surface | Verified in code | Result |
|---|---|---|
| Profile toolbar star | Pinned labels "Aggiungi ai preferiti"/"Rimuovi dai preferiti" swapping with state; `.isSelected` trait when starred; explicit ≥44 pt frame + `contentShape`; hidden when the representative doesn't resolve | ✓ |
| `PreferitiView` list + empty state | Rows are `RepresentativeRow`; empty state is `ContentUnavailableView` with pinned title + description | ✓ |
| Home "Preferiti" stat card | `StatCard` is a combined element; button hint "Apre l'elenco dei preferiti"; count is live data | ✓ |
| Stats grid reflow (HStack → 2×2 `LazyVGrid`) | Declaration order Collegi → Rappresentanti → Camere → Preferiti preserved in source | ✓ in code; traversal order needs the human check below |

### Phase 20 — vote browsing

| Surface | Verified in code | Result |
|---|---|---|
| Votazioni scope line | Section-header `Text` ("Campione di {N} votazioni importate — non l'archivio completo"), N from data | ✓ |
| `VoteEventRow` | Static info (title/date/esito/tallies) one combined element; the four tallies carry the pinned labels "Favorevoli: N" / "Contrari: N" / "Astenuti: N" / "Assenti: N" (a `.sconosciuto` tally appears only if nonzero, labeled with the existing "Esito non disponibile" vocabulary); "Fonte" `Link` deliberately outside the group as its own ≥44 pt element with label + hint (the `VoteRow` pattern) | ✓ |
| VoteHistory filter chips | "Tutte" + four outcome chips: per-chip labels ("Tutte le votazioni" / "Filtra per {outcome}"), `.isSelected` trait, ≥44 pt, horizontal scroll | ✓ in code; VoiceOver reachability inside the scrolling header needs the human check |
| Search field | System `.searchable` with Italian prompt | ✓ system control |
| Empty-filter state | Distinct honest copy ("Nessuna votazione corrisponde ai filtri selezionati.") vs the no-data state | ✓ |
| Home "Votazioni in Aula (campione)" button | `Label` + hint "Apre l'elenco delle votazioni importate" | ✓ |

### Phase 21 — no new surfaces (measured early exit, no UI change).

## Pending human checks (honest enumeration — none of these can be done headless)

1. Full VoiceOver traversal of every screen above on a real device or
   interactive simulator: element order, no swallowed controls, the
   star's **state change announced on toggle**, the stats grid read in
   the declared order, the filter chips reachable and their selected
   state announced inside the scrolling section header.
2. Dynamic Type at the largest accessibility sizes, especially: the
   a-vita badge (a long string in a capsule — verify it wraps rather
   than truncates), `VoteEventRow`'s tally row (five labels in an
   `HStack` — verify no clipping), and the 2×2 stat grid.
3. Color-contrast spot check in light and dark mode for the new purple
   badge/tints (a-vita badge, Senato map tint) and the chip
   selected/unselected states — nothing is color-only by construction,
   but contrast ratios were never measured on-device in v3.
4. The composed search + chip filtering flow driven entirely via
   VoiceOver (does the results update get announced?).
5. The v2 checklist's own standing pending items (device-hardware
   VoiceOver pass, real Dynamic Type interaction audit) remain pending —
   restated here rather than silently inherited.
