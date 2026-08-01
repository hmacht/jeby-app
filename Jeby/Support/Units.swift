//
//  Units.swift
//  Jeby
//
//  Unit conversions and display formatting for marine data. Mirrors the helpers
//  in jeby-web so the iOS app shows the same imperial numbers.
//

import Foundation

enum Units {
    static func metersToFeet(_ m: Double) -> Double { m * 3.28084 }
    static func mpsToMph(_ ms: Double) -> Double { ms * 2.23694 }
    static func cToF(_ c: Double) -> Double { c * 9 / 5 + 32 }

    /// Format a lat/long as e.g. "41.3250° N, 70.5667° W".
    static func formatCoords(lat: Double, long: Double) -> String {
        let ns = "\(String(format: "%.4f", abs(lat)))° \(lat >= 0 ? "N" : "S")"
        let ew = "\(String(format: "%.4f", abs(long)))° \(long >= 0 ? "E" : "W")"
        return "\(ns), \(ew)"
    }

    /// Turn an average wave height (meters) into a friendly feet range, e.g. "2-3".
    static func seasRange(_ waveHeightMeters: Double?) -> String? {
        guard let waveHeightMeters else { return nil }
        let feet = metersToFeet(waveHeightMeters)
        let lo = max(0, Int(feet.rounded(.down)))
        let hi = Int(feet.rounded(.up))
        return lo == hi ? "\(hi)" : "\(lo)-\(hi)"
    }
}

/// A single labeled reading, formatted for display in imperial units.
struct ReadingRow: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

extension StationConditions {
    /// Display rows (feet / mph / °F / seconds), with an em dash for anything
    /// the sensor didn't report.
    var readingRows: [ReadingRow] {
        func fmt(_ value: Double?, _ convert: (Double) -> Double, _ unit: String, digits: Int = 0) -> String {
            guard let value else { return "—" }
            return "\(String(format: "%.\(digits)f", convert(value))) \(unit)"
        }

        let wind: String
        if let speed = windSpeed.value {
            let cardinal = windDirectionCardinal.map { " \($0)" } ?? ""
            wind = "\(String(format: "%.0f", Units.mpsToMph(speed))) mph\(cardinal)"
        } else {
            wind = "—"
        }

        return [
            ReadingRow(label: "Wave height", value: fmt(waveHeight.value, Units.metersToFeet, "ft", digits: 1)),
            ReadingRow(label: "Wave period", value: wavePeriod.value.map { "\(String(format: "%.0f", $0)) s" } ?? "—"),
            ReadingRow(label: "Wave length", value: fmt(waveLength.value, Units.metersToFeet, "ft")),
            ReadingRow(label: "Wind", value: wind),
            ReadingRow(label: "Water temp", value: fmt(waterTemp.value, Units.cToF, "°F")),
        ]
    }
}
