import UIKit
import TKUIKit

final class WalletContainerView: UIView, ConfigurableView {
  
  let topBarView = WalletContainerTopBarView()
  let walletBalanceContainerView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let topBarViewModel: WalletContainerTopBarView.Model
  }
  
  func configure(model: Model) {
    topBarView.configure(model: model.topBarViewModel)
  }
}

private extension WalletContainerView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(topBarView)
    addSubview(walletBalanceContainerView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    topBarView.translatesAutoresizingMaskIntoConstraints = false
    walletBalanceContainerView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      topBarView.topAnchor.constraint(equalTo: topAnchor),
      topBarView.leftAnchor.constraint(equalTo: leftAnchor),
      topBarView.rightAnchor.constraint(equalTo: rightAnchor),
      
      walletBalanceContainerView.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
      walletBalanceContainerView.leftAnchor.constraint(equalTo: leftAnchor),
      walletBalanceContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
      walletBalanceContainerView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
