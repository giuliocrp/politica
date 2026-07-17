//
//  AddressAutocompleteService.swift
//  Politici
//

import Combine
import CoreLocation
import MapKit

/// Wraps `MKLocalSearchCompleter` to provide as-you-type address suggestions,
/// biased to Italy. This is Apple's own on-device/Apple-services search
/// completion, not custom networking, so it stays within the app's
/// local-first constraint the same way `CLGeocoder` already did.
///
/// Unlike the read-only data services in `ServiceContainer`, this isn't
/// registered there as a `.shared` singleton: its `suggestions` are live,
/// mutable state scoped to one in-progress search session, not an app-wide
/// data repository. `AddressSearchView` owns an instance directly via
/// `@StateObject`, matching Apple's own usage pattern of one completer per
/// search UI.
@MainActor
final class AddressAutocompleteService: NSObject, ObservableObject {
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.5, longitude: 12.5),
            span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 13)
        )
    }

    /// Updates the in-progress query fragment; results arrive asynchronously via the delegate.
    func updateQuery(_ fragment: String) {
        completer.queryFragment = fragment
    }

    /// Clears any pending query and suggestions, e.g. right after a suggestion is selected.
    func clear() {
        completer.queryFragment = ""
        suggestions = []
    }
}

extension AddressAutocompleteService: MKLocalSearchCompleterDelegate {
    // MKLocalSearchCompleter may call its delegate from a non-main queue, so these
    // conform as `nonisolated` and hop back to the main actor to mutate `suggestions`.
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}
