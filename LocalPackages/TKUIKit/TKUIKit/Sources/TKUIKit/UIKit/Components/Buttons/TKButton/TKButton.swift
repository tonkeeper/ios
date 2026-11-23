import UIKit

open class TKButton: UIControl {
    public var configuration = TKButton.Configuration() {
        didSet {
            didUpdateConfiguration()
        }
    }

    public var padding: UIEdgeInsets = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    override open var isHighlighted: Bool {
        didSet { didUpdateControlState() }
    }

    override open var isSelected: Bool {
        didSet { didUpdateControlState() }
    }

    override open var isEnabled: Bool {
        didSet { didUpdateControlState() }
    }

    let buttonContentView = TKButtonContentView()
    let loaderView = TKLoaderView(size: .small, style: .primary)
    /// Created only for a button that sits on liquid glass.
    private var glassView: TKButtonGlassView?
    /// Whether the title was last built greyed out, so a state change rebuilds it only when that flips.
    private var isTitleGreyedOut = false

    var buttonState: TKButtonState = .normal {
        didSet { didUpdateButtonState() }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public init(configuration: Configuration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open var intrinsicContentSize: CGSize {
        let contentViewIntrinsicContentSize = buttonContentView.intrinsicContentSize
        let width = contentViewIntrinsicContentSize.width + padding.left + padding.right
        let height = contentViewIntrinsicContentSize.height + padding.top + padding.bottom
        return CGSize(width: width, height: height)
    }

    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        let contentViewSizeThatFits = buttonContentView.sizeThatFits(size)
        let width = contentViewSizeThatFits.width + padding.left + padding.right
        let height = contentViewSizeThatFits.height + padding.top + padding.bottom
        return CGSize(width: width, height: height)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        let contentViewSizeThatFits = buttonContentView.sizeThatFits(bounds.size)
        let availableWidth = bounds.width - padding.left - padding.right
        let availableHeight = bounds.height - padding.top - padding.bottom

        let contentViewWidth = availableWidth
        let contentViewHeight = min(contentViewSizeThatFits.height, availableHeight)

        let contentViewFrame = CGRect(
            x: bounds.width / 2 - contentViewWidth / 2,
            y: bounds.height / 2 - contentViewHeight / 2,
            width: contentViewWidth,
            height: contentViewHeight
        )
        buttonContentView.frame = contentViewFrame
        if isLiquidGlass {
            glassView?.frame = contentViewFrame
            buttonContentView.cornerRadius = contentViewFrame.height / 2
        }

        loaderView.sizeToFit()
        loaderView.center = CGPoint(
            x: bounds.width / 2,
            y: bounds.height / 2
        )
    }

    override open func setContentHuggingPriority(
        _ priority: UILayoutPriority,
        for axis: NSLayoutConstraint.Axis
    ) {
        super.setContentHuggingPriority(priority, for: axis)
        buttonContentView.setContentHuggingPriority(priority, for: axis)
    }

    override open func setContentCompressionResistancePriority(
        _ priority: UILayoutPriority,
        for axis: NSLayoutConstraint.Axis
    ) {
        super.setContentCompressionResistancePriority(priority, for: axis)
        buttonContentView.setContentCompressionResistancePriority(priority, for: axis)
    }
}

private extension TKButton {
    func setup() {
        buttonContentView.isUserInteractionEnabled = false

        loaderView.isHidden = true

        addSubview(buttonContentView)
        addSubview(loaderView)

        didUpdateConfiguration()

        addAction(UIAction(handler: { [weak self] _ in
            self?.configuration.action?()
        }), for: .touchUpInside)
    }

    func didUpdateButtonState() {
        updateAppearanceForState()
        buttonContentView.layer.borderColor = configuration.borderColors[buttonState]?.cgColor
        buttonContentView.layer.borderWidth = buttonState == .selected ? configuration.borderWidth : 0
    }

    /// The liquid glass design greys out a disabled button. One showing its loader is busy rather than
    /// unavailable, so it keeps its own colours, which its loader is drawn for.
    var isGreyedOut: Bool {
        isLiquidGlass && buttonState == .disabled && !configuration.showsLoader
    }

    var isLiquidGlass: Bool {
        configuration.sitsOnLiquidGlass && TKLiquidGlass.isEnabled
    }

    func updateAppearanceForState() {
        let backgroundColor = isGreyedOut ? .Button.secondaryBackground : configuration.backgroundColors[buttonState]
        if isLiquidGlass {
            let glassView = glassView ?? makeGlassView()
            glassView.isHidden = false
            glassView.tint = backgroundColor
            buttonContentView.backgroundColor = .clear
        } else {
            glassView?.isHidden = true
            buttonContentView.backgroundColor = backgroundColor
        }
        let contentAlpha = isGreyedOut ? 1 : configuration.contentAlpha[buttonState] ?? 1
        buttonContentView.titleLabel.alpha = contentAlpha
        buttonContentView.imageView.alpha = contentAlpha
        buttonContentView.iconTintColor = isGreyedOut ? .Text.secondary : configuration.iconTintColor
        if isGreyedOut != isTitleGreyedOut {
            updateTitle()
        }
    }

    func makeGlassView() -> TKButtonGlassView {
        let glassView = TKButtonGlassView()
        insertSubview(glassView, belowSubview: buttonContentView)
        self.glassView = glassView
        setNeedsLayout()
        return glassView
    }

    func updateTitle() {
        isTitleGreyedOut = isGreyedOut
        switch configuration.content.title {
        case let .plainString(string):
            let textColor = isGreyedOut ? .Text.secondary : configuration.textColor
            buttonContentView.title = string.withTextStyle(configuration.textStyle, color: textColor, alignment: .center)
        case let .attributedString(attributedString) where isGreyedOut:
            let greyedOut = NSMutableAttributedString(attributedString: attributedString)
            greyedOut.addAttribute(
                .foregroundColor,
                value: UIColor.Text.secondary,
                range: NSRange(location: 0, length: greyedOut.length)
            )
            buttonContentView.title = greyedOut
        case let .attributedString(attributedString):
            buttonContentView.title = attributedString
        case .none:
            buttonContentView.title = nil
        }
    }

    func didUpdateControlState() {
        switch (isEnabled, isHighlighted, isSelected) {
        case (false, _, _):
            buttonState = .disabled
        case (true, true, _):
            buttonState = .highlighted
        case (true, false, true):
            buttonState = .selected
        case (true, false, false):
            buttonState = .normal
        }
    }

    func didUpdateConfiguration() {
        self.padding = configuration.padding
        self.buttonContentView.padding = configuration.contentPadding
        self.buttonContentView.spacing = configuration.spacing
        self.buttonContentView.iconPosition = configuration.iconPosition
        self.buttonContentView.cornerRadius = configuration.cornerRadius
        self.loaderView.size = configuration.loaderSize
        self.loaderView.style = configuration.loaderStyle
        self.buttonContentView.contentContainerView.isHidden = configuration.showsLoader
        self.loaderView.isHidden = !configuration.showsLoader
        self.isUserInteractionEnabled = !configuration.showsLoader
        self.isEnabled = configuration.isEnabled
        updateAppearanceForState()
        updateTitle()
        if isLiquidGlass {
            // The capsule radius follows the laid-out height, and the configuration's radius was just put back.
            setNeedsLayout()
        }
        self.buttonContentView.titleLabel.numberOfLines = configuration.textNumberOfLines
        self.buttonContentView.icon = configuration.content.icon
        self.buttonContentView.borderColor = configuration.borderColors[buttonState]
        self.buttonContentView.borderWidth = configuration.borderWidth
    }
}
