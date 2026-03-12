import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class SendV3AmountBalanceView: UIView {
    var didTapSwap: (() -> Void)?
    var didTapMax: (() -> Void)?

    var convertedValue: String = "" {
        didSet {
            convertedView.convertedValue = convertedValue
        }
    }

    let stackView = UIStackView()
    let convertedView = SendV3AmountBalanceConvertedView()
    let remainingView = SendV3AmountBalanceRemainingView()
    let insufficientLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 48)
    }

    private func setup() {
        stackView.spacing = 8
        addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        stackView.addArrangedSubview(convertedView)
        stackView.addArrangedSubview(remainingView)
        stackView.addArrangedSubview(insufficientLabel)

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

        convertedView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        remainingView.setContentCompressionResistancePriority(.required, for: .horizontal)
        remainingView.setContentHuggingPriority(.required, for: .horizontal)
        insufficientLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
