import SwiftUI

/// The empty/error state shared by the sheet's tabs — "No reports yet today" on
/// Reports, "Couldn't load conditions" on Home.
///
/// Hand-built rather than `ContentUnavailableView`: that one drops its image when
/// vertical space is tight, which is exactly the short detent — the icon would
/// vanish at the height the sheet spends most of its time at.
struct StateMessage: View {
    let icon: String
    let title: String
    let detail: String

    /// An optional recovery action. Errors get one, empty states don't.
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 44))
                // Paints the symbol's own colors, the way the selected tab does.
                .symbolRenderingMode(.multicolor)

            Text(title)
                .font(.headline)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Off the divider above it. No bottom inset: at the short detent there
        // isn't the height to give away, and this sits well clear of the pill.
        .padding(.top, 40)
    }
}
