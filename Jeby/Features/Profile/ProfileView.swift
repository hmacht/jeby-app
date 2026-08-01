//
//  ProfileView.swift
//  Jeby
//
//  Profile tab — not implemented yet. Placeholder so the tab exists in navigation.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Profile",
                systemImage: "person.crop.circle",
                description: Text("Coming soon.")
            )
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
}
