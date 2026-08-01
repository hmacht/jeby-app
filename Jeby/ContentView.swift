//
//  ContentView.swift
//  Jeby
//
//  App root: the persistent map with its content sheet. The bottom bar inside
//  the sheet switches between Report and Feed.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
