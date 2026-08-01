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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stateContent(for: model.state)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("The Jeby Report")
                    .font(.headline)
                Text("\(model.location) · \(model.generatedAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func stateContent(for state: HomeViewModel.LoadState) -> some View {
        switch state {
        case .idle, .loading:
            ProgressView("Pulling data from NOAA…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
        case .failed(let message):
            errorView(message)
        case .loaded:
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let conditions = model.conditions {
                    BumpyScoreCard(
                        score: conditions.bumpyScore.score,
                        seasFeet: model.seasFeet,
                        analysis: conditions.bumpyScore.analysis,
                        disclaimers: conditions.bumpyScore.disclaimers,
                        inQuietHours: model.inQuietHours
                    )
                }

                alertsSection

                MarineForecastView(forecast: model.forecast, location: model.location)

                LiveReadingsView(stations: model.stations, conditions: model.conditions)

                camerasSection

                if let vessel = model.vessel {
                    TunedForView(vessel: vessel)
                }

                footer
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await model.refresh() }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Alerts", systemImage: "exclamationmark.triangle.fill")
            if model.alerts.isEmpty {
                AlertBanner(level: .info, message: "NOAA has no active alerts for this area.")
            } else {
                ForEach(model.alerts) { alert in
                    AlertBanner(level: alert.level, title: alert.event, message: alert.description)
                }
            }
        }
    }

    @ViewBuilder
    private var camerasSection: some View {
        if model.buoy360URL != nil || model.asitcamURL != nil {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Cameras", systemImage: "camera.fill")
                if let url = model.buoy360URL {
                    WebcamImage(url: url, caption: "Latest 360° view from the buoy", systemImage: "lifepreserver")
                }
                if let url = model.asitcamURL {
                    WebcamImage(url: url, caption: "Latest view from the MVCO ASIT tower", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            Text("Last updated \(model.generatedAt.formatted(date: .omitted, time: .shortened)) · NOAA & WHOI")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load conditions", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await model.load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }
}
