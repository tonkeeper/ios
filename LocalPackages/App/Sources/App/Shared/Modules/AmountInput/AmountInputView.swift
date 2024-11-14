import UIKit
import TKUIKit

final class AmountInputView: UIView {
  private let inputBackgroundContainerView = UIView()
  let valueView = AmountInputValueView()
  let balanceView = AmountInputBalanceView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    inputBackgroundContainerView.backgroundColor = .Background.content
    inputBackgroundContainerView.layer.cornerRadius = 16
    
    addSubview(inputBackgroundContainerView)
    addSubview(balanceView)
    inputBackgroundContainerView.addSubview(valueView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    inputBackgroundContainerView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self).inset(UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0))
      make.height.equalTo(188)
    }
    
    valueView.snp.makeConstraints { make in
      make.edges.equalTo(inputBackgroundContainerView).inset(UIEdgeInsets(top: 28, left: 0, bottom: 34, right: 0))
    }
    
    balanceView.snp.makeConstraints { make in
      make.height.equalTo(48)
      make.top.equalTo(inputBackgroundContainerView.snp.bottom)
      make.left.right.equalTo(inputBackgroundContainerView)
      make.bottom.equalTo(self)
    }
  }
}
