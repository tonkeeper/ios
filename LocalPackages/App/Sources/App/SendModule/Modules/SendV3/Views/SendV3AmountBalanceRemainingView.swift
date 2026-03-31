import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class SendV3AmountBalanceRemainingView: UIView {
    var didTapMax: (() -> Void)?

    var remaining: String = "" {
        didSet {
            remainingLabel.attributedText = remaining.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )
        }
    }

    let remainingLabel = UILabel()
    let maxButton = TKPlainButton()
    let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let title = TKLocales.Common.Numbers.max

        maxButton.configure(
            model: TKPlainButton.Model(
                title: title.withTextStyle(
                    .body2,
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
        setContentHuggingPriority(.required, for: .horizontal)
        maxButton.setContentHuggingPriority(.required, for: .horizontal)
        remainingLabel.setContentHuggingPriority(.required, for: .horizontal)

        remainingLabel.isUserInteractionEnabled = false

        stackView.spacing = 8
        stackView.alignment = .center

        addSubview(stackView)

        stackView.addArrangedSubview(remainingLabel)
        stackView.addArrangedSubview(maxButton)

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        maxButton.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
        }
    }
}
