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

    var body: some View {
        HStack(spacing: 8) {
            tab(.report, label: "Report", icon: "water.waves")
            cameraButton
            tab(.feed, label: "Feed", icon: "square.stack.3d.up.fill")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5), in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        // Sits low, overlapping the bottom safe area.
        .padding(.bottom, -10)
    }

    private func tab(_ value: SheetTab, label: String, icon: String) -> some View {
        let isSelected = selected == value

        return Button {
            withAnimation(.snappy(duration: 0.25)) { selected = value }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
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
        Button(action: onCamera) {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor.gradient, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
