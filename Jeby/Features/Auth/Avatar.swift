//
//  Avatar.swift
//  Jeby
//
//  Someone's picture, wherever it appears — the map's profile button, the
//  profile sheets, and the author on a feed card.
//

import SwiftUI

/// A photo when there is one, initials when there isn't, and a person glyph when
/// Apple's private relay left us with neither.
struct Avatar: View {
    let photoURL: URL?
    /// Up to two letters. Empty falls back to the glyph.
    let initials: String
    var size: CGFloat

    /// The signed-in user.
    init(user: AuthUser, size: CGFloat) {
        self.photoURL = user.photoURL
        self.initials = user.initials
        self.size = size
    }

    /// Anyone else — a feed author, or a profile being viewed.
    init(photoURL: URL?, name: String, size: CGFloat) {
        self.photoURL = photoURL
        self.initials = Self.initials(from: name)
        self.size = size
    }

    var body: some View {
        Group {
            if let photoURL {
                AsyncImage(url: photoURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            CardStyle.gradient(base: .blue)

            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    /// Up to two initials from a display name.
    static func initials(from name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ").prefix(2)
        return parts.compactMap(\.first).map(String.init).joined().uppercased()
    }
}
