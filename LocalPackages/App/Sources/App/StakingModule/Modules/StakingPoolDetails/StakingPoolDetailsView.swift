import UIKit
import TKUIKit

final class StakingPoolDetailsView: TKView {
  let navigationBar = TKUINavigationBar()
  let titleView = TKUINavigationBarTitleView()
  let scrollView = TKUIScrollView()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .init(
      top: .contentPadding,
      leading: .contentPadding,
      bottom: .contentPadding,
      trailing: .contentPadding
    )
    
    return stackView
  }()
  
  let listView = StakingDetailsListView()
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  let continueButtonContainer = TKPaddingContainerView()
  let descriptionLabel = UILabel()
  let descriptionLabelContainer = TKPaddingContainerView()
  let linksView = StakingDetailsLinksView()
  
  override func setup() {
    super.setup()
    backgroundColor = .Background.page
    
    navigationBar.centerView = titleView
    
    descriptionLabel.numberOfLines = 0
    descriptionLabelContainer.setViews([descriptionLabel])
    descriptionLabelContainer.padding = UIEdgeInsets(top: 12, left: 1, bottom: 16, right: 1)
    
    addSubview(scrollView)
    addSubview(navigationBar)
    scrollView.addSubview(contentStackView)
    contentStackView.addArrangedSubview(listView)
    contentStackView.addArrangedSubview(descriptionLabelContainer)
    contentStackView.addArrangedSubview(linksView)
    
    continueButtonContainer.setViews([continueButton])
    continueButtonContainer.padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    addSubview(continueButtonContainer)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    continueButtonContainer.snp.makeConstraints { make in
      make.left.bottom.right.equalTo(self)
    }
    
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self).priority(.high)
    }
    
    contentStackView.snp.makeConstraints { make in
      make.top.equalTo(self.scrollView)
      make.left.right.bottom.equalTo(self.scrollView).priority(.high)
      make.width.equalTo(scrollView)
    }
    
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let contentPadding: CGFloat = 16
}
