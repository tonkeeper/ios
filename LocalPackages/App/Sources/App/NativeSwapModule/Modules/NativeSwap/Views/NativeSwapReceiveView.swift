import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class NativeSwapReceiveView: UIControl {
    var didUpdateText: ((String) -> Void)?
    var didBeginEditing: (() -> Void)?
    var didEndEditing: (() -> Void)?
    var shouldPaste: ((String) -> Bool)?
    var didTapClear: (() -> Void)?
    var didTapTokenPicker: (() -> Void)?

    private let titleLabel = UILabel()
    private let amountView = NativeSwapAmountView(showApproximate: true)

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
        tokenButton: TokenPickerButton.Configuration,
        isShimmering: Bool = false
    ) {
        amountView.inputText = tokenAmount
        amountView.updateTokenButton(tokenButton)
        amountView.isShimmering = isShimmering
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

        setupTitleLabel()
        setupAmountView()
        setupConstraints()

        didUpdateState()
    }

    private func setupTitleLabel() {
        titleLabel.attributedText = TKLocales.NativeSwap.Field.receive.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
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

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self).inset(20)
            make.left.right.equalTo(self).inset(16)
        }

        amountView.snp.makeConstraints { make in
            make.left.right.equalTo(self).inset(16)
            make.bottom.equalTo(self).inset(18)
            make.height.equalTo(40)
        }
    }

    func didUpdateState() {
        UIView.animate(withDuration: 0.2) { [self] in
            backgroundColor = amountView.textFieldState.backgroundColor
            layer.borderColor = amountView.textFieldState.borderColor.cgColor
        }
    }
}
