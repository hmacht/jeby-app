//
//  HomeContentCard.swift
//  Jeby
//
//  The draggable card that sits over the map: the same live conditions the
//  jeby-web home page shows — hero seas, BumpyScore, alerts, webcams, live
//  readings, marine forecast, and the vessel it's tuned for.
//

import SwiftUI

struct HomeContentCard: View {
    let model: HomeViewModel
    /// Set while the sheet is collapsed, so the swipe raises the sheet instead
    /// of scrolling the report inside it.
    var scrollDisabled = false
    /// Called when the report is pulled down past its top, which lowers the
    /// sheet back over the map the way Maps does.
    var onPullDown: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stateContent(for: model.state)
        }
    }

    private var header: some View {
        TabHeader(title: "The Jeby Report") {
            HStack(spacing: 6) {
                PulsingDot()
                Text("Last updated \(model.generatedAt.formatted(date: .omitted, time: .shortened))")
            }
        } accessory: {
            if model.state == .loaded {
                VesselPicker(
                    vessels: model.vessels,
                    selected: model.selectedVessel,
                    disabled: model.vessels.isEmpty
                ) { code in
                    Task { await model.load(vessel: code) }
                }
            }
        }
    }

    @ViewBuilder
    private func stateContent(for state: HomeViewModel.LoadState) -> some View {
        switch state {
        case .idle, .loading:
            ProgressView("Pulling data from NOAA…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Sit above the floating pill rather than centering behind it.
                .padding(.bottom, 120)
        case .failed(let message):
            errorView(message)
        case .loaded:
            content
        }
    }

    private var content: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {
                if let conditions = model.conditions {
                    BumpyScoreCard(
                        score: conditions.bumpyScore.score,
                        analysis: conditions.bumpyScore.analysis,
                        disclaimers: conditions.bumpyScore.disclaimers,
                        inQuietHours: model.inQuietHours
                    )
                }

                alertsSection

                camerasSection

                LiveReadingsView(stations: model.stations, conditions: model.conditions)

                MarineForecastView(forecast: model.forecast, location: model.location)

                if let vessel = model.vessel {
                    TunedForView(vessel: vessel)
                }

                AboutCard()
            }
            .padding(20)
            // Clear the floating pill and the home indicator below it.
            .padding(.bottom, 120)
            // Pin the content to the sheet's width so nothing can pan sideways.
            .containerRelativeFrame(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(scrollDisabled)
        .scrollContentBackground(.hidden)
        // Overscroll past the top: how far the content has been dragged down.
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, overscroll in
            if overscroll < -90 { onPullDown() }
        }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Alerts", systemImage: "exclamationmark.triangle")
            if model.alerts.isEmpty {
                AlertBanner(level: .info, message: "NOAA has no active alerts for the Vineyard.")
            } else {
                // Any active alert reads red, whatever NOAA's severity says.
                ForEach(model.alerts) { alert in
                    AlertBanner(level: .danger, title: alert.event, message: alert.description)
                }
            }
        }
    }

    /// ASIT tower first, then the buoy's 360° panorama, in one scrolling strip.
    private var cameras: [CameraStrip.Camera] {
        var list: [CameraStrip.Camera] = []
        if let url = model.asitcamURL {
            list.append(.init(url: url, caption: "MVCO ASIT tower", systemImage: "antenna.radiowaves.left.and.right"))
        }
        if let url = model.buoy360URL {
            list.append(.init(url: url, caption: "Nantucket Sound Buoy 360°", systemImage: "lifepreserver"))
        }
        return list
    }

    @ViewBuilder
    private var camerasSection: some View {
        if !cameras.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Cameras", systemImage: "camera")
                CameraStrip(cameras: cameras)
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        StateMessage(
            icon: "cloud.bolt.rain.fill",
            title: "Couldn't load conditions",
            detail: message,
            actionTitle: "Try Again"
        ) {
            Task { await model.load() }
        }
    }
}
