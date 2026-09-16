import TKUIKit
import UIKit

final class StakingBalanceDetailsView: TKView {
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
    let jettonButtonContainer = TKPaddingContainerView()
    let jettonButton = TKListItemButton()
    let jettonButtonDescriptionContainer = TKPaddingContainerView()
    let jettonButtonDescriptionLabel = UILabel()
    let stakeStateButton = TKListItemButton()
    let stakeStateButtonContainer = TKPaddingContainerView()
    let listView = StakingDetailsListView()
    let linksView = StakingDetailsLinksView()
    let descriptionLabel = UILabel()
    private let bottomSpacerView = UIView()

    override func setup() {
        super.setup()
        backgroundColor = .Background.page

        scrollView.contentInsetAdjustmentBehavior = .never

        navigationBar.scrollView = scrollView
        navigationBar.centerView = titleView
        bottomSpacerView.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)

        jettonButton.isCornerRadius = true
        stakeStateButton.isCornerRadius = true

        stakeStateButtonContainer.setViews([stakeStateButton])
        stakeStateButtonContainer.padding = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)

        jettonButtonDescriptionLabel.numberOfLines = 0
        jettonButtonDescriptionContainer.setViews([jettonButtonDescriptionLabel])
        jettonButtonDescriptionContainer.padding = UIEdgeInsets(top: 12, left: 17, bottom: 16, right: 17)

        jettonButtonContainer.setViews([jettonButton])
        jettonButtonContainer.padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        jettonButtonDescriptionLabel.numberOfLines = 0
        jettonButtonDescriptionContainer.setViews([jettonButtonDescriptionLabel])
        jettonButtonDescriptionContainer.padding = UIEdgeInsets(top: 12, left: 17, bottom: 16, right: 17)

        descriptionLabel.numberOfLines = 0
        let descriptionLabelContainer = TKPaddingContainerView()
        descriptionLabelContainer.setViews([descriptionLabel])
        descriptionLabelContainer.padding = UIEdgeInsets(top: 12, left: 17, bottom: 16, right: 17)

        let listViewContainer = TKPaddingContainerView()
        listViewContainer.setViews([listView])
        listViewContainer.padding = UIEdgeInsets(top: 8, left: 16, bottom: 0, right: 16)

        let linksViewContainer = TKPaddingContainerView()
        linksViewContainer.setViews([linksView])
        linksViewContainer.padding = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)

        addSubview(scrollView)
        addSubview(navigationBar)
        scrollView.addSubview(contentStackView)
        contentStackView.addArrangedSubview(informationView)
        contentStackView.addArrangedSubview(buttonsView)
        contentStackView.addArrangedSubview(stakeStateButtonContainer)
        contentStackView.addArrangedSubview(jettonButtonContainer)
        contentStackView.addArrangedSubview(jettonButtonDescriptionContainer)
        contentStackView.addArrangedSubview(listViewContainer)
        contentStackView.addArrangedSubview(descriptionLabelContainer)
        contentStackView.addArrangedSubview(linksViewContainer)
        contentStackView.addArrangedSubview(bottomSpacerView)

        setupConstraints()
        updateScrollViewInsets()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateScrollViewInsets()
    }

    func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.bottom.right.equalTo(self)
        }

        contentStackView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.greaterThanOrEqualTo(scrollView.frameLayoutGuide)
        }
    }

    private func updateScrollViewInsets() {
        scrollView.contentInset.bottom = safeAreaInsets.bottom
        scrollView.verticalScrollIndicatorInsets.bottom = safeAreaInsets.bottom
    }
}
