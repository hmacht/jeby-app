//
//  Station.swift
//  Jeby
//
//  A data source we pull readings from, as served by /stations. Lat/long place
//  it on the map; the URLs link out to the source.
//

import Foundation

struct Station: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let lat: Double
    let long: Double
    let depthMeters: Double
    /// Latest frame from the station's camera (buoy cam / ASIT tower cam).
    let liveImageUrl: String?
    let profileUrl: String
    let detailsUrl: String

    var id: String { code }

    /// Whether this station is the MVCO sensor (vs. the NOAA buoy).
    var isMVCO: Bool { code == StationCode.mvco }
}

/// Station codes from the /stations registry. Centralized so a code change only
/// has to happen here rather than across the UI.
enum StationCode {
    static let mvco = "MVCO"
    static let buoy = "44020"
}
