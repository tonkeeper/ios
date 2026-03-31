import TKUIKit
import UIKit

final class TokenDetailsInformationView: UIView, ConfigurableView {
    private let tokenAmountLabel = UILabel()
    private let convertedAmountLabel = UILabel()
    private let transferAvailabilityButton = UIButton(type: .system)
    private let imageView = TKListItemIconView()
    private var transferAvailabilityAction: (() -> Void)?

    private let contentView = UIView()
    private let amountStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let imageConfiguration: TKListItemIconView.Configuration
        let tokenAmount: NSAttributedString
        let convertedAmount: NSAttributedString?
        let transferAvailabilityText: String?
        let transferAvailabilityAction: (() -> Void)?

        init(
            imageConfiguration: TKListItemIconView.Configuration,
            tokenAmount: String,
            convertedAmount: String?,
            transferAvailabilityText: String? = nil,
            transferAvailabilityAction: (() -> Void)? = nil
        ) {
            self.imageConfiguration = imageConfiguration
            self.tokenAmount = tokenAmount.withTextStyle(
                .h2,
                color: .Text.primary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            self.convertedAmount = convertedAmount?.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            self.transferAvailabilityText = transferAvailabilityText
            self.transferAvailabilityAction = transferAvailabilityAction
        }
    }

    func configure(model: Model) {
        imageView.configuration = model.imageConfiguration
        tokenAmountLabel.attributedText = model.tokenAmount
        convertedAmountLabel.attributedText = model.convertedAmount

        if let transferAvailabilityText = model.transferAvailabilityText {
            transferAvailabilityButton.isHidden = false
            transferAvailabilityButton.setAttributedTitle(
                makeTransferAvailabilityTitle(transferAvailabilityText),
                for: .normal
            )
            transferAvailabilityAction = model.transferAvailabilityAction
        } else {
            transferAvailabilityButton.isHidden = true
            transferAvailabilityButton.setAttributedTitle(nil, for: .normal)
            transferAvailabilityAction = nil
        }
    }
}

private extension TokenDetailsInformationView {
    func setup() {
        tokenAmountLabel.minimumScaleFactor = 0.5
        tokenAmountLabel.adjustsFontSizeToFitWidth = true

        var transferAvailabilityConfiguration = UIButton.Configuration.plain()
        transferAvailabilityConfiguration.contentInsets = .zero
        transferAvailabilityConfiguration.image = .TKUIKit.Icons.Size12.chevronRight
        transferAvailabilityConfiguration.imagePlacement = .trailing
        transferAvailabilityConfiguration.imagePadding = .transferAvailabilityChevronRightOffset
        transferAvailabilityConfiguration.baseForegroundColor = .Text.secondary
        transferAvailabilityButton.configuration = transferAvailabilityConfiguration

        transferAvailabilityButton.contentHorizontalAlignment = .left
        transferAvailabilityButton.setContentHuggingPriority(.required, for: .vertical)
        transferAvailabilityButton.setContentCompressionResistancePriority(.required, for: .vertical)
        transferAvailabilityButton.isHidden = true
        transferAvailabilityButton.addAction(UIAction(handler: { [weak self] _ in
            self?.transferAvailabilityAction?()
        }), for: .touchUpInside)

        addSubview(contentView)
        contentView.addSubview(amountStackView)
        contentView.addSubview(imageView)
        amountStackView.addArrangedSubview(tokenAmountLabel)
        amountStackView.setCustomSpacing(2, after: tokenAmountLabel)
        amountStackView.addArrangedSubview(convertedAmountLabel)
        amountStackView.setCustomSpacing(10, after: convertedAmountLabel)
        amountStackView.addArrangedSubview(transferAvailabilityButton)

        setupConstraints()
    }

    func makeTransferAvailabilityTitle(_ text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(
            attributedString: text.withTextStyle(.body2, color: .Text.secondary)
        )
        attributedString.addAttribute(
            .baselineOffset,
            value: CGFloat.transferAvailabilityChevronBottomOffset,
            range: NSRange(location: 0, length: attributedString.length)
        )
        return attributedString
    }

    func setupConstraints() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        amountStackView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: UIEdgeInsets.contentPadding.top),
            contentView.leftAnchor.constraint(equalTo: leftAnchor, constant: UIEdgeInsets.contentPadding.left),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -UIEdgeInsets.contentPadding.bottom),
            contentView.rightAnchor.constraint(equalTo: rightAnchor, constant: -UIEdgeInsets.contentPadding.right),

            amountStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            amountStackView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            amountStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).withPriority(.defaultHigh),

            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
            imageView.leftAnchor.constraint(equalTo: amountStackView.rightAnchor, constant: .imageViewLeftPadding),
            imageView.widthAnchor.constraint(equalToConstant: .imageViewSide),
            imageView.heightAnchor.constraint(equalToConstant: .imageViewSide),
        ])
    }
}

private extension UIEdgeInsets {
    static let contentPadding = UIEdgeInsets(top: 16, left: 28, bottom: 28, right: 28)
}

private extension CGFloat {
    static let imageViewLeftPadding: CGFloat = 16
    static let imageViewSide: CGFloat = 64
    static let separatorHeight: CGFloat = TKUIKit.Constants.separatorWidth
    static let transferAvailabilityChevronRightOffset: CGFloat = 3
    static let transferAvailabilityChevronBottomOffset: CGFloat = 2
}
