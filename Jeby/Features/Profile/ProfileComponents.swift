//
//  ProfileComponents.swift
//  Jeby
//
//  The pieces both profile pages render — your own and someone else's.
//

import SwiftUI

/// The pet, riding on the corner of your avatar.
struct PetBadge: View {
    let pet: Pet

    private let size: CGFloat = 34

    var body: some View {
        Group {
            if let imageURL = pet.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(CardStyle.sheetSurface, lineWidth: 3))
        // Sits just off the avatar's edge rather than centered on it.
        .offset(x: 2, y: 2)
        .accessibilityLabel(pet.name)
    }

    private var fallback: some View {
        ZStack {
            CardStyle.gradient(base: .orange)
            Image(systemName: "dog.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

/// The square photo on a boat or pet card.
struct RecordThumbnail: View {
    let imageURL: URL?
    let fallbackIcon: String

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var fallback: some View {
        ZStack {
            Color.black.opacity(0.25)
            Image(systemName: fallbackIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

/// One report in the grid: the photo, with how bumpy it was in the corner.
struct PostTile: View {
    let post: UserPost

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                AsyncImage(url: post.imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    CardStyle.surface
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                Text("\(post.bumpyScore)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    // The score's own color, same gradient as the BumpyScore bar.
                    .background(BumpyScoreColor.color(at: Double(post.bumpyScore)), in: Capsule())
                    .padding(6)
            }
    }
}
