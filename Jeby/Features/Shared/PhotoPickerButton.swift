//
//  PhotoPickerButton.swift
//  Jeby
//
//  The tap-to-add-a-photo control used by all three onboarding steps: a circle
//  for people and pets, a rounded rectangle for boats.
//

import PhotosUI
import SwiftUI

struct PhotoPickerButton: View {
    @Binding var image: UIImage?
    var icon: String
    var prompt: String
    var style: Style = .circle
    var size: CGFloat = 132
    /// The photo already on the record, shown until a new one is picked. Lets
    /// the edit sheets open with the boat's existing picture in place.
    var existingImageURL: URL?

    enum Style {
        case circle
        case card
    }

    @State private var selection: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            content
        }
        .buttonStyle(.plain)
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .accessibilityLabel(image == nil ? prompt : "Change photo")
    }

    private var content: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let existingImageURL {
                AsyncImage(url: existingImageURL) { loaded in
                    loaded.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    CardStyle.surface
                }
            } else {
                CardStyle.surface

                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.2, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(prompt)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading {
                Color.black.opacity(0.4)
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: frameWidth, height: size)
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            // Only worth a badge once there's a photo to replace; the empty
            // state already says "Add photo".
            if image != nil || existingImageURL != nil {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor, in: Circle())
                    .overlay(Circle().stroke(CardStyle.sheetSurface, lineWidth: 2))
                    .offset(x: 4, y: 4)
            }
        }
    }

    private var frameWidth: CGFloat {
        switch style {
        case .circle: return size
        // Roughly 3:2, the shape a boat photo usually comes in.
        case .card: return size * 1.5
        }
    }

    private var shape: AnyShape {
        switch style {
        case .circle: return AnyShape(Circle())
        case .card: return AnyShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }

        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let loaded = UIImage(data: data)
        else {
            return
        }
        image = loaded
    }
}
