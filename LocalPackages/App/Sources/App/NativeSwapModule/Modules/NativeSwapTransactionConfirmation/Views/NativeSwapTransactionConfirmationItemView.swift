import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class NativeSwapTransactionConfirmationItemView: UIView {
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
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

    private var value = "" {
        didSet {
            var attributes = TKTextStyle.body2.getAttributes(
                color: .Text.primary,
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
        captionModel: TKPlainButton.Model? = nil
    ) {
        self.title = title
        self.value = value

        guard let captionModel else {
            captionButton.isHidden = true
            tapButton.isHidden = true
            return
        }

        captionButton.configure(model: captionModel)
        tapButtonAction = captionModel.action
        captionButton.isHidden = false
        tapButton.isHidden = false
    }

    private func setup() {
        backgroundColor = .Background.content

        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center

        captionButton.isUserInteractionEnabled = false

        captionButton.setContentHuggingPriority(.required, for: .horizontal)
        captionButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

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
        stackView.addArrangedSubview(valueLabel)
        addSubview(tapButton)

        stackView.snp.makeConstraints { make in
            make.centerY.equalTo(snp.centerY)
            make.left.right.equalTo(self).inset(16)
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
