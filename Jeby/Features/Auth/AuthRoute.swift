//
//  AuthRoute.swift
//  Jeby
//
//  Which account sheet is open. The map's content sheet is always presented, and
//  SwiftUI only allows one sheet per presenter — so account sheets are raised
//  from inside SheetRootView, the same place the station detail sheet comes
//  from, even when the button that asked for one lives out on the map.
//

import Foundation

enum AuthRoute: Identifiable, Hashable {
    /// Signed out and trying to do something that needs an account.
    case getStarted
    /// Just created an account — the three-step flow runs before anything else.
    case onboarding
    /// Signed in, opening your own profile.
    case profile
    /// Signed in, posting a report.
    case postReport

    var id: Self { self }
}
