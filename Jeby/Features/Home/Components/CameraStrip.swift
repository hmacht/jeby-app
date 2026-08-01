//
//  CameraStrip.swift
//  Jeby
//
//  The Cameras section: every live camera frame laid end to end in one
//  horizontal scroll — the ASIT tower first, then the buoy's 360° panorama —
//  each captioned where it begins, with a scroll indicator underneath.
//

import SwiftUI

struct CameraStrip: View {
    struct Camera: Identifiable {
        let url: URL
        let caption: String
        let systemImage: String

        var id: String { url.absoluteString }
    }

    let cameras: [Camera]

    private let height: CGFloat = 200

    @State private var metrics = ScrollMetrics()

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(cameras) { camera in
                        frame(for: camera)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .trackingHorizontalScroll($metrics)

            HorizontalScrollIndicator(metrics: metrics)
        }
    }

    /// One camera's frame at full height, natural width, captioned at the
    /// leading edge so the label lands where that image starts.
    private func frame(for camera: Camera) -> some View {
        AsyncImage(url: camera.url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .frame(width: height * 16 / 9, height: height)
                .overlay(ProgressView())
        }
        .overlay(alignment: .topLeading) {
            Label(camera.caption, systemImage: camera.systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
    }
}
