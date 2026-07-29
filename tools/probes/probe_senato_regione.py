#!/usr/bin/env python3
"""Fase 26 — sonda contesto regione Senato (GO-REG).

Offline, committed per la convenzione delle sonde (output/ è gitignored e non
è mai una sorgente di import). Valuta le tre condizioni del gate GO-REG PRIMA
di qualsiasi modifica all'importer, con valori citati:

  (a) Copertura elettiva 196/196 — ogni senatore elettivo (mandate elettivo)
      porta osr:regioneElezione; i 5 a-vita ne sono privi (chiave omessa).
  (b) Ogni valore regioneElezione domestico corrisponde esattamente a uno dei
      20 valori regione di districts_senato.geojson, sotto la regola
      strict-uppercase + alias bilingui (Valle d'Aosta, Trentino-Alto Adige);
      qualsiasi altra variante fallirebbe (il gate richiede fail loud).
  (c) Per tutti i 73 senatori collegati (uninominali), la regione derivata ==
      la proprietà regione del loro collegio (uguaglianza esatta su stringhe
      canoniche) — la stessa linkage Fase 17.

Stampa anche, come contesto per la decisione electionType (Fase 26, sua fase
proprietaria): la distribuzione tipoElezione attesa (73 uninominale / 121
proporzionale / 2 estere) e la coerenza estero (i 2 con regioneElezione estera
== i 2 con tipoElezione 'circoscrizioni estere').

Sonda Python offline (come probe_camera_coverage.py / probe_plurinominale_
geography.py) — si esegue direttamente, non tramite run_probe.py (che è per
i probe SPARQL .rq di rete).

Uso: python3 tools/probes/probe_senato_regione.py
Esce 0 se (a)-(c) verificano, 1 altrimenti.
"""

import json
import sys
from collections import Counter
from pathlib import Path

# Riusa la macchina di linkage della Fase 17 invece di re-implementarla
# (convenzione: la sonda verifica, non duplica la logica sotto test).
TOOLS = Path(__file__).parent.parent
sys.path.insert(0, str(TOOLS))
from import_representatives import (  # noqa: E402
    ESTERO_COVERAGE_VALUES,
    SENATO_COLLEGIO_RE,
    SENATO_UNINOMINALE_PREFIX,
    KNOWN_TIPO_MANDATO,
)

ROOT = TOOLS.parent
CACHE = TOOLS / "raw" / "senato_senatori_sparql.json"
DISTRICTS_SENATO = ROOT / "Politici" / "Data" / "districts_senato.geojson"

MANDATE_ELETTIVO = "elettivo"

# Gli alias bilingui verificati per-voce (b): la sorgente SPARQL dà il nome
# italiano, districts_senato.geojson porta il nome bilingue ISTAT. Valle
# d'Aosta è già negli alias Fase 17 (linkage); Trentino-Alto Adige è NUOVO
# per la derivazione regione — nella linkage Fase 17 non serviva perché
# osr:collegioElezione già usa la forma bilingue per il Trentino (verificato
# sotto), mentre osr:regioneElezione usa la forma italiana. Ogni regione ha
# esattamente il numero atteso di collegi, quindi zero ambiguità.
EXPECTED_REGIONE_ALIASES = {
    "VALLE D'AOSTA": "Valle d'aosta/Vallée d'Aoste".upper(),
    "TRENTINO-ALTO ADIGE": "Trentino-Alto Adige/Südtirol".upper(),
}


def value(binding, var):
    entry = binding.get(var)
    return entry.get("value") if entry else None


