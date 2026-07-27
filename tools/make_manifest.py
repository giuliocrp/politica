#!/usr/bin/env python3
"""Regenerates Data/sources.json (the SourcesManifest the app's "Informazioni
e fonti" screen renders), upserting entries by id so re-running this script
is safe and idempotent.

Offline — makes no network calls. Each real source's `retrievedAt` is read
from tools/raw/.fetch_metadata.json (written by tools/fetch_camera.py /
tools/fetch_senato.py at the moment they last successfully fetched — see
tools/sparql_client.py), so it reflects when the data was actually
retrieved, not whenever this script happens to run. `generatedAt` (the
manifest's own top-level field) is a different thing — when *this file* was
last regenerated — and is always today's date.

Preserves the original "prototipo-dati-dimostrativi" entry as the only
remaining fictional-data source — representatives.json, districts.geojson,
and (as of the votes-import phase) votes.json now all carry real,
officially-sourced data.
"""

import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).parent.parent
MANIFEST_PATH = ROOT / "Politici" / "Data" / "sources.json"
VOTES_PATH = ROOT / "Politici" / "Data" / "votes.json"
MEMBERSHIPS_PATH = ROOT / "Politici" / "Data" / "memberships_camera.json"
FETCH_METADATA_PATH = Path(__file__).parent / "raw" / ".fetch_metadata.json"


def fail(message):
    print(f"ERRORE: {message}", file=sys.stderr)
    sys.exit(1)


def retrieved_at(source_key, fetch_metadata):
    """The real fetch date if available, else today's date as an honest
    fallback (e.g. a fresh checkout that regenerates the manifest before
    ever running `make fetch`)."""
    entry = fetch_metadata.get(source_key)
    if entry and entry.get("fetchedAt"):
        return entry["fetchedAt"]
    return date.today().isoformat()


