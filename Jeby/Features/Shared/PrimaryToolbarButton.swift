//
//  PrimaryToolbarButton.swift
//  Jeby
//
//  The one committing action in a toolbar — Post on the report composer, Save on
//  the profile editor — as a filled blue pill.
//
//  Two things it exists to get right, in one place:
//
//  * The label is white explicitly. `.borderedProminent` derives its label color
//    from the tint and ignores `foregroundStyle`, which renders dark on blue.
//  * On iOS 26 the toolbar wraps items in its own glass capsule, which sits
//    around this pill and clips it, so the shared background is turned off.
//

import SwiftUI

struct PrimaryToolbarButton: ToolbarContent {
    let title: String
    /// Swaps the button for a spinner while the action is in flight.
    var isBusy: Bool = false
    let action: () -> Void

    init(_ title: String, isBusy: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isBusy = isBusy
        self.action = action
    }

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { content }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { content }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isBusy {
            ProgressView()
        } else {
            Button(action: action) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    // Vertical padding stays modest: a nav bar is only so tall,
                    // and anything more gets clipped by it.
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
