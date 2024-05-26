import UIKit
import TKUIKit
import SnapKit

final class BuySellView: UIView, ConfigurableView {
  
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  
  let amountInputView = BuySellAmountInputView()
  
  let tabButtonsContainerView = TabButtonsContainerView(
    model: .init(tabButtons: [
      .init(id: 0, title: "Buy"),
      .init(id: 1, title: "Sell")
    ])
  )
  
  let changeCountryButton = TKButton(
    configuration: .iconHeaderButtonConfiguration(
      contentPadding: .init(top: 6, left: 12, bottom: 6, right: 12),
      padding: .init(top: 8, left: 8, bottom: 8, right: 8)
    )
  )
  
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
    setup()
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
    
    let input: BuySellAmountInputView.Model
    let button: Button
  }
  
  func configure(model: Model) {
    amountInputView.configure(model: model.input)
    continueButton.configuration.content.title = .plainString(model.button.title)
    continueButton.configuration.isEnabled = model.button.isEnabled
    continueButton.configuration.showsLoader = model.button.isActivity
    continueButton.configuration.action = model.button.action
  }
}

// MARK: - Setup

private extension BuySellView {
  func setup() {
    amountInputView.layer.cornerRadius = .contentCornerRadius
    
    addSubview(collectionView)
    continueButtonContainer.setViews([continueButton])
    addSubview(continueButtonContainer)
    
    changeCountryButton.configuration.content.title = .plainString("AA")
    
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

private extension CGFloat {
  static let contentCornerRadius: CGFloat = 16
}

private extension UIEdgeInsets {
  static let continueButtonContainerPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
