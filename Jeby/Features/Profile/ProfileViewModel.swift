//
//  ProfileViewModel.swift
//  Jeby
//
//  Loads the profile page: /users/:user_id/profile for who you are, your boat
//  and your first mate, plus /users/:user_id/posts for your reports.
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
    private(set) var posts: [UserPost] = []
    private(set) var isLoadingMore = false

    /// Cursor for the next page of reports, nil once they've all loaded.
    private var nextCursor: String?

    /// Fetches the next page of reports. Safe to call repeatedly — the grid
    /// triggers this from an appearing tile, which can fire more than once.
    func loadMorePosts(auth: AuthService) async {
        guard let cursor = nextCursor, !isLoadingMore, let userID = auth.user?.id else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
        if let page = try? await client.posts(userID: userID, cursor: cursor) {
            posts.append(contentsOf: page.posts)
            nextCursor = page.nextCursor
        }
        // On failure the cursor stays put, so the next scroll retries.
    }

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

    /// The skipper's bio. Nil when unset, so the view can skip the row entirely.
    var bio: String? {
        guard case .loaded(let profile) = state else { return nil }
        return profile.user.bio.isEmpty ? nil : profile.user.bio
    }

    /// Every report they've filed. Comes from the profile rather than `posts`,
    /// which is capped at a page.
    var reportCount: Int {
        guard case .loaded(let profile) = state else { return 0 }
        return profile.reportCount
    }

    var isVerified: Bool {
        guard case .loaded(let profile) = state else { return false }
        return profile.user.isVerified
    }

    /// The sailor's pet. Shown as part of who they are — a badge on the avatar
    /// and their name — rather than as its own section.
    var pet: Pet? {
        guard case .loaded(let profile) = state else { return nil }
        return profile.pets.first
    }

    /// The boat whose photo becomes the page's banner — the first one that has
    /// a picture, falling back to the first boat at all.
    var bannerVessel: UserVessel? {
        guard case .loaded(let profile) = state else { return nil }
        return profile.vessels.first { $0.imageURL != nil } ?? profile.vessels.first
    }

    func load(auth: AuthService) async {
        guard let userID = auth.user?.id else {
            state = .failed("You're not signed in.")
            return
        }

        // Only show the spinner on a cold load; a refresh after finishing an
        // onboarding step or an edit shouldn't blank the page out.
        if case .loaded = state {} else {
            state = .loading
        }

        let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
        do {
            // The profile is what the page is; posts are a section of it, so a
            // failure there shouldn't take the whole page down.
            async let profile = client.profile(userID: userID)
            async let firstPage = client.posts(userID: userID)

            state = .loaded(try await profile)
            let page = try? await firstPage
            posts = page?.posts ?? []
            nextCursor = page?.nextCursor
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }
}
