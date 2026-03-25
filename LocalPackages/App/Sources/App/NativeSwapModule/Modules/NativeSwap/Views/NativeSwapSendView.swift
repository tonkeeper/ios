import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class NativeSwapSendView: UIControl {
    var didUpdateText: ((String) -> Void)?
    var didTapMax: (() -> Void)?
    var didBeginEditing: (() -> Void)?
    var didEndEditing: (() -> Void)?
    var shouldPaste: ((String) -> Bool)?
    var didTapClear: (() -> Void)?
    var didTapTokenPicker: (() -> Void)?

    private let titleLabel = UILabel()
    private let amountView = NativeSwapAmountView()
    private let remainingLabel = UILabel()
    private let maxButton = TKPlainButton()
    private let insufficientLabel = UILabel()
    private let accessoryStack = UIStackView()

    private var remaining = "" {
        didSet {
            remainingLabel.attributedText = remaining.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )
        }
    }

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        tokenAmount: String,
        remaining: NativeSwapViewModelImplementation.ViewState.Remaining,
        tokenButton: TokenPickerButton.Configuration,
        isShimmering: Bool = false,
        shouldShowMaxButton: Bool = true
    ) {
        amountView.inputText = tokenAmount
        amountView.updateTokenButton(tokenButton)
        amountView.isShimmering = isShimmering
        switch remaining {
        case let .remaining(amount):
            self.remaining = amount
            remainingLabel.isHidden = false
            maxButton.isHidden = !shouldShowMaxButton
            insufficientLabel.isHidden = true
        case .insufficient:
            remainingLabel.isHidden = true
            maxButton.isHidden = true
            insufficientLabel.isHidden = false
        }
    }

    func setTextFieldDelegate(_ delegate: UITextFieldDelegate?) {
        amountView.setTextField(delegate)
    }

    func setTextFieldState(_ state: TKTextFieldState = .inactive) {
        guard amountView.textFieldState != state else { return }

        amountView.textFieldState = state
        didUpdateState()
    }

    private func setup() {
        backgroundColor = .Background.content
        layer.cornerRadius = 16
        layer.borderWidth = 1.5
        isUserInteractionEnabled = true

        addAction(
            UIAction { [weak self] _ in
                guard let self, amountView.textFieldState != .active else { return }

                amountView.textFieldState = .active
                didUpdateState()
            },
            for: .touchUpInside
        )

        maxButton.configure(
            model: TKPlainButton.Model(
                title: TKLocales.Common.Numbers.max.withTextStyle(
                    .label2,
                    color: .Accent.blue,
                    alignment: .right,
                    lineBreakMode: .byTruncatingTail
                ),
                icon: nil,
                action: { [weak self] in
                    self?.didTapMax?()
                }
            )
        )

        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        remainingLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        remainingLabel.isUserInteractionEnabled = false
        maxButton.setContentHuggingPriority(.required, for: .horizontal)
        maxButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        accessoryStack.axis = .horizontal
        accessoryStack.spacing = 8

        setupTitleLabel()
        setupInsufficientLabel()
        setupAmountView()
        setupConstraints()

        didUpdateState()
    }

    private func setupTitleLabel() {
        titleLabel.attributedText = TKLocales.NativeSwap.Field.send.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
    }

    private func setupInsufficientLabel() {
        insufficientLabel.isHidden = true
        insufficientLabel.attributedText = TKLocales.InsufficientFunds.insufficientBalance.withTextStyle(
            .body2,
            color: .Accent.red,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
        )
    }

    private func setupAmountView() {
        amountView.didUpdateText = { [weak self] text in
            self?.didUpdateState()
            self?.didUpdateText?(text)
        }

        amountView.didBeginEditing = { [weak self] in
            self?.didUpdateState()
            self?.didBeginEditing?()
        }

        amountView.didEndEditing = { [weak self] in
            self?.didUpdateState()
            self?.didEndEditing?()
        }

        amountView.shouldPaste = { [weak self] in
            self?.shouldPaste?($0) ?? true
        }

        amountView.didTapClear = { [weak self] in
            self?.didTapClear?()
        }

        amountView.didTapTokenPicker = { [weak self] in
            self?.didTapTokenPicker?()
        }
    }

    private func setupConstraints() {
        addSubview(titleLabel)
        addSubview(amountView)
        addSubview(insufficientLabel)
        addSubview(accessoryStack)
        accessoryStack.addArrangedSubview(remainingLabel)
        accessoryStack.addArrangedSubview(maxButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self).inset(12)
            make.left.equalTo(self).inset(16)
        }

        accessoryStack.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).inset(-8)
            make.centerY.equalTo(titleLabel)
            make.right.equalTo(self).inset(16)
        }

        amountView.snp.makeConstraints { make in
            make.left.right.equalTo(self).inset(16)
            make.bottom.equalTo(self).inset(18)
            make.height.equalTo(40)
        }

        insufficientLabel.snp.makeConstraints { make in
            make.right.equalTo(self).inset(16)
            make.centerY.equalTo(titleLabel)
        }
    }

    func didUpdateState() {
        UIView.animate(withDuration: 0.2) { [self] in
            backgroundColor = amountView.textFieldState.backgroundColor
            layer.borderColor = amountView.textFieldState.borderColor.cgColor
        }
    }
}
