# v2 Phase — Post-Import Status Audit

Written before making any changes in this phase, per its explicit "status
audit first" instruction. Supersedes nothing — `00-audit.md` is a frozen
snapshot and `01-real-data-import.md` covers the import itself; this doc
records what actually exists in the repo *right now*, at commit `f6867eb`,
before the reconciliation work below.

## What already exists (contrary to the task's assumption of drift)

- **Attribution screen exists and is wired**: `Views/FontiEDatiView.swift`,
  reachable from `HomeView` via both a toolbar info button and a footer
  "Informazioni e fonti" link (both push `AppRoute.fontiEDati`). It already
  renders manifest-driven source cards (name, license, "Dati aggiornati al:
  …", conditional link), an unofficial-status disclaimer paragraph, three
  avvertenza bullets, and a licenze note. It does **not** yet have an
  avvertenza about map boundaries being demonstrative (added in this phase).
- **Address autocomplete exists**: `Services/AddressAutocompleteService.swift`
  wraps `MKLocalSearchCompleter`, wired into `Views/AddressSearchView.swift`.
  Nothing to build here.
- **`PartyStyle` lives in `Views/DistrictDetailView.swift`** as a colocated
  `enum` with a hardcoded `switch` over the *old fictional* party display
  names ("Fratelli d'Italia", "Movimento 5 Stelle", …). None of the 19 real
  `party` values in the shipping data match any case, so every real
  representative's avatar currently falls through to the `default: .gray`
  case. This is being replaced with a data-derived `Data/parties.json` +
  `PartyStyleService` in this phase.
- **Home's "601 Rappresentanti" stat** comes from
  `services.representativeService.allRepresentatives().count` —
  already fully dynamic, no hardcoded number anywhere in view code.
- **`districtId` nil-safety**: already consistent everywhere. It's `String?`
  on `Representative` (changed in the import phase), decoded/encoded via
  `decodeIfPresent`/`encodeIfPresent`, and every call site
  (`RepresentativeService.representatives(for:)`'s `$0.districtId ==
  districtId` comparison, all test usages) already handles the optional
  correctly — confirmed by grep across `Politici/` and `PoliticiTests/`, and
  by the fact the project already builds and 52/52 tests already pass at
  `f6867eb`. No nil-safety bugs found to fix.

## What genuinely needs work (the real gaps)

- **`Data/votes.json` is orphaned**: still the original 37 fictional
  records (`REP001`–`REP014`), which don't match any id in the real
  `representatives.json` (`p######`/`s####`). The previous phase's tests
  explicitly *dropped* the vote→representative referential-integrity check
  to avoid a permanently-red build — this phase fixes the root cause
  (ship an empty, valid `votes.json`) so that check can be reinstated at
  full strength instead of staying dropped.
- **`PartyStyle` doesn't recognize any real party value** — see above.
- **No empty-state/provenance-badge coverage for the *specific* Italian
  copy this task specifies** — the views already have *some* graceful empty
  states ("Nessun rappresentante trovato per questo collegio.", "Nessuna
  votazione registrata.") but not the exact strings this phase requires
  ("...in questa versione del prototipo."), and there's no provenance badge
  on `RepresentativeProfileView` yet.
- **No map/district boundary-honesty caption** — nothing currently tells the
  user the 5 sample district polygons are demonstrative rectangles, not real
  electoral college boundaries.
- **SPARQL queries are inline Python string constants**, not versioned
  `.rq` files. Fetch scripts already set an `Accept` header and a
  browser-like `User-Agent` (needed for `dati.senato.it`, which rejects the
  default `Python-urllib` UA) and a 60s timeout, but have **no retry/backoff**
  on transient failures.
- **`make import` is already fully offline** (`import_representatives.py`
  only reads `tools/raw/*.json`, never touches the network) — this part of
  step 9 needed no change, just confirmation, which this audit provides.
- **`make_manifest.py` stamps `retrievedAt = date.today()` every time it
  runs**, conflating "manifest regenerated" with "data actually fetched."
  Reworked in this phase so `retrievedAt` reflects when `make fetch` last
  ran, not when `make manifest` happens to be invoked.
- **`stableSourceId` is `null` for all 601 real records** (a deliberate
  choice in the previous phase, since no semantics were given for it). This
  phase gives it a concrete, non-fabricated meaning: the bare numeric id
  from the source URI (e.g. `sourceUrl`
  `http://dati.camera.it/ocd/persona.rdf/p307394` → `stableSourceId`
  `"307394"`), verified unique across all 601 records (no Camera/Senato
  numeric-id collisions) before adopting this as the invariant tests' basis.

## Senato count: does 201 include senatori a vita?

**Yes.** Inspecting `tools/raw/senato_senatori_sparql.json` directly:

| | count | `tipoMandato` |
|---|---|---|
| Active (no `fineMandato`) | **201** | 196 × `elettivo` + **5 × `a vita, di nomina del Presidente della Repubblica`** |
| Ended (`fineMandato` present) | 7 | 6 × `elettivo` (deceased ×4, resigned ×2) + 1 × `di diritto e a vita, Presidente emerito della Repubblica` |

The 5 active life senators appointed by the President under Art. 59 of the
Constitution (Cattaneo, Monti, Piano, Rubbia, Segre) **are** counted in the
201. The 6th possible life senator, Giorgio Napolitano (former President,
life senator *by right*), is correctly excluded — his record has
`fineMandato: "2023-09-22"`, `tipoFineMandato: "Deceduto"` (he died in
September 2023).

**Inclusion criterion**: a senator is counted if their mandate record has no
`fineMandato` bound — i.e. "currently serving," regardless of whether the
mandate is `elettivo` (elected) or `a vita` (life-appointed). This single,
uniform rule was already implemented in `import_representatives.py` from the
previous phase (filtering out any senator binding with a non-null
`fineMandato`); it already defensibly and correctly includes life senators
without any special-casing. **No query or import-logic change was needed
here** — this section exists to document and verify the existing behavior,
per this phase's explicit request not to leave an unexplained number.

Camera's 400 needed no equivalent scrutiny: 400 is the exact constitutional
size of the chamber post-2020 reform, and the given query's `MINUS`-based
active-group-membership filter already excludes anyone no longer sitting
(vacant seats are filled via *surrogazione* from the same list, so the
currently-serving count is expected to equal 400 at any point in time).

## Real party/parliamentaryGroup values actually present

19 distinct `party` string values across the 601 records (verified via
direct inspection of `Data/representatives.json`, not assumed):

```
AVS, AZ-PER-RE, FDI, FI-PPE, IV-CR, LEGA, M5S, MISTO, NM(N-C-U-I)M-CP, PD-IDP
  (Camera sigla — 10 values)
Civici d'Italia-UDC-Noi Moderati (...)-MAIE-Centro Popolare, Forza Italia -
Berlusconi Presidente - PPE, Fratelli d'Italia, Italia Viva - Casa
Riformista, Lega Salvini Premier - Partito Sardo d'Azione, Misto,
MoVimento 5 Stelle, Partito Democratico - Italia Democratica e Progressista,
Per le Autonomie (SVP-PATT, Campobase)
  (Senato full group names — 9 values)
```

Every `parliamentaryGroup` and `party` value is non-empty across all 601
records (verified directly, not assumed). `Data/parties.json` gets exactly
one entry per exact string above (19 entries) — no attempt is made to merge
same-party-different-spelling pairs across chambers (e.g. `"FDI"` and
`"Fratelli d'Italia"` are textually different and are given separate,
independently-colored entries) or to normalize the `"MISTO"`/`"Misto"`
casing difference, since asserting those are "the same real party" would be
an editorial judgment this phase doesn't need to make — `PartyStyle`'s
documented gray fallback already handles any value it doesn't recognize
gracefully, so under-mapping is safe by design.

## Adapted plan

The steps below proceed largely as specified, with these adaptations given
the above:
- Step 8 (attribution): FontiEDatiView already exists in full; only the
  boundaries avvertenza is new.
- Step 4: no query/import change needed for the Senato count, only
  documentation (done above).
- Step 9: `make import`'s offline-ness needed no fix, only confirmation.
