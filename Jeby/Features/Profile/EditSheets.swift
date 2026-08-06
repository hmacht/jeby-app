//
//  EditSheets.swift
//  Jeby
//
//  Editing what onboarding collected: your name and photo, a boat and its specs,
//  and your first mate. Boats and pets can also be removed here.
//
//  Each sheet keeps its own draft state and only talks to the backend on Save,
//  so backing out with Cancel changes nothing.
//

import SwiftUI

// MARK: - You

struct EditProfileSheet: View {
    @Environment(AuthService.self) private var auth

    let currentName: String
    let currentPhotoURL: URL?

    @State private var name: String
    @State private var image: UIImage?

    init(currentName: String, currentPhotoURL: URL?) {
        self.currentName = currentName
        self.currentPhotoURL = currentPhotoURL
        _name = State(initialValue: currentName)
    }

    var body: some View {
        EditSheetScaffold(title: "Edit profile", save: save) {
            VStack(spacing: 24) {
                PhotoPickerButton(
                    image: $image,
                    icon: "person.crop.circle.badge.plus",
                    prompt: "Add photo",
                    existingImageURL: currentPhotoURL
                )

                FormField(label: "Name", placeholder: "Skipper", value: $name)
            }
        }
    }

    private func save() async -> Bool {
        guard let userID = auth.user?.id else { return false }

        do {
            var photoURL: String?
            if let image {
                photoURL = try await ImageUploader().upload(image, kind: .profile, userID: userID).absoluteString
            }

            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            try await client.updateProfile(userID: userID, displayName: trimmed, photoURL: photoURL)
            await auth.refreshProfile(displayName: trimmed, photoURL: photoURL)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Boat

struct EditVesselSheet: View {
    @Environment(AuthService.self) private var auth

    let vessel: UserVessel

    @State private var name: String
    @State private var description: String
    @State private var length: String
    @State private var weight: String
    @State private var horsepower: String
    @State private var maxPassengers: String
    @State private var image: UIImage?

    init(vessel: UserVessel) {
        self.vessel = vessel
        _name = State(initialValue: vessel.name)
        _description = State(initialValue: vessel.description)
        _length = State(initialValue: vessel.length)
        _weight = State(initialValue: vessel.weight)
        _horsepower = State(initialValue: vessel.horsepower)
        _maxPassengers = State(initialValue: vessel.maxPassengers)
    }

    var body: some View {
        EditSheetScaffold(
            title: "Edit boat",
            deleteTitle: "Delete boat",
            // The backend requires a name, so an empty one can't be saved.
            canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
            save: save,
            delete: delete
        ) {
            VStack(spacing: 24) {
                PhotoPickerButton(
                    image: $image,
                    icon: "sailboat.fill",
                    prompt: "Add a photo of her",
                    style: .card,
                    size: 150,
                    existingImageURL: vessel.imageURL
                )

                VStack(spacing: 14) {
                    FormField(label: "Boat name", placeholder: "Jeby", value: $name)
                    FormField(label: "Description", placeholder: "Grady White Freedom 215", value: $description)

                    HStack(spacing: 12) {
                        FormField(label: "Length", placeholder: "21.5 ft", value: $length)
                        FormField(label: "Weight", placeholder: "3,150 lb", value: $weight)
                    }

                    HStack(spacing: 12) {
                        FormField(label: "Horsepower", placeholder: "150 HP", value: $horsepower)
                        FormField(label: "Passengers", placeholder: "8", value: $maxPassengers, keyboard: .numbersAndPunctuation)
                    }
                }
            }
        }
    }

    private func save() async -> Bool {
        guard let userID = auth.user?.id else { return false }

        do {
            var imageURL: String?
            if let image {
                imageURL = try await ImageUploader().upload(image, kind: .boat, userID: userID).absoluteString
            }

            // imageUrl stays nil when no new photo was picked, which leaves the
            // stored one alone rather than clearing it.
            let patch = VesselPatch(
                name: name.trimmed,
                description: description.trimmed,
                imageUrl: imageURL,
                weight: weight.trimmed,
                length: length.trimmed,
                horsepower: horsepower.trimmed,
                maxPassengers: maxPassengers.trimmed
            )

            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            try await client.updateVessel(userID: userID, vesselID: vessel.id, patch)
            return true
        } catch {
            return false
        }
    }

    private func delete() async -> Bool {
        guard let userID = auth.user?.id else { return false }

        do {
            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            try await client.deleteVessel(userID: userID, vesselID: vessel.id)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - First mate

struct EditPetSheet: View {
    @Environment(AuthService.self) private var auth

    let pet: Pet

    @State private var name: String
    @State private var image: UIImage?

    init(pet: Pet) {
        self.pet = pet
        _name = State(initialValue: pet.name)
    }

    var body: some View {
        EditSheetScaffold(
            title: "Edit first mate",
            deleteTitle: "Delete first mate",
            canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
            save: save,
            delete: delete
        ) {
            VStack(spacing: 24) {
                PhotoPickerButton(
                    image: $image,
                    icon: "pawprint.fill",
                    prompt: "Add photo",
                    existingImageURL: pet.imageURL
                )

                FormField(label: "Name", placeholder: "Buoy", value: $name)
            }
        }
    }

    private func save() async -> Bool {
        guard let userID = auth.user?.id else { return false }

        do {
            var imageURL: String?
            if let image {
                imageURL = try await ImageUploader().upload(image, kind: .pet, userID: userID).absoluteString
            }

            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            try await client.updatePet(userID: userID, petID: pet.id, PetPatch(name: name.trimmed, imageUrl: imageURL))
            return true
        } catch {
            return false
        }
    }

    private func delete() async -> Bool {
        guard let userID = auth.user?.id else { return false }

        do {
            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            try await client.deletePet(userID: userID, petID: pet.id)
            return true
        } catch {
            return false
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
