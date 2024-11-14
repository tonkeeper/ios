import UIKit
import TKUIKit

final class NFTDetailsView: UIView {
  let navigationBar = TKUINavigationBar()
  let titleView = TKUINavigationBarTitleView()
  let scrollView = TKUIScrollView()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  let manageNFTContainerView = UIView()
  let informationView = NFTDetailsInformationView()
  let buttonsView = NFTDetailsButtonsView()
  let propertiesView = NFTDetailsPropertiesView()
  let detailsView = NFTDetailsDetailsView()
  
  func setManageNFTView(_ view: UIView) {
    manageNFTContainerView.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(manageNFTContainerView)
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    navigationBar.layoutIfNeeded()
    scrollView.contentInset.top = navigationBar.bounds.height
    scrollView.contentInset.bottom = safeAreaInsets.bottom
  }
  
  private func setup() {
    backgroundColor = .Background.page
  
    navigationBar.centerView = titleView
    navigationBar.scrollView = scrollView
    
    scrollView.contentInsetAdjustmentBehavior = .never
    
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    contentStackView.addArrangedSubview(manageNFTContainerView)
    contentStackView.addArrangedSubview(informationView)
    contentStackView.addArrangedSubview(buttonsView)
    contentStackView.addArrangedSubview(propertiesView)
    contentStackView.addArrangedSubview(detailsView)
    addSubview(navigationBar)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    contentStackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(scrollView)
      make.left.right.equalTo(scrollView)
      make.width.equalTo(scrollView)
    }
  }
}
