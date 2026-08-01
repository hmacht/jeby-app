//
//  WebcamImage.swift
//  Jeby
//
//  A live camera frame (buoy 360 cam or MVCO tower webcam) with a caption and
//  graceful loading / failure states.
//

import SwiftUI

struct WebcamImage: View {
    let url: URL
    let caption: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    placeholder(systemImage: "photo.badge.exclamationmark", text: "Image unavailable")
                case .empty:
                    ZStack {
                        placeholder(systemImage: nil, text: nil)
                        ProgressView()
                    }
                @unknown default:
                    placeholder(systemImage: nil, text: nil)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Label(caption, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func placeholder(systemImage: String?, text: String?) -> some View {
        ZStack {
            Rectangle().fill(.quaternary)
            VStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                if let text {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 200)
    }
}
