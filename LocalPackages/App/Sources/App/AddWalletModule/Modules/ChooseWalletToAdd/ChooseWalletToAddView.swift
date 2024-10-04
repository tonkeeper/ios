import UIKit
import TKUIKit

final class ChooseWalletToAddView: UIView, ConfigurableView {

  let continueButton = TKUIActionButton(category: .primary, size: .large)
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
    container.padding = .continueButtonPadding
    return container
  }()

  let collectionView = TKUICollectionView(
    frame: .zero,
    collectionViewLayout: UICollectionViewLayout()
  )
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .big)
    view.padding = .titleDescriptionPadding
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  struct Model {
    public let continueButtonModel: TKUIActionButton.Model
    public let continueButtonAction: () -> Void
    public let isContinueButtonEnabled: Bool
  }
  
  func configure(model: Model) {
    continueButton.configure(model: model.continueButtonModel)
    continueButton.addTapAction(model.continueButtonAction)
    continueButton.isEnabled = model.isContinueButtonEnabled
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    continueButtonContainer.layoutIfNeeded()
    collectionView.contentInset.bottom = continueButtonContainer.bounds.height - safeAreaInsets.bottom
  }
}

private extension ChooseWalletToAddView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    titleDescriptionView.backgroundColor = .Background.page
    
    addSubview(collectionView)
    addSubview(continueButtonContainer)
    
    continueButtonContainer.setViews([continueButton])
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    continueButtonContainer.snp.makeConstraints { make in
      make.bottom.left.right.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let titleBottomPadding: CGFloat = 32
  static let buttonsContainerSpacing: CGFloat = 16
}

private extension NSDirectionalEdgeInsets {
  static let titleDescriptionPadding = NSDirectionalEdgeInsets(
    top: 24,
    leading: 32,
    bottom: 16,
    trailing: 32
  )
}

private extension UIEdgeInsets {
  static let continueButtonPadding = UIEdgeInsets(
    top: 16,
    left: 32,
    bottom: 32,
    right: 32
  )
}
