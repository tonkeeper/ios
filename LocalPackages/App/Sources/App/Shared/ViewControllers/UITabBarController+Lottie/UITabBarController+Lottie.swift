import ObjectiveC.runtime
import UIKit

private var lottieControllerKey: UInt8 = 0

extension UITabBarController {
    @MainActor
    private var lottieController: (NSObject & LottieTabBarControlling)? {
        get {
            objc_getAssociatedObject(self, &lottieControllerKey) as? (NSObject & LottieTabBarControlling)
        }
        set {
            objc_setAssociatedObject(self, &lottieControllerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func configureAnimatedTabBarItems(items: [LottieResourceConvertible]) {
        if let lottieController {
            lottieController.uninstall()
        }
        let lottieController = DefaultLottieTabBarController(
            tabBarController: self,
            items: items
        )
        self.lottieController = lottieController?.denyingTapOnSelectedItem()
    }

    func playAnimatedTabBarItem(at index: Int) {
        lottieController?.playAnimation(at: index)
    }
}
