//
//  SceneDelegate.swift
//  Tonkeeper
//
//  Created by Grigory on 22.5.23..
//

import UIKit
import TKCore
import WalletCoreKeeper

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  
  var window: UIWindow?
  var appCoordinator: AppCoordinator?
  let appAssembly = AppAssembly()

  func scene(_ scene: UIScene,
             willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    
    let window = UIWindow(windowScene: windowScene)
    
    let appCoordinator = buildAppCoordinator(window: window)
    appCoordinator.start(deeplink: getDeeplink(urlContexts: connectionOptions.urlContexts))
    
    window.makeKeyAndVisible()
    
    self.appCoordinator = appCoordinator
    self.window = window
  }
  
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let deeplink = getDeeplink(urlContexts: URLContexts) else { return }
    appCoordinator?.handleDeeplink(deeplink)
  }
  
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let deeplink = getDeeplink(url: userActivity.webpageURL) else { return }
    appCoordinator?.handleDeeplink(deeplink)
  }
}

private extension SceneDelegate {
  func buildAppCoordinator(window: UIWindow) -> AppCoordinator {
    let router = WindowRouter(window: window)
    let coordinator = AppCoordinator(router: router,
                                     appAssembly: appAssembly,
                                     appStateTracker: appAssembly.coreAssembly.appStateTracker)
    return coordinator
  }
  
  func getDeeplink(urlContexts: Set<UIOpenURLContext>) -> Deeplink? {
    getDeeplink(url: urlContexts.first?.url)
  }
  
  func getDeeplink(url: URL?) -> Deeplink? {
    guard let url = url else { return nil }
    let deeplinkParser = appAssembly.walletCoreAssembly.deeplinkParser(
      handlers: [appAssembly.walletCoreAssembly.tonConnectDeeplinkHandler, appAssembly.walletCoreAssembly.tonDeeplinkHandler]
    )
    guard let deeplink = try? deeplinkParser.parse(string: url.absoluteString) else { return nil }
    return deeplink
  }
}

extension WalletCoreKeeper.Deeplink: Deeplink {}
