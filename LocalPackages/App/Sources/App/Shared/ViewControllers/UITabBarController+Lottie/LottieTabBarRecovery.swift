import Lottie
import UIKit

enum LottieTabBarRecovery {
    static let notificationNames: [Notification.Name] = [
        UIApplication.willEnterForegroundNotification,
        UIApplication.didBecomeActiveNotification,
    ]

    @MainActor
    static func refreshLayout(of tabBarController: UITabBarController) {
        tabBarController.tabBar.setNeedsLayout()
        tabBarController.tabBar.layoutIfNeeded()
    }

    @MainActor
    static func resetPlayback(of animationView: LottieAnimationView) {
        animationView.stop()
        animationView.currentProgress = 0
        animationView.reloadImages()
    }
}
