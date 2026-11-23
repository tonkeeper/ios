import ObjectiveC.runtime
import TKUIKit
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
        lottieController?.uninstall()
        lottieController = nil
        guard let tabBarController = self as? TKTabBarController else { return }

        tabBarController.didChangeStyle = { [weak tabBarController] _ in
            tabBarController?.configureAnimatedTabBarItems(items: items)
        }
        let lottieController: LottieTabBarControlling? = switch tabBarController.style {
        case .custom:
            DefaultLottieTabBarController(tabBarController: tabBarController, items: items)
        case .systemHorizontal, .systemVertical:
            ItemImageLottieTabBarController(tabBarController: tabBarController, items: items)
        }
        self.lottieController = lottieController?.denyingTapOnSelectedItem()
    }

    func playAnimatedTabBarItem(at index: Int) {
        lottieController?.playAnimation(at: index)
    }
}
