import SnapKit
import TKUIKit
import UIKit

final class TokenPickerButton: UIControl {
    var didTap: (() -> Void)?

    struct Configuration {
        let name: String
        let network: String?
        let image: TKImage
        let networkIcon: UIImage?

        init(
            name: String,
            network: String? = nil,
            image: TKImage,
            networkIcon: UIImage? = nil
        ) {
            self.name = name
            self.network = network
            self.image = image
            self.networkIcon = networkIcon
        }
    }

    var configuration: Configuration? {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    var padding: UIEdgeInsets = .zero {
        didSet {
            backgroundView.snp.remakeConstraints { make in
                make.edges.equalTo(self).inset(padding)
            }
        }
    }

    var contentPadding: UIEdgeInsets = .zero {
        didSet {
            stackView.snp.remakeConstraints { make in
                make.edges.equalTo(backgroundView).inset(contentPadding)
            }
        }
    }

    var category: TKActionButtonCategory = .tertiary {
        didSet {
            backgroundView.backgroundColor = category.backgroundColor
            networkBadgeImageView.layer.borderColor = category.backgroundColor.cgColor
        }
    }

    var tokenTitleAccessibilityIdentifier: String? {
        didSet { nameLabel.accessibilityIdentifier = tokenTitleAccessibilityIdentifier }
    }

    override var isHighlighted: Bool {
        didSet {
            let color = isHighlighted ? category.highlightedBackgroundColor : category.backgroundColor
            backgroundView.backgroundColor = color
            networkBadgeImageView.layer.borderColor = color.cgColor
        }
    }

    let imageView = TKImageView()
    let nameLabel = UILabel()
    let networkLabel = UILabel()
    let networkBadgeImageView = UIImageView()
    let switchImageView = UIImageView()

    private enum Layout {
        static let imageSize: CGFloat = 24
        static let badgeSize: CGFloat = 14
        static let badgeBorderWidth: CGFloat = 1.5
    }

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.spacing = 6
        return stackView
    }()

    let backgroundView = UIView()

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
        backgroundView.layer.cornerRadius = backgroundView.bounds.height / 2
    }

    private func setup() {
        backgroundView.backgroundColor = category.backgroundColor

        addSubview(backgroundView)
        backgroundView.addSubview(stackView)

        setContentCompressionResistancePriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        switchImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        networkLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        layer.masksToBounds = true

        imageView.contentMode = .scaleAspectFit

        backgroundView.isUserInteractionEnabled = false

        nameLabel.textColor = .Button.tertiaryForeground
        nameLabel.font = TKTextStyle.label2.font
        nameLabel.isUserInteractionEnabled = false

        networkLabel.textColor = .Text.secondary
        networkLabel.font = TKTextStyle.label2.font
        networkLabel.isUserInteractionEnabled = false

        switchImageView.image = .TKUIKit.Icons.Size16.switch
        switchImageView.tintColor = .Icon.secondary
        switchImageView.isUserInteractionEnabled = false

        networkBadgeImageView.contentMode = .scaleAspectFit
        networkBadgeImageView.isUserInteractionEnabled = false
        networkBadgeImageView.isHidden = true
        networkBadgeImageView.layer.cornerRadius = Layout.badgeSize / 2
        networkBadgeImageView.layer.masksToBounds = true
        networkBadgeImageView.layer.borderWidth = Layout.badgeBorderWidth
        networkBadgeImageView.layer.borderColor = category.backgroundColor.cgColor

        stackView.isUserInteractionEnabled = false

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(networkLabel)
        stackView.addArrangedSubview(switchImageView)

        addSubview(networkBadgeImageView)

        addAction(UIAction(handler: { [weak self] _ in
            self?.didTap?()
        }), for: .touchUpInside)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(padding)
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(backgroundView).inset(contentPadding)
        }

        imageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.imageSize)
        }

        networkBadgeImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.badgeSize)
            make.trailing.equalTo(imageView)
            make.bottom.equalTo(imageView)
        }
    }

    private func didUpdateConfiguration() {
        guard let configuration else {
            imageView.image = nil
            nameLabel.text = nil
            networkLabel.text = nil
            networkBadgeImageView.image = nil
            networkBadgeImageView.isHidden = true

            return
        }

        imageView.configure(
            model: TKImageView.Model(
                image: configuration.image,
                tintColor: .clear,
                size: .size(CGSize(width: Layout.imageSize, height: Layout.imageSize)),
                corners: .circle
            )
        )
        nameLabel.text = configuration.name

        if let networkIcon = configuration.networkIcon {
            networkBadgeImageView.image = networkIcon
            networkBadgeImageView.isHidden = false
            networkLabel.isHidden = true
        } else {
            networkBadgeImageView.isHidden = true
            if let network = configuration.network {
                networkLabel.text = network
                networkLabel.isHidden = false
            } else {
                networkLabel.isHidden = true
            }
        }
    }
}
