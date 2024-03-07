import UIKit
import TKUIKit

final class WalletContainerTopBarView: UIView, ConfigurableView {
  
  private let contentContainerView = UIView()
  private let walletButton = WalletContainerWalletButton()
  private let settingsButton = TKUIHeaderAccentIconButton()
  private let blurView: UIVisualEffectView = {
    let blurEffect = UIBlurEffect(style: .systemChromeMaterialDark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    return blurView
  }()
  
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
    let walletButtonAction: () -> Void
    let settingsButtonModel: TKUIHeaderAccentIconButton.Model
    let settingsButtonAction: () -> Void
  }
  
  func configure(model: Model) {
    walletButton.configure(model: model.walletButtonModel)
    walletButton.appearance = model.walletButtonAppearance
    settingsButton.configure(model: model.settingsButtonModel)
    
    walletButton.addTapAction(model.walletButtonAction)
    settingsButton.addTapAction(model.settingsButtonAction)
  }
}

private extension WalletContainerTopBarView {
  func setup() {
    settingsButton.foregroundColor = .Icon.secondary
    settingsButton.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    addSubview(blurView)
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
    
    blurView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let walletButtonTopInset: CGFloat = 12
  static let walletButtonBottomInset: CGFloat = 12
  static let walletButtonMaxWidth: CGFloat = 200
  static let settingsButtonRightInset: CGFloat = 8
}
