//
//  StationDetailSheet.swift
//  Jeby
//
//  Bottom sheet shown when a station marker on the map is tapped: the station's
//  name, location, depth, live readings, and a link out to the source.
//

import SwiftUI

struct StationDetailSheet: View {
    let station: Station
    let conditions: StationConditions?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AsyncImage(url: URL(string: station.profileUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay(ProgressView())
                    }
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            station.isMVCO ? "MVCO Sensor" : "NOAA Buoy",
                            systemImage: station.isMVCO ? "antenna.radiowaves.left.and.right" : "dot.radiowaves.left.and.right"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)

                        Text(station.name)
                            .font(.title3.weight(.semibold))

                        HStack(spacing: 14) {
                            Label(Units.formatCoords(lat: station.lat, long: station.long), systemImage: "mappin.and.ellipse")
                            Label("\(Int(station.depthMeters)) m deep", systemImage: "water.waves")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    readings

                    if let url = URL(string: station.detailsUrl) {
                        Link(destination: url) {
                            Label("View source", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var readings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live readings")
                .font(.headline)

            if let rows = conditions?.readingRows {
                ForEach(rows) { row in
                    HStack {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.value)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    Divider()
                }
            } else {
                Text("No readings available for this station.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
