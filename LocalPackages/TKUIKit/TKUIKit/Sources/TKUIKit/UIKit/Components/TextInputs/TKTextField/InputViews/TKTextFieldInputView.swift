import SnapKit
import UIKit

public protocol TKTextFieldInputViewControl: UIView {
    var isActive: Bool { get }
    var inputText: String { get set }
    var textFieldState: TKTextFieldState { get set }
    var accessoryView: UIView? { get set }
    var didUpdateText: ((String) -> Void)? { get set }
    var didBeginEditing: (() -> Void)? { get set }
    var didEndEditing: (() -> Void)? { get set }
    var shouldPaste: ((String) -> Bool)? { get set }
}

public final class TKTextFieldInputView: UIControl, TKTextFieldInputViewControl {
    public enum ClearButtonMode {
        case never
        case whileEditingNotEmpty
    }

    public var clearButtonMode: ClearButtonMode = .whileEditingNotEmpty {
        didSet {
            didSetClearButtonMode()
        }
    }

    // MARK: - TKTextFieldInputViewControl

    public var isActive: Bool {
        textInputControl.isActive
    }

    public var inputText: String {
        get { textInputControl.inputText }
        set {
            textInputControl.inputText = newValue
            updateTextAction()
        }
    }

    public var textFieldState: TKTextFieldState = .inactive {
        didSet {
            didUpdateState()
        }
    }

    public var accessoryView: UIView? {
        get { textInputControl.accessoryView }
        set { textInputControl.accessoryView = newValue }
    }

    public var didUpdateText: ((String) -> Void)?
    public var didBeginEditing: (() -> Void)?
    public var didEndEditing: (() -> Void)?
    public var shouldPaste: ((String) -> Bool)?

    public var padding: UIEdgeInsets = .zero {
        didSet {
            stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
                top: padding.top,
                leading: padding.left,
                bottom: padding.bottom,
                trailing: padding.right
            )
            updatePlaceholderScaleAndPosition(isTop: !placeholder.isEmpty && !inputText.isEmpty)
        }
    }

    public var stackViewSpacing: CGFloat = .stackViewSpacing {
        didSet {
            stackView.spacing = stackViewSpacing
        }
    }

    // MARK: - Properties

    public var placeholder: String = "" {
        didSet {
            placeholderLabel.attributedText = placeholder.withTextStyle(
                .body1,
                color: .Text.secondary,
                alignment: .left
            )
        }
    }

    public var currency: String? {
        didSet {
            if let currency {
                currencyLabel.attributedText = currency.withTextStyle(
                    .body1,
                    color: .Text.tertiary,
                    alignment: .left
                )
                textInputControl.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
                stackView.isUserInteractionEnabled = false
            } else {
                textInputControl.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
                stackView.isUserInteractionEnabled = true
            }
        }
    }

    // MARK: - Subviews

    private let textInputControl: TKTextFieldInputViewControl
    private lazy var clearButton: TKButton = {
        let button = TKButton()
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        var configuration = TKButton.Configuration.fieldClearButtonConfiguration()
        configuration.action = { [weak self] in
            self?.clearButtonAction()
        }
        button.configuration = configuration
        button.isHidden = true
        return button
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        label.layer.anchorPoint = .init(x: 0, y: 0.5)
        label.clipsToBounds = false
        return label
    }()

    private let currencyLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required + 1, for: .horizontal)
        return label
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = stackViewSpacing
        stack.isUserInteractionEnabled = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: padding.top,
            leading: padding.left,
            bottom: padding.bottom,
            trailing: padding.right
        )
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }()

    // MARK: - Init

    public init(textInputControl: TKTextFieldInputViewControl) {
        self.textInputControl = textInputControl
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - First Responder

    @discardableResult
    override public func becomeFirstResponder() -> Bool {
        textInputControl.becomeFirstResponder()
    }

    @discardableResult
    override public func resignFirstResponder() -> Bool {
        textInputControl.resignFirstResponder()
    }

    // MARK: - Layout

    override public func layoutSubviews() {
        super.layoutSubviews()
        updateTextInputAndPlaceholderLayoutAndScale()
    }
}

