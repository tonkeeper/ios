import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

final class TokenDetailsEthenaBalanceView: UIView {
    struct Configuration: TokenDetailsBannerItem {
        let usdeBalanceConfiguration: TKListItemButton.Configuration
        let stakingBalanceConfiguration: TKListItemButton.Configuration?

        func getView() -> UIView {
            let view = TokenDetailsEthenaBalanceView()
            view.configuration = self
            return view
        }
    }

    var configuration: Configuration = Configuration(
        usdeBalanceConfiguration: .init(listItemConfiguration: .default, isEnable: true, tapClosure: nil),
        stakingBalanceConfiguration: .init(listItemConfiguration: .default, isEnable: true, tapClosure: nil)
    ) {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let contentView = UIView()
    private let stackView = UIStackView()
    private let usdeBalanceView = TKListItemButton()
    private let stakingBalanceView = TKListItemButton()

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

        stackView.addArrangedSubview(usdeBalanceView)
        stackView.addArrangedSubview(stakingBalanceView)
    }

    private func didUpdateConfiguration() {
        usdeBalanceView.configuration = configuration.usdeBalanceConfiguration
        if let stakingBalanceConfiguration = configuration.stakingBalanceConfiguration {
            stakingBalanceView.isHidden = false
            stakingBalanceView.configuration = stakingBalanceConfiguration
        } else {
            stakingBalanceView.isHidden = true
        }
    }
}
