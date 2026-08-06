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
    let completeness: Completeness
}

struct ProfileUser: Decodable, Equatable {
    let id: String
    let email: String
    let displayName: String
    let photoUrl: String

    var photoURL: URL? { URL(string: photoUrl) }
}

/// A boat the user saved. Same free-form specs as the built-in registry, plus
/// the photo taken during onboarding.
struct UserVessel: Decodable, Equatable, Identifiable {
    let id: String
    let code: String
    let name: String
    let description: String
    let imageUrl: String
    let weight: String
    let length: String
    let horsepower: String
    let maxPassengers: String

    var imageURL: URL? { URL(string: imageUrl) }
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
        case .pet: return "pawprint.fill"
        }
    }
}
