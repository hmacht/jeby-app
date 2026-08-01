//
//  FeedContent.swift
//  Jeby
//
//  The Feed tab inside the sheet — a placeholder for community reports from the
//  water. Not implemented yet.
//

import SwiftUI

struct FeedContent: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Feed")
                        .font(.title2.weight(.bold))
                    Text("Reports from the water")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 12)

            Divider()

            ContentUnavailableView {
                Label("No reports yet", systemImage: "square.stack.3d.up")
            } description: {
                Text("Community reports will show up here.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Sit above the floating pill rather than centering behind it.
            .padding(.bottom, 120)
        }
    }
}
