//
//  ProfileSettings.swift
//  Jeby
//
//  The settings block at the bottom of the profile page: the legal pages, how to
//  reach us, what version this is, and the way out.
//

import SwiftUI

/// Where the settings rows point.
///
/// TODO: the legal pages don't exist yet — point these at the real ones before
/// shipping. They're gathered here so that's a one-line change.
enum AppLinks {
    static let terms = URL(string: "https://jeby.org/terms")
    static let privacy = URL(string: "https://jeby.org/privacy")
    static let contactEmail = "henryamacht@gmail.com"

    static var contact: URL? {
        URL(string: "mailto:\(contactEmail)?subject=Jeby%20app")
    }

    /// Marketing version and build, as Xcode stamped them — "1.2 (34)".
    static var version: String {
        let bundle = Bundle.main
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String
        guard let build, build != short else { return short }
        return "\(short) (\(build))"
    }
}

/// What the gear button in the profile's top-left opens: the legal pages, how to
/// reach us, the version, and Log out last.
struct SettingsSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Which account you're signed in as, first — it's the thing
                    // people come here to check.
                    SettingsRow(
                        icon: "envelope",
                        title: "Email",
                        value: auth.user?.email ?? "—"
                    )
                    SettingsDivider()

                    if let terms = AppLinks.terms {
                        SettingsRow(icon: "doc.text", title: "Terms and Conditions", link: terms)
                        SettingsDivider()
                    }
                    if let privacy = AppLinks.privacy {
                        SettingsRow(icon: "hand.raised", title: "Privacy Policy", link: privacy)
                        SettingsDivider()
                    }
                    // No Contact row: AboutCard below carries the same mailto.

                    // Not a link — just the build, for bug reports.
                    SettingsRow(icon: "water.waves", title: "Jeby", value: AppLinks.version)
                    SettingsDivider()

                    SettingsRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Log out",
                        isDestructive: true,
                        action: auth.signOut
                    )
                }
                .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Same card the report closes with — who we are, the open-source
                // API, and where the readings come from.
                AboutCard()
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(CardStyle.sheetSurface)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        // Logging out closes this along with the profile behind it.
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if !isSignedIn { dismiss() }
        }
    }
}

/// One settings row: an icon, a title, and either a value, a link chevron, or an
/// action.
private struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String?
    var link: URL?
    var isDestructive = false
    var action: (() -> Void)?

    var body: some View {
        if let link {
            Link(destination: link) { content }
                .buttonStyle(.plain)
        } else if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 14) {
            // The icon takes the row's own color rather than the accent, so each
            // row reads as one thing — including Log out, which stays red.
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(width: 26)

            Text(title)
                .font(.body)
                .foregroundStyle(isDestructive ? Color.red : Color.primary)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if link != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }
}

/// Inset divider between settings rows, clearing the icon column.
private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 54)
    }
}
