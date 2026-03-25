import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class NativeSwapTransactionConfirmationSendView: UIView {
    var didTapEdit: (() -> Void)?

    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let circleView = UIView()
    private let editButton = TKPlainButton()
    private let spacerView = UIView()
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

        setupStackView()
        setupEditButton()
        setupTitleLabel()
        setupCircleView()
        setupActionButton()
        setupConstraints()
    }

    private func setupStackView() {
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
    }

    private func setupEditButton() {
        editButton.configure(
            model: TKPlainButton.Model(
                title: TKLocales.NativeSwap.Confirm.Actions.edit.withTextStyle(
                    .body2,
                    color: .Accent.blue,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail
                ),
                icon: nil,
                action: nil
            )
        )
        editButton.isUserInteractionEnabled = false
    }

    private func setupTitleLabel() {
        titleLabel.attributedText = TKLocales.NativeSwap.Field.send.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
    }

    private func setupCircleView() {
        circleView.backgroundColor = .Text.tertiary
        circleView.layer.cornerRadius = 1
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
        addSubview(stackView)
        addSubview(amountLabel)
        addSubview(actionButton)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(circleView)
        stackView.addArrangedSubview(editButton)
        stackView.addArrangedSubview(spacerView)

        stackView.snp.makeConstraints { make in
            make.top.equalTo(self).inset(12)
            make.left.right.equalTo(self).inset(16)
            make.height.equalTo(20)
        }

        circleView.snp.makeConstraints { make in
            make.size.equalTo(2)
        }

        amountLabel.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp.bottom)
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
