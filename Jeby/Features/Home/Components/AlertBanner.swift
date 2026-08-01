//
//  AlertBanner.swift
//  Jeby
//
//  NOAA marine alert banner, colored by severity. Shows a friendly "no alerts"
//  state when the area is clear.
//

import SwiftUI

struct AlertBanner: View {
    let level: AlertLevel
    let title: String?
    let message: String

    init(level: AlertLevel, title: String? = nil, message: String) {
        self.level = level
        self.title = title
        self.message = message
    }

    private var tint: Color {
        switch level {
        case .info: return .blue
        case .warning: return .orange
        case .danger: return .red
        }
    }

    private var icon: String {
        switch level {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.headline)
            VStack(alignment: .leading, spacing: 3) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }
}
