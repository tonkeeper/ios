import UIKit
import TKUIKit

final class StakePoolDetailsView: UIView, ConfigurableView {
  
  let titleView = ModalTitleView()
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  
  let chooseButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  let chooseButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .chooseButtonContainerPadding
    return container
  }()
  
  // MARK: - Init
  
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
      let action: (() -> Void)
    }
    
    let title: ModalTitleView.Model
    let button: Button
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.title)
    chooseButton.configuration.content.title = .plainString(model.button.title)
    chooseButton.configuration.action = model.button.action
  }
}

// MARK: - Setup

private extension StakePoolDetailsView {
  func setup() {
    chooseButtonContainer.setViews([chooseButton])
    
    addSubview(collectionView)
    addSubview(chooseButtonContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    chooseButtonContainer.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.bottom.equalTo(self.safeAreaLayoutGuide)
    }
  }
}

private extension UIEdgeInsets {
  static let chooseButtonContainerPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
