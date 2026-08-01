//
//  HorizontalScrollIndicator.swift
//  Jeby
//
//  A slim custom indicator for the app's horizontal image strips: the thumb is
//  as wide as the slice you can see and sits where you are in the scroll, so a
//  wide panorama reads as "you're here in the sweep".
//

import SwiftUI

/// Position and extent of a horizontal scroll view, sampled from its geometry.
struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var content: CGFloat = 0
    var container: CGFloat = 0

    /// How much of the strip fits on screen at once, 0…1.
    var visibleFraction: CGFloat {
        guard content > 0 else { return 1 }
        return min(1, container / content)
    }

    /// How far along the strip we are, 0…1.
    var progress: CGFloat {
        let scrollable = content - container
        guard scrollable > 0 else { return 0 }
        return min(1, max(0, offset / scrollable))
    }

    var isScrollable: Bool { content - container > 1 }
}

struct HorizontalScrollIndicator: View {
    let metrics: ScrollMetrics
    var width: CGFloat = 96
    var thickness: CGFloat = 4

    var body: some View {
        if metrics.isScrollable {
            let thumbWidth = max(16, width * metrics.visibleFraction)

            Capsule()
                .fill(.quaternary)
                .frame(width: width, height: thickness)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.secondary)
                        .frame(width: thumbWidth, height: thickness)
                        .offset(x: (width - thumbWidth) * metrics.progress)
                }
        }
    }
}

extension View {
    /// Feeds this scroll view's horizontal geometry into `metrics`.
    func trackingHorizontalScroll(_ metrics: Binding<ScrollMetrics>) -> some View {
        onScrollGeometryChange(for: ScrollMetrics.self) { geo in
            ScrollMetrics(
                offset: geo.contentOffset.x,
                content: geo.contentSize.width,
                container: geo.containerSize.width
            )
        } action: { _, new in
            metrics.wrappedValue = new
        }
    }
}
