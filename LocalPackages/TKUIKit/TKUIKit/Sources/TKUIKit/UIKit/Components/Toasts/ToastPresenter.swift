import UIKit

public final class ToastPresenter {
    public static var windowLevel: UIWindow.Level = .normal

    public struct Configuration {
        public enum DismissRule {
            case none
            case `default`
            case duration(TimeInterval)
        }

        public enum Placement {
            case `default`
            case navigationBar
        }

        public var title: String
        public var shape: ToastView.Model.Shape
        public var isActivity: Bool
        public var icon: UIImage?
        public var iconTintColor: UIColor?
        public var numberOfLines: Int
        public var backgroundColor: UIColor
        public var foregroundColor: UIColor
        public var dismissRule: DismissRule
        public var placement: Placement
        public var topOffset: CGFloat
        public var allowsSwipeToDismiss: Bool
        public var onTap: (() -> Void)?

        public init(
            title: String,
            shape: ToastView.Model.Shape = .oval,
            isActivity: Bool = false,
            icon: UIImage? = nil,
            iconTintColor: UIColor? = nil,
            numberOfLines: Int = ToastView.Model.defaultNumberOfLines,
            backgroundColor: UIColor = .Background.contentTint,
            foregroundColor: UIColor = .Text.primary,
            dismissRule: DismissRule = .default,
            placement: Placement = .default,
            topOffset: CGFloat = 0,
            allowsSwipeToDismiss: Bool = false,
            onTap: (() -> Void)? = nil
        ) {
            self.title = title
            self.shape = shape
            self.isActivity = isActivity
            self.icon = icon
            self.iconTintColor = iconTintColor
            self.numberOfLines = numberOfLines
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.dismissRule = dismissRule
            self.placement = placement
            self.topOffset = topOffset
            self.allowsSwipeToDismiss = allowsSwipeToDismiss
            self.onTap = onTap
        }

        var viewModel: ToastView.Model {
            ToastView.Model(
                title: title,
                shape: shape,
                isActivity: isActivity,
                icon: icon,
                iconTintColor: iconTintColor,
                numberOfLines: numberOfLines,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor
            )
        }
    }

    private static var queue = [Configuration]()
    private static var isPresenting = false

    private static var toastWindow: UIWindow?
    private static var toastView: ToastView?
    private static var toastViewTopConstraint: NSLayoutConstraint?
    private static var dispatchItem: DispatchWorkItem?

    private init() {}

    public static func showToast(configuration: Configuration) {
        if isPresenting {
            guard let index = queue.firstIndex(where: { $0.title == configuration.title }) else {
                queue.append(configuration)
                return
            }

            switch index {
            case 0:
                queue[0] = configuration
                reconfigureActiveToast(with: configuration)
                scheduleAutoDismiss(for: configuration.dismissRule)
            default:
                return
            }
        } else {
            queue.append(configuration)
            show(configuration: configuration)
        }
    }

    public static func hideToast(completion: (() -> Void)? = nil) {
        if !queue.isEmpty {
            queue.removeFirst()
        }
        clearInteractionHandlers()
        hideToastView {
            teardownCurrentToast()
            showNextIfPossible()
            completion?()
        }
    }

    public static func hideAll() {
        queue.removeAll()
        hideToast()
    }

    private static func showNextIfPossible() {
        guard !queue.isEmpty else { return }
        show(configuration: queue[0])
    }

    private static func show(configuration: Configuration) {
        scheduleAutoDismiss(for: configuration.dismissRule, includeShowAnimationDelay: true)
        showToastView(configuration: configuration)
    }

    private static func scheduleAutoDismiss(
        for dismissRule: Configuration.DismissRule,
        includeShowAnimationDelay: Bool = false
    ) {
        dispatchItem?.cancel()

        let duration: TimeInterval
        switch dismissRule {
        case .none:
            return
        case .default:
            duration = .defaultPresentationDuration
        case let .duration(timeInterval):
            duration = timeInterval
        }

        let delay = includeShowAnimationDelay ? duration + .animationDuration : duration
        let dispatchItem = DispatchWorkItem {
            hideToast()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: dispatchItem)
        self.dispatchItem = dispatchItem
    }

    private static func reconfigureActiveToast(with configuration: Configuration) {
        guard let toastView = toastView else { return }

        toastView.didBeginSwipe = nil
        toastView.didCancelSwipe = nil
        toastView.didSwipeToDismiss = nil
        if let pan = toastView.panGestureRecognizer,
           pan.state == .began || pan.state == .changed
        {
            pan.isEnabled = false
            pan.isEnabled = true
        }

        toastView.transform = .identity
        toastView.alpha = 1
        toastView.layer.removeAllAnimations()

        toastView.configure(model: configuration.viewModel)
        bindInteractions(to: toastView, configuration: configuration)

        let toastHeight = toastView.intrinsicContentSize.height
        let newConstant = shownTopConstant(
            placement: configuration.placement,
            toastHeight: toastHeight,
            topOffset: configuration.topOffset
        )
        if toastViewTopConstraint?.constant != newConstant {
            toastViewTopConstraint?.constant = newConstant
            UIView.animate(
                withDuration: .animationDuration,
                delay: 0,
                options: .curveEaseInOut,
                animations: {
                    toastView.superview?.layoutIfNeeded()
                }
            )
        }
    }

