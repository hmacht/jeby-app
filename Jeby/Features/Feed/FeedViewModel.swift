//
//  FeedViewModel.swift
//  Jeby
//
//  Loads today's reports. One day at a time by design — the feed is what it's
//  like out there *now*, so yesterday's chop isn't part of it.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class FeedViewModel {

    enum State: Equatable {
        case idle
        case loading
        case loaded(FeedResponse)
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Every report loaded so far — the first page plus whatever paging added.
    private(set) var posts: [FeedPost] = []
    private(set) var isLoadingMore = false

    /// Cursor for the next page, nil once the day has been walked.
    private var nextCursor: String?

    /// Reloads from the top. Readable signed out — the feed is the app's shop
    /// window; posting to it still needs an account.
    func load() async {
        // Only spinner on a cold load; a refresh shouldn't blank the list out.
        if case .loaded = state {} else {
            state = .loading
        }

        // No date: the backend files reports under the Vineyard-local day and
        // defaults to today, so the phone's clock never picks the day.
        // No token either: this endpoint takes the API key alone.
        let client = JebyClient()
        do {
            let feed = try await client.feed()
            posts = feed.posts
            nextCursor = feed.nextCursor
            state = .loaded(feed)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }

    /// Fetches the next page, if there is one. Safe to call repeatedly — the
    /// list triggers this from an appearing row, which can fire more than once.
    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let feed = try await JebyClient().feed(cursor: cursor)
            posts.append(contentsOf: feed.posts)
            nextCursor = feed.nextCursor
        } catch {
            // Leave the cursor in place: the next scroll retries rather than
            // stranding the list at a page boundary.
        }
    }
}
