import UIKit
import TKUIKit

final class NFTDetailsDetailsView: UIView, ConfigurableView {
  
  struct Model {
    let headerViewModel: NFTDetailsSectionHeaderView.Model
    let listViewConfiguration: TKListContainerView.Configuration
  }
  
  func configure(model: Model) {
    headerView.configure(model: model.headerViewModel)
    listView.configuration = model.listViewConfiguration
  }

  private let headerView = NFTDetailsSectionHeaderView()
  private let listView = TKListContainerView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(headerView)
    addSubview(listView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    headerView.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.left.right.equalTo(self).inset(18)
    }
    listView.snp.makeConstraints { make in
      make.top.equalTo(headerView.snp.bottom)
      make.left.right.equalTo(self).inset(16)
      make.bottom.equalTo(self)
    }
  }
}
