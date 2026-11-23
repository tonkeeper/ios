import UIKit

public final class ToastView: TKPassthroughView, ConfigurableView {
    var didBeginSwipe: (() -> Void)?
    var didCancelSwipe: (() -> Void)?
    /// The swipe is let go past its threshold: the toast slides out, and `didSwipeToDismiss` follows once it is gone.
    var didCommitSwipeDismiss: (() -> Void)?
    var didSwipeToDismiss: (() -> Void)?
    var didTap: (() -> Void)?

    private(set) var panGestureRecognizer: UIPanGestureRecognizer?
    private var isSwipingUp = false
    private var swipeStartLocation: CGPoint = .zero

    let titleLabel = UILabel()
    let activityView = TKLoaderView(size: .small, style: .primary)
    let iconView = UIImageView()
    let avatarView = UIView()
    let avatarImageView = TKImageView()
    let avatarIconView = UIImageView()
    let progressBorderView = ToastProgressBorderView()
    let disclosureView = UIImageView(image: .TKUIKit.Icons.Size16.chevronRight)

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        return stackView
    }()

    // MARK: - Constraints

    private var topConstraint: NSLayoutConstraint?
    private var leftConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var rightConstraint: NSLayoutConstraint?
    private var titleHeightConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(model: Model) {
        self.model = model
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        // Intrinsic height stays one line unless preferredMaxLayoutWidth is set;
        // contentHeight() alone grows the toast without wrapping the title.
        // The title's width is read once the stack has laid it out: a stale one, left from a narrower
        // title before reconfiguring, would wrap a wider title instead of letting the toast grow.
        stackView.layoutIfNeeded()
        let preferredWidth = titleLabel.bounds.width
        guard preferredWidth > 0 else { return }
        updateTitlePreferredMaxLayoutWidth(preferredWidth)
        updateTitleHeightConstraint(forWidth: preferredWidth)
    }

    // MARK: - ConfigurableView

    private var model: Model

    public struct Model: Equatable {
        public static let defaultNumberOfLines = 4

        public enum Shape {
            case rect
            case oval

            var height: CGFloat {
                switch self {
                case .rect: return 44
                case .oval: return 48
                }
            }

            var cornerRadius: CGFloat {
                switch self {
                case .rect: return 12
                case .oval: return 24
                }
            }

            var insets: UIEdgeInsets {
                switch self {
                case .rect: return .init(top: 12, left: 16, bottom: 12, right: 16)
                case .oval: return .init(top: 14, left: 24, bottom: 14, right: 24)
                }
            }

            func insets(hasIcon: Bool) -> UIEdgeInsets {
                switch (self, hasIcon) {
                case (.oval, true):
                    return .init(top: 14, left: 16, bottom: 14, right: 24)
                default:
                    return insets
                }
            }
        }

        /// A 32 pt image in front of the text; it takes the place of `icon` and the activity indicator.
        public enum Avatar: Equatable {
            case image(TKImage, isLoading: Bool)
            case icon(UIImage, tintColor: UIColor)
        }

        let title: String
        let subtitle: String?
        let shape: Shape
        let isActivity: Bool
        let icon: UIImage?
        let iconTintColor: UIColor?
        let avatar: Avatar?
        let showsDisclosure: Bool
        let numberOfLines: Int
        let backgroundColor: UIColor
        let foregroundColor: UIColor

        init(
            title: String,
            subtitle: String? = nil,
            shape: Shape,
            isActivity: Bool,
            icon: UIImage? = nil,
            iconTintColor: UIColor? = nil,
            avatar: Avatar? = nil,
            showsDisclosure: Bool = false,
            numberOfLines: Int = Model.defaultNumberOfLines,
            backgroundColor: UIColor = .Background.contentTint,
            foregroundColor: UIColor = .Text.primary
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
        }

        var showsIcon: Bool {
            icon != nil && !isActivity && avatar == nil
        }

        var showsActivity: Bool {
            isActivity && avatar == nil
        }
    }

    public func configure(model: Model) {
        let needsSizeInvalidation = self.model != model
        self.model = model
        layer.cornerRadius = model.avatar == nil ? model.shape.cornerRadius : .avatarToastCornerRadius
        backgroundColor = model.backgroundColor
        layer.shadowColor = UIColor.black.withAlphaComponent(0.04).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        titleLabel.numberOfLines = model.numberOfLines
        titleLabel.lineBreakMode = titleLineBreakMode()
        titleLabel.attributedText = titleText(lineBreakMode: titleLineBreakMode())
        let titleWidth = titleWidthForLayout()
        updateTitlePreferredMaxLayoutWidth(titleWidth)
        updateTitleHeightConstraint(forWidth: titleWidth)

        if model.showsActivity {
            activityView.isHidden = false
            activityView.startAnimation()
        } else {
            activityView.isHidden = true
            activityView.stopAnimation()
        }

        iconView.image = model.icon
        iconView.tintColor = model.iconTintColor
        iconView.isHidden = !model.showsIcon

        configureAvatar(model.avatar)
        disclosureView.isHidden = !model.showsDisclosure

        let insets = contentInsets()
        topConstraint?.constant = insets.top
        leftConstraint?.constant = insets.left
        bottomConstraint?.constant = -insets.bottom
        rightConstraint?.constant = -insets.right

        // Invalidate after title height / insets are updated so contentHeight()
        // reads a consistent titleHeightConstraint (not a stale pre-layout value).
        if needsSizeInvalidation {
            invalidateIntrinsicContentSize()
        }
    }

    /// Shows `model` in place of the one on screen, crossfading the content instead of swapping it.
    func configure(model: Model, crossfades: Bool) {
        guard crossfades, model != self.model else {
            configure(model: model)
            return
        }
        UIView.transition(
            with: stackView,
            duration: .crossfadeDuration,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: { self.configure(model: model) }
        )
    }

    /// Marks the end of an operation on a toast with a status icon: the icon pops in and a ring in its
    /// tint flashes round the pill. A failure also shakes the content.
    func playOutcome(isFailure: Bool) {
        guard case let .icon(_, tintColor) = model.avatar, !UIAccessibility.isReduceMotionEnabled else { return }
        popAvatar()
        flashRing(color: tintColor, peakOpacity: isFailure ? 0.8 : 0.7)
        if isFailure {
            shakeContent()
        }
    }

    // MARK: - Layout

    override public var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: height()
        )
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else { return nil }
        let isInteractive = didTap != nil || didSwipeToDismiss != nil
        return isInteractive ? self : nil
    }
}

