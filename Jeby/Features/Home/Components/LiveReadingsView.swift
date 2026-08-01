//
//  LiveReadingsView.swift
//  Jeby
//
//  Per-station live readings as Flighty-style passport cards (one per station),
//  each with a "Station details" button that opens the station's detail sheet.
//

import SwiftUI

struct LiveReadingsView: View {
    let stations: [Station]
    let conditions: Conditions?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stations", systemImage: "network")

            ForEach(stations) { station in
                StationPassportCard(
                    station: station,
                    conditions: conditions?.station(for: station.code)
                )
            }
        }
    }
}

private struct StationPassportCard: View {
    let station: Station
    let conditions: StationConditions?

    @State private var showDetail = false

    private var base: Color { CardStyle.tint(isMVCO: station.isMVCO) }

    private let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading),
    ]

    var body: some View {
        GradientCard(base: base, buttonTitle: "Station details", action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name.uppercased())
                        .font(.headline.weight(.bold))
                    CardEyebrow(
                        title: "\(station.isMVCO ? "MVCO Sensor" : "NOAA Buoy") • \(Int(station.depthMeters)) m deep",
                        systemImage: station.isMVCO ? "antenna.radiowaves.left.and.right" : "dot.radiowaves.left.and.right"
                    )
                }

                if let rows = conditions?.readingRows {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(rows) { row in
                            StatCell(label: row.label, value: row.value)
                        }
                    }
                } else {
                    Text("No readings available.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            StationDetailSheet(station: station, conditions: conditions)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
