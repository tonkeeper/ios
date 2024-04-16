//
//  SceneDelegate.swift
//  Tonkeeper
//
//  Created by Grigory on 22.5.23..
//

import UIKit
import TKCore
import App
import TKCoordinator

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  
  var window: UIWindow?
  var appCoordinator: App.AppCoordinator?
  let appAssembly = AppAssembly()

  func scene(_ scene: UIScene,
             willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    
    let window = UIWindow(windowScene: windowScene)
    
    let coordinator = App.AppCoordinator(router: TKCoordinator.WindowRouter(window: window),
    coreAssembly: CoreAssembly(featureFlagsProvider: FeatureFlagsProvider(isMarketRegionPickerAvailable: {
      FirebaseConfigurator.configurator.isMarketRegionPickerAvailable
    })))
    
    if let deeplink = connectionOptions.urlContexts.first?.url.absoluteString {
      coordinator.start(deeplink: deeplink)
    } else if let universalLink = connectionOptions.userActivities.first(where: { $0.webpageURL != nil })?.webpageURL {
      coordinator.start(deeplink: universalLink.absoluteString)
    } else {
      coordinator.start(deeplink: nil)
    }
    
    window.makeKeyAndVisible()
    
    self.appCoordinator = coordinator
    self.window = window
  }
  
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    appCoordinator?.handleDeeplink(deeplink: url.absoluteString)
  }
  
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let url = userActivity.webpageURL else { return }
    appCoordinator?.handleDeeplink(deeplink: url.absoluteString)
  }
}
