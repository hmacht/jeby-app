//
//  AppDelegate.swift
//  Jeby
//
//  Firebase has to be configured before anything touches Auth, and the app
//  delegate's launch callback is the earliest reliable point — SwiftUI can build
//  a View's body more than once, so configuration doesn't belong there.
//

import FirebaseCore
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
