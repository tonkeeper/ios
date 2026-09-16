import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class NativeSwapTransactionConfirmationItemView: UIView {
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let titleValueSpacer = UIView()
    private let valueStackView = UIStackView()
    private let valueLabel = UILabel()
    private let valueIconImageView = UIImageView()
    private let tapButton = UIButton(type: .system)
    private var tapButtonAction: (() -> Void)?
    let captionButton = TKPlainButton()

    private var title = "" {
        didSet {
            titleLabel.attributedText = title.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
        }
    }

    private func setValue(_ value: String, color: UIColor) {
        var attributes = TKTextStyle.body2.getAttributes(
            color: color,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
        )

        if let font = attributes[.font] as? UIFont {
            attributes[.font] = font.withTabularLiningNumbers()
        }

        valueLabel.attributedText = NSAttributedString(
            string: value,
            attributes: attributes
        )
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
        title: String,
        value: String,
        valueColor: UIColor = .Text.primary,
        valueIcon: UIImage? = nil,
        captionModel: TKPlainButton.Model? = nil,
        captionAccessibilityIdentifier: String? = nil
    ) {
        self.title = title
        setValue(value, color: valueColor)
        valueIconImageView.image = valueIcon
        valueIconImageView.tintColor = valueColor
        valueIconImageView.isHidden = valueIcon == nil

        guard let captionModel else {
            captionButton.isHidden = true
            tapButton.isHidden = true
            captionButton.accessibilityIdentifier = nil
            tapButton.accessibilityIdentifier = nil
            stackView.setCustomSpacing(stackView.spacing, after: titleLabel)
            return
        }

        stackView.setCustomSpacing(
            captionModel.title == nil ? 4 : stackView.spacing,
            after: titleLabel
        )
        captionButton.configure(model: captionModel)
        tapButtonAction = captionModel.action
        captionButton.isHidden = false
        tapButton.isHidden = false
        captionButton.accessibilityIdentifier = captionAccessibilityIdentifier
        tapButton.accessibilityIdentifier = captionAccessibilityIdentifier
    }

    private func setup() {
        backgroundColor = .Background.content

        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center

        valueStackView.axis = .vertical
        valueStackView.alignment = .trailing
        valueStackView.spacing = 2

        captionButton.isUserInteractionEnabled = false
        valueIconImageView.contentMode = .scaleAspectFit
        valueIconImageView.isHidden = true

        captionButton.setContentHuggingPriority(.required, for: .horizontal)
        captionButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleValueSpacer.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        titleValueSpacer.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)

        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        valueIconImageView.setContentHuggingPriority(.required, for: .horizontal)
        valueIconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        tapButton.addAction(
            UIAction { [weak self] _ in
                self?.tapButtonAction?()
            },
            for: .touchUpInside
        )

        isUserInteractionEnabled = true

        setupConstraints()
    }

    private func setupConstraints() {
        addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(captionButton)
        stackView.addArrangedSubview(titleValueSpacer)
        stackView.addArrangedSubview(valueStackView)
        valueStackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(valueIconImageView)
        addSubview(tapButton)

        stackView.snp.makeConstraints { make in
            make.centerY.equalTo(snp.centerY)
            make.left.right.equalTo(self).inset(16)
        }

        valueIconImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        tapButton.snp.makeConstraints { make in
            make.top.left.right.bottom.equalTo(self).inset(16)
        }
    }
}

private extension UIFont {
    func withTabularLiningNumbers() -> UIFont {
        let features: [[UIFontDescriptor.FeatureKey: Any]] = [
            [
                .type: kNumberSpacingType,
                .selector: kMonospacedNumbersSelector, // tabular-nums
            ],
        ]

        let descriptor = fontDescriptor.addingAttributes([
            .featureSettings: features,
        ])

        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
