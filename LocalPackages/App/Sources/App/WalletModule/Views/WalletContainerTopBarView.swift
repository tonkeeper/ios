import UIKit
import TKUIKit

final class WalletContainerTopBarView: UIView, ConfigurableView {
  
  private let contentContainerView = UIView()
  private let walletButton = TKButton()
  private let settingsButton = TKButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let walletButtonConfiguration: TKButton.Configuration
    let settingButtonConfiguration: TKButton.Configuration
  }
  
  func configure(model: Model) {
    walletButton.configuration = model.walletButtonConfiguration
    settingsButton.configuration = model.settingButtonConfiguration
  }
}

private extension WalletContainerTopBarView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentContainerView)
    contentContainerView.addSubview(settingsButton)
    contentContainerView.addSubview(walletButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentContainerView.translatesAutoresizingMaskIntoConstraints = false
    walletButton.translatesAutoresizingMaskIntoConstraints = false
    settingsButton.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentContainerView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      contentContainerView.leftAnchor.constraint(equalTo: leftAnchor),
      contentContainerView.rightAnchor.constraint(equalTo: rightAnchor),
      contentContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      settingsButton.rightAnchor.constraint(equalTo: contentContainerView.rightAnchor, constant: -.settingsButtonRightInset),
      settingsButton.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor),
      
      walletButton.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: .walletButtonTopInset),
      walletButton.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor, constant: -.walletButtonBottomInset),
      walletButton.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
      walletButton.widthAnchor.constraint(lessThanOrEqualToConstant: .walletButtonMaxWidth)
    ])
  }
}

private extension CGFloat {
  static let walletButtonTopInset: CGFloat = 12
  static let walletButtonBottomInset: CGFloat = 12
  static let walletButtonMaxWidth: CGFloat = 200
  static let settingsButtonRightInset: CGFloat = 8
}
