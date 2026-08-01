//
//  PulsingDot.swift
//  Jeby
//
//  A small live-status dot with a ring that pulses out of it, used next to the
//  "Last updated" line so the report reads as live. Holds still when the system
//  asks for reduced motion.
//

import SwiftUI

struct PulsingDot: View {
    var color: Color = .red
    var size: CGFloat = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(color, lineWidth: 1)
                    .scaleEffect(pulsing ? 3 : 1)
                    .opacity(pulsing ? 0 : 0.7)
            }
            .animation(
                pulsing ? .easeOut(duration: 1.8).repeatForever(autoreverses: false) : .default,
                value: pulsing
            )
            .onAppear { pulsing = !reduceMotion }
    }
}
