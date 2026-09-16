import UIKit

public final class TKSensitiveContentController {
    public static var didTakeScreenshot: (() -> Void)?

    private weak var viewController: UIViewController?
    private weak var windowScene: UIWindowScene?
    private var title: String = ""
    private var observers = [NSObjectProtocol]()
    private var inactiveBlurWindow: UIWindow?
    private var isAppInactive = false
    private var isSceneInactive = false
    private var needsScreenshotWarningOnForeground = false

    public init() {}

    deinit {
        stop()
    }

    public func start(
        in viewController: UIViewController,
        title: String
    ) {
        stop()
        self.viewController = viewController
        self.title = title
        windowScene = viewController.view.window?.windowScene
        isAppInactive = UIApplication.shared.applicationState != .active
        if let windowScene = windowScene {
            isSceneInactive = windowScene.activationState != .foregroundActive
        } else {
            isSceneInactive = false
        }

        addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification
        ) { [weak self] _ in
            Self.didTakeScreenshot?()
            self?.handleScreenshot()
        }
        addObserver(
            forName: UIScreen.capturedDidChangeNotification
        ) { [weak self] _ in
            self?.showWarningIfScreenIsCaptured()
        }
        addObserver(
            forName: UIApplication.willResignActiveNotification
        ) { [weak self] _ in
            self?.isAppInactive = true
            self?.updateInactiveBlur()
        }
        addObserver(
            forName: UIApplication.didBecomeActiveNotification
        ) { [weak self] _ in
            self?.isAppInactive = false
            self?.updateInactiveBlur()
            self?.showPendingScreenshotWarningIfNeeded()
        }
        addObserver(
            forName: UIScene.willDeactivateNotification
        ) { [weak self] notification in
            guard self?.isCurrentSceneNotification(notification) == true else { return }
            self?.isSceneInactive = true
            self?.updateInactiveBlur()
        }
        addObserver(
            forName: UIScene.didActivateNotification
        ) { [weak self] notification in
            guard self?.isCurrentSceneNotification(notification) == true else { return }
            self?.isSceneInactive = false
            self?.updateInactiveBlur()
            self?.showPendingScreenshotWarningIfNeeded()
        }

        updateInactiveBlur()
        showWarningIfScreenIsCaptured()
    }

    public func stop() {
        ToastPresenter.hideAll()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        hideInactiveBlur()
        viewController = nil
        windowScene = nil
        isAppInactive = false
        isSceneInactive = false
        needsScreenshotWarningOnForeground = false
    }
}

private extension TKSensitiveContentController {
    func addObserver(
        forName name: Notification.Name,
        using block: @escaping (Notification) -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main,
            using: block
        )
        observers.append(observer)
    }

    func handleScreenshot() {
        needsScreenshotWarningOnForeground = true
        showWarning()
    }

    func showPendingScreenshotWarningIfNeeded() {
        guard needsScreenshotWarningOnForeground else { return }
        guard !isAppInactive, !isSceneInactive else { return }
        needsScreenshotWarningOnForeground = false
        showWarning()
    }

    func showWarning() {
        ToastPresenter.showToast(
            configuration: ToastPresenter.Configuration(
                title: title,
                shape: .rect,
                numberOfLines: 0,
                backgroundColor: .Background.contentTint,
                foregroundColor: .Text.primary,
                dismissRule: .duration(5),
                topOffset: toastTopOffset()
            )
        )
    }

    func showWarningIfScreenIsCaptured() {
        guard UIScreen.main.isCaptured else { return }
        showWarning()
    }

    func updateInactiveBlur() {
        if isAppInactive || isSceneInactive {
            showInactiveBlur()
        } else {
            hideInactiveBlur()
        }
    }

    func showInactiveBlur() {
        guard inactiveBlurWindow == nil,
              let windowScene = windowScene ?? viewController?.view.window?.windowScene ?? UIApplication.keyWindowScene
        else {
            return
        }

        let blurWindow = UIWindow(windowScene: windowScene)
        blurWindow.windowLevel = .alert
        blurWindow.isUserInteractionEnabled = false
        blurWindow.rootViewController = UIViewController()
        blurWindow.rootViewController?.view = TKSecureInactiveBlurView()
        blurWindow.isHidden = false
        inactiveBlurWindow = blurWindow
    }

    func hideInactiveBlur() {
        inactiveBlurWindow?.isHidden = true
        inactiveBlurWindow = nil
    }

    func toastTopOffset() -> CGFloat {
        guard let view = viewController?.view,
              let window = view.window
        else {
            return 0
        }

        let viewMinY = view.convert(view.bounds.origin, to: window).y
        return max(0, viewMinY - window.safeAreaInsets.top)
    }

    func isCurrentSceneNotification(_ notification: Notification) -> Bool {
        guard let windowScene else { return true }
        return notification.object as? UIWindowScene === windowScene
    }
}
