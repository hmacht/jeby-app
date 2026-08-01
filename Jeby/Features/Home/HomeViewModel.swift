//
//  HomeViewModel.swift
//  Jeby
//
//  Drives the Home tab: loads the same data the jeby-web home page shows
//  (vessels, conditions, forecast, alerts, images, stations) from the jeby-go
//  backend and exposes it as observable state.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {

    // Marthas Vineyard Sound, MA — the backend is Vineyard-only, so the buoy/zone
    // live server-side; the app only chooses which vessel to score.
    let location = "Marthas Vineyard Sound, MA"

    // Small Craft is the default vessel when none is selected — the broadest
    // fit for most people opening the app.
    static let defaultVessel = "SMALL"

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: LoadState = .idle

    private(set) var vessels: [Vessel] = []
    private(set) var selectedVessel: String = HomeViewModel.defaultVessel
    private(set) var conditions: Conditions?
    private(set) var forecast: ForecastSummary?
    private(set) var alerts: [Alert] = []
    private(set) var stations: [Station] = []
    private(set) var buoy360URL: URL?
    private(set) var asitcamURL: URL?
    private(set) var generatedAt = Date()

    private let client: JebyClientProtocol

    init(client: JebyClientProtocol = JebyClient()) {
        self.client = client
    }

    /// Station-merged readings (prefers the NOAA buoy, falls back to MVCO).
    var readings: Readings { Readings(conditions) }

    /// Live wave height (feet) for a station, used by the map markers/overlays.
    func waveHeightFeet(for code: String) -> Double? {
        guard let meters = conditions?.station(for: code).waveHeight.value else { return nil }
        return Units.metersToFeet(meters)
    }

    /// The vessel the BumpyScore is currently computed for.
    var vessel: Vessel? {
        conditions?.vessel ?? vessels.first { $0.code == selectedVessel }
    }

    /// Hero seas number: live wave height in feet, to one decimal.
    var seasFeet: String? {
        guard let meters = readings.waveHeight else { return nil }
        return String(format: "%.1f", Units.metersToFeet(meters))
    }

    /// Overnight the backend pauses AI scoring and serves a quiet-hours message
    /// with a null score. Detect it so we can show a moon instead of a dash.
    var inQuietHours: Bool {
        (conditions?.bumpyScore.analysis ?? "").lowercased().contains("quiet hours")
    }

    /// Initial load, or a full reload when switching vessels.
    func load(vessel code: String? = nil) async {
        if let code { selectedVessel = code }
        if vessels.isEmpty { state = .loading }

        do {
            // Vessels first so we can resolve the selection against the registry.
            if vessels.isEmpty {
                vessels = try await client.vessels()
            }
            let requested = code ?? selectedVessel
            selectedVessel = vessels.first { $0.code == requested }?.code
                ?? vessels.first { $0.code == HomeViewModel.defaultVessel }?.code
                ?? vessels.first?.code
                ?? HomeViewModel.defaultVessel

            async let conditions = client.conditions(vessel: selectedVessel)
            async let forecast = client.forecastSummary()
            async let alerts = client.activeAlerts()
            async let images = client.images()
            async let stations = client.stations()

            self.conditions = try await conditions
            self.forecast = try? await forecast
            self.alerts = (try? await alerts) ?? []
            self.stations = (try? await stations) ?? []

            if let images = try? await images {
                self.buoy360URL = images.buoy360.flatMap(URL.init(string:))
                self.asitcamURL = URL(string: images.asitcam2)
            }

            self.generatedAt = Date()
            state = .loaded
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }

    /// Pull-to-refresh: re-pull for the current vessel without a full-screen spinner.
    func refresh() async {
        await load()
    }
}
