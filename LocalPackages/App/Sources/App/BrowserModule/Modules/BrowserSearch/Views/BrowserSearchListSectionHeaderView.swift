import UIKit
import TKUIKit

final class BrowserSearchListSectionHeaderView: UICollectionReusableView {

  private let titleView = TKListTitleView()

  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(titleView)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    titleView.snp.makeConstraints { make in
      make.left.equalTo(self)
      make.centerY.equalTo(self)
    }
  }
}

// MARK: -  ConfigurableView

extension BrowserSearchListSectionHeaderView: ConfigurableView {

  struct Model: Hashable {
    let titleModel: TKListTitleView.Model
  }

  func configure(model: Model) {
    titleView.configure(model: model.titleModel)
  }
}
