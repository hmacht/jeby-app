//
//  FeedView.swift
//  Jeby
//
//  Feed tab — not implemented yet. Placeholder so the tab exists in navigation.
//

import SwiftUI

struct FeedView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Feed",
                systemImage: "square.stack.3d.up",
                description: Text("Coming soon.")
            )
            .navigationTitle("Feed")
        }
    }
}

#Preview {
    FeedView()
}