private extension ToastView {
    func height() -> CGFloat {
        if model.numberOfLines == 1, model.subtitle == nil, model.avatar == nil {
            return model.shape.height
        } else {
            return max(model.shape.height, ceil(contentHeight()))
        }
    }

    /// A subtitle is a second paragraph of the title label, so the two lines share one width and
    /// each is cut to a line of its own.
    func titleText(lineBreakMode: NSLineBreakMode) -> NSAttributedString {
        guard let subtitle = model.subtitle else {
            return model.title.withTextStyle(
                .label2,
                color: model.foregroundColor,
                alignment: .center,
                lineBreakMode: lineBreakMode
            )
        }
        let text = NSMutableAttributedString(
            attributedString: (model.title + "\n").withTextStyle(
                .label2,
                color: model.foregroundColor,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
        )
        text.append(
            subtitle.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
        )
        return text
    }

    func contentInsets() -> UIEdgeInsets {
        model.avatar == nil
            ? model.shape.insets(hasIcon: model.showsIcon || model.showsActivity)
            : .avatarToastInsets
    }

    func leadingSide() -> CGFloat {
        if model.avatar != nil {
            return .avatarSide
        }
        return model.showsIcon || model.showsActivity ? 16 : 0
    }

    func configureAvatar(_ avatar: Model.Avatar?) {
        avatarView.isHidden = avatar == nil
        switch avatar {
        case let .image(image, isLoading):
            avatarView.backgroundColor = .clear
            avatarImageView.isHidden = false
            avatarImageView.image = image
            avatarIconView.isHidden = true
            setProgressBorderVisible(isLoading)
        case let .icon(icon, tintColor):
            avatarView.backgroundColor = tintColor.withAlphaComponent(0.12)
            avatarImageView.isHidden = true
            avatarIconView.isHidden = false
            avatarIconView.image = icon
            avatarIconView.tintColor = tintColor
            setProgressBorderVisible(false)
        case nil:
            setProgressBorderVisible(false)
        }
    }

    func setProgressBorderVisible(_ isVisible: Bool) {
        progressBorderView.isHidden = !isVisible
        if isVisible {
            guard !progressBorderView.isAnimating else { return }
            progressBorderView.startAnimation()
        } else {
            progressBorderView.stopAnimation()
        }
    }

    func popAvatar() {
        avatarView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        avatarView.alpha = 0
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: .allowUserInteraction
        ) {
            self.avatarView.transform = .identity
        }
        let fadeIn = UIViewPropertyAnimator(
            duration: 0.2,
            timingParameters: UICubicTimingParameters(
                controlPoint1: CGPoint(x: 0.33, y: 1),
                controlPoint2: CGPoint(x: 0.68, y: 1)
            )
        )
        fadeIn.addAnimations { self.avatarView.alpha = 1 }
        fadeIn.startAnimation()
    }

