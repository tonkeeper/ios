import SnapKit
import TKUIKit
import UIKit

final class BalanceHeaderBalanceAmountButton: UIControl {
    enum State {
        struct Amount {
            let balance: String
            let color: UIColor
        }

        case amount(Amount)
        case secure(color: UIColor)
    }

    struct Configuration {
        let state: State
        let action: (() -> Void)?
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.64 : 1
        }
    }

    var configuration = Configuration(
        state: .amount(State.Amount(balance: "-", color: .Text.primary)),
        action: nil
    ) {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private var tapHandler: (() -> Void)?

    private let balanceLabel = UILabel()
    private let secureLabel = UILabel()
    private let secureView = UIView()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        secureView.layoutIfNeeded()
        secureView.layer.cornerRadius = secureView.bounds.height / 2
    }

    private func setup() {
        stackView.isUserInteractionEnabled = false
        balanceLabel.isUserInteractionEnabled = false
        secureView.isUserInteractionEnabled = false

        secureView.backgroundColor = .Button.secondaryBackground
        secureView.layer.cornerCurve = .continuous
        secureView.layer.masksToBounds = true

        stackView.axis = .horizontal
        stackView.alignment = .center

        addSubview(stackView)
        stackView.addArrangedSubview(balanceLabel)
        stackView.addArrangedSubview(secureView)
        secureView.addSubview(secureLabel)

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        secureLabel.snp.makeConstraints { make in
            make.left.right.equalTo(secureView).inset(16)
            make.top.equalTo(secureView).offset(5)
            make.bottom.equalTo(secureView).offset(5)
        }

        addAction(UIAction(handler: { [weak self] _ in
            self?.configuration.action?()
        }), for: .touchUpInside)

        didUpdateConfiguration()
    }

    private func didUpdateConfiguration() {
        switch configuration.state {
        case let .amount(amount):
            secureView.isHidden = true
            balanceLabel.isHidden = false
            balanceLabel.attributedText = amount.balance.withTextStyle(
                .balance,
                color: amount.color,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
        case let .secure(color):
            secureView.isHidden = false
            balanceLabel.isHidden = true
            secureLabel.attributedText = "* * *".withTextStyle(
                .num2,
                color: color
            )
        }
    }
}
