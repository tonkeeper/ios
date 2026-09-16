import UIKit

public final class ToastView: TKPassthroughView, ConfigurableView {
    var didBeginSwipe: (() -> Void)?
    var didCancelSwipe: (() -> Void)?
    var didSwipeToDismiss: (() -> Void)?
    var didTap: (() -> Void)?

    private(set) var panGestureRecognizer: UIPanGestureRecognizer?

    let titleLabel = UILabel()
    let activityView = TKLoaderView(size: .small, style: .primary)
    let iconView = UIImageView()

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

        let title: String
        let shape: Shape
        let isActivity: Bool
        let icon: UIImage?
        let iconTintColor: UIColor?
        let numberOfLines: Int
        let backgroundColor: UIColor
        let foregroundColor: UIColor

        init(
            title: String,
            shape: Shape,
            isActivity: Bool,
            icon: UIImage? = nil,
            iconTintColor: UIColor? = nil,
            numberOfLines: Int = Model.defaultNumberOfLines,
            backgroundColor: UIColor = .Background.contentTint,
            foregroundColor: UIColor = .Text.primary
        ) {
            self.title = title
            self.shape = shape
            self.isActivity = isActivity
            self.icon = icon
            self.iconTintColor = iconTintColor
            self.numberOfLines = numberOfLines
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
        }
    }

    public func configure(model: Model) {
        let needsSizeInvalidation = self.model.shape != model.shape
            || self.model.numberOfLines != model.numberOfLines
            || self.model.title != model.title
            || self.model.isActivity != model.isActivity
            || self.model.icon != model.icon
        self.model = model
        layer.cornerRadius = model.shape.cornerRadius
        backgroundColor = model.backgroundColor
        layer.shadowColor = UIColor.black.withAlphaComponent(0.04).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        titleLabel.numberOfLines = model.numberOfLines
        titleLabel.lineBreakMode = titleLineBreakMode()
        titleLabel.attributedText = model.title
            .withTextStyle(
                .label2,
                color: model.foregroundColor,
                alignment: .center,
                lineBreakMode: titleLineBreakMode()
            )
        let titleWidth = titleWidthForLayout()
        updateTitlePreferredMaxLayoutWidth(titleWidth)
        updateTitleHeightConstraint(forWidth: titleWidth)

        if model.isActivity {
            activityView.isHidden = false
            activityView.startAnimation()
        } else {
            activityView.isHidden = true
            activityView.stopAnimation()
        }

        iconView.image = model.icon
        iconView.tintColor = model.iconTintColor
        iconView.isHidden = model.isActivity || model.icon == nil

        let insets = model.shape.insets(hasIcon: model.icon != nil && !model.isActivity)
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
        if model.numberOfLines == 1 {
            return model.shape.height
        } else {
            return max(model.shape.height, ceil(contentHeight()))
        }
    }

    func titleLineBreakMode() -> NSLineBreakMode {
        // byTruncatingTail in the attributed paragraph style collapses
        // sizeThatFits to one line, so height is measured with wrapping
        // separately. Keep truncating on the displayed string so overflow
        // past numberOfLines still shows a trailing ellipsis.
        model.numberOfLines == 0 ? .byWordWrapping : .byTruncatingTail
    }

    func titleWidthForLayout() -> CGFloat {
        let hasIcon = model.icon != nil && !model.isActivity
        let insets = model.shape.insets(hasIcon: hasIcon)
        let sideInset: CGFloat = 20
        let maxWidth = UIScreen.main.bounds.width - sideInset * 2
        let iconWidth: CGFloat = hasIcon || model.isActivity ? 16 : 0
        let spacing = iconWidth > 0 ? stackView.spacing : 0
        return maxWidth - insets.left - insets.right - iconWidth - spacing
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
        measuringLabel.attributedText = model.title.withTextStyle(
            .label2,
            color: model.foregroundColor,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        return ceil(
            measuringLabel.sizeThatFits(
                CGSize(width: width, height: .greatestFiniteMagnitude)
            ).height
        )
    }

    func contentHeight() -> CGFloat {
        let hasIcon = model.icon != nil && !model.isActivity
        let insets = model.shape.insets(hasIcon: hasIcon)
        let iconWidth: CGFloat = hasIcon || model.isActivity ? 16 : 0
        // Prefer titleHeightConstraint over remeasuring: updateTitleHeightConstraint
        // may have sized from laid-out bounds while titleWidthForLayout() still
        // uses a UIScreen estimate, and those widths can disagree.
        let titleHeight = titleHeightConstraint?.constant
            ?? measuredTitleHeight(forWidth: titleWidthForLayout())
        return max(titleHeight, iconWidth) + insets.top + insets.bottom
    }

    func setup() {
        iconView.contentMode = .scaleAspectFit
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)

        stackView.isUserInteractionEnabled = false
        addSubview(stackView)
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(activityView)
        stackView.addArrangedSubview(titleLabel)

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
        panGestureRecognizer = gesture
        addGestureRecognizer(gesture)
    }

    @objc
    func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        guard didSwipeToDismiss != nil else { return }

        switch recognizer.state {
        case .began:
            didBeginSwipe?()
        case .changed:
            let translation = recognizer.translation(in: self)
            guard abs(translation.x) >= abs(translation.y) else { return }
            transform = CGAffineTransform(translationX: translation.x, y: 0)
        case .ended, .cancelled:
            let translation = recognizer.translation(in: recognizer.view)
            let velocity = recognizer.velocity(in: recognizer.view)
            let shouldDismiss = abs(translation.x) > bounds.width * SwipeConstants.dismissTranslationRatio
                || abs(velocity.x) > SwipeConstants.dismissVelocityThreshold

            if shouldDismiss {
                let direction: CGFloat = {
                    if abs(velocity.x) > SwipeConstants.dismissVelocityThreshold {
                        return velocity.x >= 0 ? 1 : -1
                    }
                    return translation.x >= 0 ? 1 : -1
                }()
                dismissBySwipe(direction: direction)
            } else {
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
        default:
            break
        }
    }

    func dismissBySwipe(direction: CGFloat) {
        guard let containerView = superview else {
            didSwipeToDismiss?()
            return
        }

        let offScreenTranslation = direction > 0
            ? containerView.bounds.width
            : -containerView.bounds.width

        UIView.animate(
            withDuration: SwipeConstants.dismissAnimationDuration,
            delay: 0,
            options: .curveEaseIn
        ) {
            self.transform = CGAffineTransform(translationX: offScreenTranslation, y: 0)
            self.alpha = 0
        } completion: { _ in
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
        let titleHeightConstraint = titleLabel.heightAnchor.constraint(
            equalToConstant: TKTextStyle.label2.lineHeight
        )
        self.titleHeightConstraint = titleHeightConstraint
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            titleHeightConstraint,
        ])
    }
}

private enum SwipeConstants {
    static let dismissTranslationRatio: CGFloat = 0.35
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

        let pan = gestureRecognizer as! UIPanGestureRecognizer
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) >= abs(velocity.y)
    }
}
