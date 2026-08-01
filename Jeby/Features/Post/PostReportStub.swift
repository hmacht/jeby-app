//
//  PostReportStub.swift
//  Jeby
//
//  UI-only placeholder for posting your own report from the camera button.
//  Not implemented — just the entry point.
//

import SwiftUI

struct PostReportStub: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Post a Report", systemImage: "camera.fill")
            } description: {
                Text("Snap a photo and share the conditions you're seeing on the water. Coming soon.")
            } actions: {
                Button("Maybe later") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .navigationTitle("New Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
