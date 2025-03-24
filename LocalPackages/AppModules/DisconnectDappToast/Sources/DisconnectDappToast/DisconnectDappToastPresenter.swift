import UIKit
import SwiftUI
import TKUIKit

@MainActor
public final class DisconnectDappToastPresenter {
  
  private static var window: UIWindow?
  
  public static func presentSignRaw(
    model: DisconnectDappToastModel,
    windowScene: UIWindowScene) {
      let window = TKPassthroughWindow(windowScene: windowScene)
      window.makeKeyAndVisible()
      self.window = window
      
      let viewController = DisconnectDappToastViewController()
      window.rootViewController = viewController
      
      viewController.didHide = {
        self.window = nil
      }
      
      viewController.present(
        model: model
      )
    }
}
