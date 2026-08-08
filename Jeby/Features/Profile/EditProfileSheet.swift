//
//  EditProfileSheet.swift
//  Jeby
//
//  The one place to edit your profile: you, your first mate, and your boat, all
//  on a single page. Everything the onboarding flow collects can be changed here
//  and nowhere else, so there's a single answer to "where do I fix this?".
//
//  Nothing is written until Save, so backing out with the X changes nothing.
//  The pet and boat sections create-or-update: onboarding is skippable, so
//  someone can arrive here without either.
//

import SwiftUI

struct EditProfileSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let currentName: String
    let currentBio: String
    let currentPhotoURL: URL?
    let currentPet: Pet?
    let currentVessel: UserVessel?

    // You
    @State private var name: String
    @State private var bio: String
    @State private var image: UIImage?

    // First mate
    @State private var petName: String
    @State private var petImage: UIImage?

    // Boat
    @State private var boatName: String
    @State private var boatDescription: String
    @State private var homeHarbor: String
    @State private var length: String
    @State private var weight: String
    @State private var horsepower: String
    @State private var maxPassengers: String
    @State private var boatImage: UIImage?

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var confirmingRemoval: Removal?
    /// Set when Save is blocked by something the user can fix here.
    @State private var issue: FieldIssue?

    /// A delete the user has asked to confirm. Applied immediately, unlike the
    /// text fields — removing a record isn't a draft edit.
    private enum Removal: String, Identifiable {
        case pet, boat
        var id: String { rawValue }
    }

    /// Something entered that can't be saved as it stands.
    private enum FieldIssue: Equatable {
        case petNeedsName
        case boatNeedsName

        var message: String {
            switch self {
            case .petNeedsName:
                return "Give your first mate a name — a photo on its own can't be saved."
            case .boatNeedsName:
                return "Give your boat a name — her photo and specs can't be saved without one."
            }
        }
    }

    init(currentName: String, currentBio: String, currentPhotoURL: URL?, currentPet: Pet?, currentVessel: UserVessel?) {
        self.currentName = currentName
        self.currentBio = currentBio
        self.currentPhotoURL = currentPhotoURL
        self.currentPet = currentPet
        self.currentVessel = currentVessel

        _name = State(initialValue: currentName)
        _bio = State(initialValue: currentBio)
        _petName = State(initialValue: currentPet?.name ?? "")
        _boatName = State(initialValue: currentVessel?.name ?? "")
        _boatDescription = State(initialValue: currentVessel?.description ?? "")
        _homeHarbor = State(initialValue: currentVessel?.homeHarbor ?? "")
        _length = State(initialValue: VesselSpec.text(currentVessel?.lengthFt))
        _weight = State(initialValue: VesselSpec.text(currentVessel?.weightLb))
        _horsepower = State(initialValue: VesselSpec.text(currentVessel?.horsepower))
        _maxPassengers = State(initialValue: VesselSpec.text(currentVessel?.maxPassengers))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    photos

                    SectionGap()
                    youSection

                    SectionGap()
                    petSection

                    SectionGap()
                    boatSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CardStyle.sheetSurface)
            // Typing the missing name clears the complaint as they go, rather
            // than making them hit Save again to find out it's fixed.
            .onChange(of: petName) { _, _ in clearIssue(.petNeedsName) }
            .onChange(of: boatName) { _, _ in clearIssue(.boatNeedsName) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .disabled(isSaving)
                    .accessibilityLabel("Close")
                }
                // In the bar rather than the content, so it shares the line with
                // the close and save buttons.
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Jeby Profile")
                            .font(.headline)
                    }
                    .foregroundStyle(.primary)
                }
                PrimaryToolbarButton("Save", isBusy: isSaving) {
                    Task { await save() }
                }
            }
        }
        // A half-finished upload shouldn't be swipeable out from under itself.
        .interactiveDismissDisabled(isSaving)
        .confirmationDialog(
            "This can't be undone.",
            isPresented: Binding(get: { confirmingRemoval != nil }, set: { if !$0 { confirmingRemoval = nil } }),
            titleVisibility: .visible
        ) {
            if let confirmingRemoval {
                Button(confirmingRemoval == .pet ? "Remove first mate" : "Delete boat", role: .destructive) {
                    Task { await remove(confirmingRemoval) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Photos

    /// You and your first mate, side by side — the pet rides on your profile, so
    /// the two pictures belong together.
    private var photos: some View {
        HStack(alignment: .top, spacing: 28) {
            photoPicker(
                image: $image,
                existing: currentPhotoURL,
                icon: "person.crop.circle.badge.plus",
                caption: "You"
            )
            photoPicker(
                image: $petImage,
                existing: currentPet?.imageURL,
                icon: "dog.fill",
                caption: petName.isEmpty ? "First mate" : petName
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func photoPicker(image: Binding<UIImage?>, existing: URL?, icon: String, caption: String) -> some View {
        VStack(spacing: 8) {
            PhotoPickerButton(
                image: image,
                icon: icon,
                prompt: "Add",
                size: 96,
                existingImageURL: existing
            )
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Sections

    private var youSection: some View {
        VStack(spacing: 0) {
            EditRow(label: "Name") {
                TextField("Skipper", text: $name)
            }
            RowDivider()
            EditRow(label: "Bio") {
                TextField("Been running the Sound since '98", text: $bio, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }

    private var petSection: some View {
        VStack(spacing: 0) {
            EditRow(label: "First mate") {
                TextField("Baxter", text: $petName)
            }

            issueMessage(for: .petNeedsName)

            if currentPet != nil {
                RowDivider()
                DestructiveRow(title: "Remove first mate") { confirmingRemoval = .pet }
            }
        }
    }

    /// The complaint sits under the section it's about, not at the foot of the
    /// page — otherwise "give it a name" doesn't say which name.
    @ViewBuilder
    private func issueMessage(for candidate: FieldIssue) -> some View {
        if issue == candidate {
            Text(candidate.message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private var boatSection: some View {
        VStack(spacing: 0) {
            EditRow(label: "Boat") {
                TextField("Jeby", text: $boatName)
            }
            RowDivider()
            EditRow(label: "Description") {
                TextField("Grady White Freedom 215", text: $boatDescription)
            }
            RowDivider()
            EditRow(label: "Harbor") {
                TextField("Oak Bluffs, MA", text: $homeHarbor)
            }
            RowDivider()
            EditRow(label: "Length", unit: "ft") {
                TextField("21.5", text: $length).keyboardType(.decimalPad)
            }
            RowDivider()
            EditRow(label: "Weight", unit: "lb") {
                TextField("3,150", text: $weight).keyboardType(.decimalPad)
            }
            RowDivider()
            EditRow(label: "Power", unit: "hp") {
                TextField("150", text: $horsepower).keyboardType(.decimalPad)
            }
            RowDivider()
            EditRow(label: "Aboard") {
                TextField("8", text: $maxPassengers).keyboardType(.numberPad)
            }
            RowDivider()
            EditRow(label: "Photo") {
                PhotoPickerButton(
                    image: $boatImage,
                    icon: "sailboat.fill",
                    prompt: "Add",
                    style: .card,
                    size: 72,
                    existingImageURL: currentVessel?.imageURL
                )
            }

            issueMessage(for: .boatNeedsName)

            if currentVessel != nil {
                RowDivider()
                DestructiveRow(title: "Delete boat") { confirmingRemoval = .boat }
            }
        }
    }

    // MARK: - Saving

    private func save() async {
        guard let userID = auth.user?.id else {
            errorMessage = "You're not signed in anymore. Try again."
            return
        }

        // Before anything uploads: a photo for a nameless pet would otherwise be
        // pushed to Storage and then silently dropped, since the record can't be
        // created without a name.
        if let found = validate() {
            withAnimation(.snappy) { issue = found }
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            try await saveProfile(userID: userID, client: client)
            try await savePet(userID: userID, client: client)
            try await saveBoat(userID: userID, client: client)
            dismiss()
        } catch {
            errorMessage = "That didn't save. Check your connection and try again."
        }
    }

    /// What's stopping the save, if anything. Both records are name-keyed: the
    /// backend requires one, so anything else entered for a nameless pet or boat
    /// has nowhere to go.
    private func validate() -> FieldIssue? {
        let petNamed = !petName.trimmed.isEmpty
        let boatNamed = !boatName.trimmed.isEmpty

        // An existing record can't have its name emptied out from under it.
        if currentPet != nil && !petNamed { return .petNeedsName }
        if currentVessel != nil && !boatNamed { return .boatNeedsName }

        // A new one only needs a name if something was actually entered for it.
        if currentPet == nil && !petNamed && petImage != nil { return .petNeedsName }
        if currentVessel == nil && !boatNamed && hasBoatDetails { return .boatNeedsName }

        return nil
    }

    private func clearIssue(_ candidate: FieldIssue) {
        guard issue == candidate else { return }
        withAnimation(.snappy) { issue = nil }
    }

    /// True when the boat section carries anything worth saving besides a name.
    private var hasBoatDetails: Bool {
        boatImage != nil
            || ![boatDescription, homeHarbor, length, weight, horsepower, maxPassengers]
                .allSatisfy { $0.trimmed.isEmpty }
    }

    private func saveProfile(userID: String, client: JebyClient) async throws {
        var photoURL: String?
        if let image {
            photoURL = try await ImageUploader().upload(image, kind: .profile, userID: userID).absoluteString
        }

        let trimmed = name.trimmed
        try await client.updateProfile(
            userID: userID,
            displayName: trimmed,
            photoURL: photoURL,
            bio: bio.trimmed
        )
        // Keep the Firebase profile in step so the avatar button updates without
        // waiting on a profile fetch.
        await auth.refreshProfile(displayName: trimmed, photoURL: photoURL)
    }

    private func savePet(userID: String, client: JebyClient) async throws {
        let trimmed = petName.trimmed

        var imageURL: String?
        if let petImage {
            imageURL = try await ImageUploader().upload(petImage, kind: .pet, userID: userID).absoluteString
        }

        if let currentPet {
            // Nothing touched means nothing to send.
            guard trimmed != currentPet.name || imageURL != nil else { return }
            try await client.updatePet(userID: userID, petID: currentPet.id, PetPatch(name: trimmed, imageUrl: imageURL))
        } else {
            // A name is the minimum for a pet to exist at all.
            guard !trimmed.isEmpty else { return }
            try await client.createPet(userID: userID, name: trimmed, imageURL: imageURL)
        }
    }

    private func saveBoat(userID: String, client: JebyClient) async throws {
        let trimmed = boatName.trimmed

        var imageURL: String?
        if let boatImage {
            imageURL = try await ImageUploader().upload(boatImage, kind: .boat, userID: userID).absoluteString
        }

        if let currentVessel {
            // imageUrl stays nil when no new photo was picked, which leaves the
            // stored one alone rather than clearing it. The specs are always
            // sent — this form owns all four, so a field the user emptied has to
            // travel as an explicit null to actually clear it.
            try await client.updateVessel(userID: userID, vesselID: currentVessel.id, VesselPatch(
                name: trimmed.isEmpty ? nil : trimmed,
                description: boatDescription.trimmed,
                imageUrl: imageURL,
                homeHarbor: homeHarbor.trimmed,
                lengthFt: .set(VesselSpec.parse(length)),
                weightLb: .set(VesselSpec.parse(weight)),
                horsepower: .set(VesselSpec.parse(horsepower)),
                maxPassengers: .set(VesselSpec.parseCount(maxPassengers))
            ))
        } else {
            guard !trimmed.isEmpty else { return }
            try await client.createVessel(userID: userID, NewVessel(
                name: trimmed,
                description: boatDescription.trimmed,
                imageUrl: imageURL ?? "",
                homeHarbor: homeHarbor.trimmed,
                lengthFt: VesselSpec.parse(length),
                weightLb: VesselSpec.parse(weight),
                horsepower: VesselSpec.parse(horsepower),
                maxPassengers: VesselSpec.parseCount(maxPassengers)
            ))
        }
    }

    private func remove(_ removal: Removal) async {
        guard let userID = auth.user?.id else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            switch removal {
            case .pet:
                guard let currentPet else { return }
                try await client.deletePet(userID: userID, petID: currentPet.id)
            case .boat:
                guard let currentVessel else { return }
                try await client.deleteVessel(userID: userID, vesselID: currentVessel.id)
            }
            dismiss()
        } catch {
            errorMessage = "Couldn't remove that. Check your connection and try again."
        }
    }
}

// MARK: - Row furniture

private struct DestructiveRow: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
