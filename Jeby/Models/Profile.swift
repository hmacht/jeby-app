//
//  Profile.swift
//  Jeby
//
//  The signed-in user's own record, as served by /users/:user_id/profile —
//  who they are, their boats, their pet, and whatever onboarding still needs.
//
//  `createdAt` is deliberately absent from these types: Go emits timestamps with
//  fractional seconds, which JSONDecoder's .iso8601 strategy rejects, and no
//  screen shows them.
//

import Foundation

struct Profile: Decodable, Equatable {
    let user: ProfileUser
    let vessels: [UserVessel]
    let pets: [Pet]
    /// Every report they've ever filed, not just today's.
    let reportCount: Int
    let completeness: Completeness
}

struct ProfileUser: Decodable, Equatable {
    let id: String
    let email: String
    let displayName: String
    let photoUrl: String
    /// A line about the skipper. Optional, and not part of completeness —
    /// onboarding never asks for it.
    let bio: String
    /// Earned by filing enough reports, or granted by hand. The backend owns the
    /// rule; this is just the answer.
    let isVerified: Bool

    var photoURL: URL? { URL(string: photoUrl) }
}

/// A boat the user owns — their own record, not an entry in the built-in
/// registry.
///
/// The registry's `Vessel` keeps specs as free-form strings because its entries
/// are size classes ("26-65 ft"). A boat someone actually owns has one length,
/// so these are numbers, each in a fixed unit named by the field. All optional:
/// onboarding lets you skip them and owners often don't know their weight.
struct UserVessel: Decodable, Equatable, Identifiable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String
    /// Where she's kept — "Oak Bluffs, MA". Free text.
    let homeHarbor: String
    let lengthFt: Double?
    let weightLb: Double?
    let horsepower: Double?
    let maxPassengers: Int?

    var imageURL: URL? { URL(string: imageUrl) }

    /// The specs that are filled in, formatted with their units, joined into one
    /// line: "21.5 ft · 3,150 lb · 150 hp · 8 aboard".
    var specSummary: String {
        [
            lengthFt.map { "\(VesselSpec.format($0)) ft" },
            weightLb.map { "\(VesselSpec.format($0)) lb" },
            horsepower.map { "\(VesselSpec.format($0)) hp" },
            maxPassengers.map { "\($0) aboard" },
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }
}

/// Formatting and parsing for the numeric boat specs, so the edit form and the
/// profile row agree on what "21.5" looks like.
enum VesselSpec {
    /// Drops a pointless trailing ".0" and groups thousands — 21.5 and 3,150.
    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: value as NSNumber) ?? String(value)
    }

    /// A form field's text as a number. Empty means the user cleared it, so nil
    /// covers both "blank" and "nonsense" — the field is optional either way.
    /// Grouping separators are stripped so a pasted "3,150" still parses.
    static func parse(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    /// The same, for the passenger count.
    static func parseCount(_ text: String) -> Int? {
        guard let value = parse(text) else { return nil }
        return Int(value)
    }

    /// Fills an edit form's field from a stored value.
    static func text(_ value: Double?) -> String {
        value.map(format) ?? ""
    }

    static func text(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }
}

/// The sailor's pet — a name and a photo.
struct Pet: Decodable, Equatable, Identifiable {
    let id: String
    let name: String
    let imageUrl: String

    var imageURL: URL? { URL(string: imageUrl) }
}

/// What onboarding still needs. Every step is skippable, so this is what the
/// profile page reads to decide whether to show the incomplete state.
struct Completeness: Decodable, Equatable {
    let isComplete: Bool
    /// Decoded as raw strings so a piece added server-side later can't break
    /// decoding on an older build; unknown values are dropped by `pieces`.
    let missing: [String]

    var pieces: [ProfilePiece] { missing.compactMap(ProfilePiece.init(rawValue:)) }
}

/// One thing a complete profile needs. Raw values match the backend's
/// MissingName/MissingPhoto/MissingBoat/MissingPet constants.
enum ProfilePiece: String, CaseIterable, Identifiable {
    case name
    case photo
    case boat
    case pet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "Your name"
        case .photo: return "Profile photo"
        case .boat: return "Your boat"
        case .pet: return "Your first mate"
        }
    }

    var detail: String {
        switch self {
        case .name: return "So people know who's reporting."
        case .photo: return "Put a face to your reports."
        case .boat: return "Add a boat with a photo and its specs."
        case .pet: return "Every sailor needs a first mate."
        }
    }

    var icon: String {
        switch self {
        case .name: return "person.text.rectangle"
        case .photo: return "person.crop.circle"
        case .boat: return "sailboat.fill"
        case .pet: return "dog.fill"
        }
    }
}
