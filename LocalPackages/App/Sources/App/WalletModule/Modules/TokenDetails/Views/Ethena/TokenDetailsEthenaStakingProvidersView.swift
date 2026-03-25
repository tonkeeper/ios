import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

final class TokenDetailsEthenaStakingProvidersView: UIView {
    struct Configuration: TokenDetailsBannerItem {
        let providersConfigurations: [TKListItemButton.Configuration]

        func getView() -> UIView {
            let view = TokenDetailsEthenaStakingProvidersView()
            view.configuration = self
            return view
        }
    }

    var configuration: Configuration = Configuration(providersConfigurations: []) {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let contentView = UIView()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .Background.page
        contentView.backgroundColor = .Background.content

        stackView.axis = .vertical

        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        addSubview(contentView)
        contentView.addSubview(stackView)

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
    }

    private func didUpdateConfiguration() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for configuration in configuration.providersConfigurations {
            let button = TKListItemButton()
            button.configuration = configuration
            stackView.addArrangedSubview(button)
        }
    }
}
