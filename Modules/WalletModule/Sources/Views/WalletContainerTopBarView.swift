import UIKit
import TKUIKit

final class WalletContainerTopBarView: UIView, ConfigurableView {
  
  private let contentContainerView = UIView()
  private let walletButton = WalletContainerWalletButton()
  private let settingsButton = TKUIHeaderAccentIconButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let walletButtonModel: WalletContainerWalletButton.Model
    let walletButtonAppearance: WalletContainerWalletButton.Appearance
    let settingsButtonModel: TKUIHeaderAccentIconButton.Model
  }
  
  func configure(model: Model) {
    walletButton.configure(model: model.walletButtonModel)
    walletButton.appearance = model.walletButtonAppearance
    settingsButton.configure(model: model.settingsButtonModel)
  }
}

private extension WalletContainerTopBarView {
  func setup() {
    settingsButton.foregroundColor = .Icon.secondary
    settingsButton.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    
    backgroundColor = .Background.page
    contentContainerView.backgroundColor = .Background.page
    
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
    ])
  }
}

private extension CGFloat {
  static let walletButtonTopInset: CGFloat = 12
  static let walletButtonBottomInset: CGFloat = 12
  static let settingsButtonRightInset: CGFloat = 8
}
