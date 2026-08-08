//
//  BumpyScoreCard.swift
//  Jeby
//
//  The BumpyScore™ card, Flighty-style: a gradient tinted by the score, the big
//  score, the first two sentences of the AI analysis, and a button to read the
//  full analysis (with disclaimers and the score scale).
//

import SwiftUI

struct BumpyScoreCard: View {
    let score: Int?
    let analysis: String?
    let disclaimers: [String]
    let inQuietHours: Bool

    @State private var showDetails = false

    /// Card tint: the score's color, or a neutral slate during quiet hours.
    private var base: Color {
        guard let score, !inQuietHours else { return Color(red: 0.30, green: 0.36, blue: 0.46) }
        return BumpyScoreColor.color(at: Double(score))
    }

    private var preview: String {
        (analysis?.firstSentences(2)) ?? "BumpyScore™ analysis unavailable right now."
    }

    var body: some View {
        GradientCard(
            base: base,
            buttonTitle: analysis != nil ? "Read full AI Analysis" : nil,
            action: analysis != nil ? { showDetails = true } : nil
        ) {
            VStack(alignment: .leading, spacing: 10) {
                CardEyebrow(title: "BumpyScore™", systemImage: "gauge.open.with.lines.needle.33percent")

                HStack(alignment: .firstTextBaseline) {
                    if inQuietHours {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 52))
                    } else {
                        Text(score.map(String.init) ?? "—")
                            .font(.system(size: 64, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    Spacer()
                }

                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showDetails) {
            BumpyScoreDetailSheet(
                score: score,
                analysis: analysis,
                disclaimers: disclaimers,
                inQuietHours: inQuietHours
            )
        }
    }
}

private struct BumpyScoreDetailSheet: View {
    let score: Int?
    let analysis: String?
    let disclaimers: [String]
    let inQuietHours: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    scale

                    VStack(alignment: .leading, spacing: 8) {
                        Label(inQuietHours ? "Quiet Hours" : "AI Analysis", systemImage: "sparkles")
                            .font(.headline)
                        Text(analysis ?? "BumpyScore™ analysis unavailable right now.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !disclaimers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Disclaimers", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            ForEach(disclaimers, id: \.self) { item in
                                Label(item, systemImage: "circle.fill")
                                    .labelStyle(BulletLabelStyle())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("BumpyScore™")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var scale: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BumpyScoreColor.gradient)
                        .frame(height: 10)
                    if let score {
                        let pct = min(100, max(0, Double(score)))
                        Circle()
                            .fill(.white)
                            .overlay(Circle().stroke(BumpyScoreColor.color(at: pct), lineWidth: 4))
                            .frame(width: 22, height: 22)
                            .shadow(radius: 2, y: 1)
                            .offset(x: (geo.size.width - 22) * pct / 100)
                    }
                }
                .frame(height: 22)
            }
            .frame(height: 22)

            HStack {
                ForEach([0, 25, 50, 75, 100], id: \.self) { tick in
                    Text("\(tick)")
                    if tick != 100 { Spacer() }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

/// Renders a small filled bullet in place of the label's icon.
private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.tertiary)
            configuration.title
        }
    }
}
