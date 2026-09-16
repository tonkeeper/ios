import SwiftUI
import TKUIKit
import UIKit

@MainActor
public final class DisconnectDappToastPresenter {
    private static var window: UIWindow?

    public static func presentToast(
        model: DisconnectDappToastModel,
        windowScene: UIWindowScene
    ) {
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
