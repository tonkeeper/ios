//
//  SceneDelegate.swift
//  Signer
//
//  Created by Grigory Serebryanyy on 05.12.2023.
//

import UIKit
import SignerCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  private var appCoordinator: AppCoordinator?
  
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    
    let window = UIWindow(windowScene: windowScene)
    let coordinator = AppCoordinator(
      router: .init(window: window),
      signerCoreAssembly: SignerCore.Assembly()
    )
    window.makeKeyAndVisible()
    coordinator.start()
    
    self.appCoordinator = coordinator
    self.window = window
  }
}
