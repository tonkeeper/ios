import TKUIKit
import UIKit

final class OpenDappWarningBannerView: UIView, ConfigurableView {
    private let textLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let text: NSAttributedString

        init(text: String) {
            self.text = text.withTextStyle(
                .body2,
                color: .Text.primary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )
        }
    }

    func configure(model: Model) {
        textLabel.attributedText = model.text
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func setup() {
        textLabel.numberOfLines = 0

        let iconImageView = UIImageView()
        iconImageView.image = .TKUIKit.Icons.Size16.exclamationMarkCircle
        iconImageView.tintColor = .Icon.secondary

        let iconContainer = UIView()

        let backgroundView = UIView()
        backgroundView.backgroundColor = .Background.content
        backgroundView.layer.cornerRadius = 16

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12

        stackView.addArrangedSubview(textLabel)
        stackView.addArrangedSubview(iconContainer)

        addSubview(backgroundView)
        addSubview(stackView)
        iconContainer.addSubview(iconImageView)
        iconContainer.snp.makeConstraints { make in
            make.width.equalTo(16)
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }

        iconImageView.snp.makeConstraints { make in
            make.top.equalTo(iconContainer).inset(4)
            make.left.right.equalTo(iconContainer)
        }
    }
}
