//
//  EditRow.swift
//  Jeby
//
//  The labeled-row layout used by the profile editor and the post composer: a
//  fixed label column on the left, the field filling the rest, hairlines inset
//  to the value column. Shared so the two pages can't drift apart.
//

import SwiftUI

/// One labeled row, with an optional fixed unit on the trailing edge.
struct EditRow<Content: View>: View {
    let label: String
    var unit: String?
    @ViewBuilder var content: () -> Content

    /// Wide enough for the longest label, so every field starts on the same line.
    static var labelWidth: CGFloat { 100 }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body)
                .frame(width: Self.labelWidth, alignment: .leading)

            content()
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let unit {
                Text(unit)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

/// Hairline between rows, inset to line up with the value column.
struct RowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 132)
    }
}

/// The heavier break between groups of rows.
struct SectionGap: View {
    var body: some View {
        Divider()
            .padding(.top, 8)
    }
}