    private static func bindInteractions(
        to toastView: ToastView,
        configuration: Configuration
    ) {
        if configuration.allowsSwipeToDismiss {
            toastView.didBeginSwipe = {
                dispatchItem?.cancel()
                dispatchItem = nil
            }
            toastView.didCancelSwipe = {
                guard let configuration = queue.first else { return }
                scheduleAutoDismiss(for: configuration.dismissRule)
            }
            toastView.didSwipeToDismiss = {
                dismissToastBySwipe()
            }
        } else {
            toastView.didBeginSwipe = nil
            toastView.didCancelSwipe = nil
            toastView.didSwipeToDismiss = nil
        }
        if let onTap = configuration.onTap {
            toastView.didTap = {
                onTap()
                guard let configuration = queue.first else { return }
                scheduleAutoDismiss(for: configuration.dismissRule)
            }
        } else {
            toastView.didTap = nil
        }
    }

    private static func dismissToastBySwipe() {
        dispatchItem?.cancel()
        dispatchItem = nil
        clearInteractionHandlers()

        if !queue.isEmpty {
            queue.removeFirst()
        }

        teardownCurrentToast()
        showNextIfPossible()
    }

    private static func clearInteractionHandlers() {
        toastView?.didBeginSwipe = nil
        toastView?.didCancelSwipe = nil
        toastView?.didSwipeToDismiss = nil
        toastView?.didTap = nil
    }

    private static func teardownCurrentToast() {
        toastWindow = nil
        toastView?.removeFromSuperview()
        toastView = nil
        toastViewTopConstraint = nil
        isPresenting = false
    }

    private static func shownTopConstant(
        placement: Configuration.Placement,
        toastHeight: CGFloat,
        topOffset: CGFloat
    ) -> CGFloat {
        let baseOffset: CGFloat
        switch placement {
        case .default:
            baseOffset = 0
        case .navigationBar:
            let navigationBarHeight: CGFloat = 64
            baseOffset = (navigationBarHeight - toastHeight) / 2
        }
        return baseOffset + topOffset
    }

    private static func hiddenTopConstant(toastHeight: CGFloat) -> CGFloat {
        -toastHeight - .hideInset
    }

    private static func hideToastView(completion: @escaping () -> Void) {
        guard let toastWindow = toastWindow,
              let toastView = toastView
        else {
            completion()
            return
        }

        toastView.transform = .identity
        toastViewTopConstraint?.constant = hiddenTopConstant(toastHeight: toastView.intrinsicContentSize.height)
        UIView.animate(
            withDuration: .animationDuration,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
                toastView.alpha = 0
                toastWindow.layoutIfNeeded()
            },
            completion: { _ in
                completion()
            }
        )
    }

    private static func showToastView(
        configuration: Configuration,
        completion: (() -> Void)? = nil
    ) {
        let scene = UIApplication.keyWindowScene
        guard let scene = scene else { return }
        let toastWindow = TKPassthroughWindow(windowScene: scene)
        toastWindow.windowLevel = ToastPresenter.windowLevel
        let viewController = BasicViewController()
        viewController.view.alpha = 0
        toastWindow.rootViewController = viewController
        toastWindow.makeKeyAndVisible()
        self.toastWindow = toastWindow

        isPresenting = true

        let toastView = ToastView(model: configuration.viewModel)
        toastView.alpha = 0
        bindInteractions(to: toastView, configuration: configuration)
        self.toastView = toastView
        toastWindow.addSubview(toastView)
        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.centerXAnchor.constraint(
            equalTo: toastWindow.centerXAnchor
        ).isActive = true
        toastView.leftAnchor.constraint(
            greaterThanOrEqualTo: toastWindow.leftAnchor,
            constant: 20
        ).withPriority(.defaultHigh).isActive = true
        toastView.rightAnchor.constraint(
            lessThanOrEqualTo: toastWindow.rightAnchor,
            constant: -20
        ).withPriority(.defaultHigh).isActive = true
        let toastHeight = toastView.intrinsicContentSize.height
        let topConstraint = toastView.topAnchor.constraint(
            equalTo: toastWindow.safeAreaLayoutGuide.topAnchor,
            constant: hiddenTopConstant(toastHeight: toastHeight)
        )
        toastViewTopConstraint = topConstraint
        topConstraint.isActive = true
        toastWindow.layoutIfNeeded()
        toastWindow.setNeedsLayout()

        topConstraint.constant = shownTopConstant(
            placement: configuration.placement,
            toastHeight: toastHeight,
            topOffset: configuration.topOffset
        )
        UIView.animate(
            withDuration: .animationDuration,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
                toastView.alpha = 1
                toastWindow.layoutIfNeeded()
            },
            completion: { _ in
                completion?()
            }
        )
    }
}

private extension CGFloat {
    static let hideInset: CGFloat = 20
}

private extension TimeInterval {
    static let animationDuration: TimeInterval = 0.2
    static let defaultPresentationDuration: TimeInterval = 2.0
}
