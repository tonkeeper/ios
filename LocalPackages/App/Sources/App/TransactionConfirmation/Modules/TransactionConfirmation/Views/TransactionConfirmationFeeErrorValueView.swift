import TKLocalize
import TKUIKit
import UIKit

final class TransactionConfirmationFeeErrorValueView: UIView {
    struct Configuration: TKListContainerItemValue {
        let retry: () -> Void

        func getView() -> UIView {
            let view = TransactionConfirmationFeeErrorValueView()
            view.configure(configuration: self)
            return view
        }
    }

    private let titleLabel = UILabel()
    private let retryButton = TKPlainButton()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 4

        titleLabel.attributedText = TKLocales.TransactionConfirmation.feeUnavailable.withTextStyle(
            .label1,
            color: .Text.secondary,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
        )
        retryButton.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(retryButton)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func configure(configuration: Configuration) {
        retryButton.configure(
            model: .init(
                title: TKLocales.Actions.retry.withTextStyle(.label1, color: .Text.accent),
                icon: .init(
                    image: .TKUIKit.Icons.Size16.refresh,
                    tintColor: .Text.accent,
                    padding: .init(top: 4, left: 4, bottom: 4, right: 0)
                ),
                action: configuration.retry
            )
        )
    }
}
