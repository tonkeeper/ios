import UIKit
import TKUIKit
import SnapKit

final class BuySellOperatorView: UIView, ConfigurableView {
  
  let titleView = ModalTitleView()
  
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .continueButtonContainerPadding
    return container
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Button {
      let title: String
      let isEnabled: Bool
      let isActivity: Bool
      let action: (() -> Void)
    }
    
    let title: ModalTitleView.Model
    let button: Button
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.title)
    continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.button.title))
    continueButton.configuration.isEnabled = model.button.isEnabled
    continueButton.configuration.showsLoader = model.button.isActivity
    continueButton.configuration.action = model.button.action
  }
}

private extension BuySellOperatorView {
  func setup() {
    addSubview(collectionView)
    continueButtonContainer.setViews([continueButton])
    addSubview(continueButtonContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    continueButtonContainer.snp.makeConstraints { make in
      make.bottom.equalTo(self.safeAreaLayoutGuide)
      make.left.right.equalTo(self)
    }
  }
}

private extension UIEdgeInsets {
  static let continueButtonContainerPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
