import TKUIKit
import UIKit

final class TransactionConfirmationNetworkFeeValueView: UIView {
    struct Configuration: TKListContainerItemValue {
        let primaryText: String
        let tokenSymbol: String?
        let showsPicker: Bool

        func getView() -> UIView {
            let view = TransactionConfirmationNetworkFeeValueView()
            view.configure(configuration: self)
            return view
        }
    }

    private let valueLabel = UILabel()
    private let pickerImageView = UIImageView()
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

        valueLabel.numberOfLines = 1
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        pickerImageView.image = .TKUIKit.Icons.Size16.switch
        pickerImageView.tintColor = .Text.accent
        pickerImageView.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(stackView)
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(pickerImageView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        pickerImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }
    }

    private func configure(configuration: Configuration) {
        let value = NSMutableAttributedString(
            attributedString: configuration.primaryText.withTextStyle(
                .label1,
                color: .Text.primary,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )
        )
        if let tokenSymbol = configuration.tokenSymbol {
            value.append(
                " · \(tokenSymbol)".withTextStyle(
                    .body1,
                    color: .Text.accent,
                    alignment: .right,
                    lineBreakMode: .byTruncatingTail
                )
            )
        }
        valueLabel.attributedText = value
        pickerImageView.isHidden = !configuration.showsPicker
    }
}
