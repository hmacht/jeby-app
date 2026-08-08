//
//  UserPost.swift
//  Jeby
//
//  One of your own reports, as served by /users/:user_id/posts. The feed's
//  version carries an author too; here the author is you.
//

import Foundation

struct UserPost: Decodable, Equatable, Identifiable {
    let id: String
    /// The Vineyard-local calendar day the report is filed under, `yyyy-MM-dd`.
    let day: String
    let imageUrl: String
    let caption: String
    /// How bumpy it actually was out there, 0-100.
    let bumpyScore: Int
    /// When it was filed, stamped by the server on insert.
    let createdAt: Date

    var imageURL: URL? { URL(string: imageUrl) }

    /// "Friday, July 4 at 2:30 PM" — the date on the detail sheet.
    var filedAt: String {
        createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute())
    }
}
