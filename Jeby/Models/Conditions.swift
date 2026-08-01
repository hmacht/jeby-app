//
//  Conditions.swift
//  Jeby
//
//  The full conditions payload for one vessel: the vessel it's for, that
//  vessel's BumpyScore, and the ocean readings from each station we pull.
//

import Foundation

struct Conditions: Decodable, Hashable {
    let vessel: Vessel
    let bumpyScore: BumpyScore
    let mvco: StationConditions
    let buoy: StationConditions
}

struct BumpyScore: Decodable, Hashable {
    /// 0–100, or nil when not yet computed / during quiet hours.
    let score: Int?
    let disclaimers: [String]
    let analysis: String?
}

/// The ocean readings from a single station (the MVCO sensor or the NOAA buoy).
struct StationConditions: Decodable, Hashable {
    let waveHeight: Reading
    let wavePeriod: Reading
    let waveLength: Reading
    let windSpeed: Reading
    let windDirectionDegrees: Reading
    let windDirectionCardinal: String?
    let waterTemp: Reading
}

extension Conditions {
    /// The readings for a station: the MVCO sensor, or the NOAA buoy otherwise.
    func station(for code: String) -> StationConditions {
        code == StationCode.mvco ? mvco : buoy
    }
}

/// A flat, station-merged view of the readings for display. Each field prefers
/// the NOAA buoy and falls back to the MVCO sensor so a gap in one source still
/// shows a number.
struct Readings {
    let waveHeight: Double?       // meters
    let wavePeriod: Double?       // seconds
    let waveLength: Double?       // meters
    let windSpeed: Double?        // m/s
    let windDirectionDegrees: Double?
    let windDirectionCardinal: String?
    let waterTemp: Double?        // °C

    /// Flatten the two stations into one set of readings, preferring the buoy
    /// and falling back to MVCO for each field independently.
    init(_ conditions: Conditions?) {
        let buoy = conditions?.buoy
        let mvco = conditions?.mvco
        func pick(_ keyPath: KeyPath<StationConditions, Reading>) -> Double? {
            buoy?[keyPath: keyPath].value ?? mvco?[keyPath: keyPath].value
        }

        waveHeight = pick(\.waveHeight)
        wavePeriod = pick(\.wavePeriod)
        waveLength = pick(\.waveLength)
        windSpeed = pick(\.windSpeed)
        windDirectionDegrees = pick(\.windDirectionDegrees)
        windDirectionCardinal = buoy?.windDirectionCardinal ?? mvco?.windDirectionCardinal
        waterTemp = pick(\.waterTemp)
    }
}
