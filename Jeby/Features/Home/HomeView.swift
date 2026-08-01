//
//  HomeView.swift
//  Jeby
//
//  The Home tab: an Apple Maps background centered on Martha's Vineyard with a
//  marker for each station, and the live marine conditions in a draggable card
//  that scrolls up over the map. Tapping a station marker opens a detail sheet.
//

import MapKit
import SwiftUI

struct HomeView: View {
    @State private var model = HomeViewModel()
    @State private var camera: MapCameraPosition = .region(HomeView.vineyardRegion)
    @State private var selectedStation: Station?

    /// Martha's Vineyard Sound, framed to show both stations with padding.
    static let vineyardRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.405, longitude: -70.42),
        span: MKCoordinateSpan(latitudeDelta: 0.62, longitudeDelta: 0.62)
    )

    var body: some View {
        Map(position: $camera) {
            ForEach(model.stations) { station in
                let feet = model.waveHeightFeet(for: station.code)
                let coord = CLLocationCoordinate2D(latitude: station.lat, longitude: station.long)
                let tint = SeaState.color(forFeet: feet)

                Annotation(station.name, coordinate: coord) {
                    StationPin(
                        isMVCO: station.isMVCO,
                        waveText: SeaState.label(forFeet: feet),
                        tint: tint,
                        isSelected: selectedStation?.id == station.id
                    )
                    .onTapGesture { selectedStation = station }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: .constant(true)) {
            HomeContentCard(model: model)
                .presentationDetents([.fraction(0.5), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
                .presentationBackground(.regularMaterial)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .sheet(item: $selectedStation) { station in
                    StationDetailSheet(
                        station: station,
                        conditions: model.conditions?.station(for: station.code)
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
        }
        .task {
            if model.state == .idle { await model.load() }
        }
    }
}

/// A tappable map marker showing a station's live wave height, tinted by sea
/// state and enlarged when selected.
private struct StationPin: View {
    let isMVCO: Bool
    let waveText: String
    let tint: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isMVCO ? "antenna.radiowaves.left.and.right" : "dot.radiowaves.left.and.right")
                .font(.system(size: 12, weight: .bold))
            Text(waveText)
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.gradient, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .scaleEffect(isSelected ? 1.15 : 1)
        .animation(.snappy, value: isSelected)
    }
}

#Preview {
    HomeView()
}
