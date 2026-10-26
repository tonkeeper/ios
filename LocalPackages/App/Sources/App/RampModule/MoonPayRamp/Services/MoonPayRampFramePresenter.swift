import MoonPay
import TKUIKit
import UIKit

@MainActor
protocol MoonPayRampFramePresenting: AnyObject {
    func runHeadless(
        _ frame: MoonPayFrame,
        environment: MoonPayEnvironment,
        onEvent: @escaping (MoonPayFrameEvent) -> Void,
        onFailure: @escaping (MoonPayFrameError) -> Void
    ) -> MoonPayRampFrameHandle

    func presentModal(
        _ frame: MoonPayFrame,
        environment: MoonPayEnvironment,
        onEvent: @escaping (MoonPayFrameEvent) -> Void,
        onFailure: @escaping (MoonPayFrameError) -> Void,
        onClose: @escaping () -> Void
    ) -> MoonPayRampFrameHandle
}

@MainActor
final class MoonPayRampFrameHandle {
    private let dismissAction: () -> Void

    init(dismiss: @escaping () -> Void) {
        dismissAction = dismiss
    }

    func dismiss() {
        dismissAction()
    }
}

@MainActor
final class MoonPayRampFramePresenter: MoonPayRampFramePresenting {
    weak var hostViewController: UIViewController?
    private var headlessControllers: [String: MoonPayFrameViewController] = [:]

    func presentModal(
        _ frame: MoonPayFrame,
        environment: MoonPayEnvironment,
        onEvent: @escaping (MoonPayFrameEvent) -> Void,
        onFailure: @escaping (MoonPayFrameError) -> Void,
        onClose: @escaping () -> Void
    ) -> MoonPayRampFrameHandle {
        let controller = MoonPayFrameViewController(frame: frame, environment: environment)
        controller.didReceiveEvent = onEvent
        controller.didFailToLoad = onFailure

        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .fullScreen
        navigationController.configureTransparentAppearance()
        controller.setupRightCloseButton { [weak navigationController] in
            navigationController?.dismiss(animated: true, completion: onClose)
        }
        hostViewController?.topPresentedViewController().present(navigationController, animated: true)
        return MoonPayRampFrameHandle { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }
    }

    func runHeadless(
        _ frame: MoonPayFrame,
        environment: MoonPayEnvironment,
        onEvent: @escaping (MoonPayFrameEvent) -> Void,
        onFailure: @escaping (MoonPayFrameError) -> Void
    ) -> MoonPayRampFrameHandle {
        guard let host = hostViewController else {
            onFailure(.loadFailed("host is not on screen"))
            return MoonPayRampFrameHandle {}
        }
        let controller = MoonPayFrameViewController(frame: frame, environment: environment)
        let channelId = controller.channelId
        controller.didReceiveEvent = { [weak self] event in
            onEvent(event)
            switch event {
            case .complete, .error:
                self?.removeHeadless(channelId)
            default:
                break
            }
        }
        controller.didFailToLoad = { [weak self] error in
            onFailure(error)
            self?.removeHeadless(channelId)
        }

        // A WKWebView outside the window hierarchy may not run scripts.
        host.addChild(controller)
        controller.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        controller.view.alpha = 0.01
        controller.view.isUserInteractionEnabled = false
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        headlessControllers[channelId] = controller
        return MoonPayRampFrameHandle { [weak self] in
            self?.removeHeadless(channelId)
        }
    }

    private func removeHeadless(_ channelId: String) {
        guard let controller = headlessControllers.removeValue(forKey: channelId) else { return }
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }
}
