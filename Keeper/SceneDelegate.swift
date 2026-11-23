import App
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLogging
import TKUIKit
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var launchCoordinator: App.LaunchCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        ScreenRenderTracker.shared.launchMark(.sceneConnect)
        TKDevPreferencesManager.shared.showsTouches = TKAppPreferences.showTouches
        let window = TKWindow(windowScene: windowScene)
        let coordinator = App.LaunchCoordinator(
            router: TKCoordinator.WindowRouter(window: window),
            remoteConfig: AppDelegate.remoteConfig,
            coreAssembly: AppDelegate.takeLaunchAssembly()
        )

        let isWidgetTap = connectionOptions.urlContexts.first.map { Self.handleWidgetTap($0.url, isColdStart: true) } ?? false
        let incomingDeeplink = isWidgetTap ? nil : Self.incomingDeeplink(from: connectionOptions)
        let attribution = CampaignAttributionService.shared
        attribution.beginForwarding()
        attribution.noteDelivered(incomingDeeplink)
        if !isWidgetTap {
            attribution.forwardColdStart(scene: scene, connectionOptions: connectionOptions)
        }
        coordinator.start(deeplink: CampaignAttributionDecoding.appLink(incomingDeeplink))
        attribution.attachRouter { [weak coordinator] link in
            _ = coordinator?.handleDeeplink(deeplink: link)
        }
        attribution.finishForwarding()

        window.makeKeyAndVisible()

        self.launchCoordinator = coordinator
        self.window = window
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Log.i("app will enter foreground")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Log.i("app did enter background")
    }

    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        // Branch reads this activity for the initial referrer. The system does not always
        // deliver it through `scene(_:continue:)`.
        scene.userActivity = NSUserActivity(activityType: userActivityType)
        scene.delegate = self
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url, !Self.handleWidgetTap(url, isColdStart: false) else { return }
        forward(url.absoluteString) {
            CampaignAttributionService.shared.forwardCustomScheme(scene: scene, urlContexts: URLContexts)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else { return }
        forward(url.absoluteString) {
            CampaignAttributionService.shared.forwardUniversalLink(scene: scene, userActivity: userActivity)
        }
    }

    /// Live Activity and widget taps open the app themselves, bypassing the deep link parser and attribution.
    private static func handleWidgetTap(_ url: URL, isColdStart: Bool) -> Bool {
        TransactionLiveActivityTap.handle(url, isColdStart: isColdStart) || WalletWidgetTap.handle(url, isColdStart: isColdStart)
    }

    private func forward(_ link: String, providerWork: () -> Void) {
        let attribution = CampaignAttributionService.shared
        attribution.beginForwarding()
        attribution.noteDelivered(link)
        providerWork()
        if let appLink = CampaignAttributionDecoding.appLink(link) {
            _ = launchCoordinator?.handleDeeplink(deeplink: appLink)
        }
        attribution.finishForwarding()
    }

    private static func incomingDeeplink(from connectionOptions: UIScene.ConnectionOptions) -> String? {
        if let deeplink = connectionOptions.urlContexts.first?.url.absoluteString {
            return deeplink
        }
        return connectionOptions.userActivities.first(where: { $0.webpageURL != nil })?.webpageURL?.absoluteString
    }
}
