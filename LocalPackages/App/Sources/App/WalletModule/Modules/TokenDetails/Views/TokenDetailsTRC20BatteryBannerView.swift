import TKLocalize
import TKUIKit
import UIKit

final class TokenDetailsTRC20BatteryBannerView: UIView {
    struct Configuration: TokenDetailsBannerItem {
        func getView() -> UIView {
            let view = TokenDetailsTRC20BatteryBannerView()
            view.configuration = self
            return view
        }

        let chargeButtonAction: (() -> Void)?
    }

    var configuration: Configuration = Configuration(chargeButtonAction: nil) {
        didSet {
            chargeButton.configuration.action = { [weak self] in
                self?.configuration.chargeButtonAction?()
            }
        }
    }

    private let chargeButton = TKButton()
    private let contentView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        contentView.backgroundColor = .Background.content
        contentView.layer.cornerRadius = 16

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.attributedText = TKLocales.TokenDetails.Trc20.Usdt.BatteryBanner.title
            .withTextStyle(
                .label1,
                color: .Text.primary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )

        let captionLabel = UILabel()
        captionLabel.numberOfLines = 0
        captionLabel.attributedText = TKLocales.TokenDetails.Trc20.Usdt.BatteryBanner.caption
            .withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )

        chargeButton.configuration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .small
        )
        chargeButton.configuration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.TokenDetails.Trc20.Usdt.BatteryBanner.chargeButton)
        )

        let iconImageViewContainer = UIView()

        let iconImageView = UIImageView()
        iconImageView.image = .App.Images.Battery.batteryBanner

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16

        iconImageViewContainer.addSubview(iconImageView)

        let leftStackView = UIStackView()
        leftStackView.axis = .vertical
        leftStackView.alignment = .leading

        leftStackView.addArrangedSubview(titleLabel)
        leftStackView.addArrangedSubview(captionLabel)
        leftStackView.addArrangedSubview(chargeButton)

        leftStackView.setCustomSpacing(12, after: captionLabel)

        stackView.addArrangedSubview(leftStackView)
        stackView.addArrangedSubview(iconImageViewContainer)

        addSubview(contentView)
        contentView.addSubview(stackView)

        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(44)
            make.top.left.right.equalTo(iconImageViewContainer)
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(contentView).inset(UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16))
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        }
    }
}
