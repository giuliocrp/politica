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
    @State private var selectedDistrictId: String?
    @State private var hasFitCamera = false
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
                ForEach(services.districtService.districts) { district in
                    MapPolygon(coordinates: district.exteriorCoordinates)
                        .foregroundStyle(fillColor(for: district).opacity(district.id == selectedDistrictId ? 0.55 : 0.28))
                        .stroke(
                            district.id == selectedDistrictId ? Color.orange : fillColor(for: district),
                            lineWidth: district.id == selectedDistrictId ? 4 : 2
                        )
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
                        selectedDistrictId = services.districtService.district(for: coordinate)?.id
                    }
            )
        }
        .navigationTitle("Mappa dei Collegi")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            legend
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedDistrict {
                selectionCard(selectedDistrict)
            }
        }
        .onAppear {
            guard !hasFitCamera else { return }
            hasFitCamera = true
            if let bounds = GeoJSONLoader.bounds(for: services.districtService.districts) {
                cameraPosition = .region(bounds.region)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .blue, label: "Camera dei Deputati")
            legendItem(color: .purple, label: "Senato della Repubblica")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func selectionCard(_ district: District) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(district.name)
                .font(.headline)
            Text(district.chamber == .camera ? "Camera dei Deputati" : "Senato della Repubblica")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

    private func fillColor(for district: District) -> Color {
        district.chamber == .camera ? .blue : .purple
    }
}

#Preview {
    NavigationStack {
        MapView(path: .constant([]))
    }
}
