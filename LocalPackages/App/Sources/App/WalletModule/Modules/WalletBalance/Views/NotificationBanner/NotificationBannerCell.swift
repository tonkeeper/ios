import TKUIKit
import UIKit

final class NotificationBannerCell: UICollectionViewCell {
    struct Configuration {
        let bannerViewConfiguration: NotificationBannerView.Model

        init(bannerViewConfiguration: NotificationBannerView.Model) {
            self.bannerViewConfiguration = bannerViewConfiguration
        }

        static var `default`: Configuration {
            Configuration(
                bannerViewConfiguration: NotificationBannerView.Model(
                    title: nil,
                    caption: nil,
                    appearance: .regular
                )
            )
        }
    }

    var configuration = Configuration(
        bannerViewConfiguration: NotificationBannerView.Model(
            title: nil,
            caption: nil,
            appearance: .regular,
            closeButton: nil
        )
    ) {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    let bannerView = NotificationBannerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        contentView.addSubview(bannerView)
        bannerView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
        didUpdateConfiguration()
    }

    private func didUpdateConfiguration() {
        bannerView.configure(model: configuration.bannerViewConfiguration)
    }
}
