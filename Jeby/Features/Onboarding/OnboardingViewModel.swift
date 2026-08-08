//
//  OnboardingViewModel.swift
//  Jeby
//
//  Drives the three-step flow that runs after sign-up: who you are, your boat,
//  and your first mate. Each step saves when you leave it, so skipping the pet
//  page never costs you the boat you just entered.
//

import Observation
import SwiftUI

/// The steps, in order.
enum OnboardingStep: String, CaseIterable, Identifiable, Hashable {
    case name
    case boat
    case pet

    var id: String { rawValue }

    /// Where to resume from when the profile page asks for a missing piece.
    /// Name and photo are collected on the same screen.
    init(piece: ProfilePiece) {
        switch piece {
        case .name, .photo: self = .name
        case .boat: self = .boat
        case .pet: self = .pet
        }
    }
}

@MainActor
@Observable
final class OnboardingViewModel {

    // MARK: - Step 1: you

    var name = ""
    var bio = ""
    var profileImage: UIImage?

    // MARK: - Step 2: your boat

    var boatName = ""
    var boatDescription = ""
    var boatHomeHarbor = ""
    var boatLength = ""
    var boatWeight = ""
    var boatHorsepower = ""
    var boatMaxPassengers = ""
    var boatImage: UIImage?

    // MARK: - Step 3: your first mate

    var petName = ""
    var petImage: UIImage?

    // MARK: - Flow

    private(set) var step: OnboardingStep
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    /// True once the last step has been left, by finishing or skipping.
    private(set) var isFinished = false

    private let auth: AuthService
    private let client: JebyClient
    private let uploader = ImageUploader()

    /// Where the flow started, so resuming for a single missing piece from the
    /// profile page doesn't march the user through the steps before it.
    private let startingStep: OnboardingStep
    /// True when resuming for one specific piece — finishing that step ends the
    /// flow rather than continuing to the next.
    private let isSingleStep: Bool

    init(auth: AuthService, startingAt step: OnboardingStep = .name, singleStep: Bool = false) {
        self.auth = auth
        self.startingStep = step
        self.step = step
        self.isSingleStep = singleStep
        // The token is fetched per request; Firebase refreshes it when it's near
        // expiry, so a slow onboarding session won't go stale mid-flow.
        self.client = JebyClient(idToken: { [auth] in try await auth.idToken() })
    }

    var isFirstStep: Bool { step == startingStep }

    /// Progress across the whole flow, for the dots at the top.
    var stepIndex: Int { OnboardingStep.allCases.firstIndex(of: step) ?? 0 }

    // MARK: - Navigation

    /// Saves the current step, then moves on. Staying put on failure means a
    /// dropped connection doesn't silently discard what they typed.
    func continueFromCurrentStep() async {
        guard await save(step) else { return }
        advance()
    }

    /// Leaves the step without saving it.
    func skipCurrentStep() {
        errorMessage = nil
        advance()
    }

    private func advance() {
        guard !isSingleStep, let next = OnboardingStep.allCases[safe: stepIndex + 1] else {
            isFinished = true
            return
        }
        step = next
    }

    // MARK: - Saving

    /// Returns false when the step failed to save. An empty step is a no-op
    /// success — it's the same as skipping.
    private func save(_ step: OnboardingStep) async -> Bool {
        guard let userID = auth.user?.id else {
            errorMessage = "You're not signed in anymore. Try again."
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            switch step {
            case .name: try await saveName(userID: userID)
            case .boat: try await saveBoat(userID: userID)
            case .pet: try await savePet(userID: userID)
            }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private func saveName(userID: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        var photoURL: String?
        if let profileImage {
            photoURL = try await uploader.upload(profileImage, kind: .profile, userID: userID).absoluteString
        }

        guard !trimmedName.isEmpty || !trimmedBio.isEmpty || photoURL != nil else { return }

        try await client.updateProfile(
            userID: userID,
            displayName: trimmedName.isEmpty ? nil : trimmedName,
            photoURL: photoURL,
            bio: trimmedBio.isEmpty ? nil : trimmedBio
        )
        // Keep the Firebase profile in step so the avatar button updates without
        // waiting on a profile fetch.
        await auth.refreshProfile(displayName: trimmedName.isEmpty ? nil : trimmedName, photoURL: photoURL)
    }

    private func saveBoat(userID: String) async throws {
        let trimmedName = boatName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var imageURL = ""
        if let boatImage {
            imageURL = try await uploader.upload(boatImage, kind: .boat, userID: userID).absoluteString
        }

        // Unparseable or blank specs become nil — every one of them is optional,
        // and this step is meant to be quick.
        try await client.createVessel(userID: userID, NewVessel(
            name: trimmedName,
            description: boatDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            imageUrl: imageURL,
            homeHarbor: boatHomeHarbor.trimmingCharacters(in: .whitespacesAndNewlines),
            lengthFt: VesselSpec.parse(boatLength),
            weightLb: VesselSpec.parse(boatWeight),
            horsepower: VesselSpec.parse(boatHorsepower),
            maxPassengers: VesselSpec.parseCount(boatMaxPassengers)
        ))
    }

    private func savePet(userID: String) async throws {
        let trimmedName = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var imageURL: String?
        if let petImage {
            imageURL = try await uploader.upload(petImage, kind: .pet, userID: userID).absoluteString
        }

        try await client.createPet(userID: userID, name: trimmedName, imageURL: imageURL)
    }

}

private extension Array {
    /// Bounds-checked lookup, for stepping past the last step.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
