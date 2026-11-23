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

        /// What the toast tells: it sets the haptic, and on a toast with a status icon, the outcome animation.
        public enum Feedback {
            case neutral
            case success
            case failure
        }

        public var title: String
        public var subtitle: String?
        public var shape: ToastView.Model.Shape
        public var isActivity: Bool
        public var icon: UIImage?
        public var iconTintColor: UIColor?
        public var avatar: ToastView.Model.Avatar?
        public var showsDisclosure: Bool
        public var numberOfLines: Int
        public var backgroundColor: UIColor
        public var foregroundColor: UIColor
        public var feedback: Feedback
        /// Off when something else already played this outcome's haptic; the animation stays.
        public var playsHaptic = true
        public var dismissRule: DismissRule
        public var placement: Placement
        public var topOffset: CGFloat
        public var allowsSwipeToDismiss: Bool
        public var onTap: (() -> Void)?
        /// The user swiped the toast away. A pinned toast's owner learns it here, so it does not pin it again.
        public var onSwipeToDismiss: (() -> Void)?

        public init(
            title: String,
            subtitle: String? = nil,
            shape: ToastView.Model.Shape = .oval,
            isActivity: Bool = false,
            icon: UIImage? = nil,
            iconTintColor: UIColor? = nil,
            avatar: ToastView.Model.Avatar? = nil,
            showsDisclosure: Bool = false,
            numberOfLines: Int = ToastView.Model.defaultNumberOfLines,
            backgroundColor: UIColor = .Background.contentTint,
            foregroundColor: UIColor = .Text.primary,
            feedback: Feedback = .neutral,
            dismissRule: DismissRule = .default,
            placement: Placement = .default,
            topOffset: CGFloat = 0,
            allowsSwipeToDismiss: Bool = false,
            onTap: (() -> Void)? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
            self.shape = shape
            self.isActivity = isActivity
            self.icon = icon
            self.iconTintColor = iconTintColor
            self.avatar = avatar
            self.showsDisclosure = showsDisclosure
            self.numberOfLines = numberOfLines
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.feedback = feedback
            self.dismissRule = dismissRule
            self.placement = placement
            self.topOffset = topOffset
            self.allowsSwipeToDismiss = allowsSwipeToDismiss
            self.onTap = onTap
        }

        var viewModel: ToastView.Model {
            ToastView.Model(
                title: title,
                subtitle: subtitle,
                shape: shape,
                isActivity: isActivity,
                icon: icon,
                iconTintColor: iconTintColor,
                avatar: avatar,
                showsDisclosure: showsDisclosure,
                numberOfLines: numberOfLines,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor
            )
        }

        var isLoading: Bool {
            if isActivity { return true }
            if case .image(_, isLoading: true) = avatar { return true }
            return false
        }
    }

    private static var queue = [Configuration]()
    private static var pinned: Configuration?
    private static var isPresenting = false
    private static var isPinnedOnScreen = false
    private static var isHiding = false
    /// The toast on screen is sliding out after a swipe: a pin it shows is not brought back after another toast.
    private static var isSwipedAway = false
    /// A pinned toast plays its outcome once: not again when it comes back after another toast.
    private static var isPinnedOutcomeDue = false

    private static var toastWindow: UIWindow?
    private static var toastView: ToastView?
    private static var toastViewTopConstraint: NSLayoutConstraint?
    private static var dispatchItem: DispatchWorkItem?
    private static var showAnimator: UIViewPropertyAnimator?
    private static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    private init() {}

    public static func showToast(configuration: Configuration) {
        playHaptic(of: configuration)
        if isPinnedOnScreen {
            queue.append(configuration)
            hidePinnedToastView()
        } else if isPresenting {
            guard let index = queue.firstIndex(where: { $0.title == configuration.title }) else {
                queue.append(configuration)
                return
            }

            switch index {
            case 0:
                queue[0] = configuration
                guard !isHiding else { return }
                reconfigureActiveToast(with: configuration)
                playOutcome(of: configuration)
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
        guard !isPinnedOnScreen else {
            completion?()
            return
        }
        if !queue.isEmpty {
            queue.removeFirst()
        }
        guard !isHiding else {
            completion?()
            return
        }
        dispatchItem?.cancel()
        dispatchItem = nil
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

    /// Whether `showToast` with this title would update the toast on screen in place.
    public static func isShowingToast(title: String) -> Bool {
        isPresenting && !isPinnedOnScreen && !isHiding && queue.first?.title == title
    }

    /// Keeps the toast up until `unpinToast()`. Other toasts take its place while they are shown,
    /// `hideToast()` and `hideAll()` leave it, and pinning again updates it in place.
    public static func pinToast(configuration: Configuration) {
        pinned = configuration
        isPinnedOutcomeDue = !isPinnedOnScreen
        playHaptic(of: configuration)
        if isPinnedOnScreen {
            reconfigureActiveToast(with: configuration)
            playOutcome(of: configuration)
            scheduleAutoDismiss(for: configuration.dismissRule)
        } else if !isPresenting {
            showNextIfPossible()
        }
    }

    public static func unpinToast() {
        pinned = nil
        guard isPinnedOnScreen else { return }
        hidePinnedToastView()
    }

    private static func hidePinnedToastView() {
        if isSwipedAway {
            pinned = nil
        }
        isPinnedOnScreen = false
        dispatchItem?.cancel()
        dispatchItem = nil
        clearInteractionHandlers()
        hideToastView {
            teardownCurrentToast()
            showNextIfPossible()
        }
    }

    private static var shownConfiguration: Configuration? {
        isPinnedOnScreen ? pinned : queue.first
    }

    private static func showNextIfPossible() {
        if let configuration = queue.first {
            show(configuration: configuration)
        } else if let pinned {
            show(configuration: pinned, playsOutcome: isPinnedOutcomeDue)
            isPinnedOnScreen = isPresenting
            if isPinnedOnScreen {
                isPinnedOutcomeDue = false
            }
        }
    }

    private static func show(configuration: Configuration, playsOutcome: Bool = true) {
        scheduleAutoDismiss(for: configuration.dismissRule, includeShowAnimationDelay: true)
        showToastView(configuration: configuration)
        if playsOutcome {
            playOutcome(of: configuration)
        }
    }

    /// Plays when the toast is asked for, not when it shows, so it confirms the tap behind it even
    /// while another toast is up. A toast with a loader tells nothing yet, so it has no haptic.
    private static func playHaptic(of configuration: Configuration) {
        guard configuration.playsHaptic, !configuration.isLoading else { return }
        switch configuration.feedback {
        case .neutral:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .failure:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private static func playOutcome(of configuration: Configuration) {
        guard let toastView, !configuration.isLoading else { return }
        switch configuration.feedback {
        case .neutral:
            break
        case .success:
            toastView.playOutcome(isFailure: false)
        case .failure:
            toastView.playOutcome(isFailure: true)
        }
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

        let delay = includeShowAnimationDelay ? duration + .showDuration : duration
        let dispatchItem = DispatchWorkItem {
            if isPinnedOnScreen {
                unpinToast()
            } else {
                hideToast()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: dispatchItem)
        self.dispatchItem = dispatchItem
    }

    private static func reconfigureActiveToast(with configuration: Configuration) {
        guard let toastView = toastView else { return }

        toastView.didBeginSwipe = nil
        toastView.didCancelSwipe = nil
        toastView.didCommitSwipeDismiss = nil
        toastView.didSwipeToDismiss = nil
        isSwipedAway = false
        if let pan = toastView.panGestureRecognizer,
           pan.state == .began || pan.state == .changed
        {
            pan.isEnabled = false
            pan.isEnabled = true
        }

        stopShowAnimation()
        toastView.transform = .identity
        toastView.alpha = 1
        toastView.layer.removeAllAnimations()

        toastView.configure(model: configuration.viewModel, crossfades: true)
        bindInteractions(to: toastView, configuration: configuration)

        let toastHeight = toastView.intrinsicContentSize.height
        toastViewTopConstraint?.constant = shownTopConstant(
            placement: configuration.placement,
            toastHeight: toastHeight,
            topOffset: configuration.topOffset
        )
        guard !isReduceMotionEnabled else { return }
        let resize = UIViewPropertyAnimator(duration: .resizeDuration, timingParameters: UICubicTimingParameters.easeOutExpo)
        resize.addAnimations { toastView.superview?.layoutIfNeeded() }
        resize.startAnimation()
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
                guard let configuration = shownConfiguration else { return }
                scheduleAutoDismiss(for: configuration.dismissRule)
            }
            toastView.didCommitSwipeDismiss = {
                isSwipedAway = true
                configuration.onSwipeToDismiss?()
            }
            toastView.didSwipeToDismiss = {
                dismissToastBySwipe()
            }
        } else {
            toastView.didBeginSwipe = nil
            toastView.didCancelSwipe = nil
            toastView.didCommitSwipeDismiss = nil
            toastView.didSwipeToDismiss = nil
        }
        if let onTap = configuration.onTap {
            toastView.didTap = {
                onTap()
                guard let configuration = shownConfiguration else { return }
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

        if isPinnedOnScreen {
            pinned = nil
        } else if !queue.isEmpty {
            queue.removeFirst()
        }

        teardownCurrentToast()
        showNextIfPossible()
    }

    private static func clearInteractionHandlers() {
        toastView?.didBeginSwipe = nil
        toastView?.didCancelSwipe = nil
        toastView?.didCommitSwipeDismiss = nil
        toastView?.didSwipeToDismiss = nil
        toastView?.didTap = nil
    }

    private static func teardownCurrentToast() {
        toastWindow = nil
        toastView?.removeFromSuperview()
        toastView = nil
        toastViewTopConstraint = nil
        isPresenting = false
        isPinnedOnScreen = false
        isSwipedAway = false
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

    private static func hideToastView(completion: @escaping () -> Void) {
        guard toastWindow != nil, let toastView else {
            completion()
            return
        }

        isHiding = true
        stopShowAnimation()
        let reducesMotion = isReduceMotionEnabled
        let hide = UIViewPropertyAnimator(
            duration: reducesMotion ? .crossfadeDuration : .hideDuration,
            curve: .easeIn
        ) {
            toastView.alpha = 0
            toastView.transform = reducesMotion ? .identity : .slidOut
        }
        hide.addCompletion { _ in
            isHiding = false
            completion()
        }
        hide.startAnimation()
    }

    private static func showToastView(configuration: Configuration) {
        let scene = UIApplication.keyWindowScene
        guard let scene = scene else { return }
        let toastWindow = TKPassthroughWindow(windowScene: scene)
        toastWindow.windowLevel = ToastPresenter.windowLevel
        let viewController = BasicViewController()
        viewController.view.alpha = 0
        toastWindow.rootViewController = viewController
        // A key toast window would take the keyboard down on whatever screen is being typed in.
        toastWindow.isHidden = false
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
            constant: shownTopConstant(
                placement: configuration.placement,
                toastHeight: toastHeight,
                topOffset: configuration.topOffset
            )
        )
        toastViewTopConstraint = topConstraint
        topConstraint.isActive = true
        toastWindow.layoutIfNeeded()

        let show: UIViewPropertyAnimator
        if isReduceMotionEnabled {
            show = UIViewPropertyAnimator(duration: .crossfadeDuration, curve: .easeInOut)
        } else {
            toastView.transform = .slidOut
            show = UIViewPropertyAnimator(duration: .showDuration, timingParameters: UICubicTimingParameters.easeOutExpo)
        }
        show.addAnimations {
            toastView.alpha = 1
            toastView.transform = .identity
        }
        show.addCompletion { [weak show] _ in
            if showAnimator === show {
                showAnimator = nil
            }
        }
        show.startAnimation()
        showAnimator = show
    }

    /// Leaves the toast where the entrance has taken it, so a hide or a change starts from there
    /// and the entrance cannot finish over it.
    private static func stopShowAnimation() {
        guard let showAnimator, showAnimator.state == .active else { return }
        showAnimator.stopAnimation(true)
        self.showAnimator = nil
    }
}

private extension CGAffineTransform {
    static let slidOut = CGAffineTransform(translationX: 0, y: -8)
}

private extension UICubicTimingParameters {
    static var easeOutExpo: UICubicTimingParameters {
        UICubicTimingParameters(controlPoint1: CGPoint(x: 0.16, y: 1), controlPoint2: CGPoint(x: 0.3, y: 1))
    }
}

private extension TimeInterval {
    static let showDuration: TimeInterval = 0.3
    static let hideDuration: TimeInterval = 0.2
    static let resizeDuration: TimeInterval = 0.25
    static let crossfadeDuration: TimeInterval = 0.15
    static let defaultPresentationDuration: TimeInterval = 2.0
}
