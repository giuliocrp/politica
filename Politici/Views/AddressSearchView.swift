//
//  AddressSearchView.swift
//  Politici
//

import CoreLocation
import MapKit
import SwiftUI

struct AddressSearchView: View {
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services
    @StateObject private var autocomplete = AddressAutocompleteService()

    @State private var query: String
    @State private var isSearching = false
    @State private var errorMessage: String?
    /// One entry per chamber, each holding **every** collegio that chamber
    /// answers with. It is an array rather than a single district because a
    /// comune-name query can legitimately answer with several — Roma spans
    /// seven Camera collegi — and Phase 30B's rule is that such a comune must
    /// never be reduced to one collegio presented as the answer. The
    /// coordinate path still produces exactly one per chamber.
    @State private var resolvedMatches: [Chamber: [District]]?
    /// The comune whose **published assignment** produced `resolvedMatches`,
    /// or `nil` when they came from the coordinate path. Drives the caption
    /// that tells the two apart. Phase 30B.
    @State private var resolvedComune: Comune?
    /// Set when a typed name matches more than one comune (a homonym, e.g.
    /// "Castro" in Bergamo and Lecce): the user picks which province before we
    /// resolve anything. Phase 30.
    @State private var comuneCandidates: [Comune]?
    @State private var hasAutoSearched = false
    @State private var suggestionsVisible = true
    @State private var suppressNextQueryChange = false

    private let sampleCities = ["Roma", "Milano", "Napoli", "Torino", "Firenze"]

    init(path: Binding<[AppRoute]>, initialQuery: String = "") {
        self._path = path
        self._query = State(initialValue: initialQuery)
    }

    private var showSuggestions: Bool {
        suggestionsVisible && !autocomplete.suggestions.isEmpty && !isSearching
    }

