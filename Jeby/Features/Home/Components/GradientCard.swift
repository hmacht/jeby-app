//
//  GradientCard.swift
//  Jeby
//
//  A Flighty-style gradient card: a tinted diagonal background, freeform content,
//  and an optional frosted full-width button at the bottom. Used for the
//  BumpyScore and per-station readings cards.
//

import SwiftUI

struct GradientCard<Content: View>: View {
    /// Base tint; the background runs from a dark shade of it to a brighter one.
    var base: Color
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content()

            if let buttonTitle, let action {
                Button(action: action) {
                    HStack {
                        Text(buttonTitle)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .foregroundStyle(.white)
    }

    private var gradient: LinearGradient { CardStyle.gradient(base: base) }
}

/// The shared look for the app's station surfaces — the passport cards and the
/// map pins — so they read as one family.
enum CardStyle {
    /// The sheet's own background: a flat gray, darker than the cards sitting
    /// on it.
    static let sheetSurface = Color(.systemGray6)

    /// Background for the sheet's plain cards — a step up from the sheet behind
    /// them. One knob for the forecast, tuned-for, and about cards.
    static let surface = Color(.systemGray5)

    /// Per-station tint: teal for the MVCO sensor, blue for the NOAA buoy.
    static func tint(isMVCO: Bool) -> Color { isMVCO ? .teal : .blue }

    /// Dark → bright diagonal wash over a base tint.
    static func gradient(base: Color) -> LinearGradient {
        LinearGradient(
            colors: [base.mix(with: .black, by: 0.72), base.mix(with: .black, by: 0.24)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A single labeled statistic (uppercase caption + big value), Flighty-style.
struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small uppercase eyebrow with an icon, used as a card header.
struct CardEyebrow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.8))
    }
}
