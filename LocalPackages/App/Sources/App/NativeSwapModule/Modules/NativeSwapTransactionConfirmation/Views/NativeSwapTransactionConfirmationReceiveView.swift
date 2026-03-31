import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class NativeSwapTransactionConfirmationReceiveView: UIView {
    var didTapEdit: (() -> Void)?

    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let actionButton = UIButton()

    private var amount: String = "" {
        didSet {
            amountLabel.attributedText = amount.withTextStyle(
                .num2,
                color: .Text.primary,
                alignment: .left,
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
        amount: String
    ) {
        self.amount = amount
    }

    private func setup() {
        backgroundColor = .Background.content

        setupTitleLabel()
        setupActionButton()
        setupConstraints()
    }

    private func setupTitleLabel() {
        titleLabel.attributedText = TKLocales.NativeSwap.Field.receive.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
    }

    private func setupActionButton() {
        actionButton.addAction(
            UIAction { [weak self] _ in
                self?.didTapEdit?()
            },
            for: .touchUpInside
        )
    }

    private func setupConstraints() {
        addSubview(titleLabel)
        addSubview(amountLabel)
        addSubview(actionButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self).inset(12)
            make.left.right.equalTo(self).inset(16)
            make.height.equalTo(20)
        }

        amountLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.left.right.equalTo(self).inset(16)
            make.bottom.equalTo(self).inset(10)
            make.height.equalTo(36)
        }

        actionButton.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.top.left.right.bottom.equalTo(self)
        }
    }
}
