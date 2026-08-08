//
//  PublicProfileSheet.swift
//  Jeby
//
//  Someone else's profile, reached by tapping the author of a report. The same
//  layout as your own — boat photo as the banner, avatar hanging over it, boat
//  as running text — minus everything that only makes sense for the owner: no
//  Edit, no settings, no email, no reports grid of their own.
//

import SwiftUI

struct PublicProfileSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let userID: String
    /// What the feed card already knew, so there's something on screen while the
    /// full profile loads.
    let placeholderName: String
    let placeholderPhotoURL: URL?

    @State private var profile: PublicProfile?
    @State private var errorMessage: String?
    /// Their reports: the page the profile carried, plus whatever paging added.
    @State private var posts: [UserPost] = []
    @State private var nextCursor: String?
    @State private var isLoadingMore = false
    /// One of their reports, opened from the grid. Read-only — see PostDetailSheet.
    @State private var selectedPost: UserPost?

    private static let avatarOverhang: CGFloat = 44
    private static let avatarSize: CGFloat = 88

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    banner

                    VStack(alignment: .leading, spacing: 24) {
                        identity
                        reports

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, Self.avatarOverhang + 12)
                    .padding(.bottom, 40)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(CardStyle.sheetSurface)
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .task { await load() }
        .sheet(item: $selectedPost) { post in
            // No onDeleted: someone else's report is readable, not removable.
            PostDetailSheet(post: post)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// Their boat's photo, with their avatar hanging over its bottom-left corner.
    private var banner: some View {
        Group {
            if let imageURL = bannerVessel?.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    bannerPlaceholder
                }
            } else {
                bannerPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        // Clip before the overlay, so the avatar can hang outside the banner.
        .clipped()
        .overlay(alignment: .bottomLeading) {
            Avatar(
                photoURL: profile?.user.photoURL ?? placeholderPhotoURL,
                name: profile?.user.displayName ?? placeholderName,
                size: Self.avatarSize
            )
            .overlay(Circle().stroke(CardStyle.sheetSurface, lineWidth: 4))
            .overlay(alignment: .bottomTrailing) {
                if let pet = profile?.pets.first {
                    PetBadge(pet: pet)
                }
            }
            .padding(.leading, 20)
            .offset(y: Self.avatarOverhang)
        }
    }

    private var bannerPlaceholder: some View {
        ZStack {
            CardStyle.gradient(base: .blue)
            Image(systemName: "sailboat.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(profile?.user.displayName.isEmpty == false
                     ? profile!.user.displayName
                     : placeholderName)
                    .font(.title2.weight(.bold))

                if profile?.user.isVerified == true {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Verified")
                }
            }

            if let petName = profile?.pets.first?.name, !petName.isEmpty {
                Text("First Mate: \(petName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let bio = profile?.user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            boatLines

            if let profile {
                Text(profile.reportCount == 1 ? "1 report" : "\(profile.reportCount) reports")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .padding(.top, 10)
            }
        }
    }

    /// Everything they've filed, same grid as your own profile.
    @ViewBuilder
    private var reports: some View {
        if !posts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Reports", systemImage: "square.stack.3d.up.fill")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(posts) { post in
                        Button {
                            selectedPost = post
                        } label: {
                            PostTile(post: post)
                        }
                        .buttonStyle(.plain)
                        // Fetch the next page a row early.
                        .onAppear {
                            if post.id == posts.dropLast(3).last?.id {
                                Task { await loadMore() }
                            }
                        }
                    }
                }

                if isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        if let page = try? await JebyClient().publicPosts(userID: userID, cursor: cursor) {
            posts.append(contentsOf: page.posts)
            nextCursor = page.nextCursor
        }
        // On failure the cursor stays put, so the next scroll retries.
    }

    /// Their boat as running text. Read-only — there's nothing to tap through to.
    @ViewBuilder
    private var boatLines: some View {
        if let vessels = profile?.vessels, !vessels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(vessels) { vessel in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(vessel.name)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            if !vessel.homeHarbor.isEmpty {
                                Text("·")
                                Text(vessel.homeHarbor)
                            }
                        }

                        if !vessel.specSummary.isEmpty {
                            Text(vessel.specSummary)
                                .monospacedDigit()
                        }

                        if !vessel.description.isEmpty {
                            Text(vessel.description)
                                .lineLimit(2)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 10)
        }
    }

    /// The boat whose photo becomes the banner — the first with a picture.
    private var bannerVessel: UserVessel? {
        guard let vessels = profile?.vessels else { return nil }
        return vessels.first { $0.imageURL != nil } ?? vessels.first
    }

    private func load() async {
        // Public endpoint: the API key alone is enough.
        let client = JebyClient()
        do {
            let loaded = try await client.publicProfile(userID: userID)
            profile = loaded
            posts = loaded.posts
            nextCursor = loaded.nextCursor
        } catch {
            errorMessage = "Couldn't load this profile."
        }
    }
}
