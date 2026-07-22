//
//  RepresentativeService.swift
//  Politici
//

import Foundation

/// Loads `representatives.json` once and answers representative lookups.
final class RepresentativeService {
    static let shared = RepresentativeService()

    private(set) var representatives: [Representative] = []
    private(set) var loadError: Error?

    init(resource: String = "representatives", bundle: Bundle = .main) {
        do {
            representatives = try LocalJSONLoader.decode(
                [Representative].self,
                fromResource: resource,
                bundle: bundle
            )
        } catch {
            loadError = error
            representatives = []
        }
    }

    func allRepresentatives() -> [Representative] {
        representatives
    }

    func representative(withId id: String) -> Representative? {
        representatives.first { $0.id == id }
    }

    func representatives(for districtId: String) -> [Representative] {
        representatives.filter { $0.districtId == districtId }
    }

    /// The Camera plurinominale deputies of one circoscrizione, sorted by
    /// name — what DistrictDetailView's Phase 18 section lists. Filtering
    /// on `electionType == .plurinominale` (not just the circoscrizione
    /// string) keeps uninominale deputies out of their own circoscrizione's
    /// section and estero deputies off every geographic page even in the
    /// hypothetical where a circoscrizione string matched.
    func plurinominaleRepresentatives(inCircoscrizione circoscrizione: String) -> [Representative] {
        Self.plurinominaleRepresentatives(inCircoscrizione: circoscrizione, from: representatives)
    }

    /// Static so tests can exercise the grouping as a pure function on
    /// hand-built fixtures, independent of any bundled resource.
    static func plurinominaleRepresentatives(
        inCircoscrizione circoscrizione: String,
        from representatives: [Representative]
    ) -> [Representative] {
        representatives
            .filter {
                $0.chamber == .camera
                    && $0.electionType == .plurinominale
                    && $0.circoscrizione == circoscrizione
            }
            .sorted { $0.name < $1.name }
    }

    /// The Senato proporzionale senators of one regione, sorted by name —
    /// what DistrictDetailView's Phase 26 Senato section lists (the mirror of
    /// the Camera plurinominale grouping above). Filtering on
    /// `electionType == .plurinominale` (the approved Senato mapping of "Eletto
    /// proporzionale…", not just the regione string) keeps the region's
    /// uninominale senators out of its proporzionale section, and the a-vita
    /// (nil regione) and estero ("Estero" regione, `.estero`) senators off
    /// every geographic page even in the hypothetical where a regione string
    /// matched.
    func proporzionaleSenators(inRegione regione: String) -> [Representative] {
        Self.proporzionaleSenators(inRegione: regione, from: representatives)
    }

    /// Static so tests can exercise the grouping as a pure function on
    /// hand-built fixtures, independent of any bundled resource.
    static func proporzionaleSenators(
        inRegione regione: String,
        from representatives: [Representative]
    ) -> [Representative] {
        representatives
            .filter {
                $0.chamber == .senato
                    && $0.electionType == .plurinominale
                    && $0.regione == regione
            }
            .sorted { $0.name < $1.name }
    }

    /// The deputies elected in one plurinominale collegio, sorted by name —
    /// what the Phase 25 plurinominale-collegio detail page lists. Filtering
    /// on `electionType == .plurinominale` (not merely the id) keeps it to
    /// the deputies actually elected there by proportional list: the
    /// uninominale deputies whose seat geographically sits inside the same
    /// collegio also carry the id, but they belong on their own uninominale
    /// collegio page, not here.
    func deputies(inPlurinominaleCollegio collegioId: String) -> [Representative] {
        Self.deputies(inPlurinominaleCollegio: collegioId, from: representatives)
    }

    /// Static so tests can exercise the grouping as a pure function on
    /// hand-built fixtures, independent of any bundled resource.
    static func deputies(
        inPlurinominaleCollegio collegioId: String,
        from representatives: [Representative]
    ) -> [Representative] {
        representatives
            .filter {
                $0.chamber == .camera
                    && $0.electionType == .plurinominale
                    && $0.collegioPlurinominale == collegioId
            }
            .sorted { $0.name < $1.name }
    }
}
