//
//  AppDelegate.swift
//  Tonkeeper
//
//  Created by Grigory on 22.5.23..
//

import TKAppInfo
import TKCore
import TKFeatureFlags
import TKLogging
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseConfigurator.configurator.configure()
        Log.configure()

        AptabaseConfigurator.configurator.configure(
            sendStatsImmediately: TKAppPreferences.sendStatsImmediately
        )

        UNUserNotificationCenter.current().delegate = self

        clearBadgeCount()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        clearBadgeCount()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "PushNotificationOpen"),
            object: nil,
            userInfo: response.notification.request.content.userInfo
        )
    }

    func clearBadgeCount() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}
