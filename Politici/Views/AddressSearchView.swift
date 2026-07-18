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

    var body: some View {
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
                    TextField("Es. Roma, Via del Corso", text: $query)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit(search)
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                if showSuggestions {
                    suggestionsList
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Città campione disponibili")
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

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
        .padding()
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

        errorMessage = nil
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

    /// Free-text submission: falls back to `GeocodingProviding` (CLGeocoder, then
    /// the five-city offline table) exactly as before autocomplete was added.
    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        suggestionsVisible = false
        errorMessage = nil
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

    private func resolveCoordinate(_ coordinate: CLLocationCoordinate2D) {
        if let district = services.districtService.district(for: coordinate) {
            path.append(.districtDetail(districtId: district.id))
        } else {
            errorMessage = "Indirizzo non coperto dal prototipo. Prova con una città campione come Roma, Milano o Torino."
        }
    }
}

#Preview {
    NavigationStack {
        AddressSearchView(path: .constant([]))
    }
}
