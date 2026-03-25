import TKUIKit
import UIKit

final class TokenDetailsTRC20FeesBannerView: UIView {
    enum Style {
        case battery
        case trx
    }

    struct Configuration: TokenDetailsBannerItem {
        let title: String
        let caption: String
        let buttonTitle: String
        let style: Style
        let action: (() -> Void)?

        func getView() -> UIView {
            let view = TokenDetailsTRC20FeesBannerView()
            view.configuration = self
            return view
        }
    }

    var configuration: Configuration? {
        didSet {
            applyConfiguration()
        }
    }

    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let captionLabel = UILabel()
    private let actionButton = TKButton()
    private let labelsStack = UIStackView()
    private let textStack = UIStackView()
    private let iconContainerView = UIView()
    private let iconBackgroundView = UIView()
    private let iconImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension TokenDetailsTRC20FeesBannerView {
    func setup() {
        contentView.backgroundColor = .Background.content
        contentView.layer.cornerRadius = 16

        titleLabel.numberOfLines = 0
        captionLabel.numberOfLines = 0
        iconImageView.contentMode = .scaleAspectFit

        iconBackgroundView.layer.cornerRadius = 14
        iconBackgroundView.layer.masksToBounds = true

        actionButton.configuration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .small
        )

        labelsStack.axis = .vertical
        labelsStack.alignment = .leading
        labelsStack.spacing = 0
        labelsStack.addArrangedSubview(titleLabel)
        labelsStack.addArrangedSubview(captionLabel)

        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 12
        textStack.addArrangedSubview(labelsStack)
        textStack.addArrangedSubview(actionButton)

        let rootStack = UIStackView()
        rootStack.axis = .horizontal
        rootStack.alignment = .top
        rootStack.spacing = 16
        rootStack.addArrangedSubview(textStack)
        rootStack.addArrangedSubview(iconContainerView)

        iconContainerView.addSubview(iconBackgroundView)
        iconBackgroundView.addSubview(iconImageView)

        addSubview(contentView)
        contentView.addSubview(rootStack)

        iconContainerView.snp.makeConstraints { make in
            make.width.equalTo(44)
            make.height.equalTo(48)
        }

        iconBackgroundView.snp.makeConstraints { make in
            make.width.height.equalTo(44)
            make.bottom.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalTo(iconBackgroundView)
            make.width.height.equalTo(44)
        }

        rootStack.snp.makeConstraints { make in
            make.edges.equalTo(contentView).inset(UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16))
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        }
    }

    func applyConfiguration() {
        guard let configuration else { return }

        titleLabel.attributedText = configuration.title.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )

        captionLabel.attributedText = configuration.caption.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )

        actionButton.configuration.content = .init(title: .plainString(configuration.buttonTitle))
        actionButton.configuration.action = configuration.action

        switch configuration.style {
        case .battery:
            iconBackgroundView.layer.cornerRadius = 12
            iconBackgroundView.backgroundColor = .Accent.blue
            iconImageView.image = .TKUIKit.Icons.Size24.flash.withRenderingMode(.alwaysTemplate)
            iconImageView.tintColor = .Constant.white
            iconImageView.snp.updateConstraints { make in
                make.width.height.equalTo(32)
            }
        case .trx:
            iconBackgroundView.layer.cornerRadius = 22
            iconBackgroundView.backgroundColor = .clear
            iconImageView.image = .App.Currency.Vector.trc20.withRenderingMode(.alwaysOriginal)
            iconImageView.tintColor = nil
            iconImageView.snp.updateConstraints { make in
                make.width.height.equalTo(44)
            }
        }
    }
}
