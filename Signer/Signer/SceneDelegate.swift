//
//  SceneDelegate.swift
//  Signer
//
//  Created by Grigory Serebryanyy on 05.12.2023.
//

import UIKit
import TKCoordinator
import SignerCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  
  var window: UIWindow?
  private var appCoordinator: AppCoordinator?
  
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    
    let window = UIWindow(windowScene: windowScene)
    let coordinator = AppCoordinator(
      router: WindowRouter(window: window),
      signerCoreAssembly: SignerCore.Assembly()
    )
    
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
    _ = appCoordinator?.handleDeeplink(deeplink: url.absoluteString)
  }
  
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let url = userActivity.webpageURL else { return }
    _ = appCoordinator?.handleDeeplink(deeplink: url.absoluteString)
  }
}
