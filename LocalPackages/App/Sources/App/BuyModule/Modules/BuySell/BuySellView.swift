import UIKit
import TKUIKit
import SnapKit

final class BuySellView: UIView {
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
    
  let amountInputView = BuySellAmountInputView()
  
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
    
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    amountInputView.layer.cornerRadius = .contentCornerRadius
    
    addSubview(collectionView)
    addSubview(continueButton)
    
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
      
    continueButton.snp.makeConstraints { make in
      make.bottom.equalTo(self.safeAreaLayoutGuide).inset(CGFloat.contentVerticalPadding)
      make.leading.equalTo(self).offset(CGFloat.contentHorizontalMargin)
      make.trailing.equalTo(self).inset(CGFloat.contentHorizontalMargin)
    }
  }
}

private extension CGFloat {
  static let contentCornerRadius: CGFloat = 16
  static let contentVerticalPadding: CGFloat = 16
  static let contentHorizontalMargin: CGFloat = 16
}
