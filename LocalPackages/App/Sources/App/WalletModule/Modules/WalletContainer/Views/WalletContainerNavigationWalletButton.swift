import SnapKit
import TKUIKit
import UIKit

/// The wallet picker as the system navigation bar's title view: glass tinted with the wallet's
/// colour, plain for the default one. A title view gets no glass of its own, so the pill draws it,
/// interactive so a press animates like the bar buttons beside it.
final class WalletContainerNavigationWalletButton: UIView {
    var didTap: (() -> Void)?

    private let glassView = UIVisualEffectView()
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        return stackView
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = .TKUIKit.Icons.Size16.chevronDown
        imageView.alpha = 0.64
        return imageView
    }()

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
        glassView.layer.cornerRadius = bounds.height / 2
    }

    override func accessibilityActivate() -> Bool {
        didTap?()
        return true
    }

    /// `color` is nil for the default wallet colour, which keeps the plain glass.
    func configure(model: WalletButtonConfig, color: UIColor?) {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.tintColor = color
            effect.isInteractive = true
            glassView.effect = effect
        } else {
            glassView.effect = nil
            glassView.backgroundColor = color
        }
        let contentColor: UIColor = color == nil ? .Icon.primary : .white
        iconImageView.tintColor = contentColor
        chevronImageView.tintColor = contentColor
        titleLabel.attributedText = model.title.withTextStyle(
            .label2,
            color: color == nil ? .Text.primary : .white,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        accessibilityLabel = model.title

        switch model.icon {
        case let .emoji(emoji):
            emojiLabel.isHidden = false
            emojiLabel.text = emoji
            iconImageView.isHidden = true
            iconImageView.image = nil
        case let .image(image):
            emojiLabel.isHidden = true
            emojiLabel.text = nil
            iconImageView.isHidden = false
            iconImageView.image = image
        }
    }
}

private extension WalletContainerNavigationWalletButton {
    func setup() {
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "wallet_picker"

        glassView.clipsToBounds = true
        glassView.layer.cornerCurve = .continuous
        stackView.isUserInteractionEnabled = false

        emojiLabel.font = .systemFont(ofSize: 17)

        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(emojiLabel)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(chevronImageView)
        stackView.setCustomSpacing(6, after: iconImageView)
        stackView.setCustomSpacing(6, after: emojiLabel)
        stackView.setCustomSpacing(6, after: titleLabel)

        addSubview(glassView)
        glassView.contentView.addSubview(stackView)

        iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        emojiLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        // The same height as the system glass of the bar items beside it.
        snp.makeConstraints { make in
            make.height.equalTo(CGFloat.height)
        }
        glassView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        stackView.snp.makeConstraints { make in
            make.centerY.equalTo(self)
            make.left.equalTo(self).offset(CGFloat.leftInset)
            make.right.equalTo(self).offset(-CGFloat.rightInset)
        }
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }

        // A tap recogniser leaves the touches to the interactive glass, which plays the press.
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didRecogniseTap))
        tapRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(tapRecognizer)
    }
}

@objc private extension WalletContainerNavigationWalletButton {
    func didRecogniseTap() {
        didTap?()
    }
}

private extension CGFloat {
    static let height: CGFloat = 44
    static let leftInset: CGFloat = 12
    static let rightInset: CGFloat = 14
}
