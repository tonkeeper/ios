import UIKit
import TKUIKit

final class NFTDetailsPropertiesView: UIView, ConfigurableView {
  
  struct Model {
    let headerViewModel: NFTDetailsSectionHeaderView.Model
    let propertyViewsModels: [NFTDetailsPropertyView.Model]
  }
  
  func configure(model: Model) {
    headerView.configure(model: model.headerViewModel)
    
    propertiesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.propertyViewsModels.forEach {
      let view = NFTDetailsPropertyView()
      view.configure(model: $0)
      propertiesStackView.addArrangedSubview(view)
    }
  }
  
  private let headerView = NFTDetailsSectionHeaderView()
  private let scrollView: UIScrollView = {
    let scrollView = UIScrollView()
    scrollView.showsHorizontalScrollIndicator = false
    return scrollView
  }()
  private let propertiesStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = .propertiesSpacing
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    scrollView.contentInset.left = 16
    scrollView.contentInset.right = 16
    
    addSubview(headerView)
    addSubview(scrollView)
    scrollView.addSubview(propertiesStackView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    headerView.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.left.right.equalTo(self).inset(18)
    }
    scrollView.snp.makeConstraints { make in
      make.top.equalTo(headerView.snp.bottom)
      make.left.right.equalTo(self)
      make.bottom.equalTo(self).offset(-CGFloat.scrollViewBottomSpace)
      make.height.equalTo(CGFloat.scrollViewHeight)
    }
    propertiesStackView.snp.makeConstraints { make in
      make.edges.height.equalTo(scrollView)
    }
  }
}

private extension CGFloat {
  static let propertiesSpacing: CGFloat = 12
  static let scrollViewHeight: CGFloat = 70
  static let scrollViewBottomSpace: CGFloat = 20
}
