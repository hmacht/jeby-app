//
//  SheetRootView.swift
//  Jeby
//
//  The content of the map's sheet: a switchable body (Report or Feed) above a
//  pinned bottom tab bar. The camera button opens a stub for posting a report.
//
//  This view also raises the account sheets. They're presented from here rather
//  than from HomeView because the map's content sheet is always up, and SwiftUI
//  only honors one sheet per presenter.
//

import SwiftUI

struct SheetRootView: View {
    @Environment(AuthService.self) private var auth

    let model: HomeViewModel
    /// Owned by HomeView so its refresh button can reload the feed too.
    let feed: FeedViewModel
    /// True while the sheet sits at its short detent. Scrolling is off there, so
    /// a swipe on the content is handed to the sheet and raises it over the map.
    let isCollapsed: Bool
    /// The open account sheet. Bound to HomeView, which sets it from the profile
    /// button out on the map.
    @Binding var authRoute: AuthRoute?
    /// Pulling the report down past its top lowers the sheet again.
    var onPullDown: () -> Void = {}

    @State private var tab: SheetTab = .report

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
                    FeedContent(
                        model: feed,
                        scrollDisabled: isCollapsed,
                        onPullDown: onPullDown
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The sheet is vertical-only: nothing inside it may pan or spill sideways.
            .clipped()
            .ignoresSafeArea(.container, edges: .bottom)

            // Posting writes to the backend, so it needs an account — signed-out
            // taps get the Get Started card instead of a dead end.
            SheetTabBar(selected: $tab) {
                authRoute = auth.isSignedIn ? .postReport : .getStarted
            }
        }
        .sheet(item: $authRoute) { route in
            switch route {
            case .getStarted:
                GetStartedSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .onboarding:
                OnboardingFlow()
            case .profile:
                ProfileSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .postReport:
                // Owns its own height: short for the camera, full for the
                // review page.
                PostReportSheet()
            }
        }
    }
}
