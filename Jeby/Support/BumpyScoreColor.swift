//
//  BumpyScoreColor.swift
//  Jeby
//
//  The green→purple gradient used by the BumpyScore bar, plus sampling of a
//  color at a 0–100 position so the marker matches the bar underneath it.
//  Mirrors the SCORE_STOPS gradient in jeby-web.
//

import SwiftUI

enum BumpyScoreColor {
    /// Evenly spaced 0 → 100 gradient stops (green, lime, yellow, orange, red, purple).
    static let stops: [Color] = [
        Color(red: 0.290, green: 0.871, blue: 0.502), // #4ade80
        Color(red: 0.639, green: 0.902, blue: 0.208), // #a3e635
        Color(red: 0.980, green: 0.800, blue: 0.082), // #facc15
        Color(red: 0.984, green: 0.573, blue: 0.235), // #fb923c
        Color(red: 0.937, green: 0.267, blue: 0.267), // #ef4444
        Color(red: 0.659, green: 0.333, blue: 0.969), // #a855f7
    ]

    static var gradient: LinearGradient {
        LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
    }

    /// Sample the gradient color at a given 0–100 position.
    static func color(at percent: Double) -> Color {
        let rgbStops: [(Double, Double, Double)] = [
            (0.290, 0.871, 0.502),
            (0.639, 0.902, 0.208),
            (0.980, 0.800, 0.082),
            (0.984, 0.573, 0.235),
            (0.937, 0.267, 0.267),
            (0.659, 0.333, 0.969),
        ]
        let p = min(100, max(0, percent)) / 100
        let span = 1.0 / Double(rgbStops.count - 1)
        let i = min(rgbStops.count - 2, Int(p / span))
        let t = (p - Double(i) * span) / span
        let a = rgbStops[i]
        let b = rgbStops[i + 1]
        return Color(
            red: a.0 + (b.0 - a.0) * t,
            green: a.1 + (b.1 - a.1) * t,
            blue: a.2 + (b.2 - a.2) * t
        )
    }
}
