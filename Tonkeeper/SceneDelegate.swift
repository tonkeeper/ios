//
//  SceneDelegate.swift
//  Tonkeeper
//
//  Created by Grigory on 22.5.23..
//

import App
import TKCoordinator
import TKFeatureFlags
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
        let window = TKWindow(windowScene: windowScene)
        let coordinator = App.LaunchCoordinator(
            router: TKCoordinator.WindowRouter(window: window),
            remoteConfig: TKFirebaseRemoteConfigProvider(
                requestTimeoutMs: 1500
            )
        )

        if let deeplink = connectionOptions.urlContexts.first?.url.absoluteString {
            coordinator.start(deeplink: deeplink)
        } else if let universalLink = connectionOptions.userActivities.first(where: { $0.webpageURL != nil })?.webpageURL {
            coordinator.start(deeplink: universalLink.absoluteString)
        } else {
            coordinator.start(deeplink: nil)
        }

        window.makeKeyAndVisible()

        self.launchCoordinator = coordinator
        self.window = window
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        _ = launchCoordinator?.handleDeeplink(deeplink: url.absoluteString)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else { return }
        _ = launchCoordinator?.handleDeeplink(deeplink: url.absoluteString)
    }
}
