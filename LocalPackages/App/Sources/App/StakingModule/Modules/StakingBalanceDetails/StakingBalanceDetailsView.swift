import UIKit
import TKUIKit

final class StakingBalanceDetailsView: TKView {
  let scrollView = TKUIScrollView()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    
    return stackView
  }()
  
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
  
  override func setup() {
    super.setup()
    backgroundColor = .Background.page
    
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
    scrollView.addSubview(contentStackView)
    contentStackView.addArrangedSubview(informationView)
    contentStackView.addArrangedSubview(buttonsView)
    contentStackView.addArrangedSubview(stakeStateButtonContainer)
    contentStackView.addArrangedSubview(jettonButtonContainer)
    contentStackView.addArrangedSubview(jettonButtonDescriptionContainer)
    contentStackView.addArrangedSubview(listViewContainer)
    contentStackView.addArrangedSubview(descriptionLabelContainer)
    contentStackView.addArrangedSubview(linksViewContainer)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
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
