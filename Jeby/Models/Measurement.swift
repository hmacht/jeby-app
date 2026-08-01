//
//  Measurement.swift
//  Jeby
//
//  A numeric reading paired with its unit, mirroring the jeby-go `Measurement`
//  type. `value` is nil when the sensor didn't report; `unit` is always set
//  since it's a property of the field, not the reading.
//

import Foundation

struct Reading: Decodable, Hashable {
    let value: Double?
    let unit: String
}
