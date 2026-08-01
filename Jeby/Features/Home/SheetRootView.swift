//
//  SheetRootView.swift
//  Jeby
//
//  The content of the map's sheet: a switchable body (Report or Feed) above a
//  pinned bottom tab bar. The camera button opens a stub for posting a report.
//

import SwiftUI

struct SheetRootView: View {
    let model: HomeViewModel
    /// True while the sheet sits at its short detent. Scrolling is off there, so
    /// a swipe on the content is handed to the sheet and raises it over the map.
    let isCollapsed: Bool
    /// Pulling the report down past its top lowers the sheet again.
    var onPullDown: () -> Void = {}

    @State private var tab: SheetTab = .report
    @State private var showPostReport = false

    var body: some View {
        // A ZStack so only the body runs into the bottom safe area — the pill
        // stays above the home indicator and content scrolls under it.
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .report:
                    HomeContentCard(
                        model: model,
                        scrollDisabled: isCollapsed,
                        onPullDown: onPullDown
                    )
                case .feed:
                    FeedContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The sheet is vertical-only: nothing inside it may pan or spill sideways.
            .clipped()
            .ignoresSafeArea(.container, edges: .bottom)

            SheetTabBar(selected: $tab) { showPostReport = true }
        }
        .sheet(isPresented: $showPostReport) {
            PostReportStub()
        }
    }
}
