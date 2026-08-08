//
//  TabHeader.swift
//  Jeby
//
//  The header every tab in the sheet wears: title, a line of context under it,
//  and an optional readout on the right.
//

import SwiftUI

/// Home and Reports had identical headers built twice. Sharing one keeps the
/// title size, subtitle size, and insets in step — they sit directly above the
/// same divider, so a difference of a few points between them is visible.
struct TabHeader<Subtitle: View, Accessory: View>: View {
    let title: String
    let subtitle: Subtitle
    let accessory: Accessory

    init(
        title: String,
        @ViewBuilder subtitle: () -> Subtitle,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle()
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer()

            accessory
        }
        .padding(.horizontal, 20)
        // Enough to clear the sheet's grabber, no more.
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

extension TabHeader where Accessory == EmptyView {
    init(title: String, @ViewBuilder subtitle: () -> Subtitle) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() })
    }
}
