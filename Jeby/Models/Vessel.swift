//
//  Vessel.swift
//  Jeby
//
//  A boat in the registry, as served by /vessels. Specs are free-form strings
//  because craft categories are ranges ("26-65 ft") and some specs are unknown.
//

import Foundation

struct Vessel: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let description: String
    let weight: String
    let length: String
    let horsepower: String
    let maxPassengers: String

    var id: String { code }

    /// Whether this vessel is the Island Queen.
    var isIslandQueen: Bool { code == "IQ" }
}
