//
//  Forecast.swift
//  Jeby
//
//  Marine forecast, alerts, and live image payloads from the jeby-go backend.
//

import Foundation

struct ForecastSummary: Decodable, Hashable {
    let periods: [ForecastPeriod]
    let full: String
}

struct ForecastPeriod: Decodable, Hashable, Identifiable {
    let header: String
    let text: String

    var id: String { header }
}

struct Alert: Decodable, Hashable, Identifiable {
    let event: String
    let description: String
    let severity: String

    var id: String { event + description }

    /// Map NOAA severity strings onto our banner levels.
    var level: AlertLevel {
        switch severity {
        case "Extreme", "Severe": return .danger
        case "Moderate": return .warning
        default: return .info
        }
    }
}

enum AlertLevel {
    case info, warning, danger
}

struct Images: Decodable, Hashable {
    let buoy360: String?
    let asitcam2: String
}