    /// A `ScrollView`, not a bare `VStack` (Phase 32A — docs/v4/32a-release.md
    /// §4). Phase 30B made this screen's tallest state much taller than it had
    /// ever been: a comune divided between several collegi lists **all** of
    /// them, and Roma's answer is seven Camera rows plus three Senato ones
    /// under two explanatory paragraphs. In a non-scrolling `VStack` that
    /// overflows the screen, and the overflow was measured to be
    /// *unreachable* — the whole-screen accessibility audit found Roma's seven
    /// Camera collegi on screen and **none of its three Senato ones anywhere
    /// in the accessibility tree**. Listing every assigned collegio is the
    /// point of the name path; a collegio the user cannot reach is not listed.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cerca il tuo collegio")
                        .font(.title2.bold())
                    Text("Inserisci un indirizzo o una città per trovare il collegio elettorale e i rappresentanti collegati.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField("Es. Roma, Via del Corso", text: $query)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .onSubmit(search)
                            .accessibilityHint("Inserisci un indirizzo o una città per trovare il collegio")
                            .accessibilityIdentifier("addressSearch.field")
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    if showSuggestions {
                        suggestionsList
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Comuni di esempio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sampleCities, id: \.self) { city in
                                Button(city) {
                                    selectSampleCity(city)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                                .accessibilityIdentifier("addressSearch.city.\(city)")
                            }
                        }
                    }
                }

                Button {
                    search()
                } label: {
                    if isSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Ricerca in corso…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Cerca collegio")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                .accessibilityIdentifier("addressSearch.submit")

                if let errorMessage {
                    // `Label` already presents icon+text as one accessibility
                    // element (VoiceOver reads just the title), so no extra
                    // grouping is needed here.
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }

                if let comuneCandidates {
                    candidatesSection(comuneCandidates)
                }

                if let resolvedMatches {
                    resultsSection(resolvedMatches)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Cerca Indirizzo")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: query) { _, newValue in
            if suppressNextQueryChange {
                suppressNextQueryChange = false
                return
            }
            suggestionsVisible = true
            autocomplete.updateQuery(newValue)
        }
        .task {
            guard !hasAutoSearched, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            hasAutoSearched = true
            search()
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(autocomplete.suggestions.enumerated()), id: \.offset) { index, suggestion in
                Button {
                    resolveSuggestion(suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)

                if index < autocomplete.suggestions.count - 1 {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectSampleCity(_ city: String) {
        suppressNextQueryChange = true
        query = city
        suggestionsVisible = false
        autocomplete.clear()
        search()
    }

    /// Resolves a tapped autocomplete suggestion to a coordinate via `MKLocalSearch`,
    /// then runs the same point-in-polygon district resolution as free-text search.
    private func resolveSuggestion(_ suggestion: MKLocalSearchCompletion) {
        suppressNextQueryChange = true
        query = suggestion.title
        suggestionsVisible = false
        autocomplete.clear()

        clearResults()
        isSearching = true

        Task {
            defer { isSearching = false }
            let localSearch = MKLocalSearch(request: MKLocalSearch.Request(completion: suggestion))
            do {
                let response = try await localSearch.start()
                guard let coordinate = response.mapItems.first?.placemark.coordinate else {
                    errorMessage = "Nessun risultato per questo indirizzo."
                    return
                }
                resolveCoordinate(coordinate)
            } catch {
                errorMessage = "Nessun risultato per questo indirizzo."
            }
        }
    }

    /// Free-text submission, routed down one of **two deliberately distinct
    /// paths** (Phase 30B — docs/v4/30b-comuni-assignment.md):
    ///
    /// * the text names a comune → answer with the collegi **ISTAT publishes**
    ///   for it. A sourced fact, so it carries none of the simplified
    ///   geometry's border artefacts or dropped-island gaps — and it can be a
    ///   *set*, which is how Roma stops being answered with one of its seven
    ///   Camera collegi. A homonym (`Castro` in Bergamo *and* Lecce) asks for
    ///   the province first (Phase 30).
    /// * anything else (a street address, "Roma Termini", …) → the unchanged
    ///   coordinate path through `GeocodingProviding` (CLGeocoder → comuni
    ///   table → five-city fallback) and point-in-polygon.
    ///
    /// The comune check is exact-name and offline, so it never fires for a
    /// full street address and `CLGeocoder` still wins for address-level
    /// queries.
    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        suggestionsVisible = false
        clearResults()

        switch services.comuneService.match(name: trimmed) {
        case .ambiguous(let candidates):
            comuneCandidates = candidates
            return
        case .one(let comune):
            resolveComune(comune)
            return
        case .none:
            break  // not a comune name — fall through to the coordinate path
        }

        isSearching = true
        Task {
            defer { isSearching = false }
            do {
                let coordinate = try await services.geocodingService.geocode(address: trimmed)
                resolveCoordinate(coordinate)
            } catch {
                errorMessage = "Non è stato possibile associare l'indirizzo a un collegio elettorale."
            }
        }
    }

    /// The user picked one province for a homonym name: answer from that
    /// comune's published assignment, skipping the ambiguous geocode.
    private func selectCandidate(_ comune: Comune) {
        clearResults()
        resolveComune(comune)
    }

    /// Answers from the **published** comune → collegio assignment, per
    /// chamber, listing every collegio the source assigns. A comune spanning
    /// several is shown as all of them, never reduced to one.
    private func resolveComune(_ comune: Comune) {
        let matches = services.districtService.districts(assignedTo: comune)
        if matches.isEmpty {
            errorMessage = "Nessun collegio elettorale trovato per questo comune."
        } else {
            resolvedComune = comune
            resolvedMatches = matches
        }
    }

    /// Resolves a coordinate against BOTH chambers independently — a position
    /// may fall inside a Camera collegio, a Senato collegio, both, or neither,
    /// and each is reported on its own line rather than silently preferring
    /// one chamber (see `resultsSection`). Geometry answers at most one
    /// collegio per chamber, so each entry here is a single-element list.
    private func resolveCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let matches = services.districtService.districts(containing: coordinate)
        if matches.isEmpty {
            errorMessage = "Nessun collegio elettorale trovato per questa posizione. Prova con il nome di un comune (es. Roma, Milano, Torino)."
        } else {
            resolvedMatches = matches.mapValues { [$0] }
        }
    }

    private func clearResults() {
        errorMessage = nil
        resolvedMatches = nil
        resolvedComune = nil
        comuneCandidates = nil
    }

    /// Homonym chooser: the same comune name exists in more than one province,
    /// so present each candidate as "Nome (Provincia)" and let the user pick.
    private func candidatesSection(_ candidates: [Comune]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Più comuni con questo nome")
                .font(.headline)
                .accessibilityIdentifier("addressSearch.candidates.header")
            Text("Scegli la provincia:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(candidates) { comune in
                Button {
                    selectCandidate(comune)
                } label: {
                    HStack {
                        Text("\(comune.name) (\(comune.province))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("addressSearch.candidate.\(comune.province)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func resultsSection(_ matches: [Chamber: [District]]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(matches.values.contains { $0.count > 1 } ? "Collegi trovati" : "Collegio trovato")
                .font(.headline)
                .accessibilityIdentifier("addressSearch.results.header")
            // The two paths answer different questions and can legitimately
            // differ near a simplified boundary, so the result says which one
            // produced it rather than presenting both as the same kind of fact.
            Text(resolvedComune == nil
                 ? "Collegio determinato dalla posizione geografica trovata."
                 : "Assegnazione del comune ai collegi pubblicata da ISTAT (basi geografiche dei collegi 2020).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("addressSearch.results.source")
            ChamberResultGroup(chamber: .camera, districts: matches[.camera] ?? []) { district in
                path.append(.districtDetail(districtId: district.id))
            }
            ChamberResultGroup(chamber: .senato, districts: matches[.senato] ?? []) { district in
                path.append(.districtDetail(districtId: district.id))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// One chamber's slice of `AddressSearchView`'s dual-chamber result — **one,
/// many, or none**, the three outcomes Phase 30B's name path has to be able
/// to express (docs/v4/30b-comuni-assignment.md):
///
/// * **one** — the ordinary case, and every case the coordinate path can
///   produce: a single tappable "Collegio Camera / Senato: {name}" row.
/// * **many** — a comune the source assigns to several uninominale collegi
///   (Roma spans seven Camera collegi). Every one of them is listed, under
///   copy that says the comune is divided between them: reducing the set to
///   its largest-territory member would present a computed pick with the same
///   confidence as a genuinely unique answer, which is the silent-failure
///   shape this phase exists to remove.
/// * **none** — the honest not-covered copy `resolveCoordinate` used to show
///   for the whole search, scoped to just this chamber since the other one
///   may still have resolved.
private struct ChamberResultGroup: View {
    let chamber: Chamber
    let districts: [District]
    let onSelect: (District) -> Void

    private var chamberLabel: String {
        chamber == .camera ? "Camera" : "Senato"
    }

    /// "della Camera" / "del Senato" — the genitive the multi-collegio
    /// sentence needs.
    private var chamberGenitive: String {
        chamber == .camera ? "della Camera" : "del Senato"
    }

    /// Stable across all three branches below, so a test can assert the dual
    /// structure regardless of how many collegi each chamber answered with.
    private var identifier: String {
        "addressSearch.result.\(chamber == .camera ? "camera" : "senato")"
    }

    var body: some View {
        if districts.isEmpty {
            Text("Collegio \(chamberLabel): non coperto dal prototipo per questa camera.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityIdentifier(identifier)
        } else if districts.count == 1, let district = districts.first {
            row(district, caption: "Collegio \(chamberLabel)")
                .accessibilityIdentifier(identifier)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // The group's identifier lives on this header, not on the
                // enclosing VStack: an `accessibilityIdentifier` applied to a
                // plain container propagates down and *overrides* the
                // per-collegio identifiers set inside it, which would erase
                // exactly the per-row addressability this branch exists for.
                Text("Collegi \(chamberLabel): \(districts.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(identifier)
                Text("Questo comune è diviso tra \(districts.count) collegi uninominali \(chamberGenitive): sono elencati tutti. Cerca un indirizzo completo per sapere quale ti riguarda.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(districts) { district in
                    row(district, caption: nil)
                        .accessibilityIdentifier("\(identifier).\(district.id)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ district: District, caption: String?) -> some View {
        Button {
            onSelect(district)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let caption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(district.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apre i dettagli del collegio")
    }
}

#Preview {
    NavigationStack {
        AddressSearchView(path: .constant([]))
    }
}
