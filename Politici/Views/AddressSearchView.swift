//
//  AddressSearchView.swift
//  Politici
//

import SwiftUI

struct AddressSearchView: View {
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services
    @State private var query: String
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hasAutoSearched = false

    private let sampleCities = ["Roma", "Milano", "Napoli", "Torino", "Firenze"]

    init(path: Binding<[AppRoute]>, initialQuery: String = "") {
        self._path = path
        self._query = State(initialValue: initialQuery)
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Città campione disponibili")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sampleCities, id: \.self) { city in
                            Button(city) {
                                query = city
                                search()
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
                    ProgressView()
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
        .task {
            guard !hasAutoSearched, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            hasAutoSearched = true
            search()
        }
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isSearching = true

        Task {
            defer { isSearching = false }
            do {
                let coordinate = try await services.geocodingService.geocode(address: trimmed)
                if let district = services.districtService.district(for: coordinate) {
                    path.append(.districtDetail(districtId: district.id))
                } else {
                    errorMessage = "Indirizzo non coperto dal prototipo. Prova con una città campione come Roma, Milano o Torino."
                }
            } catch {
                errorMessage = "Indirizzo non coperto dal prototipo. Prova con una città campione come Roma, Milano o Torino."
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddressSearchView(path: .constant([]))
    }
}
