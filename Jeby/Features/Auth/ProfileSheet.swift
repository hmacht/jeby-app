//
//  ProfileSheet.swift
//  Jeby
//
//  Who you are, your boats, your first mate — and, when onboarding was skipped,
//  exactly what's still missing and a way back into that step.
//

import SwiftUI

struct ProfileSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var model = ProfileViewModel()
    /// The open sub-sheet. One enum rather than several `.sheet` modifiers,
    /// because a view only honors one presentation at a time.
    @State private var route: ProfileRoute?

    /// What the profile page can open on top of itself.
    private enum ProfileRoute: Identifiable {
        /// An onboarding step, resumed from the incomplete card.
        case resume(OnboardingStep)
        case editProfile
        case editVessel(UserVessel)
        case editPet(Pet)

        var id: String {
            switch self {
            case .resume(let step): return "resume-\(step.rawValue)"
            case .editProfile: return "profile"
            case .editVessel(let vessel): return "vessel-\(vessel.id)"
            case .editPet(let pet): return "pet-\(pet.id)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    identity

                    switch model.state {
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)

                    case .failed(let message):
                        failure(message)

                    case .loaded(let profile):
                        if !profile.completeness.isComplete {
                            IncompleteProfileCard(pieces: profile.completeness.pieces) { piece in
                                route = .resume(OnboardingStep(piece: piece))
                            }
                        }
                        boats(profile.vessels)
                        pets(profile.pets)

                    case .idle:
                        EmptyView()
                    }

                    signOutButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(CardStyle.sheetSurface)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await model.load(auth: auth) }
        .sheet(item: $route) { route in
            switch route {
            case .resume(let step):
                // Single-step: finishing the piece they tapped returns here
                // rather than walking the rest of the flow.
                OnboardingFlow(startingStep: step, singleStep: true)
            case .editProfile:
                EditProfileSheet(
                    currentName: model.displayName ?? auth.user?.displayName ?? "",
                    currentPhotoURL: model.photoURL ?? auth.user?.photoURL
                )
            case .editVessel(let vessel):
                EditVesselSheet(vessel: vessel)
            case .editPet(let pet):
                EditPetSheet(pet: pet)
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

    @ViewBuilder
    private var identity: some View {
        if let user = auth.user {
            VStack(spacing: 12) {
                Avatar(user: user, size: 84)

                VStack(spacing: 4) {
                    // Apple lets people hide their name, and their email can be
                    // a private relay address — so neither is guaranteed.
                    Text(model.displayName ?? user.displayName ?? "Signed in")
                        .font(.title3.weight(.semibold))

                    if let email = user.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .topTrailing) {
                Button("Edit") { route = .editProfile }
                    .font(.subheadline.weight(.semibold))
                    .padding(16)
            }
        }
    }

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
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private func boats(_ vessels: [UserVessel]) -> some View {
        if !vessels.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Boats", systemImage: "sailboat.fill")

                VStack(spacing: 10) {
                    ForEach(vessels) { vessel in
                        Button {
                            route = .editVessel(vessel)
                        } label: {
                            RecordRow(
                                imageURL: vessel.imageURL,
                                fallbackIcon: "sailboat.fill",
                                title: vessel.name,
                                subtitle: vessel.summary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pets(_ pets: [Pet]) -> some View {
        if !pets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "First mate", systemImage: "pawprint.fill")

                VStack(spacing: 10) {
                    ForEach(pets) { pet in
                        Button {
                            route = .editPet(pet)
                        } label: {
                            RecordRow(
                                imageURL: pet.imageURL,
                                fallbackIcon: "pawprint.fill",
                                title: pet.name,
                                subtitle: nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            auth.signOut()
        } label: {
            Text("Sign out")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}

/// The nag: one row per thing onboarding skipped, each a way back into that step.
struct IncompleteProfileCard: View {
    let pieces: [ProfilePiece]
    var onTap: (ProfilePiece) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Finish your profile")
                        .font(.subheadline.weight(.bold))
                    Text("\(pieces.count) thing\(pieces.count == 1 ? "" : "s") left")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(pieces) { piece in
                    Button {
                        onTap(piece)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: piece.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(piece.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(piece.detail)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if piece != pieces.last {
                        Divider().overlay(.white.opacity(0.15))
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardStyle.gradient(base: .orange))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

/// A saved boat or pet: its photo, name, and a line of detail.
private struct RecordRow: View {
    let imageURL: URL?
    let fallbackIcon: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        icon
                    }
                } else {
                    icon
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var icon: some View {
        ZStack {
            Color.black.opacity(0.25)
            Image(systemName: fallbackIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private extension UserVessel {
    /// The specs that are actually filled in, joined into one line.
    var summary: String {
        [length, weight, horsepower]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            ProfileSheet()
                .environment(AuthService())
                .presentationDetents([.large])
        }
        .preferredColorScheme(.dark)
}
