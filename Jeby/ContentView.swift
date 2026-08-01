//
//  ContentView.swift
//  Jeby
//
//  Root tab bar: Home (live conditions), Feed, and Profile.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "square.stack.3d.up.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
