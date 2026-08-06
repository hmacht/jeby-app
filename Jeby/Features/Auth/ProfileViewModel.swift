//
//  ProfileViewModel.swift
//  Jeby
//
//  Loads /users/:user_id/profile so the profile page can show the user's boats
//  and pet, and nag about whatever onboarding skipped.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class ProfileViewModel {

    enum State: Equatable {
        case idle
        case loading
        case loaded(Profile)
        case failed(String)
    }

    private(set) var state: State = .idle

    /// The name jeby-go has, which is the one the user chose. Falls back to the
    /// Firebase profile in the view when the fetch hasn't landed.
    var displayName: String? {
        guard case .loaded(let profile) = state else { return nil }
        let name = profile.user.displayName
        return name.isEmpty ? nil : name
    }

    /// The photo jeby-go has, for the same reason as `displayName`.
    var photoURL: URL? {
        guard case .loaded(let profile) = state else { return nil }
        return profile.user.photoURL
    }

    func load(auth: AuthService) async {
        guard let userID = auth.user?.id else {
            state = .failed("You're not signed in.")
            return
        }

        // Only show the spinner on a cold load; a refresh after finishing an
        // onboarding step shouldn't blank the page out.
        if case .loaded = state {} else {
            state = .loading
        }

        let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
        do {
            state = .loaded(try await client.profile(userID: userID))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }
}
