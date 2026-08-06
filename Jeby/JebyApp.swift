//
//  JebyApp.swift
//  Jeby
//
//  Created by Henry Macht on 8/1/26.
//

import SwiftUI

@main
struct JebyApp: App {
    /// Configures Firebase at launch — see AppDelegate.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// One auth session for the whole app. Built here so it starts listening for
    /// Firebase state changes before any view asks whether we're signed in.
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
        }
    }
}
