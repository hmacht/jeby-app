//
//  FeedContent.swift
//  Jeby
//
//  The Feed tab inside the sheet: today's reports from everyone on the water.
//  A card is the photo, then who filed it, then what they said.
//

import SwiftUI

struct FeedContent: View {
    @Environment(AuthService.self) private var auth

    /// Owned by HomeView so the map's refresh button can reload this too.
    let model: FeedViewModel
    /// True while the sheet sits at its short detent. Scrolling is off there, so
    /// a swipe on the content is handed to the sheet and raises it over the map.
    var scrollDisabled = false
    /// Pulling the feed down past its top lowers the sheet again.
    var onPullDown: () -> Void = {}

    /// The author whose profile is open, if any.
    @State private var viewingAuthor: PostAuthor?

    var body: some View {
        VStack(spacing: 0) {
            header(average: loadedFeed?.averageBumpyScore)

            Divider()

            switch model.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let text):
                StateMessage(
                    icon: "cloud.bolt.rain.fill",
                    title: "Couldn't load reports",
                    detail: text,
                    actionTitle: "Try Again"
                ) {
                    Task { await model.load() }
                }

            case .loaded:
                if model.posts.isEmpty {
                    StateMessage(
                        // Same symbol as the Reports tab that got you here.
                        icon: "cloud.rainbow.crop",
                        title: "No reports yet today",
                        detail: "Be the first! Tap the camera to share what it's like out there."
                    )
                } else {
                    list
                }
            }
        }
        .task { await model.load() }
        // Signing in mid-session should fill the feed rather than leave the
        // signed-out message sitting there.
        .onChange(of: auth.isSignedIn) { _, _ in
            Task { await model.load() }
        }
        .sheet(item: $viewingAuthor) { author in
            PublicProfileSheet(
                userID: author.id,
                placeholderName: author.displayName,
                placeholderPhotoURL: author.photoURL
            )
            // Opens as a half sheet — a glance at who filed it, without losing
            // the feed behind it. Draggable up for the full profile.
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// The loaded feed, if there is one — the header reads the day's average off
    /// it, and the average covers the whole day rather than the page shown.
    private var loadedFeed: FeedResponse? {
        guard case .loaded(let feed) = model.state else { return nil }
        return feed
    }

    /// The day the feed covers, as the API bucketed it — which is the Vineyard's
    /// calendar day, not the phone's. Falls back to today before the first load.
    private var dayLabel: String {
        guard let day = loadedFeed?.day, let label = DayLabel.long(apiDay: day) else {
            return DayLabel.long(Date())
        }
        return label
    }

    private func header(average: Int?) -> some View {
        TabHeader(title: "Community Reports") {
            Text(dayLabel)
        } accessory: {
            if let average {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(average)")
                        .font(.title.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(BumpyScoreColor.color(at: Double(average)))
                        .contentTransition(.numericText())
                    Text("AVG BUMPY")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Average bumpy rating today")
                .accessibilityValue("\(average) out of 100")
            }
        }
    }

    private var list: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 28) {
                ForEach(model.posts) { post in
                    FeedCard(post: post) { author in
                        viewingAuthor = author
                    }
                    // Fetch the next page a few cards before the end, so the
                    // list is already longer by the time the bottom arrives.
                    .onAppear {
                        if post.id == model.posts.dropLast(3).last?.id {
                            Task { await model.loadMore() }
                        }
                    }
                }

                if model.isLoadingMore {
                    ProgressView().padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            // Clear the floating pill and the home indicator below it.
            .padding(.bottom, 120)
            // Pin the content to the sheet's width so nothing can pan sideways.
            .containerRelativeFrame(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(scrollDisabled)
        .scrollContentBackground(.hidden)
        // Overscroll past the top: how far the content has been dragged down.
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, overscroll in
            if overscroll < -90 { onPullDown() }
        }
    }

}

/// One report, laid out like a timeline entry: avatar in its own column, then
/// name and time, the caption, the rating, and the photo beneath.
private struct FeedCard: View {
    let post: FeedPost
    var onTapAuthor: (PostAuthor) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            author

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    nameRow

                    // What they were in, which is half of what a rating means.
                    if let boatLength = post.author?.boatLength {
                        Text("Boat Length: \(boatLength)")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                bumpyRating

                AsyncImage(url: post.imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    // Holds the row's height steady while it loads, rather than
                    // letting the list jump as each photo arrives.
                    CardStyle.surface.aspectRatio(3.0 / 4.0, contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var author: some View {
        if let author = post.author {
            Button {
                onTapAuthor(author)
            } label: {
                Avatar(photoURL: author.photoURL, name: author.displayName, size: 40)
            }
            .buttonStyle(.plain)
        } else {
            Avatar(photoURL: nil, name: "", size: 40)
        }
    }

    private var nameRow: some View {
        HStack(spacing: 5) {
            if let author = post.author {
                Button {
                    onTapAuthor(author)
                } label: {
                    HStack(spacing: 5) {
                        Text(author.displayName.isEmpty ? "Someone out there" : author.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if author.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .accessibilityLabel("Verified")
                        }

                        // The first mate rides along in gray, the way it does on
                        // their profile.
                        if !author.petName.isEmpty {
                            Text("& \(author.petName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            Text(post.relativeTime)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .layoutPriority(1)
        }
    }

    /// Plain colored text rather than a badge — it's a reading, not a tag.
    private var bumpyRating: some View {
        Text("Bumpy Rating: \(post.bumpyScore)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(BumpyScoreColor.color(at: Double(post.bumpyScore)))
            .accessibilityLabel("Bumpy rating \(post.bumpyScore) out of 100")
    }
}