// MARK: - Private Methods

extension TKTextFieldInputView {
    func setup() {
        addSubview(stackView)
        addSubview(clearButton)
        addSubview(placeholderLabel)

        stackView.addArrangedSubview(textInputControl)
        stackView.addArrangedSubview(currencyLabel)

        textInputControl.didUpdateText = { [weak self] text in
            guard let self else { return }

            inputText = text
            didUpdateText?(inputText)
            updateTextAction()
        }

        textInputControl.didBeginEditing = { [weak self] in
            self?.didBeginEditing?()
            self?.updateClearButtonVisibility()
        }

        textInputControl.didEndEditing = { [weak self] in
            self?.didEndEditing?()
            self?.updateClearButtonVisibility()
        }

        textInputControl.shouldPaste = { [weak self] in
            self?.shouldPaste?($0) ?? true
        }

        addAction(UIAction(handler: { [weak self] _ in
            self?.textInputControl.becomeFirstResponder()
        }), for: .touchUpInside)

        setupConstraints()
    }

    func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.top.left.bottom.equalTo(self)
        }

        clearButton.snp.makeConstraints { make in
            make.top.right.bottom.equalTo(self)
            make.left.equalTo(stackView.snp.right).inset(-8)
        }
    }

    func updateClearButtonVisibility() {
        let isClearButtonVisible: Bool
        switch clearButtonMode {
        case .never:
            isClearButtonVisible = false
        case .whileEditingNotEmpty:
            isClearButtonVisible = !inputText.isEmpty && isActive
        }
        clearButton.isHidden = !isClearButtonVisible
    }

    func updateCurrencyVisibility() {
        currencyLabel.alpha = inputText.isEmpty || currency == nil ? 0 : 1
    }

    func updateTextInputAndPlaceholderLayoutAndScale() {
        updateTextInputControlPosition(isNeedToMove: !placeholder.isEmpty && !inputText.isEmpty)
        updatePlaceholderScaleAndPosition(isTop: !placeholder.isEmpty && !inputText.isEmpty)
    }

    func updateTextInputControlPosition(isNeedToMove: Bool) {
        let textInputControlTransform: CGAffineTransform =
            isNeedToMove ? CGAffineTransform(translationX: 0, y: .inputControlYOffset) : .identity
        textInputControl.transform = textInputControlTransform
        currencyLabel.transform = textInputControlTransform
    }

    func updatePlaceholderScaleAndPosition(isTop: Bool) {
        let scale: CGFloat = isTop ? .placeholderScale : 1
        let transform =
            isTop ? CGAffineTransform(scaleX: .placeholderScale, y: .placeholderScale) : .identity
        placeholderLabel.transform = transform
        let horizontalSpace = bounds.width - padding.left - padding.right
        let sizeThatFits = placeholderLabel.sizeThatFits(CGSize(width: horizontalSpace, height: 0))
        let size = CGSize(width: min(horizontalSpace, sizeThatFits.width), height: sizeThatFits.height)
        let y: CGFloat = isTop ? .placeholderTopMargin : padding.top
        let frame = CGRect(
            x: padding.left,
            y: y,
            width: size.width * scale,
            height: size.height * scale
        )
        placeholderLabel.frame = frame
    }

    func clearButtonAction() {
        inputText = ""
        didUpdateText?(inputText)
        updateTextAction()
    }

    func updateTextAction() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.updateClearButtonVisibility()
            self.updateCurrencyVisibility()
            self.updateTextInputAndPlaceholderLayoutAndScale()
        }
    }

    func didUpdateState() {
        textInputControl.textFieldState = textFieldState
    }

    func didSetClearButtonMode() {
        updateClearButtonVisibility()
    }
}

extension CGFloat {
    static let placeholderScale: CGFloat = 0.75
    static let placeholderTopMargin: CGFloat = 12
    static let inputControlYOffset: CGFloat = 8
    static let stackViewSpacing: CGFloat = 4
}
