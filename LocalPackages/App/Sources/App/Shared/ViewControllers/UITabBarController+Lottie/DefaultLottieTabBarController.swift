import Lottie
import SnapKit
import TKUIKit
import UIKit

@MainActor
final class DefaultLottieTabBarController: NSObject {
    private final class LottieTabView {
        let animationView: LottieAnimationView
        weak var iconContainer: UIView?

        init(animationView: LottieAnimationView, iconContainer: UIView? = nil) {
            self.animationView = animationView
            self.iconContainer = iconContainer
        }
    }

    private weak var tabBarController: TKTabBarController?
    private let animatedViews: [LottieTabView]

    init?(
        tabBarController: UITabBarController,
        items: [LottieResourceConvertible]
    ) {
        guard let tabBarController = tabBarController as? TKTabBarController else {
            return nil
        }
        self.tabBarController = tabBarController

        let resources = items.compactMap(\.asLottieResource)
        guard resources.count == items.count else {
            return nil
        }

        self.animatedViews = resources
            .map { resource in
                let animationView = LottieAnimationView(
                    name: resource.name,
                    bundle: resource.bundle,
                    subdirectory: resource.subdirectory
                )
                animationView.loopMode = .playOnce
                animationView.contentMode = .center
                animationView.backgroundBehavior = .pauseAndRestore
                animationView.isUserInteractionEnabled = false
                animationView.isAccessibilityElement = false
                return LottieTabView(animationView: animationView)
            }

        super.init()
        startAppStateObservation()
        startTabBarLayoutObservation()
        installAnimationViewsIfNeeded()
        updateSelection(selectedIndex: tabBarController.selectedIndex)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension DefaultLottieTabBarController: LottieTabBarControlling {
    func uninstall() {
        NotificationCenter.default.removeObserver(self)
        tabBarController?.didLayoutTabBar = nil
        for (index, view) in animatedViews.enumerated() {
            detachAnimationView(view, at: index)
            view.animationView.stop()
        }
    }

    func playAnimation(at index: Int) {
        installAnimationViewsIfNeeded()

        for animationView in animatedViews.map(\.animationView) {
            animationView.stop()
            animationView.currentProgress = 0
        }

        updateSelection(selectedIndex: index)
        animatedViews[safe: index]?.animationView.play()
    }
}

extension DefaultLottieTabBarController {
    private func startAppStateObservation() {
        for name in LottieTabBarRecovery.notificationNames {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(recoverAfterAppStateChange),
                name: name,
                object: nil
            )
        }
    }

    private func startTabBarLayoutObservation() {
        tabBarController?.didLayoutTabBar = { [weak self] in
            self?.installAnimationViewsIfNeeded()
        }
    }

    private func installAnimationViewsIfNeeded() {
        guard let tabBarController else { return }

        for (index, view) in animatedViews.enumerated() {
            guard let iconContainer = tabBarController.tabBarIconContainer(at: index) else {
                detachAnimationView(view, at: index)
                continue
            }

            let hidesStaticIcon = view.animationView.animation != nil
            guard view.animationView.superview !== iconContainer else {
                tabBarController.setTabBarStaticIconHidden(hidesStaticIcon, at: index)
                iconContainer.bringSubviewToFront(view.animationView)
                continue
            }

            view.animationView.removeFromSuperview()
            iconContainer.addSubview(view.animationView)
            view.animationView.snp.remakeConstraints { make in
                make.edges.equalTo(iconContainer)
            }
            tabBarController.setTabBarStaticIconHidden(hidesStaticIcon, at: index)
            view.iconContainer = iconContainer
        }
    }

    private func detachAnimationView(_ view: LottieTabView, at index: Int) {
        tabBarController?.setTabBarStaticIconHidden(false, at: index)
        view.iconContainer = nil
        view.animationView.removeFromSuperview()
    }

    private func updateSelection(selectedIndex: Int) {
        tabBarController?.applyCustomBarSelection(at: selectedIndex)
        for (index, view) in animatedViews.enumerated() {
            let color = index == selectedIndex ? UIColor.TabBar.activeIcon : UIColor.TabBar.inactiveIcon
            let valueProvider = ColorValueProvider(color.asLottieColor)

            view.animationView.setValueProvider(
                valueProvider,
                keypath: AnimationKeypath(keypath: "**.Fill 1.Color")
            )
            view.animationView.setValueProvider(
                valueProvider,
                keypath: AnimationKeypath(keypath: "**.Stroke 1.Color")
            )
        }
    }

    @objc
    private func recoverAfterAppStateChange() {
        guard let tabBarController else { return }

        LottieTabBarRecovery.refreshLayout(of: tabBarController)
        installAnimationViewsIfNeeded()
        for view in animatedViews {
            LottieTabBarRecovery.resetPlayback(of: view.animationView)
        }
        updateSelection(selectedIndex: tabBarController.selectedIndex)
        for view in animatedViews {
            view.animationView.forceDisplayUpdate()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
