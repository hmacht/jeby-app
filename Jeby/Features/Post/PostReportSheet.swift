//
//  PostReportSheet.swift
//  Jeby
//
//  Filing a report, in two pages: take the shot, then say how it was.
//
//  The camera comes first and the photo is required — there's no form to fill in
//  without one, because a report is fundamentally the picture, taken now, of
//  what it's actually like out there.
//
//  The shutter goes straight to the form, with the shot shown there to check.
//  A separate review page asked "look good?" before the only page that could
//  answer it, and back from the form retakes just as well.
//

import SwiftUI

struct PostReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The shot, once taken. It's the navigation path itself — a real stack entry
    /// rather than a state inside the camera view, so the details page gets the
    /// system's own navigation bar and its back button returns to the viewfinder.
    ///
    /// The image rides in the path rather than in a separate `@State`: the
    /// destination closure captures the view as it was when the body last ran,
    /// so a separate property would still be nil on the push that sets it, and
    /// the first report would come up blank.
    @State private var path: [UIImage] = []

    /// The only height this sheet has. Short enough that the map still reads
    /// behind it, and fixed — every page of the flow is laid out for it, so
    /// there's nothing to gain from dragging it taller.
    private static let sheetHeight: PresentationDetent = .fraction(0.72)

    var body: some View {
        NavigationStack(path: $path) {
            CameraCaptureView(
                onCapture: { path = [$0] },
                onCancel: { dismiss() }
            )
            // Only the camera hides it — the page pushed on top shows its own.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UIImage.self) { image in
                PostDetailsView(image: image) { dismiss() }
            }
        }
        // A single detent, so the sheet can't be dragged up.
        .presentationDetents([Self.sheetHeight])
        .presentationDragIndicator(.hidden)
    }
}
