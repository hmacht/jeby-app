//
//  SeaState.swift
//  Jeby
//
//  Maps a wave height (in feet) to a color, label, and map-overlay radius so the
//  station markers and their shaded zones read at a glance: calm greens through
//  rough reds.
//

import SwiftUI

enum SeaState {
    /// Calm → rough color ramp keyed off wave height in feet.
    static func color(forFeet feet: Double?) -> Color {
        guard let feet else { return .gray }
        switch feet {
        case ..<1: return .green
        case 1..<2: return .mint
        case 2..<3: return .yellow
        case 3..<4: return .orange
        default: return .red
        }
    }

    /// Short display label, e.g. "2.3 ft", or an em dash when unavailable.
    static func label(forFeet feet: Double?) -> String {
        guard let feet else { return "—" }
        return String(format: "%.1f ft", feet)
    }

    /// Radius (meters) of the shaded zone around a station — larger seas, larger zone.
    static func radiusMeters(forFeet feet: Double?) -> Double {
        let f = feet ?? 1
        return max(1500, min(5000, 1500 + f * 900))
    }
}
