import App
import CoreSpotlight
import TKCore
import TKFeatureFlags
import TKLogging
import TKUIKit
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    static let remoteConfig = TKFirebaseRemoteConfigProvider(requestTimeoutMs: 1500)
    /// Built at launch so the device session refresh starts here; the first scene takes it.
    private static var launchAssembly: CoreAssembly?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        ScreenRenderTracker.shared.launchMark(.didFinishLaunching)
        FirebaseConfigurator.configurator.configure()
        Log.configure()
        Self.remoteConfig.startLoading()
        // A push wakes the app without UI, and the Keychain is closed before the first unlock.
        if application.isProtectedDataAvailable, launchOptions?[.remoteNotification] == nil {
            let remoteConfig = Self.remoteConfig
            let assembly = LaunchCoordinator.makeCoreAssembly(remoteConfig: remoteConfig)
            assembly.keeperCoreAssembly.startDeviceSession(after: { await remoteConfig.load() })
            Self.launchAssembly = assembly
        }
        CampaignAttributionService.shared.start(launchOptions: launchOptions)

        UNUserNotificationCenter.current().delegate = self

        clearBadgeCount()
        indexMainAppSearchItem()

        return true
    }

    static func takeLaunchAssembly() -> CoreAssembly? {
        defer { launchAssembly = nil }
        return launchAssembly
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
        NotificationCenter.default.post(name: .foregroundPushReceived, object: nil)
        return PushNotificationTapQueue.isShowingDestination?(notification.request.content.userInfo) == true ? [] : [.banner]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        PushNotificationTapQueue.enqueue(userInfo: response.notification.request.content.userInfo)
    }

    func clearBadgeCount() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    private func indexMainAppSearchItem() {
        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? "Keeper"

        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = appName
        attributeSet.displayName = appName
        attributeSet.keywords = ["wallet", "keeper"]

        let item = CSSearchableItem(
            uniqueIdentifier: "main-app",
            domainIdentifier: Bundle.main.bundleIdentifier,
            attributeSet: attributeSet
        )
        item.expirationDate = Date.distantFuture

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            guard let error else { return }
            Log.e("Failed to index main app Spotlight item: \(error.localizedDescription)")
        }
    }
}
