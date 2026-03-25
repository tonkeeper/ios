import TKUIKit
import UIKit

final class EthenaStakingDetailsView: TKView {
    let scrollView = TKUIScrollView()
    let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()
    let informationView = TokenDetailsInformationView()
    let buttonsView = TokenDetailsHeaderButtonsView()
    let stakingInfoView = EthenaStakingDetailsInfoView()
    let jettonButtonContainer = TKPaddingContainerView()
    let jettonButton = TKListItemButton()
    let jettonButtonDescriptionContainer = TKPaddingContainerView()
    let jettonButtonDescriptionLabel = TKActionLabel()
    let linksView = StakingDetailsLinksView()

    override func setup() {
        super.setup()
        backgroundColor = .Background.page

        scrollView.contentInsetAdjustmentBehavior = .never

        navigationBar.scrollView = scrollView
        navigationBar.centerView = titleView

        jettonButton.isCornerRadius = true

        jettonButtonDescriptionLabel.numberOfLines = 0
        jettonButtonDescriptionContainer.setViews([jettonButtonDescriptionLabel])
        jettonButtonDescriptionContainer.padding = UIEdgeInsets(top: 12, left: 17, bottom: 16, right: 17)

        jettonButtonContainer.setViews([jettonButton])
        jettonButtonContainer.padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        jettonButtonDescriptionLabel.numberOfLines = 0
        jettonButtonDescriptionContainer.setViews([jettonButtonDescriptionLabel])
        jettonButtonDescriptionContainer.padding = UIEdgeInsets(top: 12, left: 17, bottom: 16, right: 17)

        let linksViewContainer = TKPaddingContainerView()
        linksViewContainer.setViews([linksView])
        linksViewContainer.padding = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)

        stakingInfoView.isHidden = true

        addSubview(scrollView)
        addSubview(navigationBar)
        scrollView.addSubview(contentStackView)
        contentStackView.addArrangedSubview(informationView)
        contentStackView.addArrangedSubview(buttonsView)
        contentStackView.addArrangedSubview(stakingInfoView)
        contentStackView.addArrangedSubview(jettonButtonContainer)
        contentStackView.addArrangedSubview(jettonButtonDescriptionContainer)
        contentStackView.addArrangedSubview(linksViewContainer)

        setupConstraints()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.layoutIfNeeded()
        scrollView.contentInset.top = navigationBar.bounds.height
        scrollView.contentInset.bottom = safeAreaInsets.bottom + 16
    }

    func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(self)
            make.width.equalTo(self).priority(.high)
        }

        contentStackView.snp.makeConstraints { make in
            make.top.equalTo(self.scrollView)
            make.left.right.bottom.equalTo(self.scrollView).priority(.high)
            make.width.equalTo(scrollView)
            make.bottom.equalTo(scrollView)
        }
    }
}

private extension CGFloat {
    static let contentPadding: CGFloat = 16
}
