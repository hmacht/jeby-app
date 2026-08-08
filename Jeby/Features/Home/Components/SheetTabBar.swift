//
//  SheetTabBar.swift
//  Jeby
//
//  The gray pill that floats over the bottom of the content sheet: Report, a
//  big camera button, and Feed. It's an overlay, not a bar — sheet content
//  scrolls underneath it. The map behind the sheet is untouched.
//

import SwiftUI

enum SheetTab {
    case report, feed
}

struct SheetTabBar: View {
    @Binding var selected: SheetTab
    var onCamera: () -> Void

    @State private var cameraTaps = 0

    var body: some View {
        HStack(spacing: 8) {
            tab(.report, label: "Home", icon: "water.waves")
            cameraButton
            tab(.feed, label: "Reports", icon: "cloud.rainbow.crop", multicolorWhenSelected: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5), in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        // Sits low, overlapping the bottom safe area.
        .padding(.bottom, -10)
    }

    private func tab(
        _ value: SheetTab,
        label: String,
        icon: String,
        multicolorWhenSelected: Bool = false
    ) -> some View {
        let isSelected = selected == value

        return Button {
            withAnimation(.snappy(duration: 0.25)) { selected = value }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    // Multicolor paints the symbol's own colors and overrides the
                    // tint below, so it's only switched on for the selected tab.
                    .symbolRenderingMode(isSelected && multicolorWhenSelected ? .multicolor : .monochrome)
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 64, height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cameraButton: some View {
        Button {
            cameraTaps += 1
            onCamera()
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor.gradient, in: Circle())
        }
        .buttonStyle(.plain)
        // A counter rather than a Bool: consecutive taps have to register as
        // separate events for the feedback to fire each time.
        .sensoryFeedback(.impact(weight: .medium), trigger: cameraTaps)
    }
}
