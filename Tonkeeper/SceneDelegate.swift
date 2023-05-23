//
//  SceneDelegate.swift
//  Tonkeeper
//
//  Created by Grigory on 22.5.23..
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  
  var window: UIWindow?
  var appCoordinator: AppCoordinator?

  func scene(_ scene: UIScene,
             willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    
    let window = UIWindow(windowScene: windowScene)
    
    let appCoordinator = buildAppCoordinator(window: window)
    appCoordinator.start()
    
    window.makeKeyAndVisible()
    
    self.appCoordinator = appCoordinator
    self.window = window
  }
}

private extension SceneDelegate {
  func buildAppCoordinator(window: UIWindow) -> AppCoordinator {
    let router = WindowRouter(window: window)
    let appAssembly = AppAssembly()
    let coordinator = AppCoordinator(router: router,
                                     appAssembly: appAssembly)
    return coordinator
  }
}

