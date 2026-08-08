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
                VStack(alignment: .leading, spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: 20) {
                        identity

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
            }
            .navigationTitle("Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Edge-to-edge live camera frame across the top of the sheet, falling back
    /// to the station's profile photo when it has no camera. The buoy cam is a
    /// 9.6:1 stitched 360° panorama, so it gets zoomed and panned instead of
    /// squashed into a strip; everything else keeps its own aspect ratio.
    @ViewBuilder
    private var header: some View {
        let source = station.liveImageUrl ?? station.profileUrl

        if station.code == StationCode.buoy, station.liveImageUrl != nil {
            PanoramaHeader(urlString: source)
        } else {
            image(at: source, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 220)
                .clipped()
        }
    }

    /// Profile-style row: circular photo, then the station's name and details.
    private var identity: some View {
        HStack(spacing: 14) {
            image(at: station.profileUrl)
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Label(
                    station.isMVCO ? "MVCO Sensor" : "NOAA Buoy",
                    systemImage: station.isMVCO ? "antenna.radiowaves.left.and.right" : "dot.radiowaves.left.and.right"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(CardStyle.tint(isMVCO: station.isMVCO))

                Text(station.name)
                    .font(.title3.weight(.semibold))

                HStack(spacing: 14) {
                    Label(Units.formatCoords(lat: station.lat, long: station.long), systemImage: "mappin.and.ellipse")
                    Label("\(Int(station.depthMeters)) m deep", systemImage: "water.waves")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func image(at urlString: String, contentMode: ContentMode = .fill) -> some View {
        AsyncImage(url: URL(string: urlString)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .overlay(ProgressView())
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

/// The buoy cam's 360° panorama, zoomed to the header's height so it can be
/// panned side to side, with a slim indicator showing where you are in the sweep.
private struct PanoramaHeader: View {
    let urlString: String

    private let height: CGFloat = 200

    @State private var metrics = ScrollMetrics()

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                AsyncImage(url: URL(string: urlString)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: height)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 400, height: height)
                        .overlay(ProgressView())
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: height)
            .trackingHorizontalScroll($metrics)

            HorizontalScrollIndicator(metrics: metrics)
        }
        .padding(.bottom, 4)
    }
}
