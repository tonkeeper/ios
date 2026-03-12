import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class NativeSwapAmountView: UIControl {
    var didUpdateText: ((String) -> Void)?
    var didBeginEditing: (() -> Void)?
    var didEndEditing: (() -> Void)?
    var shouldPaste: ((String) -> Bool)?
    var didTapClear: (() -> Void)?
    var didTapTokenPicker: (() -> Void)?

    var textFieldState: TKTextFieldState = .inactive {
        didSet {
            if textFieldState == .active {
                textTextField.becomeFirstResponder()
            }
            updateViewsVisibility()
        }
    }

    var inputText: String {
        get { textTextField.inputText }
        set {
            textTextField.inputText = newValue
            updateViewsVisibility()

            // Update shimmer text if currently shimmering
            if isShimmering {
                updateShimmerText()
            }
        }
    }

    var isShimmering: Bool = false {
        didSet {
            guard isShimmering != oldValue else { return }

            if isShimmering {
                startShimmering()
            } else {
                stopShimmering()
            }
        }
    }

    private let showApproximate: Bool

    private let stackView = UIStackView()
    private let approximateLabel = UILabel()
    private let textTextField = TKTextInputTextFieldControl()
    private let clearButton = TKButton()
    private let tokenView = TokenPickerButton()
    private let spacerView = UIControl()
    private let shimmerLabel = TKShimmerLabel()

    init(showApproximate: Bool = false) {
        self.showApproximate = showApproximate
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTokenButton(_ configuration: TokenPickerButton.Configuration) {
        tokenView.configuration = configuration
    }

    func setTextField(_ delegate: UITextFieldDelegate?) {
        textTextField.delegate = delegate
    }

    private func setup() {
        isUserInteractionEnabled = true

        addAction(
            UIAction { [weak self] _ in
                guard let self, textFieldState != .active else { return }

                textFieldState = .active
            },
            for: .touchUpInside
        )

        spacerView.isUserInteractionEnabled = true
        spacerView.setContentHuggingPriority(.required, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        spacerView.addAction(
            UIAction { [weak self] _ in
                guard let self, textFieldState != .active else { return }

                textFieldState = .active
            },
            for: .touchUpInside
        )

        setupApproximateLabel()
        setupTextFiled()
        setupClearButton()
        setupTokenView()
        setupShimmerView()
        setupConstraints()
    }

    private func setupApproximateLabel() {
        approximateLabel.attributedText = TKLocales.Common.Numbers.approximate.withTextStyle(
            .num2,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byClipping
        )
        approximateLabel.setContentHuggingPriority(.required, for: .horizontal)
        approximateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func setupTextFiled() {
        textTextField.font = TKTextStyle.num2.font
        textTextField.keyboardType = .decimalPad
        textTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textTextField.placeholder = "0"

        textTextField.didUpdateText = { [weak self] text in
            self?.didUpdateText?(text)
            self?.updateViewsVisibility()
        }

        textTextField.didBeginEditing = { [weak self] in
            self?.didUpdateActiveState()
            self?.updateViewsVisibility()
            self?.didBeginEditing?()
        }

        textTextField.didEndEditing = { [weak self] in
            self?.didUpdateActiveState()
            self?.updateViewsVisibility()
            self?.didEndEditing?()
        }

        textTextField.shouldPaste = { [weak self] in
            self?.shouldPaste?($0) ?? true
        }
    }

    private func setupClearButton() {
        clearButton.configuration = TKButton.Configuration(
            content: TKButton.Configuration.Content(
                icon: .TKUIKit.Icons.Size16.xmarkCircle
            ),
            contentPadding: .zero,
            padding: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20),
            iconTintColor: .Icon.secondary,
            contentAlpha: [.normal: 1, .disabled: 0.48, .highlighted: 0.48],
            action: { [weak self] in
                self?.didTapClear?()
            }
        )
        clearButton.isHidden = true
        clearButton.setContentHuggingPriority(.required, for: .horizontal)
        clearButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func setupTokenView() {
        tokenView.contentPadding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 12)
        tokenView.setContentHuggingPriority(.required, for: .horizontal)
        tokenView.setContentCompressionResistancePriority(.required, for: .horizontal)
        tokenView.didTap = { [weak self] in
            self?.didTapTokenPicker?()
        }
    }

    private func setupShimmerView() {
        shimmerLabel.isHidden = true
        shimmerLabel.label.font = TKTextStyle.num2.font
        shimmerLabel.label.numberOfLines = 1
        shimmerLabel.clipsToBounds = false
        shimmerLabel.label.lineBreakMode = .byClipping
    }

    private func setupConstraints() {
        addSubview(stackView)
        addSubview(shimmerLabel)

        if showApproximate {
            stackView.addArrangedSubview(approximateLabel)
        }
        stackView.setCustomSpacing(4, after: approximateLabel)
        stackView.addArrangedSubview(textTextField)
        stackView.setCustomSpacing(8, after: textTextField)
        stackView.addArrangedSubview(spacerView)
        stackView.addArrangedSubview(clearButton)
        stackView.setCustomSpacing(8, after: clearButton)
        stackView.addArrangedSubview(tokenView)

        stackView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(self)
        }

        shimmerLabel.snp.makeConstraints { make in
            make.left.equalTo(stackView.snp.left)
            make.top.bottom.equalTo(textTextField)
            make.right.equalTo(tokenView).inset(-8)
        }
    }

    func didUpdateActiveState() {
        textFieldState = textTextField.isActive ? .active : .inactive
    }

    func updateViewsVisibility() {
        guard showApproximate else { return }
        approximateLabel.isHidden = textTextField.inputText.isEmpty || textTextField.text == "0"
    }

    private func startShimmering() {
        updateShimmerText()

        // Hide the actual text and approximate label
        textTextField.alpha = 0
        approximateLabel.alpha = 0

        shimmerLabel.isHidden = false
        shimmerLabel.startAnimation()
    }

    private func stopShimmering() {
        // Show the actual text field immediately, before hiding shimmer
        textTextField.alpha = 1
        approximateLabel.alpha = 1

        shimmerLabel.isHidden = true
        shimmerLabel.stopAnimation()

        // Restore approximate label visibility
        updateViewsVisibility()
    }

    private func updateShimmerText() {
        let shouldShowApproximate = showApproximate && !textTextField.inputText.isEmpty && textTextField.text != "0"
        let text = shouldShowApproximate ? (
            TKLocales.Common.Numbers.approximate + String.Symbol.shortSpace + textTextField.inputText
        ) : textTextField.inputText
        shimmerLabel.text = text.withTextStyle(
            .num2,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byClipping
        )
    }
}
