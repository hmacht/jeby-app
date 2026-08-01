//
//  SectionHeader.swift
//  Jeby
//
//  Small reusable section title used across the Home tab.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
