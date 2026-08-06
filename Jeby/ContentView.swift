//
//  ContentView.swift
//  Jeby
//
//  App root: the persistent map with its content sheet. The bottom bar inside
//  the sheet switches between Report and Feed.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        HomeView()
            .preferredColorScheme(.dark)
            // Firebase is configured by the app delegate at launch, which lands
            // after the App struct is built — so the session starts here.
            .task { auth.start() }
    }
}

#Preview {
    ContentView()
        .environment(AuthService())
}
