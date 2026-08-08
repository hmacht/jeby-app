//
//  PublicProfile.swift
//  Jeby
//
//  Someone else's profile, as served by /users/profiles/:user_id — what you get
//  by tapping the author of a report in the feed.
//
//  Deliberately not the same type as `Profile`: no email, and nothing about what
//  their onboarding skipped. Those are the owner's business.
//

import Foundation

struct PublicProfile: Decodable, Equatable {
    let user: PublicUser
    let vessels: [UserVessel]
    let pets: [Pet]
    /// Every report they've filed; `posts` is the first page of them.
    let reportCount: Int
    let posts: [UserPost]
    /// Nil on the last page. Opaque — pass it back as `cursor`.
    let nextCursor: String?
}

/// A page of reports plus the cursor that follows it.
struct PostPage: Decodable, Equatable {
    let posts: [UserPost]
    let nextCursor: String?
}

struct PublicUser: Decodable, Equatable {
    let id: String
    let displayName: String
    let photoUrl: String
    let bio: String
    let isVerified: Bool

    var photoURL: URL? { URL(string: photoUrl) }
}

/// One report in the feed, with whoever filed it.
struct FeedPost: Decodable, Equatable, Identifiable {
    let id: String
    let userId: String
    let day: String
    let imageUrl: String
    let caption: String
    let bumpyScore: Int
    let createdAt: Date
    let author: PostAuthor?

    var imageURL: URL? { URL(string: imageUrl) }

    /// How long ago it was filed — "2h ago", the way a timeline reads.
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: .now)
    }
}

/// The slice of a profile the feed renders, so a card needs no second lookup.
/// Identifiable so tapping one can drive a sheet.
struct PostAuthor: Decodable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let photoUrl: String
    /// Their first boat's length, when they've given one — how bumpy it was
    /// depends a lot on what you were in.
    let boatLengthFt: Double?
    /// Their first mate's name, shown alongside their own.
    let petName: String
    let isVerified: Bool

    var photoURL: URL? { URL(string: photoUrl) }

    /// "21.5 ft", or nil when they haven't said.
    var boatLength: String? {
        boatLengthFt.map { "\(VesselSpec.format($0)) ft" }
    }
}

/// The day's reports from everyone.
struct FeedResponse: Decodable, Equatable {
    let day: String
    let count: Int
    /// Nil on the last page. Opaque — pass it back as `cursor`.
    let nextCursor: String?
    /// What the day's reports average out to. Nil when nobody has posted — an
    /// average of nothing isn't zero, and zero means glassy.
    let averageBumpyScore: Int?
    let posts: [FeedPost]
}
