//
//  Avatar.swift
//  Jeby
//
//  The user's picture, wherever it appears — the map's profile button and the
//  profile sheet.
//

import SwiftUI

/// The user's photo when there is one, their initials when there isn't, and a
/// person glyph when Apple's private relay left us with neither.
struct Avatar: View {
    let user: AuthUser
    var size: CGFloat

    var body: some View {
        Group {
            if let photoURL = user.photoURL {
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

            if user.initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(user.initials)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
