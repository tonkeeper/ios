import TKUIKit
import UIKit

struct TransactionConfirmationHeaderImageItem: TKPopUp.Item {
    func getView() -> UIView {
        TransactionConfirmationHeaderImageItemView(configuration: configuration)
    }

    let configuration: TransactionConfirmationHeaderImageItemView.Configuration
    let bottomSpace: CGFloat
}

final class TransactionConfirmationHeaderImageItemView: UIView {
    struct Configuration {
        struct Badge {
            let image: TKImage
            let backgroundColor: UIColor
            let size: TKListItemBadgeView.Configuration.Size
            init(
                image: TKImage,
                backgroundColor: UIColor = .Background.page,
                size: TKListItemBadgeView.Configuration.Size = .xlarge
            ) {
                self.image = image
                self.backgroundColor = backgroundColor
                self.size = size
            }
        }

        let imageViewModel: TKImageView.Model
        let backgroundColor: UIColor
        let badge: Badge?

        init(
            imageViewModel: TKImageView.Model,
            backgroundColor: UIColor = .clear,
            badge: Badge?
        ) {
            self.imageViewModel = imageViewModel
            self.backgroundColor = backgroundColor
            self.badge = badge
        }

        init(
            image: TKImage,
            corners: TKImageView.Corners,
            badge: Badge?
        ) {
            self.imageViewModel = TKImageView.Model(
                image: image,
                size: .size(CGSize(width: 96, height: 96)),
                corners: corners
            )
            self.backgroundColor = .clear
            self.badge = badge
        }
    }

    let configuration: Configuration

    let iconView = TKListItemIconView()

    init(configuration: Configuration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(iconView)

        var badge: TKListItemIconView.Configuration.Badge?
        if let configurationBadge = configuration.badge {
            badge = TKListItemIconView.Configuration.Badge(
                configuration: TKListItemBadgeView.Configuration(
                    item: .image(configurationBadge.image),
                    size: configurationBadge.size,
                    tintColor: .Constant.white,
                    backgroundColor: configurationBadge.backgroundColor
                ),
                position: .bottomRight
            )
        }

        iconView.configuration = TKListItemIconView.Configuration(
            content: .image(
                configuration.imageViewModel
            ),
            alignment: .center,
            cornerRadius: 12,
            backgroundColor: configuration.backgroundColor,
            size: CGSize(width: 96, height: 96),
            badge: badge
        )

        iconView.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
            make.center.equalTo(self)
            make.width.height.equalTo(96)
        }
    }
}
