# v2 Phase — Real ISTAT Electoral-College Boundaries: Pre-Build Verification

Written before building `tools/build_boundaries.sh`, verifying every claim
in the phase brief against the actual raw shapefile rather than trusting
it — consistent with this project's honesty rules and the practice
established in `docs/v2/02-post-import-audit.md`.

## Prerequisites confirmed present

- `ogr2ogr` installed: `/opt/homebrew/bin/ogr2ogr`, GDAL 3.13.1.
- Raw shapefile present at exactly the path the brief specified:
  `tools/raw/collegi/CAMERA_CollegiUNINOMINALI_2020/CAMERA_CollegiUNINOMINALI_2020.shp`
  (plus its `.dbf`/`.prj`/`.shx`/etc. siblings).
- `tools/raw/SOURCES.txt` has an ISTAT entry: license **CC BY 4.0**,
  `RetrievedAt: 2025-07-18`, URL
  `https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2`.
- Sibling shapefiles for Senato and Circoscrizioni/Plurinominali layers are
  also present under `tools/raw/collegi/` but are **out of scope** per the
  brief (Camera uninominali only) and are not touched.

## Schema verified via `ogrinfo -so`

| Claim in the brief | Verified |
|---|---|
| Feature Count: 147 | **147** ✓ |
| Projection EPSG:32632 | **EPSG:32632** (WGS 84 / UTM zone 32N) ✓ |
| `CU20_COD` = college id | Present, type `Integer64` — cast to `String` on import as instructed |
| `CU20_DEN` = college name | Present, `String(150)`, e.g. `"Piemonte 1 - U01"` |
| `CU20_C1` = region field | Present, `String(254)` — **see finding below** |

## Finding: `CU20_C1` is not a region

The brief hedged this itself ("**Likely** the regional or plurinominal
code"). Direct inspection of sample records shows `CU20_C1` is the
within-collegio-plurinominale sequence suffix — literally the tail of
`CU20_DEN`:

```
CU20_DEN = "Piemonte 1 - U01"   CU20_C1 = "U01"
CU20_DEN = "Piemonte 1 - U02"   CU20_C1 = "U02"
CU20_DEN = "Piemonte 2 - U01"   CU20_C1 = "U01"
```

It is **not** a region name or region code in any geographic sense —
"U01"/"U02"/… repeats across every plurinominale grouping nationwide and
carries no region information by itself. Implemented literally as
instructed anyway (`region: CU20_C1`), since it's real, non-fabricated data
from the source file, not an invented value — but flagging this clearly
here (and in code comments) since the field name "region" would otherwise
mislead a reader into thinking it's a geographic region. The `region` field
currently isn't rendered anywhere in the app UI, so this has no user-facing
impact yet. If genuine region data is wanted later, it would need to be
parsed from `CU20_DEN`'s prefix (e.g. `"Piemonte 1"` before the ` - U01`)
instead.

## Finding: genuine MultiPolygon geometry, substantial not edge-case

Test-converted the Sicilia/Sardegna subset (16 features) to GeoJSON to
verify the "MultiPolygon" requirement wasn't just theoretical:

```
Sicilia 1 - U06  -> MultiPolygon, 19 parts
Sicilia 2 - U06  -> MultiPolygon, 18 parts
Sardegna - U02   -> MultiPolygon, 33 parts
Sardegna - U04   -> MultiPolygon, 124 parts
```

(15 of 16 Sicilia/Sardegna features are MultiPolygon; only one, "Sicilia 2 -
U02", is a plain single Polygon.) This confirms the MultiPolygon-with-holes
architecture requirement is addressing a real, substantial feature of the
data — likely small satellite islands/islets bundled into the nearest
mainland or major-island collegio — not a hypothetical edge case. Simplification
tolerance for `make boundaries` is chosen to hit the <3MB target while
verifying the national feature count stays at 147 and Sicily/Sardinia still
render as visibly multi-part on the map (see manual simulator check).

## Adapted plan

No deviation from the brief's steps was needed based on the above — the
`CU20_C1`/"region" finding is disclosed rather than acted on (implemented
literally, as the brief's own "Likely" hedge anticipated might need
correction later), and the MultiPolygon finding *confirms* rather than
changes the planned architecture.
