//
//  ProfileSheet.swift
//  Jeby
//
//  Your profile, laid out like a social profile: your boat's photo as the
//  banner with your avatar hanging over it, then your name, bio and boat as
//  running text, and your reports.
//
//  Your pet is part of who you are here rather than its own section — a badge on
//  your photo and half of your name — so it's edited from the profile sheet too.
//
//  Settings live behind the gear in the top-left rather than at the bottom of
//  the page — see SettingsSheet.
//

import SwiftUI

struct ProfileSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var model = ProfileViewModel()
    /// The open sub-sheet. One enum rather than several `.sheet` modifiers,
    /// because a view only honors one presentation at a time.
    @State private var route: ProfileRoute?

    /// How far the avatar hangs below the banner.
    private static let avatarOverhang: CGFloat = 44
    private static let avatarSize: CGFloat = 88

    /// What the profile page can open on top of itself.
    private enum ProfileRoute: Identifiable {
        case settings
        /// The edit hub — the only way into any of the forms.
        case edit
        /// One of your own reports, opened from the grid.
        case post(UserPost)

        var id: String {
            switch self {
            case .settings: return "settings"
            case .edit: return "edit"
            case .post(let post): return "post-\(post.id)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                switch model.state {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)

                case .failed(let message):
                    failure(message)

                case .loaded(let profile):
                    loaded(profile)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(CardStyle.sheetSurface)
            .ignoresSafeArea(edges: .top)
            .toolbar {
                // Close is top-left on every sheet in the app, so settings takes
                // the other side here.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        route = .settings
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .task { await model.load(auth: auth) }
        .sheet(item: $route) { route in
            switch route {
            case .settings:
                SettingsSheet()
            case .edit:
                EditProfileSheet(
                    currentName: model.displayName ?? auth.user?.displayName ?? "",
                    currentBio: model.bio ?? "",
                    currentPhotoURL: model.photoURL ?? auth.user?.photoURL,
                    currentPet: model.pet,
                    currentVessel: model.bannerVessel
                )
            case .post(let post):
                PostDetailSheet(post: post) {
                    Task { await model.load(auth: auth) }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: route?.id) { _, id in
            // Any sub-sheet closing can have changed the profile — a saved edit,
            // a delete, or a finished onboarding step — so re-read it.
            if id == nil {
                Task { await model.load(auth: auth) }
            }
        }
        // Signing out drops the sheet's reason to exist.
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if !isSignedIn { dismiss() }
        }
    }

    // MARK: - Page

    private func loaded(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            banner

            // The Edit button sits beside the hanging avatar, so this row starts
            // right below the banner rather than below the avatar.
            HStack {
                Spacer()
                Button("Edit profile") { route = .edit }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 24) {
                identity(profile)
                reports
            }
            .padding(.horizontal, 20)
            // The Edit button row above already clears the hanging avatar, so
            // this only needs to keep the name off its bottom edge.
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    /// The boat's photo, with the avatar hanging over its bottom-left corner.
    private var banner: some View {
        Group {
            if let imageURL = model.bannerVessel?.imageURL {
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
            if let user = auth.user {
                Avatar(user: user, size: Self.avatarSize)
                    .overlay(Circle().stroke(CardStyle.sheetSurface, lineWidth: 4))
                    // The pet rides on the corner of your picture, the way it
                    // rides on the boat.
                    .overlay(alignment: .bottomTrailing) {
                        if let pet = model.pet {
                            PetBadge(pet: pet)
                        }
                    }
                    .padding(.leading, 20)
                    .offset(y: Self.avatarOverhang)
            }
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

    private var nameLine: String {
        model.displayName ?? auth.user?.displayName ?? "Signed in"
    }

    private func identity(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                // Apple lets people hide their name, so this isn't guaranteed.
                Text(nameLine)
                    .font(.title2.weight(.bold))

                if model.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Verified")
                }
            }

            // The email lives in Settings; this line is for the first mate. Only
            // shown when there is one — an empty label reads as missing data.
            if let petName = model.pet?.name, !petName.isEmpty {
                Text("First Mate: \(petName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let bio = model.bio {
                Text(bio)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            boatLines(profile.vessels)

            // Under the boat, where the rest of the standing detail sits.
            Text(model.reportCount == 1 ? "1 report" : "\(model.reportCount) reports")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .padding(.top, 10)
        }
    }

    /// The boat as plain metadata under the bio, the way a social profile shows
    /// a location and a join date. Read-only: editing lives in the hub behind
    /// "Edit profile", which is the only way into any of the forms.
    @ViewBuilder
    private func boatLines(_ vessels: [UserVessel]) -> some View {
        if !vessels.isEmpty {
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

    // MARK: - Reports

    private var reports: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Reports", systemImage: "square.stack.3d.up.fill")

            if model.posts.isEmpty {
                Text("Nothing posted yet. Tap the camera to share what it's like out there.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 18))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(model.posts) { post in
                        Button {
                            route = .post(post)
                        } label: {
                            PostTile(post: post)
                        }
                        .buttonStyle(.plain)
                        // Fetch the next page a row early, so the grid is longer
                        // by the time the bottom arrives.
                        .onAppear {
                            if post.id == model.posts.dropLast(3).last?.id {
                                Task { await model.loadMorePosts(auth: auth) }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Failure

    private func failure(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try again") {
                Task { await model.load(auth: auth) }
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 80)
    }
}

// MARK: - Cards
