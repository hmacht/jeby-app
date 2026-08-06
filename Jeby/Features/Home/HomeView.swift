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
    @Environment(AuthService.self) private var auth

    @State private var model = HomeViewModel()
    @State private var camera: MapCameraPosition = .region(HomeView.vineyardRegion)
    @State private var selectedStation: Station?
    @State private var detent: PresentationDetent = HomeView.collapsedDetent
    @State private var isRefreshing = false
    /// The open account sheet, if any. Owned here because both the profile
    /// button on the map and the camera button down in the sheet set it.
    @State private var authRoute: AuthRoute?

    /// The resting height of the sheet, showing the top half of the map.
    static let collapsedDetent: PresentationDetent = .fraction(0.5)

    /// Martha's Vineyard Sound, framed to show both stations with padding and
    /// centered south of them so they sit above the sheet.
    static let vineyardRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.27, longitude: -70.42),
        span: MKCoordinateSpan(latitudeDelta: 0.62, longitudeDelta: 0.62)
    )

    var body: some View {
        // The button sits in the ZStack, not on the map, so only the map runs
        // under the status bar.
        ZStack(alignment: .topTrailing) {
            map
            VStack(spacing: 10) {
                profileButton
                refreshButton
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .task {
            if model.state == .idle { await model.load() }
        }
        // Signing in closes the gate. A brand-new account continues into
        // onboarding instead of dropping the user back on the map.
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            guard isSignedIn else { return }

            let startOnboarding = auth.needsOnboarding
            auth.onboardingHandled()
            authRoute = nil
            guard startOnboarding else { return }

            Task {
                // Let the Get Started sheet finish dismissing first: swapping a
                // presented sheet's item in the same tick can drop the new one.
                try? await Task.sleep(for: .milliseconds(450))
                authRoute = .onboarding
            }
        }
    }

    private var map: some View {
        Map(position: $camera) {
            ForEach(model.stations) { station in
                let feet = model.waveHeightFeet(for: station.code)
                let coord = CLLocationCoordinate2D(latitude: station.lat, longitude: station.long)
                Annotation(station.name, coordinate: coord) {
                    StationPin(
                        isMVCO: station.isMVCO,
                        waveText: SeaState.label(forFeet: feet),
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
            SheetRootView(
                model: model,
                isCollapsed: detent == Self.collapsedDetent,
                authRoute: $authRoute
            ) {
                detent = Self.collapsedDetent
            }
                .presentationDetents([Self.collapsedDetent, .large], selection: $detent)
                // Apple Maps behavior: a swipe up on the card raises the sheet
                // over the map first, and only scrolls once it's expanded.
                .presentationContentInteraction(.resizes)
                .presentationBackgroundInteraction(.enabled(upThrough: Self.collapsedDetent))
                .presentationBackground(CardStyle.sheetSurface)
                .presentationDragIndicator(.hidden)
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
    }

    /// Your account: opens the profile when signed in, the Get Started card when
    /// not. Shows your Apple photo or initials so it's obvious which it'll be.
    private var profileButton: some View {
        Button {
            authRoute = auth.isSignedIn ? .profile : .getStarted
        } label: {
            Group {
                if let user = auth.user {
                    Avatar(user: user, size: 32)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 40, height: 40)
            .glassCircle()
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(auth.isSignedIn ? "Profile" : "Sign in")
    }

    /// Manual re-pull of everything — pins, readings, report — for when the
    /// ten-minute auto-refresh isn't soon enough.
    private var refreshButton: some View {
        Button {
            guard !isRefreshing else { return }
            Task {
                isRefreshing = true
                await model.refresh()
                isRefreshing = false
            }
        } label: {
            Group {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.primary)
            .frame(width: 40, height: 40)
            .glassCircle()
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .accessibilityLabel("Refresh conditions")
    }
}

/// A tappable map marker showing a station's live wave height, tinted by sea
/// state and enlarged when selected.
private struct StationPin: View {
    let isMVCO: Bool
    let waveText: String
    let isSelected: Bool

    /// Same tint and wash as the station's passport card in the sheet.
    private var tint: Color { CardStyle.tint(isMVCO: isMVCO) }

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
        .background(CardStyle.gradient(base: tint), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .scaleEffect(isSelected ? 1.15 : 1)
        .animation(.snappy, value: isSelected)
    }
}

private extension View {
    /// Liquid Glass where the OS has it, frosted material on older systems.
    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Circle())
        } else {
            background(.ultraThinMaterial, in: Circle())
        }
    }
}

#Preview {
    HomeView()
        .environment(AuthService())
}