def load_fetch_metadata():
    if not FETCH_METADATA_PATH.exists():
        return {}
    try:
        return json.loads(FETCH_METADATA_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def votazioni_scope_note():
    """Builds the votes source's descriptive note from what's ACTUALLY in
    Data/votes.json (not from tools/config/votes_scope.json's nominal N),
    since tools/import_votes.py's maxPositionRecords budget can legitimately
    reduce the real included count below the configured default — see
    docs/v2/04-votes-import.md."""
    if not VOTES_PATH.exists():
        return (
            "Nessuna votazione importata ancora — esegui 'make fetch' e "
            "'make import' (vedi docs/v2/04-votes-import.md)."
        )
    votes = json.loads(VOTES_PATH.read_text(encoding="utf-8"))
    # Phase 20 normalized votes.json to {"events":[...],"positions":[...]}
    # (docs/v3/20-vote-browsing.md); each event carries the sourceUrl. Handle
    # both shapes so this note is robust across the schema change — the old
    # flat list (still used by votes.sample.json) and the current object.
    # (This function had gone stale on the new schema — first re-run since
    # Phase 20 was Phase 25; see docs/v4/25-plurinominale-geography.md.)
    events = votes["events"] if isinstance(votes, dict) else votes
    vote_count = len({e["sourceUrl"] for e in events if e.get("sourceUrl")})
    sittings = len({e["id"].split("_")[1] for e in events if "_" in e.get("id", "")})
    return (
        f"Campione stratificato di {vote_count} votazioni dell'Assemblea, XIX "
        "legislatura (voto elettronico, non a scrutinio segreto), con la "
        "posizione di voto di ogni deputato coinvolto. Non è l'archivio "
        f"completo: le votazioni sono selezionate per copertura su {sittings} "
        "sedute distribuite in più mesi, in parte voti procedurali (ordini "
        "del giorno) e in parte votazioni finali su atti. Le votazioni a "
        "scrutinio segreto sono escluse: il dato sorgente non attribuisce una "
        "posizione al singolo deputato per quel tipo di voto, per garantirne "
        "la segretezza. Il Senato non è incluso in questa fase."
    )


def adesioni_scope_note():
    """Builds the group-membership source's note from what's ACTUALLY in
    Data/memberships_camera.json (Phase 28), so the counts can't drift from
    the shipped artifact."""
    if not MEMBERSHIPS_PATH.exists():
        return (
            "Nessuno storico delle adesioni importato ancora — esegui "
            "'make fetch' e 'make import' (vedi docs/v4/28-membership-history.md)."
        )
    data = json.loads(MEMBERSHIPS_PATH.read_text(encoding="utf-8"))
    memberships = data["memberships"]
    by_person = {}
    for m in memberships:
        by_person.setdefault(m["representativeId"], []).append(m)
    switchers = sum(1 for iv in by_person.values() if len(iv) > 1)
    return (
        f"Storico delle adesioni ai gruppi parlamentari dei {len(by_person)} "
        "deputati in carica della XIX legislatura, ottenuto tramite "
        "interrogazione SPARQL all'endpoint ufficiale dati.camera.it. Ogni "
        f"adesione è un intervallo con data di inizio ed eventuale data di "
        f"fine ({len(memberships)} intervalli in tutto; {switchers} deputati "
        "hanno cambiato gruppo almeno una volta): questo permette di "
        "attribuire ogni voto al gruppo di cui il deputato faceva parte alla "
        "data del voto, e non all'attuale. La sigla del gruppo è il dato "
        "canonico; il nome esteso conserva la troncatura alla parentesi "
        "presente nella fonte. Solo Camera: le votazioni importate sono solo "
        "della Camera."
    )


def real_sources(fetch_metadata):
    return [
        {
            "id": "camera-dei-deputati-xix-legislatura",
            "name": "Camera dei Deputati — Open Data (XIX Legislatura)",
            "url": "https://dati.camera.it/sparql",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("camera", fetch_metadata),
            "notes": (
                "Dati su deputati, gruppi parlamentari e commissioni della XIX "
                "Legislatura, ottenuti tramite interrogazione SPARQL "
                "all'endpoint ufficiale dati.camera.it. I deputati eletti in "
                "un collegio uninominale sono associati al relativo collegio "
                "ISTAT; i deputati eletti con quota proporzionale o all'estero "
                "non hanno un collegio associato (districtId è null)."
            ),
        },
        {
            "id": "senato-della-repubblica-xix-legislatura",
            "name": "Senato della Repubblica — Open Data (XIX Legislatura)",
            "url": "https://dati.senato.it/sparql",
            "license": "CC BY 3.0",
            "retrievedAt": retrieved_at("senato", fetch_metadata),
            "notes": (
                "Dati su senatori, gruppi parlamentari e commissioni della XIX "
                "Legislatura, ottenuti tramite tre interrogazioni SPARQL "
                "all'endpoint ufficiale dati.senato.it. I senatori eletti in un "
                "collegio uninominale sono associati al relativo collegio ISTAT "
                "(districtId); gli altri non hanno un collegio associato "
                "(districtId è null). Vedi docs/v3/17-senato-mandates.md."
            ),
        },
        {
            "id": "istat-collegi-elettorali-camera-uninominali",
            "name": "ISTAT — Basi geografiche dei collegi elettorali (Camera, uninominali)",
            "url": "https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("istat", fetch_metadata),
            "notes": (
                "Confini geografici dei 147 collegi uninominali della Camera "
                "(D.Lgs. 177/2020), riproiettati da EPSG:32632 a EPSG:4326 e "
                "semplificati per l'uso su mobile."
            ),
        },
        {
            "id": "istat-collegi-elettorali-senato-uninominali",
            "name": "ISTAT — Basi geografiche dei collegi elettorali (Senato, uninominali)",
            "url": "https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("istat", fetch_metadata),
            "notes": (
                "Confini geografici dei 74 collegi uninominali del Senato "
                "(D.Lgs. 177/2020), riproiettati da EPSG:32632 a EPSG:4326 e "
                "semplificati per l'uso su mobile. Stesso rilascio ISTAT dei "
                "confini della Camera (vedi la fonte "
                "istat-collegi-elettorali-camera-uninominali), scaricato "
                "nello stesso momento. 73 dei 74 collegi sono collegati al "
                "rispettivo senatore eletto in via uninominale (districtId "
                "associato tramite osr:collegioElezione; vedi "
                "docs/v3/17-senato-mandates.md)."
            ),
        },
        {
            "id": "istat-collegi-elettorali-camera-plurinominali",
            "name": "ISTAT — Basi geografiche dei collegi elettorali (Camera, plurinominali)",
            "url": "https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("istat", fetch_metadata),
            "notes": (
                "Confini geografici dei 49 collegi plurinominali della Camera "
                "(D.Lgs. 177/2020), riproiettati da EPSG:32632 a EPSG:4326 e "
                "semplificati per l'uso su mobile. Stesso rilascio ISTAT dei "
                "confini uninominali (vedi la fonte "
                "istat-collegi-elettorali-camera-uninominali), scaricato "
                "nello stesso momento. Ogni deputato eletto con quota "
                "proporzionale è associato al proprio collegio plurinominale."
            ),
        },
        {
            "id": "istat-collegi-elettorali-senato-plurinominali",
            "name": "ISTAT — Basi geografiche dei collegi elettorali (Senato, plurinominali)",
            "url": "https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("istat", fetch_metadata),
            "notes": (
                "Confini geografici dei 26 collegi plurinominali del Senato "
                "(D.Lgs. 177/2020), riproiettati da EPSG:32632 a EPSG:4326 e "
                "semplificati per l'uso su mobile. Stesso rilascio ISTAT dei "
                "confini della Camera, scaricato nello stesso momento. I "
                "senatori non sono ancora collegati al proprio collegio "
                "plurinominale in questo prototipo."
            ),
        },
        {
            "id": "istat-comuni-centroidi",
            "name": "ISTAT — Comuni (assegnazione ai collegi e centroidi)",
            "url": "https://www.istat.it/notizia/le-basi-geografiche-dei-nuovi-collegi-elettorali-2",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("istat", fetch_metadata),
            "notes": (
                "Tabella dei 7.904 comuni italiani. Per ciascuno riporta "
                "l'assegnazione ai collegi uninominali pubblicata dalla fonte "
                "(CU20_COD per la Camera, SU20_COD per il Senato): è questa, e "
                "non la geometria, a rispondere alla ricerca per nome di "
                "comune. Sei comuni (Roma, Milano, Napoli, Torino, Palermo, "
                "Genova) sono divisi tra più collegi uninominali e vengono "
                "mostrati con tutti i collegi assegnati, mai con uno solo. "
                "Riporta inoltre un punto interno (centroide) per ciascun "
                "comune, usato per la ricerca per coordinate/indirizzo tramite "
                "point-in-polygon, senza rete. Derivata dal livello comunale "
                "UT_Collegi2020 dello stesso rilascio ISTAT dei confini dei "
                "collegi (D.Lgs. 177/2020; vedi la fonte "
                "istat-collegi-elettorali-camera-uninominali), scaricato nello "
                "stesso momento — nessun nuovo download. I nomi omonimi (6, es. "
                "Castro, Livo) sono distinti per provincia."
            ),
        },
        {
            "id": "camera-dei-deputati-votazioni-xix-legislatura",
            "name": "Camera dei Deputati — Votazioni (XIX Legislatura)",
            "url": "https://dati.camera.it/sparql",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("camera_votazioni", fetch_metadata),
            "notes": votazioni_scope_note(),
        },
        {
            "id": "camera-dei-deputati-adesioni-gruppi-xix-legislatura",
            "name": "Camera dei Deputati — Adesioni ai gruppi parlamentari (XIX Legislatura)",
            "url": "https://dati.camera.it/sparql",
            "license": "CC BY 4.0",
            "retrievedAt": retrieved_at("camera_adesioni", fetch_metadata),
            "notes": adesioni_scope_note(),
        },
    ]


def main():
    if not MANIFEST_PATH.exists():
        fail(f"{MANIFEST_PATH.relative_to(ROOT)} non esiste")

    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{MANIFEST_PATH.relative_to(ROOT)} non è JSON valido: {error}")

    fetch_metadata = load_fetch_metadata()

    sources_by_id = {s["id"]: s for s in manifest.get("sources", [])}
    for source in real_sources(fetch_metadata):
        sources_by_id[source["id"]] = source

    manifest["schemaVersion"] = 2
    manifest["generatedAt"] = date.today().isoformat()
    manifest["sources"] = [sources_by_id[key] for key in sorted(sources_by_id)]

    serialized = json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    MANIFEST_PATH.write_text(serialized, encoding="utf-8")

    print(f"OK: {len(manifest['sources'])} fonti in {MANIFEST_PATH.relative_to(ROOT)}")
    for source in manifest["sources"]:
        print(f"  - {source['id']} ({source['license']}, retrievedAt={source['retrievedAt']})")


if __name__ == "__main__":
    main()