def main():
    print("=" * 72)
    print("Fase 26 — sonda contesto regione Senato (GO-REG)")
    print("=" * 72)

    cache = json.loads(CACHE.read_text(encoding="utf-8"))
    bindings = cache["results"]["bindings"]

    # Solo senatori in carica (nessun fineMandato) — stessa regola dell'importer.
    serving = [b for b in bindings if not value(b, "fineMandato")]

    # Indici dal file di confine reale (non da una lista hardcoded):
    #   regione.upper() -> stringa regione spedita (canonica)
    #   (regione.upper(), subCode) -> id collegio
    #   id collegio -> stringa regione spedita
    gj = json.loads(DISTRICTS_SENATO.read_text(encoding="utf-8"))
    canonical_regioni = {}
    uninominale_index = {}
    regione_of_id = {}
    for feature in gj["features"]:
        p = feature["properties"]
        if p.get("chamber") != "Senato" or p.get("collegioType") != "uninominale":
            continue
        regione = p["regione"]
        canonical_regioni[regione.upper()] = regione
        uninominale_index[(regione.upper(), p["subCode"])] = p["id"]
        regione_of_id[p["id"]] = regione
    shipped_count = len(canonical_regioni)
    print(f"\nValori regione spediti (districts_senato.geojson): {shipped_count}")

    ok = True

    # --- (a) copertura elettiva 196/196 ---
    print("\n--- (a) copertura elettiva regioneElezione ---")
    elettivo = [b for b in serving if value(b, "tipoMandato") == MANDATE_ELETTIVO]
    a_vita = [b for b in serving if value(b, "tipoMandato") != MANDATE_ELETTIVO]
    with_reg = [b for b in serving if value(b, "regioneElezione") is not None]
    without_reg = [b for b in serving if value(b, "regioneElezione") is None]
    # sanity: ogni tipoMandato serving è nel vocabolario noto
    unknown_mandato = [value(b, "tipoMandato") for b in serving if value(b, "tipoMandato") not in KNOWN_TIPO_MANDATO]
    print(f"  senatori in carica: {len(serving)}")
    print(f"  mandate elettivo: {len(elettivo)}   non-elettivo (a-vita/emerito): {len(a_vita)}")
    print(f"  con regioneElezione: {len(with_reg)}   senza: {len(without_reg)}")
    elettivo_ids = {value(b, "senatore") for b in elettivo}
    with_reg_ids = {value(b, "senatore") for b in with_reg}
    same_set = elettivo_ids == with_reg_ids
    print(f"  insieme(elettivo) == insieme(con regioneElezione): {same_set}")
    if len(with_reg) != 196 or len(elettivo) != 196 or not same_set or unknown_mandato:
        ok = False
        print("  (a) FALLITA")
    else:
        print("  (a) OK — 196/196 elettivi con regioneElezione, 5 a-vita senza")

    # --- (b) ogni valore domestico mappa a uno dei 20, alias verificati ---
    print("\n--- (b) mappatura regioneElezione domestico -> regione spedita ---")
    domestic_fail = []
    alias_used = Counter()
    exact_used = Counter()
    estero_reg = []
    for b in with_reg:
        raw = value(b, "regioneElezione")
        up = raw.upper()
        if up in ESTERO_COVERAGE_VALUES:
            estero_reg.append(raw)
            continue
        if up in EXPECTED_REGIONE_ALIASES:
            up2 = EXPECTED_REGIONE_ALIASES[up]
            if up2 in canonical_regioni:
                alias_used[raw] += 1
            else:
                domestic_fail.append(raw)
        elif up in canonical_regioni:
            exact_used[raw] += 1
        else:
            domestic_fail.append(raw)
    print(f"  valori domestici mappati per uguaglianza esatta: {len(exact_used)} distinti")
    print(f"  valori domestici mappati via alias bilingue:")
    for raw, c in sorted(alias_used.items()):
        print(f"    {raw!r} ({c}) -> {canonical_regioni[EXPECTED_REGIONE_ALIASES[raw.upper()]]!r}")
    print(f"  valori estero (non geografici, gestiti separatamente): {sorted(set(estero_reg))}")
    if domestic_fail:
        ok = False
        print(f"  (b) FALLITA — valori non mappabili: {sorted(set(domestic_fail))}")
    else:
        covered = set(exact_used) | {r.upper() for r in alias_used}
        print(f"  (b) OK — {len(exact_used) + len(alias_used)} regioni domestiche distinte, 0 non mappate")

    # --- (c) regione derivata == regione del collegio, per i 73 collegati ---
    print("\n--- (c) coerenza regione derivata vs collegio (73 uninominali) ---")
    uni = [b for b in serving if (value(b, "tipoElezione") or "").startswith(SENATO_UNINOMINALE_PREFIX)]
    mismatch = []
    trentino_bilingual_in_collegio = 0
    for b in uni:
        raw = value(b, "regioneElezione")
        up = raw.upper()
        derived = canonical_regioni.get(EXPECTED_REGIONE_ALIASES.get(up, up))
        # id collegio via la stessa regola di parsing Fase 17
        col = value(b, "collegioElezione")
        prefix = col.split(" (", 1)[0]
        m = SENATO_COLLEGIO_RE.match(prefix)
        col_regione_raw = m.group("regione") if m else None
        if col_regione_raw and "SÜDTIROL" in col_regione_raw.upper():
            trentino_bilingual_in_collegio += 1
        # Stessa linkage Fase 17 (link_senato_collegio): l'alias regione si
        # applica alla regione del collegio PRIMA del lookup nell'indice.
        # Valle d'Aosta arriva italiano-only anche nel collegioElezione
        # ("VALLE D'AOSTA - U01"), quindi senza l'alias il lookup mancherebbe.
        col_regione_key = EXPECTED_REGIONE_ALIASES.get(col_regione_raw.upper(), col_regione_raw.upper()) if m else None
        district_id = uninominale_index.get((col_regione_key, m.group("sub"))) if m else None
        shipped_regione = regione_of_id.get(district_id)
        if derived is None or shipped_regione is None or derived != shipped_regione:
            mismatch.append((value(b, "senatore"), raw, derived, shipped_regione))
    print(f"  senatori uninominali: {len(uni)}")
    print(f"  collegioElezione Trentino in forma bilingue (/SÜDTIROL): {trentino_bilingual_in_collegio}")
    if mismatch:
        ok = False
        print(f"  (c) FALLITA — {len(mismatch)} discordanze:")
        for sid, raw, derived, shipped in mismatch[:10]:
            print(f"    {sid}: regioneElezione={raw!r} derivata={derived!r} collegio={shipped!r}")
    else:
        print(f"  (c) OK — 73/73 regione derivata == regione del collegio")

    # --- contesto electionType (decisione Fase 26) ---
    print("\n--- contesto decisione electionType ---")
    tipo = Counter(value(b, "tipoElezione") for b in serving)
    for k, c in sorted(tipo.items(), key=lambda x: (x[0] is None, x[0] or "")):
        print(f"  {c:4}  {k!r}")
    uninominale = sum(1 for b in serving if (value(b, "tipoElezione") or "").startswith("Eletto uninominale"))
    proporzionale = sum(1 for b in serving if (value(b, "tipoElezione") or "").startswith("Eletto proporzionale"))
    estere = sum(1 for b in serving if value(b, "tipoElezione") == "circoscrizioni estere")
    print(f"  mappatura raccomandata -> uninominale {uninominale} / plurinominale {proporzionale} / estero {estere} / (a-vita null 5)")
    estero_by_tipo = {value(b, "senatore") for b in serving if value(b, "tipoElezione") == "circoscrizioni estere"}
    estero_by_reg = {value(b, "senatore") for b in serving if (value(b, "regioneElezione") or "").upper() in ESTERO_COVERAGE_VALUES}
    print(f"  coerenza estero: insieme(tipoElezione estere) == insieme(regioneElezione estera): {estero_by_tipo == estero_by_reg} ({len(estero_by_tipo)})")

    print("\n" + "=" * 72)
    if ok:
        print("GO-REG: condizioni (a)-(c) verificate.")
        print("=" * 72)
        return 0
    print("GO-REG: NO-GO — almeno una condizione non verificata (vedi sopra).")
    print("=" * 72)
    return 1


if __name__ == "__main__":
    sys.exit(main())