    /// The ring shows after 0.1 s, holds its peak until 0.35 s and fades out by 0.9 s while it grows
    /// 2 pt out of the pill on every side.
    func flashRing(color: UIColor, peakOpacity: Float) {
        let ring = CALayer()
        ring.frame = bounds
        ring.cornerRadius = bounds.height / 2
        ring.borderWidth = 1.5
        ring.borderColor = color.resolvedColor(with: traitCollection).cgColor
        ring.opacity = 0

        let duration: CFTimeInterval = 0.9
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0, peakOpacity, peakOpacity, 0]
        opacity.keyTimes = [0, 0.1, 0.25, 0.35, duration].map { NSNumber(value: $0 / duration) }
        opacity.duration = duration

        let expandedBounds = bounds.insetBy(dx: -2, dy: -2)
        let expand = CABasicAnimation(keyPath: "bounds")
        expand.toValue = NSValue(cgRect: expandedBounds)
        let cornerRadius = CABasicAnimation(keyPath: "cornerRadius")
        cornerRadius.toValue = expandedBounds.height / 2
        for animation in [expand, cornerRadius] {
            animation.beginTime = 0.1
            animation.duration = duration - 0.1
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            animation.fillMode = .both
        }

        let group = CAAnimationGroup()
        group.animations = [opacity, expand, cornerRadius]
        group.duration = duration
        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        layer.addSublayer(ring)
        ring.add(group, forKey: nil)
        CATransaction.commit()
    }

    func shakeContent() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -4, 4, -2, 1, 0]
        shake.keyTimes = [0, 0.2, 0.4, 0.6, 0.8, 1]
        shake.timingFunctions = Array(
            repeating: CAMediaTimingFunction(controlPoints: 0.65, 0, 0.35, 1),
            count: 5
        )
        shake.duration = 0.4
        shake.beginTime = CACurrentMediaTime() + 0.05
        stackView.layer.add(shake, forKey: nil)
    }

    func titleLineBreakMode() -> NSLineBreakMode {
        // byTruncatingTail in the attributed paragraph style collapses
        // sizeThatFits to one line, so height is measured with wrapping
        // separately. Keep truncating on the displayed string so overflow
        // past numberOfLines still shows a trailing ellipsis.
        model.numberOfLines == 0 ? .byWordWrapping : .byTruncatingTail
    }

    func titleWidthForLayout() -> CGFloat {
        let insets = contentInsets()
        let sideInset: CGFloat = 20
        let maxWidth = UIScreen.main.bounds.width - sideInset * 2
        let leadingSide = leadingSide()
        let leadingSpacing = model.avatar != nil ? CGFloat.avatarSpacing : stackView.spacing
        let leadingWidth = leadingSide > 0 ? leadingSide + leadingSpacing : 0
        let disclosureWidth = model.showsDisclosure ? 16 + stackView.spacing : 0
        return maxWidth - insets.left - insets.right - leadingWidth - disclosureWidth
    }

    func updateTitlePreferredMaxLayoutWidth(_ width: CGFloat) {
        guard width > 0, titleLabel.preferredMaxLayoutWidth != width else { return }
        titleLabel.preferredMaxLayoutWidth = width
        titleLabel.invalidateIntrinsicContentSize()
    }

    func updateTitleHeightConstraint(forWidth width: CGFloat) {
        let height = measuredTitleHeight(forWidth: width)
        guard titleHeightConstraint?.constant != height else { return }
        titleHeightConstraint?.constant = height
        invalidateIntrinsicContentSize()
    }

    func measuredTitleHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return TKTextStyle.label2.lineHeight }
        // Measure with wrapping so multi-line height is correct even when the
        // displayed attributed text uses byTruncatingTail for the ellipsis.
        let measuringLabel = UILabel()
        measuringLabel.numberOfLines = model.numberOfLines
        measuringLabel.attributedText = titleText(lineBreakMode: .byWordWrapping)
        return ceil(
            measuringLabel.sizeThatFits(
                CGSize(width: width, height: .greatestFiniteMagnitude)
            ).height
        )
    }

    func contentHeight() -> CGFloat {
        let insets = contentInsets()
        // Prefer titleHeightConstraint over remeasuring: updateTitleHeightConstraint
        // may have sized from laid-out bounds while titleWidthForLayout() still
        // uses a UIScreen estimate, and those widths can disagree.
        let titleHeight = titleHeightConstraint?.constant
            ?? measuredTitleHeight(forWidth: titleWidthForLayout())
        return max(titleHeight, leadingSide()) + insets.top + insets.bottom
    }

    func setup() {
        iconView.contentMode = .scaleAspectFit
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        avatarView.layer.cornerRadius = .avatarSide / 2
        avatarView.clipsToBounds = true
        avatarImageView.corners = .circle
        avatarImageView.size = .none
        avatarIconView.contentMode = .scaleAspectFit
        disclosureView.tintColor = .Icon.secondary

        stackView.isUserInteractionEnabled = false
        addSubview(progressBorderView)
        addSubview(stackView)
        avatarView.addSubview(avatarImageView)
        avatarView.addSubview(avatarIconView)
        stackView.addArrangedSubview(avatarView)
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(activityView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(disclosureView)
        stackView.setCustomSpacing(.avatarSpacing, after: avatarView)

        setupConstraints()
        configure(model: model)
        setupSwipeToDismissGesture()
        setupTapGesture()
    }

    func setupTapGesture() {
        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapGesture(_:))
        )
        addGestureRecognizer(gesture)
    }

    @objc
    func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, didTap != nil else { return }
        didTap?()
    }

    func setupSwipeToDismissGesture() {
        let gesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePanGesture(_:))
        )
        gesture.delegate = self
        gesture.maximumNumberOfTouches = 1
        panGestureRecognizer = gesture
        addGestureRecognizer(gesture)
    }

    @objc
    func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        guard didSwipeToDismiss != nil else { return }

        switch recognizer.state {
        case .began:
            let movement = swipeMovement(of: recognizer)
            isSwipingUp = movement.y < 0 && abs(movement.y) > abs(movement.x)
            didBeginSwipe?()
        case .changed:
            let translation = recognizer.translation(in: self)
            transform = isSwipingUp
                ? CGAffineTransform(translationX: 0, y: min(translation.y, 0))
                : CGAffineTransform(translationX: translation.x, y: 0)
        case .ended:
            let offScreenTransform = swipeDismissTransform(
                translation: recognizer.translation(in: self),
                velocity: recognizer.velocity(in: self)
            )
            if let offScreenTransform {
                dismissBySwipe(to: offScreenTransform)
            } else {
                springBack()
            }
        case .cancelled:
            // The finger may still be down, so a cancelled swipe decides nothing.
            springBack()
        default:
            break
        }
    }

    func springBack() {
        didCancelSwipe?()
        UIView.animate(
            withDuration: SwipeConstants.resetAnimationDuration,
            delay: 0,
            usingSpringWithDamping: SwipeConstants.resetAnimationDamping,
            initialSpringVelocity: 0,
            options: .allowUserInteraction
        ) {
            self.transform = .identity
        }
    }

    /// Where the finger went before the pan began: the pan's own translation starts only once it is recognised.
    /// Measured in the window, which does not move while the toast slides in or resizes under the finger.
    func swipeMovement(of pan: UIPanGestureRecognizer) -> CGPoint {
        let location = pan.location(in: nil)
        return CGPoint(x: location.x - swipeStartLocation.x, y: location.y - swipeStartLocation.y)
    }

    func swipeDismissTransform(translation: CGPoint, velocity: CGPoint) -> CGAffineTransform? {
        if isSwipingUp {
            let sign = swipeDismissSign(
                offset: translation.y,
                speed: velocity.y,
                dismissOffset: bounds.height * SwipeConstants.dismissUpTranslationRatio
            )
            guard sign == .minus else { return nil }
            return CGAffineTransform(translationX: 0, y: -(center.y + bounds.height / 2))
        }
        guard let sign = swipeDismissSign(
            offset: translation.x,
            speed: velocity.x,
            dismissOffset: bounds.width * SwipeConstants.dismissTranslationRatio
        ) else { return nil }
        let width = superview?.bounds.width ?? bounds.width
        return CGAffineTransform(translationX: sign == .plus ? width : -width, y: 0)
    }

    /// A flick goes its own way; a slower release goes the way the toast was dragged once that is far enough.
    func swipeDismissSign(offset: CGFloat, speed: CGFloat, dismissOffset: CGFloat) -> FloatingPointSign? {
        if abs(speed) > SwipeConstants.dismissVelocityThreshold {
            return speed.sign
        }
        return abs(offset) > dismissOffset ? offset.sign : nil
    }

    func dismissBySwipe(to offScreenTransform: CGAffineTransform) {
        didCommitSwipeDismiss?()
        UIView.animate(
            withDuration: SwipeConstants.dismissAnimationDuration,
            delay: 0,
            options: .curveEaseIn
        ) {
            self.transform = offScreenTransform
            self.alpha = 0
        } completion: { _ in
            // A toast brought back meanwhile, reconfigured with new content, stays: the dismissal was the old one's.
            guard self.alpha == 0 else { return }
            self.didSwipeToDismiss?()
        }
    }

    func setupConstraints() {
        stackView.translatesAutoresizingMaskIntoConstraints = false

        topConstraint = stackView.topAnchor.constraint(equalTo: topAnchor)
        leftConstraint = stackView.leftAnchor.constraint(equalTo: leftAnchor)
        bottomConstraint = stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        rightConstraint = stackView.rightAnchor.constraint(equalTo: rightAnchor)

        topConstraint?.isActive = true
        leftConstraint?.isActive = true
        bottomConstraint?.isActive = true
        rightConstraint?.isActive = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        disclosureView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarIconView.translatesAutoresizingMaskIntoConstraints = false
        progressBorderView.translatesAutoresizingMaskIntoConstraints = false
        let titleHeightConstraint = titleLabel.heightAnchor.constraint(
            equalToConstant: TKTextStyle.label2.lineHeight
        )
        self.titleHeightConstraint = titleHeightConstraint
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            disclosureView.widthAnchor.constraint(equalToConstant: 16),
            disclosureView.heightAnchor.constraint(equalToConstant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: .avatarSide),
            avatarView.heightAnchor.constraint(equalToConstant: .avatarSide),
            avatarImageView.topAnchor.constraint(equalTo: avatarView.topAnchor),
            avatarImageView.leftAnchor.constraint(equalTo: avatarView.leftAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),
            avatarImageView.rightAnchor.constraint(equalTo: avatarView.rightAnchor),
            avatarIconView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarIconView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarIconView.widthAnchor.constraint(equalToConstant: .avatarIconSide),
            avatarIconView.heightAnchor.constraint(equalToConstant: .avatarIconSide),
            progressBorderView.topAnchor.constraint(equalTo: topAnchor),
            progressBorderView.leftAnchor.constraint(equalTo: leftAnchor),
            progressBorderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressBorderView.rightAnchor.constraint(equalTo: rightAnchor),
            titleHeightConstraint,
        ])
    }
}

