import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class SendV3AmountBalanceView: UIView {
    var didTapSwap: (() -> Void)?
    var didTapMax: (() -> Void)?

    var isSwapVisible: Bool = true {
        didSet {
            convertedView.isSwapHidden = !isSwapVisible
        }
    }

    var convertedValue: String = "" {
        didSet {
            convertedView.convertedValue = convertedValue
        }
    }

    var limitError: String? {
        didSet {
            didUpdateLimitError()
        }
    }

    let mainStackView = UIStackView()
    let rowStackView = UIStackView()
    let convertedView = SendV3AmountBalanceConvertedView()
    let remainingView = SendV3AmountBalanceRemainingView()
    let insufficientLabel = UILabel()
    let limitErrorLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        mainStackView.axis = .vertical
        mainStackView.spacing = 4
        addSubview(mainStackView)

        mainStackView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0))
        }

        rowStackView.axis = .horizontal
        rowStackView.spacing = 8
        rowStackView.addArrangedSubview(convertedView)
        rowStackView.addArrangedSubview(remainingView)
        rowStackView.addArrangedSubview(insufficientLabel)

        mainStackView.addArrangedSubview(rowStackView)
        mainStackView.addArrangedSubview(limitErrorLabel)

        convertedView.didTapSwap = { [weak self] in
            self?.didTapSwap?()
        }

        remainingView.didTapMax = { [weak self] in
            self?.didTapMax?()
        }

        insufficientLabel.isHidden = true
        insufficientLabel.attributedText = TKLocales.InsufficientFunds.insufficientBalance
            .withTextStyle(
                .body2,
                color: .Accent.red,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )

        limitErrorLabel.isHidden = true
        limitErrorLabel.numberOfLines = 0

        convertedView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        remainingView.setContentCompressionResistancePriority(.required, for: .horizontal)
        remainingView.setContentHuggingPriority(.required, for: .horizontal)
        insufficientLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        limitErrorLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func didUpdateLimitError() {
        if let text = limitError, !text.isEmpty {
            limitErrorLabel.attributedText = text.withTextStyle(
                .body2,
                color: .Accent.red,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )
            limitErrorLabel.isHidden = false
        } else {
            limitErrorLabel.attributedText = nil
            limitErrorLabel.isHidden = true
        }
    }
}
