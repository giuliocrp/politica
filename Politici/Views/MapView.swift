//
//  MapView.swift
//  Politici
//

import CoreLocation
import MapKit
import SwiftUI

struct MapView: View {
    @Binding var path: [AppRoute]
    @Environment(\.services) private var services
    @State private var selectedChamber: Chamber = .camera
    @State private var selectedDistrictId: String?
    @State private var fittedChambers: Set<Chamber> = []
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.5, longitude: 12.5),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )

    private var selectedDistrict: District? {
        selectedDistrictId.flatMap(services.districtService.district(withId:))
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                ForEach(services.districtService.allDistricts(chamber: selectedChamber)) { district in
                    districtOverlay(district)
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let coordinate = proxy.convert(value.location, from: .local) else { return }
                        selectedDistrictId = services.districtService.district(for: coordinate, chamber: selectedChamber)?.id
                    }
            )
        }
        .navigationTitle("Mappa dei Collegi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path.append(.collegiList)
                } label: {
                    Label("Sfoglia come elenco", systemImage: "list.bullet")
                }
                .accessibilityHint("Mostra tutti i collegi in un elenco navigabile, alternativo alla mappa")
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                ChamberPicker(selection: $selectedChamber)
                    .padding(.horizontal, 12)
                caption
            }
            .padding(.top, 8)
            .background(.thinMaterial)
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedDistrict {
                selectionCard(selectedDistrict)
            }
        }
        .onAppear { fitCamera(to: selectedChamber) }
        .onChange(of: selectedChamber) { _, newChamber in
            selectedDistrictId = nil
            fitCamera(to: newChamber)
        }
    }

    private func fitCamera(to chamber: Chamber) {
        guard !fittedChambers.contains(chamber) else { return }
        fittedChambers.insert(chamber)
        if let bounds = GeoJSONLoader.bounds(for: services.districtService.allDistricts(chamber: chamber)) {
            cameraPosition = .region(bounds.region)
        }
    }

    /// One `MapPolygon` per part of the district's geometry — most collegi
    /// are a single Polygon, but many (56 of 147 Camera / 34 of 74 Senato
    /// in the shipping ISTAT data) are MultiPolygon, e.g. a mainland
    /// collegio that also includes small offshore islands. `MapPolygon(_:)`
    /// renders each MKPolygon's own interior holes automatically.
    @MapContentBuilder
    private func districtOverlay(_ district: District) -> some MapContent {
        let isSelected = district.id == selectedDistrictId
        let color = chamberColor
        ForEach(Array(district.polygons.enumerated()), id: \.offset) { _, polygon in
            MapPolygon(polygon)
                .foregroundStyle(color.opacity(isSelected ? 0.55 : 0.28))
                .stroke(isSelected ? Color.orange : color, lineWidth: isSelected ? 4 : 2)
        }
    }

    /// Every overlay on screen belongs to `selectedChamber` (only that
    /// chamber's districts are ever rendered — see `body`), so the fill
    /// color is a function of the picker, not of each individual feature.
    private var chamberColor: Color {
        selectedChamber == .camera ? .blue : .purple
    }

    private var caption: some View {
        Text(selectedChamber == .camera
            ? "Collegi uninominali — Camera dei Deputati"
            : "Collegi uninominali — Senato della Repubblica")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionCard(_ district: District) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text(district.name)
                    .font(.headline)
                Text(district.chamber == .camera ? "Camera dei Deputati" : "Senato della Repubblica")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Button {
                path.append(.districtDetail(districtId: district.id))
            } label: {
                Text("Vedi dettagli del collegio")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}

/// Segmented Camera/Senato toggle shared by `MapView` and `CollegiListView`
/// — the two "browse collegi" entry points (see `CollegioRow`'s sibling
/// `RepresentativeRow` precedent for the two-screen-shared-component
/// convention). Visible labels stay short ("Camera"/"Senato") to fit a
/// segmented control; VoiceOver reads the full institutional name via the
/// explicit accessibility label on each segment.
struct ChamberPicker: View {
    @Binding var selection: Chamber

    var body: some View {
        Picker("Camera del Parlamento", selection: $selection) {
            Text("Camera")
                .accessibilityLabel("Camera dei Deputati")
                .tag(Chamber.camera)
            Text("Senato")
                .accessibilityLabel("Senato della Repubblica")
                .tag(Chamber.senato)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

#Preview {
    NavigationStack {
        MapView(path: .constant([]))
    }
}