private extension CGFloat {
    static let avatarSide: CGFloat = 32
    static let avatarIconSide: CGFloat = 20
    static let avatarSpacing: CGFloat = 12
    static let avatarToastCornerRadius: CGFloat = 28
}

private extension UIEdgeInsets {
    static let avatarToastInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
}

private extension TimeInterval {
    static let crossfadeDuration: TimeInterval = 0.15
}

private enum SwipeConstants {
    static let dismissTranslationRatio: CGFloat = 0.35
    static let dismissUpTranslationRatio: CGFloat = 0.5
    static let dismissVelocityThreshold: CGFloat = 800
    static let dismissAnimationDuration: TimeInterval = 0.2
    static let resetAnimationDuration: TimeInterval = 0.2
    static let resetAnimationDamping: CGFloat = 0.8
}

extension ToastView: UIGestureRecognizerDelegate {
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        guard didSwipeToDismiss != nil else { return false }

        let movement = swipeMovement(of: gestureRecognizer as! UIPanGestureRecognizer)
        // The toast hangs from the top of the screen, so up is its only way off vertically.
        return abs(movement.x) >= abs(movement.y) || movement.y < 0
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only the first finger starts the swipe: one landing later must not move its origin.
        if gestureRecognizer === panGestureRecognizer, gestureRecognizer.numberOfTouches == 0 {
            swipeStartLocation = touch.location(in: nil)
        }
        return true
    }
}
